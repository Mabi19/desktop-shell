import { Variable, exec } from "astal";
import { App, Gdk, Gtk } from "astal/gtk4";
import Gio from "gi://Gio?version=2.0";
import GLib from "gi://GLib?version=2.0";
import { notificationCenterMonitor } from "../notification-center/notification-center";
import { Separator } from "../widgets/separator";
import { AudioIndicator } from "./audio";
import { SystemTray } from "./tray";

const time = Variable(new GLib.DateTime()).poll(1000, () => new GLib.DateTime());

const powermenu = new Gio.Menu();
powermenu.append("Suspend", "powermenu.suspend");
powermenu.append("Shutdown", "powermenu.shutdown");
powermenu.append("Reboot", "powermenu.reboot");

const suspendAction = new Gio.SimpleAction({ name: "suspend" });
suspendAction.connect("activate", () => exec("systemctl sleep"));
const shutdownAction = new Gio.SimpleAction({ name: "shutdown" });
shutdownAction.connect("activate", () => exec("systemctl poweroff"));
const rebootAction = new Gio.SimpleAction({ name: "reboot" });
rebootAction.connect("activate", () => exec("systemctl reboot"));

const powermenuGroup = new Gio.SimpleActionGroup();
powermenuGroup.add_action(suspendAction);
powermenuGroup.add_action(shutdownAction);
powermenuGroup.add_action(rebootAction);

const PowerButton = () => (
    <menubutton
        name="power-button"
        menuModel={powermenu}
        setup={(self) => self.insert_action_group("powermenu", powermenuGroup)}
    >
        <image iconName="system-shutdown-symbolic" />
    </menubutton>
);

function toggleNotificationCenter(monitor: Gdk.Monitor) {
    if (notificationCenterMonitor.get() == monitor) {
        notificationCenterMonitor.set(null);
    } else {
        notificationCenterMonitor.set(monitor);
    }
}

const TimeAndNotifications = ({ monitor }: { monitor: Gdk.Monitor }) => (
    <button name="time-and-notifications" onClicked={() => toggleNotificationCenter(monitor)}>
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
