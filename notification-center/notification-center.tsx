import { App, Astal, Gdk } from "astal/gtk3";
import { Calendar } from "../widgets/calendar";

export const NotificationCenter = (monitor: Gdk.Monitor) => {
    return (
        <window
            name={`notification-center${monitor}`}
            namespace="notification-center"
            className="notification-center"
            anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.BOTTOM | Astal.WindowAnchor.RIGHT}
            layer={Astal.Layer.TOP}
            gdkmonitor={monitor}
            setup={(self) => App.add_window(self)}
            visible={false}
        >
            <box vertical={true}>
                <Calendar />
            </box>
        </window>
    );
};
