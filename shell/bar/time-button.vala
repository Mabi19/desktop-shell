[GtkTemplate(ui = "/land/mabi/shell/ui/bar/time-button.ui")]
class TimeButton : Gtk.Button {
    internal TimeService service { get; private set; }

    static construct {
        typeof(TimeService).ensure();
    }

    construct {
        service = TimeService.get_default();
    }
}
