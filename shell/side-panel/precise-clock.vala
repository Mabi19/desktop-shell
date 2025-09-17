[GtkTemplate(ui = "/land/mabi/shell/ui/side-panel/precise-clock.ui")]
class PreciseClock : Gtk.Box {
    private bool _active;
    public bool active {
        get {
            return _active;
        }
        set {
            _active = value;
            update_time();
        }
    }

    internal string time_long { get; private set; }
    private TimeService service;

    private void update_time() {
        if (_active) {
            time_long = service.time_long;
        }
    }

    construct {
        service = TimeService.get_default();
        service.notify["time-long"].connect(this.update_time);
        time_long = service.time_long;
        _active = false;
    }
}
