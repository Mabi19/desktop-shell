class BluetoothDeviceEntry : Gtk.Box {
    private Gtk.Image icon;
    private Gtk.Label label;
    private Adw.Spinner spinner;

    private AstalBluetooth.Device _device;
    public AstalBluetooth.Device device {
        get {
            return _device;
        }
        construct {
            _device = value;
        }
    }

    static construct {
        set_css_name("bt-entry");
    }

    construct {
        spacing = 8;

        icon = new Gtk.Image.from_icon_name(_device.icon);
        _device.bind_property("icon", icon, "icon-name", BindingFlags.DEFAULT);
        append(icon);
        label = new Gtk.Label(_device.alias);
        _device.bind_property("alias", label, "label", BindingFlags.DEFAULT);
        label.hexpand = true;
        label.halign = START;
        append(label);
        spinner = new Adw.Spinner();
        _device.bind_property("connecting", spinner, "visible", BindingFlags.SYNC_CREATE);
        append(spinner);
    }

    public BluetoothDeviceEntry(AstalBluetooth.Device device) {
        Object(device: device);
    }
}

[GtkTemplate(ui = "/land/mabi/shell/ui/bar/bluetooth/menu.ui")]
class BluetoothMenu : Gtk.Popover {
    internal BluetoothService service { get; private set; }

    [GtkChild]
    private unowned Gtk.ListBox connected_devices;
    [GtkChild]
    private unowned Gtk.ListBox paired_devices;
    [GtkChild]
    private unowned Gtk.Switch powered_switch;
    [GtkChild]
    private unowned Gtk.Button open_manager_button;

    private Gtk.Widget create_device_widget(Object device_obj) {
        var device = (AstalBluetooth.Device)device_obj;
        var entry = new BluetoothDeviceEntry(device);
        return entry;
    }


    [GtkCallback]
    void handle_connected_row_activated(Gtk.ListBoxRow row) {
        var entry = (BluetoothDeviceEntry)row.get_child();
        entry.device.disconnect_device.begin();
    }

    private async void connect_to_device(AstalBluetooth.Device device) {
        if (!device.connecting) {
            try {
                yield device.connect_device();
            } catch (Error e) {
                warning("Couldn't connect to Bluetooth device: %s", e.message);
            }
        }
    }

    [GtkCallback]
    void handle_paired_row_activated(Gtk.ListBoxRow row) {
        var entry = (BluetoothDeviceEntry)row.get_child();
        connect_to_device.begin(entry.device);
    }

    [GtkCallback]
    void open_device_manager() {
        unowned var cmd = MabiShell.config.bluetooth_manager_command;
        if (cmd == null) {
            return;
        }

        try {
            Process.spawn_command_line_async(cmd);
            popdown();
        } catch (SpawnError e) {
            warning("Couldn't spawn Bluetooth manager process: %s\n", e.message);
        }
    }

    private void handle_bt_manager_change() {
        if (MabiShell.config.bluetooth_manager_command != null) {
            open_manager_button.sensitive = true;
            open_manager_button.tooltip_text = null;
        } else {
            open_manager_button.sensitive = false;
            open_manager_button.tooltip_text = "This requires bluetooth_manager_command to be set in the config";
        }
    }

    construct {
        service = BluetoothService.get_default();
        connected_devices.bind_model(service.connected_devices, create_device_widget);
        paired_devices.bind_model(service.paired_devices, create_device_widget);

        service.bind_property("is-powered", powered_switch, "active",
                              BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);

        MabiShell.config.notify["bluetooth-manager-command"].connect(handle_bt_manager_change);
        handle_bt_manager_change();
    }

    public override void dispose() {
        dispose_template(typeof(BluetoothMenu));
        base.dispose();
    }
}
