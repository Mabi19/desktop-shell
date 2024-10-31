import { bind } from "astal";
import { App, Astal, Widget } from "astal/gtk3";
import { interval } from "astal/time";
import AstalNotifd from "gi://AstalNotifd";
import GLib from "gi://GLib";
import { primaryMonitor } from "../utils/config";
import { Notifier } from "../utils/notifier";
import { ProgressBar } from "../widgets/progress-bar";

const notifd = AstalNotifd.get_default();

const DEFAULT_TIMEOUT = 5000;
const notificationTimeouts = new Map<number, { timeLeft: number; paused: boolean }>();
const timeoutUpdate = new Notifier();

let lastFireTime = GLib.get_monotonic_time();
interval(10, () => {
    const now = GLib.get_monotonic_time();
    const delta = (now - lastFireTime) / 1000;

    for (let [id, { timeLeft, paused }] of notificationTimeouts) {
        if (paused) {
            continue;
        }

        timeLeft -= delta;
        if (timeLeft > 0) {
            notificationTimeouts.set(id, { timeLeft, paused });
        } else {
            notifd.get_notification(id).dismiss();
            notificationTimeouts.delete(id);
        }
    }

    timeoutUpdate.notify();

    lastFireTime = now;
});

function setPaused(id: number, state: boolean) {
    const data = notificationTimeouts.get(id);
    if (!data) {
        return;
    }

    data.paused = state;
}

export const NotificationPopupWindow = () => {
    const popupBox = (
        <box vertical={true} name="notification-popup-area" spacing={12} vexpand={false}></box>
    ) as Widget.Box;

    popupBox.hook(notifd, "notified", (_, id) => {
        const notification = notifd.get_notification(id);
        const widget = <Notification notification={notification} />;
        notificationTimeouts.set(id, { timeLeft: DEFAULT_TIMEOUT, paused: false });
        popupBox.add(widget);
        notification.connect("resolved", () => {
            // TODO: move into notification center
            popupBox.remove(widget);
            widget.destroy();
        });
    });

    return (
        <window
            name="notification-popup-area"
            namespace="notification-popup-area"
            anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT}
            layer={Astal.Layer.OVERLAY}
            gdkmonitor={bind(primaryMonitor)}
            setup={(self) => App.add_window(self)}
            // TODO: set visible only if there are notifications
        >
            {popupBox}
        </window>
    );
};

const NotificationIcon = ({ notification }: { notification: AstalNotifd.Notification }) => {
    if (notification.image) {
        return <icon icon={bind(notification, "image")} className="icon" />;
    }
    if (notification.appIcon) {
        return <icon icon={bind(notification, "appIcon")} className="icon" />;
    } else if (notification.desktopEntry) {
        return <icon icon={bind(notification, "desktopEntry")} className="icon" />;
    } else {
        return <icon icon="dialog-information-symbolic" className="icon" />;
    }
};

const Notification = ({ notification }: { notification: AstalNotifd.Notification }) => {
    // TODO: revealer for animations
    // TODO: urgency (low: dimmed progress bar, normal: regular progress bar, critical: red border?)
    // TODO: actions
    // TODO: other stuff?
    return (
        // put the progress bar outside of the padding box so that it can hug the edge
        <eventbox
            onHover={() => setPaused(notification.id, true)}
            onHoverLost={() => setPaused(notification.id, false)}
        >
            <box vertical={true} vexpand={false} widthRequest={300} className="notification">
                <box vertical={true} className="content" spacing={8}>
                    <box spacing={8}>
                        <NotificationIcon notification={notification} />
                        <label label={bind(notification, "summary")} className="title" xalign={0} />
                    </box>
                    <label
                        label={bind(notification, "body")}
                        className="description"
                        useMarkup={true}
                        wrap={true}
                        xalign={0}
                    />
                    <box spacing={8}>
                        <button>a</button>
                        <button>b</button>
                    </box>
                </box>

                <ProgressBar
                    fraction={bind(timeoutUpdate).as(() => {
                        const timeLeft = notificationTimeouts.get(notification.id)?.timeLeft;
                        if (!timeLeft) {
                            return 1;
                        } else {
                            return 1 - timeLeft / DEFAULT_TIMEOUT;
                        }
                    })}
                />
            </box>
        </eventbox>
    );
};
