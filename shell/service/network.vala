class NetworkService : Object {
    private static NetworkService instance = null;
    public static NetworkService get_default() {
        if (instance == null) {
            debug("initializing NetworkService");
            instance = new NetworkService();
        }
        return instance;
    }

    private NM.Client _client;
    public NM.Client? client { get { return _client; } }

    public bool is_available { get; private set; default = false; }
    public NM.DeviceEthernet? ethernet { get; private set; default = null; }
    public NM.DeviceWifi? wifi { get; private set; default = null; }
    public bool wifi_is_primary { get; private set; default = false; }
    public string? primary_interface { get; private set; default = null; }
    public ListStore wifi_networks { get; private set; }
    public WifiNetwork? active_wifi_network { get; private set; default = null; }
    public bool is_scanning { get; private set; default = false; }
    public bool wireless_enabled {
        get {
            return client != null && client.wireless_enabled;
        }
        set {
            if (client != null) {
                client.wireless_enabled = value;
            }
        }
    }

    private static uint ssid_hash(Bytes b) {
        return b.hash();
    }

    private static bool ssid_equal(Bytes a, Bytes b) {
        return a.compare(b) == 0;
    }

    // BSSID -> owning network. NM differentiates APs by BSSID, so this
    // provides O(1) lookup for add/remove events and deduplication.
    private Gee.HashMap<string, WifiNetwork> bssid_map;
    // SSID -> network. Used to group APs sharing the same SSID into one
    // WifiNetwork object.
    private Gee.HashMap<Bytes, WifiNetwork> ssid_map;

    private int64 last_scan_before_request = -1;

    construct {
        wifi_networks = new ListStore(typeof(WifiNetwork));
        bssid_map = new Gee.HashMap<string, WifiNetwork>();
        ssid_map = new Gee.HashMap<Bytes, WifiNetwork>(ssid_hash, ssid_equal);
    }

    private void update_available() {
        is_available = (client != null && (ethernet != null || wifi != null));
    }

    private bool device_has_primary_connection(NM.Device device) {
        if (client == null || client.primary_connection == null) {
            return false;
        }

        foreach (var primary_device in client.primary_connection.devices) {
            if (device == primary_device) {
                return true;
            }
        }
        return false;
    }

    private void update_primary() {
        if (client == null || client.primary_connection == null || (wifi == null && ethernet == null)) {
            wifi_is_primary = false;
            primary_interface = null;
            return;
        }

        bool wifi_in_primary = false;
        bool ethernet_in_primary = false;
        foreach (var device in client.primary_connection.devices) {
            if (device == wifi) {
                wifi_in_primary = true;
            }
            if (device == ethernet) {
                ethernet_in_primary = true;
            }
        }

        if (ethernet_in_primary) {
            wifi_is_primary = false;
            primary_interface = ethernet.interface;
        } else if (wifi_in_primary) {
            wifi_is_primary = true;
            primary_interface = wifi.interface;
        } else {
            wifi_is_primary = false;
            primary_interface = null;
        }
    }

    private int device_priority(NM.Device device) {
        switch (device.state) {
        case NM.DeviceState.ACTIVATED:
            if (device.ip4_connectivity == FULL || device.ip6_connectivity == FULL) {
                return 900;
            }
            return 800;
        case NM.DeviceState.DISCONNECTED:
            return 700;
        case NM.DeviceState.UNAVAILABLE:
            return 600;
            default:
            return 0;
        }
    }

    private bool should_replace_device(NM.Device current, int current_priority, NM.Device candidate, int candidate_priority) {
        if (candidate_priority > current_priority) {
            return true;
        }
        if (candidate_priority < current_priority) {
            return false;
        }
        return candidate.interface.collate(current.interface) < 0;
    }

    private void update_devices() {
        NM.DeviceEthernet? new_ethernet = null;
        NM.DeviceWifi? new_wifi = null;
        int ethernet_priority = -1;
        int wifi_priority = -1;

        foreach (var device in client.devices) {
            int priority = device_priority(device);
            if (device_has_primary_connection(device)) {
                priority += 1000;
            }

            switch (device.device_type) {
            case NM.DeviceType.ETHERNET:
                if (new_ethernet == null || should_replace_device(new_ethernet, ethernet_priority, device, priority)) {
                    new_ethernet = (NM.DeviceEthernet)device;
                    ethernet_priority = priority;
                }
                break;
            case NM.DeviceType.WIFI:
                if (new_wifi == null || should_replace_device(new_wifi, wifi_priority, device, priority)) {
                    new_wifi = (NM.DeviceWifi)device;
                    wifi_priority = priority;
                }
                break;
            default:
                break;
            }
        }

        if (ethernet != new_ethernet) {
            if (new_ethernet != null) {
                debug("Selected ethernet device: %s (priority %d)", new_ethernet.interface, ethernet_priority);
            }
            ethernet = new_ethernet;
        }
        if (wifi != new_wifi) {
            if (new_wifi != null) {
                debug("Selected Wi-Fi device: %s (priority %d)", new_wifi.interface, wifi_priority);
            }
            wifi = new_wifi;
            is_scanning = false;

            bssid_map.clear();
            ssid_map.clear();
            wifi_networks.remove_all();
            active_wifi_network = null;

            if (wifi != null) {
                wifi.access_point_added.connect(on_access_point_added);
                wifi.access_point_removed.connect(on_access_point_removed);
                wifi.notify["active-access-point"].connect(on_active_access_point_changed);
                wifi.notify["last-scan"].connect(on_last_scan_changed);

                unowned var aps = wifi.get_access_points();
                for (uint i = 0; i < aps.length; i++) {
                    var ap = aps.get(i);
                    track_access_point(ap);
                }
            }
        }

        update_available();
        update_primary();
    }

    private void track_access_point(NM.AccessPoint ap) {
        if (bssid_map.has_key(ap.bssid)) {
            return;
        }

        var ssid = ap.ssid;
        if (ssid == null) {
            return;
        }

        WifiNetwork network;
        if (ssid_map.has_key(ssid)) {
            network = ssid_map[ssid];
        } else {
            network = new WifiNetwork(ssid);
            ssid_map[ssid] = network;
        }

        network.add_ap(ap);
        bssid_map[ap.bssid] = network;

        if (network.connection == null) {
            network.connection = find_connection_for_ap(ap);
        }

        if (wifi != null && ap == wifi.active_access_point) {
            active_wifi_network = network;
            uint pos;
            if (wifi_networks.find(network, out pos)) {
                wifi_networks.remove(pos);
            }
        } else if (active_wifi_network == null || active_wifi_network != network) {
            if (!network_in_list(network)) {
                wifi_networks.append(network);
                sort_wifi_networks();
            }
        }
    }

    private bool network_in_list(WifiNetwork network) {
        for (uint i = 0; i < wifi_networks.n_items; i++) {
            if (wifi_networks.get_item(i) == network) {
                return true;
            }
        }
        return false;
    }

    private void on_access_point_added(Object ap_obj) {
        var ap = (NM.AccessPoint)ap_obj;
        if (ap.ssid != null) {
            debug("AP %s added", NM.Utils.ssid_to_utf8(ap.ssid.get_data()));
        }
        track_access_point(ap);
    }

    private void on_access_point_removed(Object ap_obj) {
        var ap = (NM.AccessPoint)ap_obj;

        if (!bssid_map.has_key(ap.bssid)) {
            return;
        }

        var network = bssid_map[ap.bssid];
        bssid_map.unset(ap.bssid);
        network.remove_ap(ap);

        if (network.ap_count == 0) {
            ssid_map.unset(network.ssid);
            if (active_wifi_network == network) {
                active_wifi_network = null;
            } else {
                uint pos;
                if (wifi_networks.find(network, out pos)) {
                    wifi_networks.remove(pos);
                }
            }
        }
    }

    private void on_active_access_point_changed() {
        if (wifi == null) {
            active_wifi_network = null;
            return;
        }

        var active_ap = wifi.active_access_point;

        if (active_wifi_network != null) {
            var old_network = active_wifi_network;
            active_wifi_network = null;
            if (ssid_map.has_key(old_network.ssid) && !network_in_list(old_network)) {
                wifi_networks.append(old_network);
                sort_wifi_networks();
            }
        }

        if (active_ap != null) {
            if (!bssid_map.has_key(active_ap.bssid)) {
                track_access_point(active_ap);
            }
            var network = bssid_map[active_ap.bssid];
            uint pos;
            if (wifi_networks.find(network, out pos)) {
                wifi_networks.remove(pos);
            }
            active_wifi_network = network;
        }
    }

    private void sort_wifi_networks() {
        wifi_networks.sort((a, b) => {
            var na = (WifiNetwork)a;
            var nb = (WifiNetwork)b;
            if ((na.connection != null) != (nb.connection != null)) {
                return na.connection != null ? -1 : 1;
            }
            return (int)(nb.best_strength - na.best_strength);
        });
    }

    private void on_connections_changed() {
        foreach (var entry in ssid_map) {
            var best_ap = entry.value.best_ap;
            if (best_ap != null) {
                entry.value.connection = find_connection_for_ap(entry.value.best_ap);
            }
        }
        sort_wifi_networks();
    }

    private NM.RemoteConnection? find_connection_for_ap(NM.AccessPoint ap) {
        if (client == null) {
            return null;
        }
        var connections = client.get_connections();
        for (uint i = 0; i < connections.length; i++) {
            var conn = connections.get(i);
            if (ap.connection_valid(conn)) {
                return conn;
            }
        }
        return null;
    }

    public async void activate_network(WifiNetwork network) {
        if (_client == null || wifi == null || network.connection == null) {
            return;
        }
        try {
            yield _client.activate_connection_async(network.connection, wifi, null, null);
        } catch (Error e) {
            warning("Failed to activate connection to %s: %s", network.display_ssid, e.message);
        }
    }

    public async void add_and_activate_connection(NM.Connection connection, NM.AccessPoint ap) {
        if (_client == null || wifi == null) {
            return;
        }
        try {
            yield _client.add_and_activate_connection_async(connection, wifi, ap.get_path(), null);
        } catch (Error e) {
            warning("Failed to add and activate connection: %s", e.message);
        }
    }

    public async void request_scan() {
        if (wifi == null || !wireless_enabled) {
            return;
        }

        last_scan_before_request = wifi.last_scan;
        is_scanning = true;

        try {
            yield wifi.request_scan_async(null);
        } catch (Error e) {
            warning("Wi-Fi scan request failed: %s", e.message);
            is_scanning = false;
        }
    }

    private void on_last_scan_changed() {
        if (!is_scanning || wifi == null) {
            return;
        }
        if (wifi.last_scan != last_scan_before_request) {
            is_scanning = false;
        }
    }

    private async void acquire_nm() {
        try {
            _client = yield new NM.Client.async(null);
            update_devices();
            _client.notify["devices"].connect(update_devices);
            _client.notify["primary-connection"].connect(update_devices);
            _client.notify["active-connections"].connect(update_devices);
            _client.notify["connections"].connect(on_connections_changed);
            _client.notify["wireless-enabled"].connect(() => {
                notify_property("wireless-enabled");
            });
            notify_property("wireless-enabled");
        } catch (Error e) {
            warning("Couldn't connect to NetworkManager: %s", e.message);
            update_available();
        }
    }

    public NetworkService() {
        this.acquire_nm.begin();
    }
}
