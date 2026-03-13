class MabiShell : Adw.Application {
    public static MabiShell instance;
    public static Config config;
    public static Gdk.Display display;

    private ListModel monitor_model;
    public Gee.HashMap<Gdk.Monitor, Gee.List<Gtk.Window> > windows;
    public Gdk.Monitor? primary_monitor { get; private set; }

    private ShellStyleManager styles;
    private ShellIPCService? ipc_service = null;
    private uint ipc_register_id = 0;

    public MabiShell() {
        Object(application_id : "land.mabi.shell");
    }

    private void create_windows_for_monitor(Gdk.Monitor mon) {
        assert(!windows.has_key(mon));
        var list = new Gee.ArrayList<Gtk.Window>();

        var bar = new Bar(mon);
        bar.present();
        list.add(bar);
        var side_panel = new RightPopupWindow(mon);
        side_panel.present();
        list.add(side_panel);

        windows.set(mon, list);
        mon.invalidate.connect(() => {
            print("monitor invalidated %s\n", mon.get_connector());
            Gee.List<Gtk.Window> mon_list;
            windows.unset(mon, out mon_list);
            foreach (var window in mon_list) {
                window.destroy();
            }
        });
    }

    private void recompute_primary_monitor() {
        Gdk.Monitor? new_primary = null;
        if (config.primary_monitor_name == null) {
            new_primary = (Gdk.Monitor?)monitor_model.get_item(0);
        } else {
            for (var i = 0;; i++) {
                var mon = (Gdk.Monitor?)monitor_model.get_item(i);
                if (mon == null) {
                    // no monitor with the right connector
                    new_primary = (Gdk.Monitor?)monitor_model.get_item(0);
                    break;
                }

                if (mon.connector == config.primary_monitor_name) {
                    new_primary = mon;
                    break;
                }
            }
        }

        if (new_primary != primary_monitor) {
            print("new primary monitor: %s\n", new_primary == null ? "[null]" : new_primary.connector);
            primary_monitor = new_primary;
        }
    }

    public override void activate() {
        if (display != null) {
            return;
        }

        var disp = Gdk.Display.get_default();
        if (disp == null) {
            error("Couldn't get GDK display");
        }
        instance = this;
        config = new Config();
        display = disp;

        styles = new ShellStyleManager(disp);

        monitor_model = display.get_monitors();
        recompute_primary_monitor();

        windows = new Gee.HashMap<Gdk.Monitor, Gee.List<Gtk.Window> >();
        Gdk.Monitor? mon;
        for (var i = 0;; i++) {
            mon = (Gdk.Monitor?)monitor_model.get_item(i);
            if (mon == null) {
                break;
            }
            print("creating surfaces on monitor %s\n", mon.get_connector());
            create_windows_for_monitor(mon);
        }
        monitor_model.items_changed.connect((position, removed, added) => {
            print("monitor model changed\n");
            for (int i = 0; i < added; i++) {
                var monitor = (Gdk.Monitor)monitor_model.get_item(position + i);
                if (monitor.get_connector() != null) {
                    print("new monitor: %s\n", monitor.get_connector());
                    recompute_primary_monitor();
                    create_windows_for_monitor(monitor);
                } else {
                    monitor.notify["connector"].connect((pspec, obj) => {
                        // needs to have a different name to not refer to the one in the parent scope
                        var mon2 = (Gdk.Monitor)obj;
                        if (!mon2.is_valid()) {
                            return;
                        }
                        print("new monitor: %s\n", monitor.get_connector());
                        recompute_primary_monitor();
                        create_windows_for_monitor(mon2);
                    });
                }
            }

        });

        config.notify["primary-monitor-name"].connect(() => {
            recompute_primary_monitor();
        });

        // I'm not sure why this is required.
        this.hold();
    }

    public override void shutdown() {
        foreach (var win_list in windows.values) {
            foreach (var window in win_list) {
                window.destroy();
            }
        }
        windows.clear();
        base.shutdown();
    }

    public override bool dbus_register(DBusConnection conn, string object_path) {
        try {
            if (!base.dbus_register(conn, object_path)) {
                return false;
            }

            ipc_service = new ShellIPCService();
            ipc_register_id = conn.register_object(object_path, ipc_service);
        } catch (Error e) {
            return false;
        }

        return true;
    }

    public override void dbus_unregister(DBusConnection conn, string object_path) {
        if (ipc_service != null) {
            conn.unregister_object(ipc_register_id);
        }
        base.dbus_unregister(conn, object_path);
    }
}

int main() {
    var app = new MabiShell();
    return app.run();
}
