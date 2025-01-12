import { App, Gdk, Gtk } from "astal/gtk4";
import type Gio from "gi://Gio?version=2.0";
import { Bar } from "./bar/bar";
import { handleMessage } from "./message";
import { NotificationPopupWindow } from "./notification-center/notification";
import { NotificationCenter } from "./notification-center/notification-center";
import style from "./style.scss";

const windows = new Map<Gdk.Monitor, Gtk.Widget[]>();

function makeWindowsForMonitor(monitor: Gdk.Monitor) {
    return [Bar(monitor), NotificationCenter(monitor)];
}

App.start({
    css: style,
    icons: `${SRC}/icons`,
    main() {
        for (const monitor of App.get_monitors()) {
            windows.set(monitor, makeWindowsForMonitor(monitor));
        }
        // this one reacts to the primary monitor
        // NotificationPopupWindow();

        const display = Gdk.Display.get_default()!;
        const monitors = display.get_monitors() as Gio.ListModel<Gdk.Monitor>;
        monitors.connect("items-changed", (self, position, removed, added) => {
            // TODO: Figure out how this works. It may be easier to just diff the monitor list than use the properties.
            console.log("monitors changed!", self, position, removed, added);
        });
    },
    requestHandler(request, res) {
        handleMessage(request, res);
    },
});
