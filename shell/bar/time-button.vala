[GtkTemplate(ui = "/land/mabi/shell/ui/bar/time-button.ui")]
class TimeButton : Gtk.Button {
    public TimeService service { get; private set; }
    public string time_short { get; private set; default = "12:35"; }

    static construct {
        typeof(TimeService).ensure();
    }

    construct {
        service = TimeService.get_default();
    }
}
