import { bind, Variable } from "astal";
import { App, Astal } from "astal/gtk4";
import { primaryMonitor } from "../utils/config";
import type { NotificationWidgetEntry } from "./notification";
import { NotificationTracker } from "./tracker";

export const NotificationPopupWindow = () => {
    const notifs = NotificationTracker.getInstance();

    const windowVisible = Variable(false);
    const box = (<box vertical={true} spacing={12} noImplicitDestroy={true}></box>) as Astal.Box;

    notifs.connect("popup-add", (_, entry: NotificationWidgetEntry) => {
        if (box.get_children().length == 0) {
            windowVisible.set(true);
        }

        box.prepend(entry.widget);
    });
    notifs.connect("popup-replace", (_, prev: NotificationWidgetEntry, curr: NotificationWidgetEntry) => {
        box.insert_child_after(curr.widget, prev.widget);
        box.remove(prev.widget);
        prev.cleanup();
    });
    notifs.connect("popup-remove", (_, entry: NotificationWidgetEntry) => {
        box.remove(entry.widget);
        entry.cleanup();
        if (box.get_first_child() == null) {
            windowVisible.set(false);
        }
    });

    // TODO: increase margin-right when notification center is active
    return (
        <window
            name="notification-popup-window"
            namespace="notification-popups"
            anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT}
            layer={Astal.Layer.OVERLAY}
            gdkmonitor={bind(primaryMonitor)}
            setup={(self) => App.add_window(self)}
            visible={windowVisible()}
            // This causes the window to be able to shrink back down when the notification is destroyed.
            // But only if it isn't transparent.
            defaultWidth={1}
            defaultHeight={1}
            onDestroy={() => windowVisible.drop()}
        >
            {box}
        </window>
    );
};
