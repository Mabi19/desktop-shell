import { App } from "astal/gtk3";
import { Bar } from "./bar/bar";
import { NotificationCenter } from "./notification-center/notification-center";
import style from "./style.scss";

App.start({
    css: style,
    main() {
        // TODO: spawn one window per monitor
        Bar(0);
        Bar(1);
        NotificationCenter(0);
        NotificationCenter(1);
    },
});
