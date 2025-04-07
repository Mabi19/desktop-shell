import { bind, exec } from "astal";
import { Gdk, Gtk } from "astal/gtk4";
import Gio from "gi://Gio?version=2.0";
import { toggleNotificationCenter } from "../notification-center/notification-center";
import { NotificationTracker } from "../notification/tracker";
import { CONFIG } from "../utils/config";
import { currentTime, makeDateTimeFormat } from "../utils/time";
import { AudioIndicator } from "./audio";
import { BatteryIndicator } from "./battery";
import { SystemTray } from "./tray";

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

const barClockFormatter = makeDateTimeFormat({ timeStyle: "short" });

function TimeAndNotifications() {
    const tracker = NotificationTracker.getInstance();
    const notificationCount = tracker.storedCount;
    return (
        <button name="time-and-notifications" onClicked={() => toggleNotificationCenter()}>
            <box spacing={6}>
                {bind(currentTime).as((d) => barClockFormatter.format(d))}
                <Gtk.Separator orientation={Gtk.Orientation.VERTICAL} />
                <box spacing={4}>
                    <image
                        iconName={bind(tracker.notifd, "dont_disturb").as((dnd) =>
                            dnd ? "fa-bell-slash-symbolic" : "fa-bell-symbolic"
                        )}
                    />
                    <label
                        label={bind(notificationCount).as((v) => v.toString())}
                        visible={bind(notificationCount).as((v) => v > 0)}
                    />
                </box>
            </box>
        </button>
    );
}

export const RightSection = () => (
    <box halign={Gtk.Align.END} spacing={8}>
        <SystemTray />
        <AudioIndicator />
        <BatteryIndicator />
        <TimeAndNotifications />
        <PowerButton />
    </box>
);
