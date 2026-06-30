class BluetoothButtonItem : Gtk.Box {
    private AstalBluetooth.Device device;
    private Gtk.Image icon;
    private Gtk.Label label;

    static construct {
        set_css_name("bluetooth-button-item");
    }

    public BluetoothButtonItem(AstalBluetooth.Device device) {
        this.device = device;
        spacing = 4;
        margin_start = 6;

        icon = new Gtk.Image();
        device.bind_property("icon", icon, "icon-name", BindingFlags.SYNC_CREATE);
        append(icon);

        label = new Gtk.Label("");
        device.notify["battery-percentage"].connect(this.update_battery);
        update_battery();
        append(label);

        device.bind_property("alias", this, "tooltip-text", BindingFlags.SYNC_CREATE);
    }

    private void update_battery() {
        if (device.battery_percentage == -1) {
            label.visible = false;
        } else {
            label.visible = true;
            label.label = "%.0f%%".printf(device.battery_percentage * 100);
        }
    }

    // Helper function to use this in a model box binding.
    public static BluetoothButtonItem create(AstalBluetooth.Device device) {
        return new BluetoothButtonItem(device);
    }
}
