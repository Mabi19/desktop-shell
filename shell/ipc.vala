[DBus(name = "land.mabi.shell.ipc")]
class ShellIPCService : Object {
    public string dispatch(string[] args) throws DBusError, IOError {
        return handle_dispatch(args);
    }

    internal signal string handle_dispatch(string[] args);
}
