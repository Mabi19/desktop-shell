errordomain ConfigError {
    INVALID_STRUCTURE,
}

enum BarStyle {
    FLOATING,
    ATTACHED,
}

class Config : Object {
    public string? primary_monitor_name { get; set; }
    public int64 max_network_usage { get; set; }
    public bool power_menu_hibernate { get; set; }
    public Color theme_inactive { get; set; }
    public Color theme_active { get; set; }
    public BarStyle bar_style { get; set; }
    public string time_format_short { get; set; }
    public string time_format_long { get; set; }
    public bool notification_debug_menu { get; set; }
    public string audio_mixer_command { get; set; }
    public Gee.ArrayList<NotificationRule> notification_rules { get; set; }

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
        theme_inactive = Color() {
            l = 0.646f, a = 0.1412f, b = -0.1027f, alpha = 1.0f
        }.recompute_rgba();
        theme_active = Color() {
            l = 0.52f, a = 0.1106f, b = -0.139f, alpha = 1.0f
        }.recompute_rgba();
        bar_style = BarStyle.FLOATING;
        time_format_short = "%H:%M";
        time_format_long = "%c";
        notification_debug_menu = false;
        audio_mixer_command = "pavucontrol";
        notification_rules = new Gee.ArrayList<NotificationRule>(null);

        var default_vesktop_cond = new NotificationRule.Condition();
        var default_vesktop_effect = new NotificationRule.Effect();
        try {
            default_vesktop_cond.app_name = new Regex("^vesktop$");
        } catch (RegexError e) {
            error("Broken regex found while constructing default notification rules");
        }
        default_vesktop_effect.app_name = "Vesktop";
        default_vesktop_effect.layout = MESSAGE;
        default_vesktop_effect.suppress_sound = true;
        var default_vesktop_rule = new NotificationRule(default_vesktop_cond, default_vesktop_effect);
        notification_rules.add(default_vesktop_rule);
    }

    private void read_string_or_null(Json.Object obj, string key, string target) {
        var member = obj.get_member(key);
        if (member == null || member.is_null()) {
            set(target, null);
            return;
        }

        if (member.get_value_type() != Type.STRING) {
            warning("Config: key '%s' has wrong type (should be string)", key);
            return;
        }

        set(target, member.get_string());
    }

    private void read_string(Json.Object obj, string key, string target) {
        var member = obj.get_member(key);
        if (member == null) {
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

    private void read_color(Json.Object obj, string key, string target) {
        var member = obj.get_member(key);
        if (member == null) {
            return;
        }

        if (member.get_value_type() != Type.STRING) {
            warning("Config: key '%s' has wrong type (should be color)", key);
            return;
        }
        var str_val = member.get_string();
        var rgba = Gdk.RGBA();
        if (!rgba.parse(str_val)) {
            warning("Config: key '%s' has wrong type (should be color)", key);
            return;
        }
        set(target, Color.from_rgba(rgba));
    }

    private void read_bar_style(Json.Object obj) {
        var member = obj.get_member("bar_style");
        if (member == null) {
            return;
        }

        if (member.get_value_type() != Type.STRING) {
            warning("Config: Invalid bar_style (should be \"floating\" | \"attached\")");
            return;
        }

        var str_val = member.get_string();
        if (str_val == "floating") {
            this.bar_style = BarStyle.FLOATING;
        } else if (str_val == "attached") {
            this.bar_style = BarStyle.ATTACHED;
        } else {
            warning("Config: Invalid bar_style (should be \"floating\" | \"attached\")");
        }
    }

    private void read_notification_rules(Json.Object obj) {
        var member = obj.get_member("notification_rules");
        if (member == null) {
            return;
        }

        if (member.get_node_type() != Json.NodeType.ARRAY) {
            warning("Config: Key 'notification_rules' has wrong type (should be array)");
            return;
        }

        var rule_array = member.get_array();
        var count = rule_array.get_length();
        for (int i = 0; i < count; i++) {
            var rule_node = rule_array.get_element(i);
            if (rule_node.get_node_type() != Json.NodeType.OBJECT) {
                warning("Config: invalid notification rule #%d (should be object)", i);
                continue;

            }
            var rule_object = rule_node.get_object();
            var rule = NotificationRule.from_json(rule_object);
            if (rule != null) {
                notification_rules.add(rule);
            }
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
        read_color(obj, "theme_inactive", "theme-inactive");
        read_color(obj, "theme_active", "theme-active");
        read_bar_style(obj);
        read_string(obj, "time_format_short", "time-format-short");
        read_string(obj, "time_format_long", "time-format-long");
        read_bool(obj, "notification_debug_menu", "notification-debug-menu");
        read_notification_rules(obj);
        read_string(obj, "audio_mixer_command", "audio-mixer-command");
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
