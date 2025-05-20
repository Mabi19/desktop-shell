// TODO: Wrapper functionality for accessing the primary monitor

errordomain ConfigError {
    INVALID_STRUCTURE,
}

class Config : Object {
    public string? primary_monitor_name = null;
    public int64 max_network_usage = 12500000;
    public bool power_menu_hibernate = false;

    construct {
        try {
            var config_file = File.new_for_path(Environment.get_user_config_dir()).get_child("mabi-shell").get_child("config.json");
            var contents = config_file.load_bytes(null, null);
            var text = (string)contents.get_data();
            var root = Json.from_string(text);
            read_root_node(root);
        } catch (Error e) {
            print("Config file not present / broken, skipping load\n");
        }
    }

    private void read_string_or_null(Json.Object obj, string key, ref string? value) {
        var member = obj.get_member(key);
        if (member == null) {
            value = null;
            return;
        }

        if (member.get_value_type() != Type.STRING) {
            warning("Config: key '%s' has wrong type (should be string)", key);
            return;
        }
        value = member.get_string();
    }

    private void read_bool(Json.Object obj, string key, ref bool value) {
        var member = obj.get_member(key);
        if (member == null) {
            return;
        }

        if (member.get_value_type() != Type.BOOLEAN) {
            warning("Config: key '%s' has wrong type (should be bool)", key);
            return;
        }
        value = member.get_boolean();
    }

    private void read_int64(Json.Object obj, string key, ref int64 value) {
        var member = obj.get_member(key);
        if (member == null) {
            return;
        }

        if (member.get_value_type() != Type.INT64) {
            warning("Config: key '%s' has wrong type (should be int)", key);
            return;
        }
        value = member.get_int();
    }

    private void read_root_node(Json.Node node) throws Error {
        if (node.get_node_type() != Json.NodeType.OBJECT) {
            throw new ConfigError.INVALID_STRUCTURE("Root must be object");
        }
        var obj = node.get_object();
        assert_nonnull(obj);

        read_string_or_null(obj, "primary_monitor", ref this.primary_monitor_name);
        read_int64(obj, "max_network_usage", ref this.max_network_usage);
        read_bool(obj, "power_menu_hibernate", ref this.power_menu_hibernate);
    }
}
