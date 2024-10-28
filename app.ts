import { App } from "astal/gtk3";
import AstalHyprland from "gi://AstalHyprland";
import { Bar } from "./bar/bar";
import { NotificationCenter } from "./notification-center/notification-center";
import style from "./style.scss";

const hyprland = AstalHyprland.get_default();

App.start({
    css: style,
    main() {
        // TODO: react to monitor adds and removes
        for (const monitor of App.get_monitors()) {
            console.log(monitor.get_display().get_name());
            Bar(monitor);
            NotificationCenter(monitor);
        }
    },
});
