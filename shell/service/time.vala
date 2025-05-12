class TimeService : Object {
    private static TimeService instance = null;
    public static TimeService get_default() {
        if (instance == null) {
            debug("initializing TimeService");
            instance = new TimeService();
        }
        return instance;
    }

    private AstalIO.Time interval;
    public string time_short { get; private set; }
    public string time_long { get; private set; }

    public TimeService() {
        assert_null(instance);
        interval = AstalIO.Time.interval(1000, null);
        interval.now.connect(this.update);
    }

    private void update() {
        var now = new DateTime.now();
        // TODO: hook this up to config
        var new_time_short = now.format("%H:%M");
        if (time_short != new_time_short) {
            time_short = new_time_short;
        }

        time_long = now.format("%c");
    }
}
