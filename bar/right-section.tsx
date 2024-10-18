import { Variable } from "astal";
import { App, Gtk } from "astal/gtk3";
import { Separator } from "../widgets/separator";

const time = Variable("").poll(1000, () => {
    const date = new Date();
    return `${date.getHours().toString().padStart(2, "0")}:${date
        .getMinutes()
        .toString()
        .padStart(2, "0")}`;
});

const PowerButton = () => <button name="power-button">{"\uf011"}</button>;

const TimeAndNotifications = ({ monitor }: { monitor: number }) => (
    <button
        name="time-and-notifications"
        onClick={() => App.toggle_window(`notification-center${monitor}`)}
    >
        <box spacing={6}>
            {time()}
            <Separator orientation={Gtk.Orientation.VERTICAL} />
            {"\uf0f3"}
        </box>
    </button>
);

export const RightSection = ({ monitor }: { monitor: number }) => (
    <box halign={Gtk.Align.END} spacing={8}>
        <TimeAndNotifications monitor={monitor} />
        <PowerButton />
    </box>
);
