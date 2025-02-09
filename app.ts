import { App, Astal, Gdk } from "astal/gtk4";
import type Gio from "gi://Gio?version=2.0";
import { Bar } from "./bar/bar";
import { NotificationCenter } from "./notification-center/notification-center";
import { NotificationPopupWindow } from "./notification/notification";
import { startOSDListeners } from "./osd/listeners";
import style from "./style.scss";
import { formatOklabAsCSS } from "./utils/color";
import { CONFIG, DATA } from "./utils/config";
import { handleMessage } from "./utils/message";

const windows = new Map<Gdk.Monitor, Astal.Window[]>();

function makeWindowsForMonitor(monitor: Gdk.Monitor) {
    return [Bar(monitor), NotificationCenter(monitor)] as Astal.Window[];
}

function applyThemeCSS() {
    const themeColorCSS = `
    :root {
        --theme-inactive: ${formatOklabAsCSS(CONFIG.theme_inactive)};
        --theme-active: ${formatOklabAsCSS(CONFIG.theme_active)};
    }
    `;
    App.apply_css(themeColorCSS);
}

App.start({
    css: style,
    icons: `${DATA}/icons`,
    main() {
        applyThemeCSS();

        for (const monitor of App.get_monitors()) {
            windows.set(monitor, makeWindowsForMonitor(monitor));
        }
        // this one reacts to the primary monitor
        if (CONFIG.enable_notifications) {
            NotificationPopupWindow();
        }

        startOSDListeners();

        const display = Gdk.Display.get_default()!;
        const monitors = display.get_monitors() as Gio.ListModel<Gdk.Monitor>;
        monitors.connect("items-changed", (monitorModel, position, idxRemoved, idxAdded) => {
            console.log("monitors changed!", position, idxRemoved, idxAdded);

            const prevSet = new Set(windows.keys());
            const currSet = new Set<Gdk.Monitor>();
            let i = 0;
            while (true) {
                const monitor = monitorModel.get_item(i) as Gdk.Monitor | null;
                i++;
                if (monitor) {
                    currSet.add(monitor);
                } else {
                    break;
                }
            }

            const removed = prevSet.difference(currSet);
            const added = currSet.difference(prevSet);

            // remove early, before anything else has a chance to break
            for (const monitor of removed) {
                const windowsToRemove = windows.get(monitor) ?? [];
                for (const window of windowsToRemove) {
                    window.destroy();
                }
            }

            display.sync();
            console.log(
                "prevSet:",
                Array.from(prevSet).map((mon) => mon.description)
            );
            console.log(
                "currSet:",
                Array.from(currSet).map((mon) => mon.description)
            );
            console.log(
                "removed:",
                Array.from(removed).map((mon) => mon.description)
            );
            console.log(
                "added:",
                Array.from(added).map((mon) => mon.description)
            );

            for (const monitor of added) {
                windows.set(monitor, makeWindowsForMonitor(monitor));
            }
        });
    },
    requestHandler(request, res) {
        handleMessage(request, res);
    },
});
