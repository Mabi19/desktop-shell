// TODO: Do not use Astal.Application (just Adw.Application)
// The only thing from there that's useful is the D-Bus instance stuff and sockets,
// which are not hard to implement
class MabiShell : Astal.Application {
    public static MabiShell instance;

    construct {
        Adw.init();

        try {
            acquire_socket();
        } catch (Error e) {
            critical("%s", e.message);
        }
        instance = this;
    }
}

void main() {
}
