import { Variable, bind } from "astal";
import { App, Astal, Gdk, Gtk } from "astal/gtk3";
import { Calendar } from "../widgets/calendar";

export const notificationCenterVisible = Variable(false);

export const NotificationCenter = (monitor: Gdk.Monitor) => {
    return (
        <window
            name={`notification-center${monitor}`}
            className="notification-center-window"
            namespace="notification-center"
            anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.BOTTOM | Astal.WindowAnchor.RIGHT}
            layer={Astal.Layer.OVERLAY}
            exclusivity={Astal.Exclusivity.NORMAL}
            gdkmonitor={monitor}
            setup={(self) => App.add_window(self)}
            visible={bind(notificationCenterVisible)}
        >
            <box vertical={true} name="notification-center">
                <Calendar />
            </box>
        </window>
    );
};
