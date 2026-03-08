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
    public double memory { get; set; default = 0; }
    public int64 memory_total_kib { get; private set; default = 0; }
    public int64 memory_available_kib { get; private set; default = 0; }
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

    private async void update_memory() {
        var file = File.new_for_path("/proc/meminfo");
        int64 mem_total = -1;
        int64 mem_available = -1;

        try {
            var stream = new DataInputStream(yield file.read_async());
            string? line;
            while ((line = yield stream.read_line_async()) != null) {
                if (line.has_prefix("MemTotal:")) {
                    mem_total = parse_meminfo_value(line, 9);
                } else if (line.has_prefix("MemAvailable:")) {
                    mem_available = parse_meminfo_value(line, 13);
                }

                if (mem_total >= 0 && mem_available >= 0) {
                    memory_total_kib = mem_total;
                    memory_available_kib = mem_available;
                    memory = 1.0 - (double)mem_available / mem_total;
                    return;
                }
            }

            error("Error reading from /proc/meminfo: missing MemTotal or MemAvailable");
        } catch (Error e) {
            error("Error reading from /proc/meminfo: %s", e.message);
        }
    }

    private int64 parse_meminfo_value(string line, int start) throws Error {
        for (int i = start; i < line.length; i++) {
            var ch = line[i];
            if (ch >= '0' && ch <= '9') {
                int end = i;
                while (end < line.length) {
                    ch = line[end];
                    if (ch < '0' || ch > '9') {
                        break;
                    }
                    end++;
                }
                return int64.parse(line[i: end]);
            }
        }

        throw new FileError.INVAL("Invalid meminfo line: %s".printf(line));
    }

    private bool update() {
        update_cpu.begin();
        update_memory.begin();
        return Source.CONTINUE;
    }
}
