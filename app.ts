import { App, Gdk, Gtk } from "astal/gtk4";
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
        NotificationPopupWindow();
    },
    requestHandler(request, res) {
        handleMessage(request, res);
    },
});

// App.connect("monitor-removed", (_source, monitor) => {
//     console.log("monitor removed", monitor.model);
//     for (const win of windows.get(monitor) ?? []) {
//         // win.destroy();
//     }
//     windows.delete(monitor);
// });

// App.connect("monitor-added", (_source, monitor) => {
//     console.log("monitor added", monitor.manufacturer, monitor.model, monitor.refreshRate);
//     windows.set(monitor, makeWindowsForMonitor(monitor));
// });
