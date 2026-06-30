class BluetoothService : Object {
    private static BluetoothService instance = null;
    public static BluetoothService get_default() {
        if (instance == null) {
            debug("initializing BluetoothService");
            instance = new BluetoothService();
        }
        return instance;
    }

    private AstalBluetooth.Bluetooth bluetooth;
    private ulong adapter_connect_id;

    public AstalBluetooth.Adapter adapter { get; private set; }
    public bool is_available { get; private set; default = false; }
    public bool is_powered {
        get {
            var adapter = bluetooth.adapters.nth_data(0);
            return adapter != null ? adapter.powered : false;
        }
        set {
            var adapter = bluetooth.adapters.nth_data(0);
            if (adapter != null) {
                adapter.powered = value;
            }
        }
    }
    public ListStore connected_devices { get; private set; }
    public double min_battery { get; private set; }
    /** The paired, but NOT connected devices. */
    public ListStore paired_devices { get; private set; }

    public BluetoothService() {
        assert_null(instance);

        bluetooth = AstalBluetooth.get_default();
        bluetooth.notify["adapters"].connect(handle_adapter_change);
        handle_adapter_change();

        connected_devices = new ListStore(typeof(AstalBluetooth.Device));
        paired_devices = new ListStore(typeof(AstalBluetooth.Device));
        bluetooth.device_added.connect(handle_device_add);
        bluetooth.device_removed.connect(handle_device_remove);
        foreach (var device in bluetooth.devices) {
            handle_device_add(device);
        }
    }

    private void handle_adapter_change() {
        var new_adapter = bluetooth.adapters.nth_data(0);

        if (adapter != null && adapter_connect_id != 0) {
            adapter.disconnect(adapter_connect_id);
            adapter_connect_id = 0;
        }
        adapter = new_adapter;
        if (new_adapter != null) {
            adapter_connect_id = new_adapter.notify["powered"].connect(handle_powered_update);
        }
        notify_property("is-powered");

        is_available = adapter != null;
    }

    private void handle_powered_update() {
        notify_property("is-powered");
    }

    private static void add_device_to_set(ListStore device_set, AstalBluetooth.Device device) {
        var count = device_set.n_items;
        for (int i = 0; i < count; i++) {
            if (device_set.get_item(i) == device) {
                return;
            }
        }
        device_set.append(device);
    }

    private static void remove_device_from_set(ListStore device_set, AstalBluetooth.Device device) {
        var count = device_set.n_items;
        for (int i = 0; i < count; i++) {
            if (device_set.get_item(i) == device) {
                device_set.remove(i);
                return;
            }
        }
    }

    private void handle_device_connected(Object obj, ParamSpec p) {
        var device = (AstalBluetooth.Device)obj;
        if (device.connected) {
            add_device_to_set(connected_devices, device);
            remove_device_from_set(paired_devices, device);
        } else {
            remove_device_from_set(connected_devices, device);
            if (device.paired) {
                add_device_to_set(paired_devices, device);
            }
        }
        update_min_battery();
    }

    private void handle_device_paired(Object obj, ParamSpec p) {
        var device = (AstalBluetooth.Device)obj;
        if (device.paired) {
            if (!device.connected) {
                add_device_to_set(paired_devices, device);
            }
        } else {
            remove_device_from_set(paired_devices, device);
        }
    }

    private void update_min_battery() {
        var new_min_battery = 9999.0;
        var connected_count = connected_devices.get_n_items();
        for (uint i = 0; i < connected_count; i++) {
            var device = (AstalBluetooth.Device)connected_devices.get_item(i);
            if (device.battery_percentage != -1) {
                new_min_battery = double.min(new_min_battery, device.battery_percentage);
            }
        }
        if (new_min_battery == 9999.0) {
            new_min_battery = 0;
        }
        min_battery = new_min_battery;
    }

    private void handle_device_add(AstalBluetooth.Device device) {
        device.notify["connected"].connect(handle_device_connected);
        device.notify["paired"].connect(handle_device_paired);
        // Tracking it in here is easier, and this doesn't run often enough to make a difference
        // I don't think unpaired devices even have this anyway
        device.notify["battery-percentage"].connect(update_min_battery);
        if (device.connected) {
            add_device_to_set(connected_devices, device);
            update_min_battery();
        } else if (device.paired) {
            add_device_to_set(paired_devices, device);
        }
    }

    private void handle_device_remove(AstalBluetooth.Device device) {
        device.notify["connected"].disconnect(handle_device_connected);
        device.notify["paired"].disconnect(handle_device_paired);
        device.notify["battery-percentage"].disconnect(update_min_battery);
        remove_device_from_set(connected_devices, device);
        remove_device_from_set(paired_devices, device);
        update_min_battery();
    }
}
