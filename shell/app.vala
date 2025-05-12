class MabiShell : Adw.Application {
    public static MabiShell instance;
    public static Gdk.Display display;

    private ShellStyleManager styles;
    private Bar bar;

    private ShellIPCService? ipc_service = null;
    private uint ipc_register_id = 0;

    public MabiShell() {
        Object(application_id : "land.mabi.shell");
    }

    public override void activate() {
        var disp = Gdk.Display.get_default();
        if (disp == null) {
            error("Couldn't get GDK display");
        }
        instance = this;
        display = disp;

        styles = new ShellStyleManager(disp);

        bar = new Bar();
        bar.present();

        // I'm not sure why this is required.
        // TODO: when a .quit() is implemented, call release()
        this.hold();
    }

    public override bool dbus_register(DBusConnection conn,      string object_path) {
        print(object_path);
        try {
            if (!base.dbus_register(conn, object_path)) {
                return false;
            }

            ipc_service = new ShellIPCService();
            ipc_service.handle_dispatch.connect(this.handle_dispatch);
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

    internal string handle_dispatch(string[] args) {
        foreach (var arg in args) {
            print("arg: %s\n", arg);
        }
        return "ok";
    }
}

int main() {
    var app = new MabiShell();
    return app.run();
}
