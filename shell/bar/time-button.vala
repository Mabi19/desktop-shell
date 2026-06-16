[GtkTemplate(ui = "/land/mabi/shell/ui/bar/time-button.ui")]
class TimeButton : Gtk.Button {
    internal TimeService service { get; private set; }
    internal NotificationService notifications { get; private set; }
    public Gdk.Monitor gdkmonitor { get; set; }
    [GtkChild]
    unowned Gtk.Revealer count_revealer;
    [GtkChild]
    unowned Gtk.Label count_label;

    static construct {
        typeof(TimeService).ensure();
    }

    construct {
        service = TimeService.get_default();
        notifications = NotificationService.get_default();
        notifications.notify["stored-count"].connect(update_notification_count);
        update_notification_count();
    }

    public override void dispose() {
        dispose_template(typeof(TimeButton));
        base.dispose();
    }

    public override void clicked() {
        var windows = MabiShell.instance.windows.get(gdkmonitor);
        var target_window = windows.first_match((win) => win is RightPopupWindow);
        if (target_window == null) {
            warning("Couldn't find side panel window to show");
            return;
        }
        var side_panel_window = (RightPopupWindow)target_window;
        side_panel_window.side_panel_shown = !side_panel_window.side_panel_shown;
    }

    [GtkCallback]
    public string get_bell_icon(bool dont_disturb) {
        return dont_disturb ? "fa-bell-snooze-symbolic" : "fa-bell-symbolic";
    }


    private void update_notification_count() {
        var count = notifications.stored_count;

        // Not updating the label when the count is 0 prevents it from flashing to 0 when fading out.
        if (count != 0) {
            count_label.label = count.to_string();
        }

        count_revealer.reveal_child = count > 0;
    }
}
