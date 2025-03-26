import { Variable, bind } from "astal";
import { App, Astal, Gdk } from "astal/gtk4";
import Adw from "gi://Adw?version=1";
import { currentTime, makeDateTimeFormat } from "../utils/time";
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

const formatter = makeDateTimeFormat({
    timeStyle: "medium",
    dateStyle: "medium",
});

// TODO: Only update this when the center is visible
function PreciseDateTime() {
    return (
        <box cssClasses={["precise-clock"]} spacing={8}>
            <image iconName="fa-clock-symbolic" pixelSize={24} />
            <label label={bind(currentTime).as((d) => formatter.format(d))} />
        </box>
    );
}

let notificationCenterWindow: Astal.Window | null;
export function createNotificationCenter() {
    notificationCenterWindow = (
        <window
            cssClasses={["notification-center-window"]}
            namespace="notification-center"
            anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.BOTTOM | Astal.WindowAnchor.RIGHT}
            layer={Astal.Layer.TOP}
            exclusivity={Astal.Exclusivity.NORMAL}
            setup={(self) => {
                App.add_window(self);
            }}
            onDestroy={() => console.log("notification center destroyed! this is a certified uh oh moment")}
        >
            <box vertical={true} name="notification-center" spacing={8}>
                <TopCarousel />
                {/* <WeatherIconDebug /> */}
                <NotificationList />
                <PreciseDateTime />
                <CalendarPanel />
            </box>
        </window>
    ) as Astal.Window;
}

export function toggleNotificationCenter() {
    if (!notificationCenterWindow) {
        throw new Error("Notification center window doesn't exist");
    }

    if (notificationCenterWindow.visible) {
        notificationCenterWindow.hide();
        cancelClickCapture();
    } else {
        // notificationCenterWindow.gdkmonitor = monitor;
        notificationCenterWindow.present();
        setupClickCapture(() => {
            notificationCenterWindow!.hide();
        });
    }
}
