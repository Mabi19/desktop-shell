class TimeService : Object {
    private static TimeService instance = null;
    public static TimeService get_default() {
        if (instance == null) {
            debug("initializing TimeService");
            instance = new TimeService();
        }
        return instance;
    }

    private Config config;
    public string time_short { get; private set; }
    public string time_long { get; private set; }

    public TimeService() {
        assert_null(instance);
        config = MabiShell.config;
        // This object is never destroyed, so this timeout never needs to be disconnected.
        Timeout.add(1000, this.update, Priority.DEFAULT);
        this.update();
    }

    private bool update() {
        var now = new DateTime.now();
        var new_time_short = now.format(config.time_format_short);
        if (time_short != new_time_short) {
            time_short = new_time_short;
        }

        time_long = now.format(config.time_format_long);
        return Source.CONTINUE;
    }
}
