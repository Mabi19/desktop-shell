import { Variable } from "astal";
import { readFile } from "astal/file";
import { Gdk } from "astal/gtk4";
import GLib from "gi://GLib?version=2.0";
import type { OklabColor } from "./color";

export const DATA = DATADIR ?? SRC;

const display = Gdk.Display.get_default()!;
const monitorModel = display.get_monitors();

export const CONFIG: {
    // Override for the primary monitor. Useful if you don't have one set as primary.
    primary_monitor: string;
    // Whether to enable notifications.
    enable_notifications: boolean;
    // The network usage considered to be 100%. In bytes per second.
    max_network_usage: number;
    // The first theme color, used for inactive workspace buttons and badges with 0 usage.
    theme_inactive: OklabColor;
    // The second theme color, used for active workspace buttons and badges with maximum usage.
    theme_active: OklabColor;
} = JSON.parse(readFile(GLib.get_home_dir() + "/.config/mabi-shell/config.json"));

function getPrimaryMonitor() {
    let i = 0;
    while (true) {
        const monitor = monitorModel.get_item(i) as Gdk.Monitor | null;
        i++;
        if (monitor) {
            if (monitor.connector == CONFIG.primary_monitor) return monitor;
        } else {
            break;
        }
    }

    return monitorModel.get_item(0) as Gdk.Monitor;
}

export const primaryMonitor = Variable(getPrimaryMonitor());
monitorModel.connect("items-changed", () => primaryMonitor.set(getPrimaryMonitor()));
