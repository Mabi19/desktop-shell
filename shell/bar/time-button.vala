[GtkTemplate(ui = "/land/mabi/shell/ui/bar/time-button.ui")]
class TimeButton : Gtk.Button {
    internal TimeService service { get; private set; }
    public Gdk.Monitor gdkmonitor { get; set; }

    static construct {
        typeof(TimeService).ensure();
    }

    construct {
        service = TimeService.get_default();
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
}
