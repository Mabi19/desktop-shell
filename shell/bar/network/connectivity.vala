class ConnectivityIndicator : LevelBin {
    private NetworkService service;
    private SystemUsageService system_usage;
    private Gtk.MenuButton menubutton;
    private Gtk.Box box;
    private ConnectivityIndicatorEthernet ethernet;
    private ConnectivityIndicatorWifi wifi;
    private Gtk.Label transfer_rate_label;

    private uint scan_timer_id;

    private void update_order() {
        if (service.primary_interface == null) {
            transfer_rate_label.visible = false;
            ethernet.remove_css_class("after-label");
            wifi.remove_css_class("after-label");
        } else {
            transfer_rate_label.visible = true;
            if (service.wifi_is_primary) {
                box.reorder_child_after(wifi, null);
                wifi.remove_css_class("after-label");
                box.reorder_child_after(ethernet, transfer_rate_label);
                ethernet.add_css_class("after-label");
            } else {
                box.reorder_child_after(ethernet, null);
                ethernet.remove_css_class("after-label");
                box.reorder_child_after(wifi, transfer_rate_label);
                wifi.add_css_class("after-label");
            }
        }
    }

    private void update_transfer_rate() {
        double net_bytes = system_usage.network_bytes;
        unowned string unit;
        if (net_bytes >= 1.0e8) {
            net_bytes /= 1.0e9;
            unit = "GB/s";
        } else if (net_bytes >= 1.0e5) {
            net_bytes /= 1.0e6;
            unit = "MB/s";
        } else {
            net_bytes /= 1.0e3;
            unit = "kB/s";
        }

        string formatted;
        if (net_bytes >= 100.0) {
            formatted = "%.0f %s".printf(net_bytes, unit);
        } else if (net_bytes >= 10.0) {
            formatted = "%.1f %s".printf(net_bytes, unit);
        } else {
            formatted = "%.2f %s".printf(net_bytes, unit);
        }

        transfer_rate_label.label = formatted;
        level = system_usage.network;
    }

    private bool scan() {
        if (menubutton.active) {
            service.request_scan.begin();
            return Source.CONTINUE;
        } else {
            scan_timer_id = 0;
            return Source.REMOVE;
        }
    }

    private void handle_menu_active() {
        if (menubutton.active) {
            scan();
            if (scan_timer_id != 0) {
                Source.remove(scan_timer_id);
            }
            scan_timer_id = Timeout.add_seconds(15, this.scan, Priority.DEFAULT);
        } else {
            if (scan_timer_id != 0) {
                Source.remove(scan_timer_id);
                scan_timer_id = 0;
            }
        }
    }

    construct {
        name = "connectivity";

        service = NetworkService.get_default();
        service.bind_property("is-available", this, "visible", BindingFlags.SYNC_CREATE);

        menubutton = new Gtk.MenuButton();
        menubutton.add_css_class("menubutton-usage-badge");
        menubutton.popover = new ConnectivityMenu();
        menubutton.notify["active"].connect(handle_menu_active);

        box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);

        ethernet = new ConnectivityIndicatorEthernet();
        service.bind_property("ethernet", ethernet, "device", BindingFlags.SYNC_CREATE);
        box.append(ethernet);

        wifi = new ConnectivityIndicatorWifi();
        service.bind_property("wifi", wifi, "device", BindingFlags.SYNC_CREATE);
        box.append(wifi);

        system_usage = SystemUsageService.get_default();
        transfer_rate_label = new Gtk.Label(null);
        box.append(transfer_rate_label);
        system_usage.notify["network"].connect(update_transfer_rate);
        update_transfer_rate();

        service.notify["primary-interface"].connect(update_order);
        update_order();

        menubutton.set_child(box);
        set_child(menubutton);
    }
}
