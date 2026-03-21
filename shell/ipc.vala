[DBus(name = "land.mabi.shell.ipc")]
class ShellIPCService : Object {
    public string dispatch(string[] args) throws DBusError, IOError {
        return handle_dispatch(args);
    }

    private string handle_dispatch(string[] args) {
        if (args.length == 0) {
            return "error: command required";
        }

        switch (args[0]) {
        case "quit":
            MabiShell.instance.release();
            return "ok";
        case "inspect":
            Gtk.Window.set_interactive_debugging(true);
            return "ok";
        case "volume":
            return handle_volume(args);
        case "brightness":
            return handle_brightness(args);
        case "osd":
            return handle_osd(args);
        case "inhibit-idle":
            var service = IdleService.get_default();
            service.inhibit = !service.inhibit;
            return "ok";
        case "help":
            return handle_help(args);
        default:
            return "error: unknown command";
        }
    }

    private bool parse_maybe_percent(string arg, out double result) {
        var s_arg = arg.strip();
        if (s_arg.has_suffix("%")) {
            if (double.try_parse(s_arg[0 : (s_arg.length - 1)], out result, null)) {
                result *= 0.01;
                return true;
            } else {
                return false;
            }
        } else {
            return double.try_parse(s_arg, out result, null);
        }
    }

    private string handle_volume(string[] args) {
        if (args.length < 2) return "usage: volume <up|down> [amount] or volume set <value> or volume mute [0|1|toggle]";

        var wp = AstalWp.get_default();
        var speaker = wp.get_default_speaker();
        if (speaker == null) return "error: no default speaker";

        bool new_mute = speaker.mute;
        double new_volume = speaker.volume;
        if (args[1] == "mute") {
            if (args.length < 3 || args[2] == "toggle") {
                new_mute = !new_mute;
            } else if (args[2] == "0") {
                new_mute = false;
            } else if (args[2] == "1") {
                new_mute = true;
            } else {
                return "error: unknown mute value";
            }
            speaker.mute = new_mute;
        } else {
            double value;
            if (args.length == 2) {
                if (args[1] == "set") {
                    return "usage: volume set <value>";
                }
                value = 0.05;
            } else {
                if (!parse_maybe_percent(args[2], out value)) {
                    return "error: not a number or percentage";
                }
            }

            switch (args[1]) {
            case "up":
                new_volume = (new_volume + value).clamp(0, 1);
                break;
            case "down":
                new_volume = (new_volume - value).clamp(0, 1);
                break;
            case "set":
                new_volume = value.clamp(0, 1);
                break;
            default:
                return "error: unknown volume command";
            }
            speaker.volume = new_volume;
            SoundService.get_default().play_deduped("audio-volume-change");
        }
        string icon;
        if (new_mute) icon = "audio-volume-muted-symbolic";
        else if (new_volume <= 0.33) icon = "audio-volume-low-symbolic";
        else if (new_volume <= 0.66) icon = "audio-volume-medium-symbolic";
        else if (new_volume <= 1.0) icon = "audio-volume-high-symbolic";
        else icon = "audio-volume-overamplified-symbolic";

        OsdService.get_default().show_value(icon, new_volume, new_mute ? "muted" : null);
        return "ok";
    }

    private string handle_brightness(string[] args) {
        if (args.length < 2) return "usage: brightness <up|down> [amount] or brightness set <value>";

        double value;
        if (args.length == 2) {
            if (args[1] == "set") {
                return "usage: volume set <value>";
            }
            value = 0.1;
        } else {
            if (!parse_maybe_percent(args[2], out value)) {
                return "error: not a number or percentage";
            }
        }

        unowned string op;
        switch (args[1]) {
        case "up":
            op = "+";
            break;
        case "down":
            op = "-";
            break;
        case "set":
            op = "";
            break;
        default:
            return "error: unknown brightness command";
        }

        try {
            var proc = new Subprocess(
                SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE,
                "brightnessctl", "-m", "set", @"$(Math.round(value * 100))%$op");

            proc.communicate_utf8_async.begin(null, null, (obj, res) => {
                try {
                    string stdout_buf;
                    proc.communicate_utf8_async.end(res, out stdout_buf, null);
                    if (proc.get_exit_status() != 0) {
                        warning("brightnessctl exited with status %d", proc.get_exit_status());
                        return;
                    }
                    // Machine-readable format: device,class,current,percentage,max
                    var parts = stdout_buf.strip().split(",");
                    if (parts.length == 5) {
                        double current = double.parse(parts[2]);
                        double max = double.parse(parts[4]);
                        double fraction = max > 0 ? current / max : 0;
                        OsdService.get_default().show_value("display-brightness-symbolic", fraction, null);
                    } else {
                        warning("brightnessctl communication failed: unknown format");
                    }
                } catch (Error e) {
                    warning("brightnessctl communication failed: %s", e.message);
                }
            });
        } catch (Error e) {
            return "error: %s".printf(e.message);
        }

        return "ok";
    }

    private string handle_osd(string[] args) {
        string? icon_name = null;
        double value = double.NAN;
        string? text = null;
        string? style = null;

        if (args.length % 2 != 1) {
            return "usage: osd <(option value)...>";
        }
        for (int i = 1; i < args.length; i += 2) {
            switch (args[i]) {
            case "-i":
            case "--icon":
                icon_name = args[i + 1];
                break;
            case "-v":
            case "--value":
                if (!parse_maybe_percent(args[i + 1], out value)) {
                    return "error: not a number or percentage";
                }
                break;
            case "-t":
            case "--text":
                text = args[i + 1];
                break;
            case "-s":
            case "--style":
                style = args[i + 1];
                break;
            default:
                return "error: unknown OSD option";
            }
        }

        if (icon_name == null) {
            return "error: icon is required";
        }
        if (value.is_nan() && text == null) {
            return "error: at least one of icon oand text are required";
        }
        OsdService.get_default().show(icon_name, value, text, style);
        return "ok";
    }

    private string handle_help(string[] args) {
        if (args.length == 1) {
            return """Available commands:
    inspect      - launch the GTK inspector
    quit         - quit mabi-shell gracefully
    inhibit-idle - toggle the idle inhibitor
    volume       - change volume and trigger OSD
    brightness   - change brightness and trigger OSD
    osd          - trigger OSD manually
    help         - show this information; use help <command> for more information about it""";
        }

        switch (args[1]) {
        case "inspect":
            return "-- inspect --\nLaunch the GTK inspector.";
        case "quit":
            return "-- quit --\nQuit mabi-shell gracefully.";
        case "inhibit-idle":
            return "-- inhibit-idle --\nToggle the idle inhibitor.";
        case "volume":
            return """--
volume <up|down> [amount]
volume set <value>
volume mute [0|1|toggle]
--
Change volume and trigger OSD.
All volume values can be either numbers in the range 0-1 or percentage points (using the % suffix).
If a value is not specified for the up & down modes, 5% is used.
If a value is not specified for the mute mode, toggle is used.""";
        case "brightness":
            return """--
brightness <up|down> [amount]
brightness set <value>
--
Change brightness and trigger OSD.
All brightness values can be either numbers in the range 0-1 or percentage points (using the % suffix).
If a value is not specified for the up & down modes, 10% is used.""";
        case "osd":
            return """-- osd <(option value)...> --
Trigger the OSD manually.
The syntax is based on options:
-i/--icon <icon name>: The icon to use
-v/--value <number>: the bar fullness
-t/--text <label>: the text next to the bar
-s/--style <style name>: the style of OSD to use
An icon must be specified, as well as at least one of value or text.
If value isn't specified, the bar is hidden;
if text isn't specified, the label is autogenerated from the value (displayed as a percentage).
The only style defined is "muted", used by default when muting the audio sink.""";
        case "help":
            return "error: too much recursion";
        default:
            return "error: unknown command";
        }
    }
}
