import { bind, Variable } from "astal";
import { App, Astal, hook } from "astal/gtk4";
import Adw from "gi://Adw?version=1";
import AstalMpris from "gi://AstalMpris?version=0.1";
import GLib from "gi://GLib?version=2.0";
import { Notifier } from "../utils/notifier";
import { currentTime, makeDateTimeFormat } from "../utils/time";
import { Calendar } from "../widgets/calendar";
import { cancelClickCapture, setupClickCapture } from "./click-capturer";
import { MediaPlayer } from "./media";
import { NotificationList } from "./notification-list";
import { WeatherIconDebug, WeatherPanel } from "./weather-panel";

function MediaCarousel() {
    const carousel = new Adw.Carousel({ spacing: 8 });
    carousel.append(<WeatherPanel />);

    const mpris = AstalMpris.get_default();
    const players = mpris.get_players();
    for (const player of players) {
        carousel.append(new MediaPlayer({ player }));
    }
    mpris.connect("player-added", (_, player) => {
        console.log("player-added", player.busName);
        players.push(player);
        carousel.append(new MediaPlayer({ player }));
    });
    mpris.connect("player-closed", (_, player) => {
        console.log("player-removed", player.busName);
        const idx = players.indexOf(player);
        if (idx < 0) {
            console.error("couldn't find player to remove", player.busName);
        }
        players.splice(idx, 1);
        const widget = carousel.get_nth_page(idx + 1);
        carousel.remove(widget);
    });

    return (
        <box vertical={true}>
            {carousel}
            {new Adw.CarouselIndicatorDots({ carousel })}
        </box>
    );
}

const openNotify = new Notifier(void 0);
const closeNotify = new Notifier(void 0);

function CalendarPanel() {
    // TODO: Consider making a fully custom calendar.
    // TODO: Show calendar events on the side to not make it W I D E.
    // This will require integrating evolution-data-server and gnome-online-accounts.
    // https://nixos.wiki/wiki/GNOME/Calendar
    // This AGS v1 PR may prove helpful: https://github.com/Aylur/ags/pull/177
    // It also includes editing, but that will probably be better left to a dedicated calendar app.
    return (
        <Calendar
            setup={(self) => {
                hook(self, openNotify, (self) => {
                    self.select_day(new GLib.DateTime());
                });
                self.add_css_class("calendar");
            }}
        />
    );
}

const formatter = makeDateTimeFormat({
    timeStyle: "medium",
    dateStyle: "medium",
});
const formattedCurrentTime = new Variable("");
function updateTime(time: Date) {
    formattedCurrentTime.set(formatter.format(time));
}

let timeUnsub: (() => void) | null;
openNotify.subscribe(() => {
    if (timeUnsub) timeUnsub();

    updateTime(currentTime.get());
    timeUnsub = currentTime.subscribe(updateTime);
});
closeNotify.subscribe(() => {
    if (timeUnsub) timeUnsub();
    timeUnsub = null;
});

function PreciseDateTime() {
    return (
        <box cssClasses={["precise-clock"]} spacing={8}>
            <image iconName="fa-clock-symbolic" pixelSize={24} />
            <label label={bind(formattedCurrentTime)} />
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
                <PreciseDateTime />
                <CalendarPanel />
                <NotificationList />
                <MediaCarousel />
                {/* <WeatherIconDebug /> */}
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
        closeNotify.notify(void 0);
    } else {
        openNotify.notify(void 0);
        notificationCenterWindow.present();
        setupClickCapture(() => {
            notificationCenterWindow!.hide();
            closeNotify.notify(void 0);
        });
    }
}
