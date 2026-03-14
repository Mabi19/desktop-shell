[GtkTemplate(ui = "/land/mabi/shell/ui/bar/time-button.ui")]
class TimeButton : Gtk.Button {
    internal TimeService service { get; private set; }
    internal NotificationService notifications { get; private set; }
    public Gdk.Monitor gdkmonitor { get; set; }

    static construct {
        typeof(TimeService).ensure();
    }

    construct {
        service = TimeService.get_default();
        notifications = NotificationService.get_default();
    }

    public override void dispose() {
        dispose_template(typeof(TimeButton));
        base.dispose();
    }

    public override void clicked() {
        MabiShell.instance.toggle_side_panel(gdkmonitor);
    }

    [GtkCallback]
    public string get_bell_icon(bool dont_disturb) {
        return dont_disturb ? "fa-bell-snooze-symbolic" : "fa-bell-symbolic";
    }
}
