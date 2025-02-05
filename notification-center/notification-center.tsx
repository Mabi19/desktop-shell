import { Variable, bind } from "astal";
import { App, Astal, Gdk } from "astal/gtk4";
import Adw from "gi://Adw?version=1";
import { Calendar } from "../widgets/calendar";
import { WeatherIconDebug, WeatherPanel } from "./weather-panel";

export const notificationCenterMonitor = Variable<Gdk.Monitor | null>(null);

function TopCarousel() {
    const carousel = new Adw.Carousel();
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

export const NotificationCenter = (monitor: Gdk.Monitor) => {
    return (
        <window
            name={`notification-center${monitor}`}
            cssClasses={["notification-center-window"]}
            namespace="notification-center"
            anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.BOTTOM | Astal.WindowAnchor.RIGHT}
            layer={Astal.Layer.OVERLAY}
            exclusivity={Astal.Exclusivity.NORMAL}
            gdkmonitor={monitor}
            setup={(self) => App.add_window(self)}
            visible={bind(notificationCenterMonitor).as((mon) => mon == monitor)}
        >
            <box vertical={true} name="notification-center">
                <TopCarousel />
                {/* <WeatherIconDebug /> */}
                <CalendarPanel />
            </box>
        </window>
    );
};
