class IdleInhibitIndicator : Adw.Bin {
    private IdleService service;

    construct {
        service = IdleService.get_default();
        var revealer = new Gtk.Revealer();
        revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_RIGHT;
        service.bind_property("inhibit", revealer, "reveal-child", BindingFlags.SYNC_CREATE);
        var button = new Gtk.Button.from_icon_name("streamline-sleep-inhibit-symbolic");
        button.clicked.connect(this.handle_click);
        button.name = "idle-inhibit";
        revealer.child = button;
        child = revealer;

        tooltip_text = "Inhibiting idle";
    }

    private void handle_click() {
        service.inhibit = false;
    }
}
