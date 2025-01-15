import { bind } from "astal";
import GObject, { register, signal } from "astal/gobject";
import { App, Astal, Gdk, Gtk, astalify } from "astal/gtk4";
import AstalNotifd from "gi://AstalNotifd";
import Pango from "gi://Pango?version=1.0";
import { primaryMonitor } from "../utils/config";
import { Timer } from "../utils/timer";
import { ProgressBar } from "../widgets/progress-bar";

const Inscription = astalify(Gtk.Inscription);

const DEFAULT_TIMEOUT = 5000;
const NOTIFICATION_CLEANUP_FUNCTION = Symbol();

@register()
class NotificationTracker extends GObject.Object {
    #widgets: Map<number, Gtk.Widget>;

    @signal(Gtk.Widget)
    declare create: (widget: Gtk.Widget) => void;

    @signal(Gtk.Widget, Gtk.Widget)
    declare replace: (prev: Gtk.Widget, curr: Gtk.Widget) => void;

    @signal(Gtk.Widget)
    declare destroy: (widget: Gtk.Widget) => void;

    constructor() {
        super();
        this.#widgets = new Map();

        const notifd = AstalNotifd.get_default();

        notifd.connect("notified", (_, id) => {
            console.log("notification created", id);

            const existingWidget = this.#widgets.get(id);

            const newWidget = Notification({
                notification: notifd.get_notification(id),
            });
            this.#widgets.set(id, newWidget);

            if (existingWidget) {
                this.emit("replace", existingWidget, newWidget);
            } else {
                this.emit("create", newWidget);
            }
        });

        notifd.connect("resolved", (_, id) => {
            console.log("notification resolved", id);

            const widget = this.#widgets.get(id);
            if (widget) {
                this.#widgets.delete(id);
                this.emit("destroy", widget);
            }
        });
    }
}

export const NotificationPopupWindow = () => {
    const notifs = new NotificationTracker();

    const box = (<box vertical={true} spacing={12} noImplicitDestroy={true}></box>) as Astal.Box;

    notifs.connect("create", (_, widget: Gtk.Widget) => {
        box.add_css_class("notification-box-active");
        box.prepend(widget);
    });
    notifs.connect("replace", (_, prev: Gtk.Widget, curr: Gtk.Widget) => {
        box.insert_child_after(curr, prev);
        // @ts-expect-error this is Object.assign()'ed
        prev[NOTIFICATION_CLEANUP_FUNCTION]?.();
        box.remove(prev);
    });
    notifs.connect("destroy", (_, widget: Gtk.Widget) => {
        console.log("removing", widget);
        box.remove(widget);
        // @ts-expect-error this is Object.assign()'ed
        widget[NOTIFICATION_CLEANUP_FUNCTION]?.();
        if (box.get_first_child() == null) {
            box.remove_css_class("notification-box-active");
        }
    });

    return (
        <window
            name="notification-popup-window"
            namespace="notification-popups"
            anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT}
            layer={Astal.Layer.OVERLAY}
            gdkmonitor={bind(primaryMonitor)}
            setup={(self) => App.add_window(self)}
            visible={true}
            // This causes the window to be able to shrink back down when the notification is destroyed.
            // But only if it isn't transparent.
            defaultWidth={-1}
            defaultHeight={-1}
        >
            {box}
        </window>
    );
};

const NotificationIcon = ({ notification }: { notification: AstalNotifd.Notification }) => {
    if (notification.image) {
        return <image iconName={notification.image} cssClasses={["icon"]} />;
    }
    if (notification.appIcon) {
        return <image iconName={notification.appIcon} cssClasses={["icon"]} />;
    } else if (notification.desktopEntry) {
        return <image iconName={notification.desktopEntry} cssClasses={["icon"]} />;
    } else {
        return <image iconName="dialog-information-symbolic" cssClasses={["icon"]} />;
    }
};

const Notification = ({ notification }: { notification: AstalNotifd.Notification }) => {
    console.log("got notification! timeout:", notification.expireTimeout);
    // TODO: Replace this with the frame clock?
    const timer = new Timer(
        notification.expireTimeout == -1 ? DEFAULT_TIMEOUT : notification.expireTimeout
    );
    const progressBar = new Gtk.ProgressBar({ fraction: 0 });
    const cleanup = timer.subscribe(() => {
        progressBar.fraction = 1 - timer.timeLeft / timer.timeout;

        if (timer.timeLeft <= 0) notification.dismiss();
    });

    /** Invoke an action by its ID, checking if it exists */
    function handleDefaultClick(event: Gdk.ButtonEvent) {
        const button = event.get_button();
        if (button == Gdk.BUTTON_PRIMARY) {
            const action = notification.get_actions().find((action) => action.id == "default");
            if (action) {
                notification.invoke("default");
            }
        } else if (button == Gdk.BUTTON_SECONDARY) {
            timer.cancel();
            notification.dismiss();
        }
    }

    // TODO: rework layout
    // Have multiple layouts switched between with heuristics

    // TODO: animations
    // TODO: urgency (low: dimmed progress bar, normal: regular progress bar, critical: red border?)
    // TODO: move into notification center

    const NOTIFICATION_WIDTH = 400;
    const NOTIFICATION_PADDING = 8;

    // progress bar is on the outside so that it can hug the edge
    return (
        <box
            onHoverEnter={() => timer.pauseCount++}
            onHoverLeave={() => timer.pauseCount--}
            onButtonPressed={(_eventBox, event) => handleDefaultClick(event)}
            vertical={true}
            hexpand={false}
            vexpand={false}
            widthRequest={NOTIFICATION_WIDTH}
            cssClasses={["notification"]}
            overflow={Gtk.Overflow.HIDDEN}
            // TODO: Do something a little less janky here. In fact, actually just return a meta-object that has some methods.
            setup={(self) => Object.assign(self, { [NOTIFICATION_CLEANUP_FUNCTION]: cleanup })}
        >
            <box hexpand={false} vertical={true} cssClasses={["content"]} spacing={8}>
                <box spacing={8}>
                    <NotificationIcon notification={notification} />
                    <label label={notification.summary} cssClasses={["title"]} xalign={0} />
                    <button onButtonPressed={() => notification.dismiss()}>
                        <image iconName="window-close-symbolic" />
                    </button>
                </box>
                <label
                    // Use U+2028 LINE SEPARATOR in order to not introduce paragraph breaks.
                    label={notification.body.replaceAll("\n", "\u2028")}
                    cssClasses={["description"]}
                    useMarkup={true}
                    wrap={true}
                    ellipsize={Pango.EllipsizeMode.MIDDLE}
                    // Setting this to a value that is definitely smaller than the box width
                    // causes the label to expand to that size.
                    maxWidthChars={5}
                    lines={3}
                    halign={Gtk.Align.FILL}
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
            {progressBar}
        </box>
    );
};
