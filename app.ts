import { App } from "astal/gtk3";
import AstalHyprland from "gi://AstalHyprland";
import { Bar } from "./bar/bar";
import { NotificationPopupWindow } from "./notification-center/notification";
import { NotificationCenter } from "./notification-center/notification-center";
import style from "./style.scss";

const hyprland = AstalHyprland.get_default();

App.start({
    css: style,
    icons: `${SRC}/icons`,
    main() {
        // TODO: react to monitor adds and removes
        for (const monitor of App.get_monitors()) {
            Bar(monitor);
            NotificationCenter(monitor);
        }
        // this one reacts to the primary monitor
        NotificationPopupWindow();
    },
});
