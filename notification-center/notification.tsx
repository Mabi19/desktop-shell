import { bind, Variable } from "astal";
import { type Subscribable } from "astal/binding";
import { App, Astal, Gtk, Widget } from "astal/gtk4";
import AstalNotifd from "gi://AstalNotifd";
import { primaryMonitor } from "../utils/config";
import { Timer } from "../utils/timer";
import { ProgressBar } from "../widgets/progress-bar";

const notifd = AstalNotifd.get_default();

const DEFAULT_TIMEOUT = 5000;

// The purpose if this class is to replace Variable<Array<Widget>>
// with a Map<number, Widget> type in order to track notification widgets
// by their id, while making it conviniently bindable as an array
class NotificationMap implements Subscribable {
    // the underlying map to keep track of id widget pairs
    private map: Map<number, Gtk.Widget> = new Map();

    // it makes sense to use a Variable under the hood and use its
    // reactivity implementation instead of keeping track of subscribers ourselves
    private var: Variable<Array<Gtk.Widget>> = Variable([]);

    // notify subscribers to rerender when state changes
    private notify() {
        this.var.set([...this.map.values()].reverse());
    }

    constructor() {
        /**
         * uncomment this if you want to
         * ignore timeout by senders and enforce our own timeout
         * note that if the notification has any actions
         * they might not work, since the sender already treats them as resolved
         */
        // notifd.ignoreTimeout = true

        notifd.connect("notified", (_, id) => {
            this.set(
                id,
                Notification({
                    notification: notifd.get_notification(id)!,
                })
            );
        });

        // notifications can be closed by the outside before
        // any user input, which have to be handled too
        notifd.connect("resolved", (_, id) => {
            this.delete(id);
        });
    }

    private set(key: number, value: Gtk.Widget) {
        // in case of replacement destroy previous widget
        this.map.get(key)?.destroy();
        this.map.set(key, value);
        this.notify();
    }

    private delete(key: number) {
        this.map.get(key)?.destroy();
        this.map.delete(key);
        this.notify();
    }

    // needed by the Subscribable interface
    get() {
        return this.var.get();
    }

    // needed by the Subscribable interface
    subscribe(callback: (list: Array<Gtk.Widget>) => void) {
        return this.var.subscribe(callback);
    }
}

export const NotificationPopupWindow = () => {
    const notifs = new NotificationMap();

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
            <box vertical name="notification-popup-area" spacing={12} vexpand={false}>
                {bind(notifs)}
            </box>
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
    console.log("got notification! timeout:", notification.expireTimeout);
    const timer = new Timer(
        notification.expireTimeout == -1 ? DEFAULT_TIMEOUT : notification.expireTimeout
    );

    /** Invoke an action by its ID, checking if it exists */
    function handleDefaultClick(event: Astal.ClickEvent) {
        if (event.button == Astal.MouseButton.PRIMARY) {
            const action = notification.get_actions().find((action) => action.id == "default");
            if (action) {
                notification.invoke("default");
            }
        } else if (event.button == Astal.MouseButton.SECONDARY) {
            notification.dismiss();
        }
    }

    // TODO: rework layout
    // Layout idea notes:
    // Easy way to close is needed. Currently that's just a right-click, but a regular close button will probably be included as well
    // Big image like in example would be cool to have, and it would prevent having to wrap the title
    // I still think that the progress bar is a cool idea (but maybe not as the notification's bottom edge)
    // that effect would be way easier to do in GTK 4
    // Also, remember to wrap and justify all the labels!
    // TODO: revealer for animations
    // TODO: urgency (low: dimmed progress bar, normal: regular progress bar, critical: red border?)
    // TODO: move into notification center
    return (
        // put the progress bar outside of the padding box so that it can hug the edge
        <eventbox
            onHover={() => timer.pauseCount++}
            onHoverLost={() => timer.pauseCount--}
            onClick={(_eventBox, event) => handleDefaultClick(event)}
            // make sure the timer doesn't try do anything weird later
            onDestroy={() => timer.cancel()}
            setup={(self) =>
                self.hook(timer, () => {
                    if (timer.timeLeft == 0) {
                        // TODO: move into notif center
                        notification.dismiss();
                    }
                })
            }
        >
            <box vertical={true} vexpand={false} widthRequest={400} className="notification">
                <box vertical={true} className="content" spacing={8}>
                    <box spacing={8}>
                        <NotificationIcon notification={notification} />
                        <label label={bind(notification, "summary")} className="title" xalign={0} />
                        <button onClick={() => notification.dismiss()}>
                            <icon icon="window-close-symbolic" />
                        </button>
                    </box>
                    <label
                        label={bind(notification, "body")}
                        className="description"
                        useMarkup={true}
                        wrap={true}
                        xalign={0}
                    />

                    {notification.get_actions().length > 0 && (
                        <box spacing={8}>
                            {notification.get_actions().map((action) => (
                                <button
                                    onClick={() => notification.invoke(action.id)}
                                    hexpand={true}
                                >
                                    {action.label}
                                </button>
                            ))}
                        </box>
                    )}
                </box>

                <ProgressBar
                    fraction={bind(timer).as(() => {
                        return 1 - timer.timeLeft / timer.timeout;
                    })}
                />
            </box>
        </eventbox>
    );
};
