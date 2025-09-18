class TimeService : Object {
    private static TimeService instance = null;
    public static TimeService get_default() {
        if (instance == null) {
            debug("initializing TimeService");
            instance = new TimeService();
        }
        return instance;
    }

    public string time_short { get; private set; }
    public string time_long { get; private set; }

    public TimeService() {
        assert_null(instance);
        // This object is never destroyed, so this timeout never needs to be disconnected.
        Timeout.add(1000, this.update, Priority.DEFAULT);
        this.update();
    }

    private bool update() {
        var now = new DateTime.now();
        // TODO: hook this up to config
        var new_time_short = now.format("%H:%M");
        if (time_short != new_time_short) {
            time_short = new_time_short;
        }

        time_long = now.format("%c");
        return Source.CONTINUE;
    }
}
