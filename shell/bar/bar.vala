[GtkTemplate(ui = "/land/mabi/shell/ui/bar/bar.ui")]
class Bar : Astal.Window {
    public Bar() {
        anchor = TOP | LEFT | RIGHT;
        add_css_class("floating");
    }

    [GtkCallback]
    void open_inspector() {
        Gtk.Window.set_interactive_debugging(true);
    }
}
