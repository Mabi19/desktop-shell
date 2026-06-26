class BluetoothIndicator : LevelBin {
    private BluetoothService service;

    private Gtk.MenuButton menubutton;
    private Gtk.Box outer_box;
    private Gtk.Image icon;

    private Gtk.Box items;
    private ModelBoxBinding items_binding;

    construct {
        name = "bluetooth";

        service = BluetoothService.get_default();
        service.bind_property("is-available", this, "visible", BindingFlags.SYNC_CREATE);

        menubutton = new Gtk.MenuButton();
        menubutton.add_css_class("menubutton-usage-badge");

        outer_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        menubutton.set_child(outer_box);

        icon = new Gtk.Image();
        service.bind_property("is-powered", icon, "icon-name", BindingFlags.SYNC_CREATE, get_bluetooth_icon, null);
        outer_box.append(icon);

        items = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);
        items_binding = new ModelBoxBinding<AstalBluetooth.Device>(items, service.connected_devices, BluetoothButtonItem.create);
        outer_box.append(items);

        set_child(menubutton);
    }

    private static bool get_bluetooth_icon(Binding b, Value from, ref Value to) {
        var powered = from.get_boolean();
        if (powered) {
            to.set_static_string("bluetooth-active-symbolic");
        } else {
            to.set_static_string("bluetooth-disabled-symbolic");
        }
        return true;
    }
}
