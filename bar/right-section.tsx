import { Variable, exec } from "astal";
import { Gdk, Gtk } from "astal/gtk4";
import Gio from "gi://Gio?version=2.0";
import GLib from "gi://GLib?version=2.0";
import { notificationCenterMonitor } from "../notification-center/notification-center";
import { CONFIG } from "../utils/config";
import { AudioIndicator } from "./audio";
import { BatteryIndicator } from "./battery";
import { SystemTray } from "./tray";

// this is a very rough approximation of converting POSIX locales into BCP 47 tags
const languageTag =
    (GLib.getenv("LC_ALL") || GLib.getenv("LC_TIME") || GLib.getenv("LANG"))?.replaceAll("_", "-")?.split(".")?.[0] ??
    undefined;
const timeFormatter = new Intl.DateTimeFormat(languageTag, {
    timeStyle: "short",
});
const time = Variable(timeFormatter.format(new Date())).poll(1000, () => timeFormatter.format(new Date()));

const powermenu = new Gio.Menu();

const suspendAction = new Gio.SimpleAction({ name: "suspend" });
suspendAction.connect("activate", () => exec("systemctl sleep"));
const hibernateAction = new Gio.SimpleAction({ name: "hibernate" });
hibernateAction.connect("activate", () => exec("systemctl hibernate"));
const shutdownAction = new Gio.SimpleAction({ name: "shutdown" });
shutdownAction.connect("activate", () => exec("systemctl poweroff"));
const rebootAction = new Gio.SimpleAction({ name: "reboot" });
rebootAction.connect("activate", () => exec("systemctl reboot"));

const powermenuGroup = new Gio.SimpleActionGroup();
for (const action of CONFIG.power_menu_options) {
    switch (action) {
        case "suspend":
            powermenu.append("Suspend", "powermenu.suspend");
            powermenuGroup.add_action(suspendAction);
            break;
        case "hibernate":
            powermenu.append("Hibernate", "powermenu.hibernate");
            powermenuGroup.add_action(hibernateAction);
            break;
        case "shutdown":
            powermenu.append("Shutdown", "powermenu.shutdown");
            powermenuGroup.add_action(shutdownAction);
            break;
        case "reboot":
            powermenu.append("Reboot", "powermenu.reboot");
            powermenuGroup.add_action(rebootAction);
    }
}

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
            {time()}
            <Gtk.Separator orientation={Gtk.Orientation.VERTICAL} />
            <image iconName="fa-bell-symbolic" />
        </box>
    </button>
);

export const RightSection = ({ monitor }: { monitor: Gdk.Monitor }) => (
    <box halign={Gtk.Align.END} spacing={8}>
        <SystemTray />
        <AudioIndicator />
        <BatteryIndicator />
        <TimeAndNotifications monitor={monitor} />
        <PowerButton />
    </box>
);
