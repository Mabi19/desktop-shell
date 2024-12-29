import { Variable } from "astal";
import { App, Gdk, Gtk } from "astal/gtk4";
import GLib from "gi://GLib?version=2.0";
import { notificationCenterMonitor } from "../notification-center/notification-center";
import { Separator } from "../widgets/separator";
import { AudioIndicator } from "./audio";
import { SystemTray } from "./tray";

const time = Variable(new GLib.DateTime()).poll(1000, () => new GLib.DateTime());

// const powerMenu = createMenu([
//     {
//         label: "Suspend",
//         handler: () => {
//             exec("systemctl sleep");
//         },
//     },
//     {
//         label: "Shutdown",
//         handler: () => {
//             exec("systemctl poweroff");
//         },
//     },
//     {
//         label: "Reboot",
//         handler: () => {
//             exec("systemctl reboot");
//         },
//     },
// ]);

const PowerButton = () => (
    <button
        name="power-button"
        // onButtonPressed={
        //     powerMenu.popup_at_widget(button, Gdk.Gravity.SOUTH, Gdk.Gravity.NORTH_EAST, null)
        // }
    >
        <image iconName="system-shutdown-symbolic" />
    </button>
);

function toggleNotificationCenter(monitor: Gdk.Monitor) {
    if (notificationCenterMonitor.get() == monitor) {
        notificationCenterMonitor.set(null);
    } else {
        notificationCenterMonitor.set(monitor);
    }
}

const TimeAndNotifications = ({ monitor }: { monitor: Gdk.Monitor }) => (
    <button name="time-and-notifications" onButtonPressed={() => toggleNotificationCenter(monitor)}>
        <box spacing={6}>
            {time((timestamp) => timestamp.format("%H:%M"))}
            <Separator />
            <image iconName="fa-bell-symbolic" />
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
