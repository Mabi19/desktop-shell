class SystemUsageService : Object {
    private static SystemUsageService instance = null;
    public static SystemUsageService get_default() {
        if (instance == null) {
            debug("initializing SystemUsageService");
            instance = new SystemUsageService();
        }
        return instance;
    }

    private NetworkService network_service;

    public double cpu { get; private set; default = 0; }
    private int64 last_idle = -1;
    private int64 last_total = -1;

    public double memory { get; private set; default = 0; }
    public int64 memory_total_kib { get; private set; default = 0; }
    public int64 memory_available_kib { get; private set; default = 0; }

    public double network { get; private set; default = 0; }
    public int64 network_bytes { get; private set; default = 0; }
    private int64 last_transferred = -1;
    private int64 last_network_measure = get_monotonic_time();

    public SystemUsageService() {
        assert_null(instance);
        network_service = NetworkService.get_default();
        network_service.notify["primary-interface"].connect(reset_network);
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
                numbers[i] = int64.parse(num_strings[i], 10);
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
                return int64.parse(line[i: end], 10);
            }
        }

        throw new FileError.INVAL("Invalid meminfo line: %s".printf(line));
    }

    private async void update_network() {
        if (network_service.primary_interface == null) {
            return;
        }
        var file = File.new_for_path("/proc/net/dev");
        try {
            var stream = new DataInputStream(yield file.read_async());
            yield stream.read_line_async();
            yield stream.read_line_async();

            string? raw_line;
            while ((raw_line = yield stream.read_line_async()) != null) {
                unowned var line = raw_line._chug();
                if (line.has_prefix(network_service.primary_interface + ":")) {
                    int field_index = 0;
                    int64 total_bytes = 0;
                    for (int i = 1; i < line.length; i++) {
                        if (line[i - 1].isspace() && line[i].isdigit()) {
                            if (field_index == 0) {
                                total_bytes = int64.parse(line[i:], 10);
                            } else if (field_index == 8) {
                                total_bytes += int64.parse(line[i:], 10);
                                break;
                            }

                            field_index++;
                        }
                    }

                    var now = get_monotonic_time();
                    var delta = now - last_network_measure;
                    if (last_transferred != -1) {
                        network_bytes = (int64)((total_bytes - last_transferred) / (delta / 1000000.0));
                        network = double.min((double)_network_bytes / MabiShell.config.max_network_usage, 1.0);
                    }
                    last_transferred = total_bytes;
                    last_network_measure = now;
                    return;
                }
            }
            // Something's out of date. Reset instead
            reset_network();
        } catch (Error e) {
            error("Error reading from /proc/net/dev: %s", e.message);
        }
    }

    private void reset_network() {
        network = 0;
        network_bytes = 0;
        last_transferred = -1;
    }

    private bool update() {
        update_cpu.begin();
        update_memory.begin();
        update_network.begin();
        return Source.CONTINUE;
    }
}
