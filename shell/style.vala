// This is separated out to avoid deprecation warnings for Gtk.StyleContext.

namespace MabiShellStyle {

public class ShellStyleManager {
    private Gdk.Display display;
    public Gtk.CssProvider main;
    public Gtk.CssProvider theme;
    public Gtk.CssProvider overrides;

    public ShellStyleManager(Gdk.Display disp) {
        display = disp;

        init_provider(out main);
        main.load_from_resource("/land/mabi/shell/shell-styles.css");
        use_provider(main);

        init_provider(out theme);
        // TODO: actually load this from the config
        // oh wait, the config won't be available here D:
        // add an external method that the config calls to make this work?
        theme.load_from_string(@":root { --theme-inactive: #C063C9; --theme-active: rebeccapurple; }");
        use_provider(theme);


        var overrides_file = File.new_for_path(Environment.get_user_config_dir()).get_child("mabi-shell").get_child("overrides.css");
        if (overrides_file.query_exists()) {
            init_provider(out overrides);
            overrides.load_from_file(overrides_file);
            use_provider(overrides, Gtk.STYLE_PROVIDER_PRIORITY_USER);
        }
    }

    private void use_provider(Gtk.CssProvider provider, uint priority = Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION) {
        Gtk.StyleContext.add_provider_for_display(display, provider, priority);
    }

    private void init_provider(out Gtk.CssProvider provider) {
        provider = new Gtk.CssProvider();
        provider.parsing_error.connect((section, error) => {
                critical(
                    "CSS error: %s (%s:%zu)",
                    error.message,
                    section.get_file().get_basename() ?? "<unknown>",
                    section.get_start_location().lines + 1
                    );
            });
    }
}

}
