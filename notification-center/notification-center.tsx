import { Variable, bind } from "astal";
import { App, Astal, Gdk } from "astal/gtk4";
import Adw from "gi://Adw?version=1";
import { Calendar } from "../widgets/calendar";
import { cancelClickCapture, setupClickCapture } from "./click-capturer";
import { NotificationList } from "./notification-list";
import { WeatherIconDebug, WeatherPanel } from "./weather-panel";

function TopCarousel() {
    const carousel = new Adw.Carousel({ spacing: 8 });
    carousel.append(<WeatherPanel />);

    return (
        <box vertical={true}>
            {carousel}
            {new Adw.CarouselIndicatorDots({ carousel })}
        </box>
    );
}

function CalendarPanel() {
    // TODO: Update when the current date changes.
    // TODO: Show calendar events on the side to not make it W I D E.
    // This will require integrating evolution-data-server and gnome-online-accounts.
    // https://nixos.wiki/wiki/GNOME/Calendar
    // This AGS v1 PR may prove helpful: https://github.com/Aylur/ags/pull/177
    // It also includes editing, but that will probably be better left to a dedicated calendar app.
    return <Calendar />;
}

let notificationCenterWindow: Astal.Window | null;
export function createNotificationCenter() {
    notificationCenterWindow = (
        <window
            cssClasses={["notification-center-window"]}
            namespace="notification-center"
            anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.BOTTOM | Astal.WindowAnchor.RIGHT}
            layer={Astal.Layer.OVERLAY}
            exclusivity={Astal.Exclusivity.NORMAL}
            setup={(self) => {
                App.add_window(self);
            }}
        >
            <box vertical={true} name="notification-center">
                <TopCarousel />
                {/* <WeatherIconDebug /> */}
                <NotificationList />
                <CalendarPanel />
            </box>
        </window>
    ) as Astal.Window;
}

export function toggleNotificationCenter(monitor: Gdk.Monitor) {
    if (!notificationCenterWindow) {
        throw new Error("Notification center window doesn't exist");
    }

    if (notificationCenterWindow.visible) {
        if (monitor == notificationCenterWindow.gdkmonitor) {
            notificationCenterWindow.visible = false;
            cancelClickCapture();
        } else {
            notificationCenterWindow.gdkmonitor = monitor;
        }
    } else {
        notificationCenterWindow.gdkmonitor = monitor;
        notificationCenterWindow.visible = true;
        setupClickCapture(() => {
            notificationCenterWindow!.visible = false;
        });
    }
}
