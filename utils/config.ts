import { Variable } from "astal";
import { Gdk } from "astal/gtk4";
import Gio from "gi://Gio?version=2.0";
import GLib from "gi://GLib?version=2.0";
import type { OklabColor } from "./color";

export const DATA = DATADIR ?? SRC;

const display = Gdk.Display.get_default()!;
const monitorModel = display.get_monitors();

interface Config {
    /** Override for the primary monitor. Useful if you don't have one set as primary. */
    primary_monitor?: string;
    /** Whether to enable notifications. */
    enable_notifications: boolean;
    /** The network usage considered to be 100%. In bytes per second. */
    max_network_usage: number;
    /** The style of the bar. "floating" is rounded with a margin, "attached" has no margins */
    bar_style: "floating" | "attached";
    /** The first theme color, used for inactive workspace buttons and badges with 0 usage. */
    theme_inactive: OklabColor;
    /** The second theme color, used for active workspace buttons and badges with maximum usage. */
    theme_active: OklabColor;
    /** The options to show in the power menu. Hibernate is disabled by default. */
    power_menu_options: ("suspend" | "hibernate" | "shutdown" | "reboot")[];
}

const CONFIG_DEFAULTS: Config = {
    enable_notifications: true,
    max_network_usage: 12_500_000,
    bar_style: "floating",
    theme_inactive: { l: 0.646, a: 0.1412, b: -0.1027 },
    theme_active: { l: 0.52, a: 0.1106, b: -0.139 },
    power_menu_options: ["suspend", "shutdown", "reboot"],
};

export const CONFIG: Config = CONFIG_DEFAULTS;

try {
    const configFile = Gio.File.new_for_path(GLib.get_home_dir() + "/.config/mabi-shell/config.json");
    const [_success, data] = configFile.load_contents(null);
    const configFileContents = new TextDecoder().decode(data);
    Object.assign(CONFIG, JSON.parse(configFileContents));
} catch (e) {
    console.log("config file not present, skipping load");
}

function getPrimaryMonitor() {
    let i = 0;
    while (true) {
        const monitor = monitorModel.get_item(i) as Gdk.Monitor | null;
        i++;
        if (monitor) {
            // immediately on creation the connector might be null
            // because the Wayland event hasn't been received yet
            while (monitor.connector == null) {
                console.log("syncing display", monitor.connector);
                display.sync();
            }

            if (monitor.connector == CONFIG.primary_monitor) return monitor;
        } else {
            break;
        }
    }

    return monitorModel.get_item(0) as Gdk.Monitor;
}

export const primaryMonitor = Variable(getPrimaryMonitor());
monitorModel.connect("items-changed", () => primaryMonitor.set(getPrimaryMonitor()));
