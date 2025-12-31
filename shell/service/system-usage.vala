class SystemUsageService : Object {
    private static SystemUsageService instance = null;
    public static SystemUsageService get_default() {
        if (instance == null) {
            debug("initializing SystemUsageService");
            instance = new SystemUsageService();
        }
        return instance;
    }

    public double cpu { get; set; default = 0; }
    private int64 last_idle = -1;
    private int64 last_total = -1;

    public SystemUsageService() {
        assert_null(instance);
        // This object is never destroyed, so this timeout never needs to be disconnected.
        Timeout.add(2000, this.update, Priority.DEFAULT);
        this.update();
    }

    private async void update_cpu() {
        var file = File.new_for_path("/proc/stat");
        try {
            var stream = new DataInputStream(yield file.read_async());
            var line = yield stream.read_line_async();
            if (line == null || !line.has_prefix("cpu ")) {
                error("Error reading from /proc/stat: file is empty");
            }
            var num_strings = line[5 :].split(" ");
            var numbers = new int64[num_strings.length];
            for (int i = 0; i < num_strings.length; i++) {
                numbers[i] = int64.parse(num_strings[i]);
            }
            int64 idle = numbers[3] + numbers[4];
            int64 total = 0;
            foreach (var num in numbers) {
                total += num;
            }

            if (last_idle >= 0) {
                double delta_idle = idle - last_idle;
                double delta_total = total - last_total;
                cpu = 1.0 - delta_idle / delta_total;
            }

            last_idle = idle;
            last_total = total;
        } catch (Error e) {
            error("Error reading from /proc/stat: %s", e.message);
        }
    }

    private bool update() {
        update_cpu.begin();
        return Source.CONTINUE;
    }
}
