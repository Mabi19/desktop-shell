import { App, Astal, Gdk, Gtk } from "astal/gtk4";
import Gio from "gi://Gio?version=2.0";
import GLib from "gi://GLib?version=2.0";
import { Bar } from "./bar/bar";
import { ClickCaptureWindow } from "./notification-center/click-capturer";
import { createNotificationCenter } from "./notification-center/notification-center";
import { NotificationPopupWindow } from "./notification/notification";
import { startOSDListeners } from "./osd/listeners";
import style from "./style.scss";
import { formatOklabAsCSS } from "./utils/color";
import { CONFIG, DATA } from "./utils/config";
import { handleMessage } from "./utils/message";
import { NetworkService } from "./utils/network";

const windows = new Map<Gdk.Monitor, Astal.Window[]>();

function makeWindowsForMonitor(monitor: Gdk.Monitor) {
    return [Bar(monitor), ClickCaptureWindow(monitor)] as Astal.Window[];
}

function applyStyles(display: Gdk.Display) {
    function loadStyleString(css: string, priority: number) {
        const provider = new Gtk.CssProvider();
        provider.load_from_string(css);
        Gtk.StyleContext.add_provider_for_display(display, provider, priority);
    }

    // basic styles
    loadStyleString(style, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

    // theme colors
    loadStyleString(
        `
:root {
    --theme-inactive: ${formatOklabAsCSS(CONFIG.theme_inactive)};
    --theme-active: ${formatOklabAsCSS(CONFIG.theme_active)};
}
    `,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    );

    // overrides
    try {
        const styleOverridesFile = Gio.File.new_for_path(GLib.get_home_dir() + "/.config/mabi-shell/overrides.css");
        const [_success, data] = styleOverridesFile.load_contents(null);
        const overrideString = new TextDecoder().decode(data);
        loadStyleString(overrideString, Gtk.STYLE_PROVIDER_PRIORITY_USER);
    } catch (e) {
        console.log("style overrides not present, skipping load");
    }
}

App.start({
    icons: `${DATA}/icons`,
    main() {
        // NetworkService.getInstance();

        const display = Gdk.Display.get_default()!;
        applyStyles(display);

        for (const monitor of App.get_monitors()) {
            windows.set(monitor, makeWindowsForMonitor(monitor));
        }
        // this one reacts to the primary monitor
        if (CONFIG.enable_notifications) {
            NotificationPopupWindow();
        }

        createNotificationCenter();
        startOSDListeners();

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
