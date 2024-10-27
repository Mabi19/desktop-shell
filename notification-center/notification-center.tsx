import { App, Astal } from "astal/gtk3";
import { Calendar } from "../widgets/calendar";

export const NotificationCenter = (monitor: number) => {
    return (
        <window
            name={`notification-center${monitor}`}
            namespace="notification-center"
            className="notification-center"
            anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.BOTTOM | Astal.WindowAnchor.RIGHT}
            layer={Astal.Layer.TOP}
            monitor={monitor}
            setup={(self) => App.add_window(self)}
            visible={false}
        >
            <box vertical={true}>
                <Calendar />
            </box>
        </window>
    );
};
