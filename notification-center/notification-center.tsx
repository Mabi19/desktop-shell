import { Variable, bind } from "astal";
import { App, Astal, Gdk } from "astal/gtk4";
import { Calendar } from "../widgets/calendar";

export const notificationCenterMonitor = Variable<Gdk.Monitor | null>(null);

export const NotificationCenter = (monitor: Gdk.Monitor) => {
    return (
        <window
            name={`notification-center${monitor}`}
            cssClasses={["notification-center-window"]}
            namespace="notification-center"
            anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.BOTTOM | Astal.WindowAnchor.RIGHT}
            layer={Astal.Layer.OVERLAY}
            exclusivity={Astal.Exclusivity.NORMAL}
            gdkmonitor={monitor}
            setup={(self) => App.add_window(self)}
            visible={bind(notificationCenterMonitor).as((mon) => mon == monitor)}
        >
            <box vertical={true} name="notification-center">
                <Calendar />
            </box>
        </window>
    );
};
