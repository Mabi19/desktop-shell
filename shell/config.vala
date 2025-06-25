// TODO: Wrapper functionality for accessing the primary monitor

errordomain ConfigError {
    INVALID_STRUCTURE,
}

enum BarStyle {
    Floating,
    Attached,
}

class Config : Object {
    // These have to be properties for notify signals to work, but can't be properties for getting pointers to them.
    // TODO: rework read_X methods to take a string name and reflect to them
    public string? primary_monitor_name { get; set; }
    public int64 max_network_usage { get; set; }
    public bool power_menu_hibernate { get; set; }
    public BarStyle bar_style { get; set; }

    private File config_file;
    private FileMonitor file_monitor;
    private uint config_reload_timeout_id;

    construct {
        config_file = File.new_for_path(Environment.get_user_config_dir()).get_child("mabi-shell").get_child("config.json");
        set_defaults();
        load_from_file(false);

        try {
            file_monitor = config_file.monitor_file(FileMonitorFlags.NONE, null);
            file_monitor.changed.connect((file, other_file, event) => {
                if (config_reload_timeout_id != 0) {
                    Source.remove(config_reload_timeout_id);
                }
                config_reload_timeout_id = Timeout.add(500, () => {
                    config_reload_timeout_id = 0;
                    print("Reloading config...\n");
                    load_from_file(true);
                });
            });
        } catch (IOError e) {
            warning("Couldn't set up file monitor, config hot reload will not work");
        }
    }

    private void set_defaults() {
        primary_monitor_name = null;
        max_network_usage = 12500000;
        power_menu_hibernate = false;
        bar_style = BarStyle.Floating;
    }

    private void read_string_or_null(Json.Object obj, string key, string target) {
        var member = obj.get_member(key);
        if (member == null) {
            set(target, null);
            return;
        }

        if (member.get_value_type() != Type.STRING) {
            warning("Config: key '%s' has wrong type (should be string)", key);
            return;
        }

        set(target, member.get_string());
    }

    private void read_bool(Json.Object obj, string key, string target) {
        var member = obj.get_member(key);
        if (member == null) {
            return;
        }

        if (member.get_value_type() != Type.BOOLEAN) {
            warning("Config: key '%s' has wrong type (should be bool)", key);
            return;
        }
        set(target, member.get_boolean());
    }

    private void read_int64(Json.Object obj, string key, string target) {
        var member = obj.get_member(key);
        if (member == null) {
            return;
        }

        if (member.get_value_type() != Type.INT64) {
            warning("Config: key '%s' has wrong type (should be int)", key);
            return;
        }
        set(target, member.get_int());
    }

    private void read_bar_style(Json.Object obj) {
        var member = obj.get_member("bar_style");
        if (member == null) {
            return;
        }

        if (member.get_value_type() != Type.STRING) {
            warning("Config: Invalid bar_style (should be \"floating\" | \"attached\")");
        }

        var str_val = member.get_string();
        if (str_val == "floating") {
            this.bar_style = BarStyle.Floating;
        } else if (str_val == "attached") {
            this.bar_style = BarStyle.Attached;
        } else {
            warning("Config: Invalid bar_style (should be \"floating\" | \"attached\")");
        }
    }

    private void read_root_node(Json.Node node) throws Error {
        if (node.get_node_type() != Json.NodeType.OBJECT) {
            throw new ConfigError.INVALID_STRUCTURE("Root must be object");
        }
        var obj = node.get_object();
        assert_nonnull(obj);

        read_string_or_null(obj, "primary_monitor", "primary-monitor-name");
        read_int64(obj, "max_network_usage", "max-network-usage");
        read_bool(obj, "power_menu_hibernate", "power-menu-hibernate");
        read_bar_style(obj);
    }

    private void load_from_file(bool is_reload) {
        freeze_notify();
        try {
            var contents = config_file.load_bytes(null, null);
            var text = (string)contents.get_data();
            var root = Json.from_string(text);

            if (is_reload) {
                set_defaults();
            }
            read_root_node(root);
        } catch (Error e) {
            print("Config file not present / broken, skipping load\n");
        }
        thaw_notify();
    }
}
