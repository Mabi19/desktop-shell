import { Variable } from "astal";
import { readFile } from "astal/file";
import { App, Gdk } from "astal/gtk4";

const display = Gdk.Display.get_default()!;
const monitorModel = display.get_monitors();

export const CONFIG: {
    primary_monitor: string;
    enable_notifications: boolean;
} = JSON.parse(readFile("./config.json"));

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
