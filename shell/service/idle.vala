[DBus(name = "org.freedesktop.ScreenSaver")]
interface ScreenSaver : Object {
    public abstract uint32 inhibit(string app_name, string reason) throws DBusError, IOError;
    public abstract void un_inhibit(uint32 cookie) throws DBusError, IOError;
}

class IdleService : Object {
    private static IdleService instance = null;
    public static IdleService get_default() {
        if (instance == null) {
            debug("initializing IdleService");
            instance = new IdleService();
        }
        return instance;
    }

    private ScreenSaver idle_daemon = null;
    private bool is_inhibiting = false;
    private uint32 inhibit_cookie;
    public bool inhibit {
        get { return is_inhibiting; }
        set {
            if (is_inhibiting == value) {
                return;
            }
            if (idle_daemon == null) {
                critical("Couldn't inhibit idle: D-Bus idle daemon not available");
                return;
            }

            try {
                if (value) {
                    inhibit_cookie = idle_daemon.inhibit("mabi-shell", "Inhibited manually");
                } else {
                    idle_daemon.un_inhibit(inhibit_cookie);
                }
            } catch (Error e) {
                critical("Couldn't inhibit idle: %s", e.message);
                return;
            }
            is_inhibiting = value;
        }
    }

    private void acquire_idle_service(Object? obj, AsyncResult res) {
        try {
            idle_daemon = Bus.get_proxy.end<ScreenSaver>(res);
        } catch (IOError e) {
            critical("Couldn't find D-Bus idle daemon: %s", e.message);
        }
    }

    public IdleService() {
        assert_null(instance);
        Bus.get_proxy.begin<ScreenSaver>(BusType.SESSION, "org.freedesktop.ScreenSaver", "/org/freedesktop/ScreenSaver", 0, null, this.acquire_idle_service);
    }
}
