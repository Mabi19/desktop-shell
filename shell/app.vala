class MabiShell : Adw.Application {
    public static MabiShell instance;
    public static Gdk.Display display;

    private Gtk.CssProvider style_provider;
    private Bar bar;

    public MabiShell() {
        Object(application_id: "land.mabi.shell");
    }

    public override void activate() {
        var disp = Gdk.Display.get_default();
        if (disp == null) {
            error("Couldn't get GDK display");
        }
        instance = this;
        display = disp;

        style_provider = new Gtk.CssProvider();
        style_provider.parsing_error.connect((section, error) => {
            critical(
                     "CSS error: %s (%s:%zu)",
                     error.message,
                     section.get_file().get_basename() ?? "<unknown>",
                     section.get_start_location().lines + 1
            );
        });

        style_provider.load_from_resource("/land/mabi/shell/shell-styles.css");
        Gtk.StyleContext.add_provider_for_display(disp, style_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        // TODO: load theme colors
        // TODO: load overrides

        bar = new Bar();
        bar.present();

        // I'm not sure why this is required.
        // TODO: when a .quit() is implemented, call release()
        this.hold();
    }
}

int main() {
    var app = new MabiShell();
    return app.run();
}
