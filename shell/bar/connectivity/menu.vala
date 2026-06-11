class AccessPointEntry : Gtk.Box {
    private Gtk.Image icon;
    private Gtk.Label label;
    private Gtk.Button settings_button;

    private WifiNetwork _network;
    public WifiNetwork network {
        get {
            return _network;
        }
        construct {
            _network = value;
        }
    }

    public signal void settings_clicked();

    private void update_strength() {
        uint8 strength = _network.best_strength;
        if (strength > 75) {
            icon.icon_name = "network-wireless-signal-excellent-symbolic";
        } else if (strength > 50) {
            icon.icon_name = "network-wireless-signal-good-symbolic";
        } else if (strength > 25) {
            icon.icon_name = "network-wireless-signal-ok-symbolic";
        } else if (strength > 0) {
            icon.icon_name = "network-wireless-signal-weak-symbolic";
        } else {
            icon.icon_name = "network-wireless-signal-none-symbolic";
        }
    }

    private void update_known() {
        var known = _network.connection != null;
        settings_button.visible = known;
        if (known) {
            add_css_class("known");
        } else {
            remove_css_class("known");
        }
    }

    static construct {
        set_css_name("ap-entry");
    }

    construct {
        spacing = 8;

        icon = new Gtk.Image.from_icon_name("network-wireless-symbolic");
        append(icon);
        label = new Gtk.Label(_network.display_ssid);
        label.hexpand = true;
        label.halign = START;
        append(label);
        settings_button = new Gtk.Button.from_icon_name("preferences-system-symbolic");
        settings_button.add_css_class("ap-settings");
        settings_button.add_css_class("flat");
        settings_button.clicked.connect(() => settings_clicked());
        append(settings_button);

        _network.notify["best-strength"].connect(update_strength);
        _network.notify["connection"].connect(update_known);
        update_known();
        update_strength();
    }

    public override void dispose() {
        _network.notify["best-strength"].disconnect(update_strength);
        _network.notify["connection"].disconnect(update_known);
        base.dispose();
    }

    public AccessPointEntry(WifiNetwork network) {
        Object(network: network);
    }
}

[GtkTemplate(ui = "/land/mabi/shell/ui/bar/connectivity/menu.ui")]
class ConnectivityMenu : Gtk.Popover {
    internal NetworkService service { get; private set; }

    [GtkChild]
    private unowned Gtk.ListBox access_points;
    [GtkChild]
    private unowned Gtk.ListBox active_access_point;
    [GtkChild]
    private unowned Gtk.Switch wifi_switch;

    private Gtk.Widget create_ap_widget(Object network_obj) {
        var network = (WifiNetwork)network_obj;
        var entry = new AccessPointEntry(network);
        entry.settings_clicked.connect(() => show_connection_editor(network));
        return entry;
    }

    private void show_new_connection_dialog(WifiNetwork network) {
        if (service.client == null || service.wifi == null) {
            return;
        }

        var connection = NM.SimpleConnection.new();
        connection.add_setting(new NM.SettingWireless() {
            ssid = network.ssid
        });
        connection.add_setting(new NM.SettingConnection() {
            uuid = NM.Utils.uuid_generate()
        });


        var root = get_root() as Gtk.Window;
        var dialog = new NMA.WifiDialog(service.client, connection, service.wifi, network.best_ap, false) {
            deletable = false,
            modal = true,
            transient_for = root
        };

        dialog.response.connect((response_id) => {
            // GTK_RESPONSE_OK
            if (response_id == -5) {
                NM.Device device;
                NM.AccessPoint ap;
                var new_conn = dialog.get_connection(out device, out ap);
                if (new_conn != null) {
                    service.add_and_activate_connection.begin(new_conn, ap);
                }
            }
            dialog.destroy();
        });

        dialog.present();
    }

    private void show_connection_editor(WifiNetwork network) {
        if (network.connection == null) {
            return;
        }

        var uuid = network.connection.get_uuid();
        try {
            Process.spawn_command_line_async("nm-connection-editor --edit=" + uuid);
            popdown();
        } catch (SpawnError e) {
            warning("Couldn't spawn nm-connection-editor: %s\n", e.message);
        }
    }

    private void handle_active_changed() {
        var net = service.active_wifi_network;
        if (net != null) {
            active_access_point.remove_all();
            var entry = new AccessPointEntry(net);
            entry.settings_clicked.connect(() => show_connection_editor(net));
            active_access_point.insert(entry, 0);
            active_access_point.visible = true;
        } else {
            active_access_point.visible = false;
        }
    }

    // Helper for showing sections
    [GtkCallback]
    bool is_non_null(void *p) {
        return p != null;
    }

    [GtkCallback]
    string format_ethernet_label(NM.DeviceState state, uint speed) {
        switch (state) {
        case NM.DeviceState.ACTIVATED:
            if (speed >= 1000) {
                return "%u Gb/s".printf(speed / 1000);
            } else {
                return "%u Mb/s".printf(speed);
            }
        case NM.DeviceState.DISCONNECTED:
            return "Disconnected";
        case NM.DeviceState.UNAVAILABLE:
            return "Unplugged";
        case NM.DeviceState.PREPARE:
        case NM.DeviceState.CONFIG:
        case NM.DeviceState.IP_CONFIG:
        case NM.DeviceState.IP_CHECK:
        case NM.DeviceState.SECONDARIES:
            return "Connecting...";
        default:
            return "";
        }
    }

    [GtkCallback]
    void handle_active_row_activated(Gtk.ListBoxRow row) {
        service.wifi.disconnect_async.begin(null);
    }

    [GtkCallback]
    void handle_available_row_activated(Gtk.ListBoxRow row) {
        var entry = (AccessPointEntry)row.get_child();
        if (entry.network.connection != null) {
            service.activate_network.begin(entry.network);
        } else {
            show_new_connection_dialog(entry.network);
        }
    }

    [GtkCallback]
    void open_connection_manager() {
        try {
            Process.spawn_command_line_async(MabiShell.config.connection_manager_command);
            popdown();
        } catch (SpawnError e) {
            warning("Couldn't spawn connection manager process: %s\n", e.message);
        }
    }

    construct {
        service = NetworkService.get_default();
        access_points.bind_model(service.wifi_networks, create_ap_widget);

        service.bind_property("wireless-enabled", wifi_switch, "active",
                              BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);

        service.notify["active-wifi-network"].connect(handle_active_changed);
        handle_active_changed();
    }

    public override void dispose() {
        dispose_template(typeof(ConnectivityMenu));
        base.dispose();
    }
}
