import { exec, Variable } from "astal";
import { App, Gdk, Gtk } from "astal/gtk3";
import GLib from "gi://GLib?version=2.0";
import { createMenu } from "../widgets/menu";
import { Separator } from "../widgets/separator";
import { AudioIndicator } from "./audio";
import { SystemTray } from "./tray";

const time = Variable(new GLib.DateTime()).poll(1000, () => new GLib.DateTime());

const powerMenu = createMenu([
    {
        label: "Suspend",
        handler: () => {
            exec("systemctl sleep");
        },
    },
    {
        label: "Shutdown",
        handler: () => {
            exec("systemctl poweroff");
        },
    },
    {
        label: "Reboot",
        handler: () => {
            exec("systemctl reboot");
        },
    },
]);

const PowerButton = () => (
    <button
        name="power-button"
        onClick={(button) =>
            powerMenu.popup_at_widget(button, Gdk.Gravity.SOUTH, Gdk.Gravity.NORTH_EAST, null)
        }
    >
        {"\uf011"}
    </button>
);

const TimeAndNotifications = ({ monitor }: { monitor: Gdk.Monitor }) => (
    <button
        name="time-and-notifications"
        // TODO: rework this to only use 1 notification center window
        onClick={() => App.toggle_window(`notification-center${monitor}`)}
    >
        <box spacing={6}>
            {time((timestamp) => timestamp.format("%H:%M"))}
            <Separator orientation={Gtk.Orientation.VERTICAL} />
            {"\uf0f3"}
        </box>
    </button>
);

export const RightSection = ({ monitor }: { monitor: Gdk.Monitor }) => (
    <box halign={Gtk.Align.END} spacing={8}>
        <SystemTray />
        <AudioIndicator />
        <TimeAndNotifications monitor={monitor} />
        <PowerButton />
    </box>
);
