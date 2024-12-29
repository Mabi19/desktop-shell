import { bind, Variable } from "astal";
import { type Subscribable } from "astal/binding";
import { App, Astal, Gdk, Gtk, hook } from "astal/gtk4";
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
        return <image iconName={bind(notification, "image")} cssClasses={["icon"]} />;
    }
    if (notification.appIcon) {
        return <image iconName={bind(notification, "appIcon")} cssClasses={["icon"]} />;
    } else if (notification.desktopEntry) {
        return <image iconName={bind(notification, "desktopEntry")} cssClasses={["icon"]} />;
    } else {
        return <image iconName="dialog-information-symbolic" cssClasses={["icon"]} />;
    }
};

const Notification = ({ notification }: { notification: AstalNotifd.Notification }) => {
    console.log("got notification! timeout:", notification.expireTimeout);
    const timer = new Timer(
        notification.expireTimeout == -1 ? DEFAULT_TIMEOUT : notification.expireTimeout
    );

    /** Invoke an action by its ID, checking if it exists */
    function handleDefaultClick(event: Gdk.ButtonEvent) {
        const button = event.get_button();
        if (button == Gdk.BUTTON_PRIMARY) {
            const action = notification.get_actions().find((action) => action.id == "default");
            if (action) {
                notification.invoke("default");
            }
        } else if (button == Gdk.BUTTON_SECONDARY) {
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
        <box
            onHover={() => timer.pauseCount++}
            onHoverLost={() => timer.pauseCount--}
            onButtonPressed={(_eventBox, event) => handleDefaultClick(event)}
            // make sure the timer doesn't try do anything weird later
            onDestroy={() => timer.cancel()}
            setup={(self) =>
                hook(self, timer, () => {
                    if (timer.timeLeft == 0) {
                        // TODO: move into notif center
                        notification.dismiss();
                    }
                })
            }
        >
            <box vertical={true} vexpand={false} widthRequest={400} cssClasses={["notification"]}>
                <box vertical={true} cssClasses={["content"]} spacing={8}>
                    <box spacing={8}>
                        <NotificationIcon notification={notification} />
                        <label
                            label={bind(notification, "summary")}
                            cssClasses={["title"]}
                            xalign={0}
                        />
                        <button onButtonPressed={() => notification.dismiss()}>
                            <image iconName="window-close-symbolic" />
                        </button>
                    </box>
                    <label
                        label={bind(notification, "body")}
                        cssClasses={["description"]}
                        useMarkup={true}
                        wrap={true}
                        xalign={0}
                    />

                    {notification.get_actions().length > 0 ? (
                        <box spacing={8}>
                            {notification.get_actions().map((action) => (
                                <button
                                    onButtonPressed={() => notification.invoke(action.id)}
                                    hexpand={true}
                                >
                                    {action.label}
                                </button>
                            ))}
                        </box>
                    ) : (
                        false
                    )}
                </box>

                <ProgressBar
                    fraction={bind(timer).as(() => {
                        return 1 - timer.timeLeft / timer.timeout;
                    })}
                />
            </box>
        </box>
    );
};
