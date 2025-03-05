import { bind, Variable } from "astal";
import GObject, { register, signal } from "astal/gobject";
import { App, Astal, Gdk, Gtk } from "astal/gtk4";
import AstalNotifd from "gi://AstalNotifd";
import GLib from "gi://GLib?version=2.0";
import GSound from "gi://GSound";
import Pango from "gi://Pango?version=1.0";
import { primaryMonitor } from "../utils/config";
import { getSoundContext } from "../utils/sound";
import { Timer } from "../utils/timer";
import { FlexBoxLayout } from "./flexbox-layout";
import { dumpNotification } from "./notification-dump";

const DEFAULT_TIMEOUT = 5000;

const iconTheme = Gtk.IconTheme.get_for_display(Gdk.Display.get_default()!);
const isIcon = (name: string | null) => name && iconTheme.has_icon(name);

const fileExists = (path: string | null) => path && GLib.file_test(path, GLib.FileTest.EXISTS);

interface WidgetEntry {
    widget: Gtk.Widget;
    cleanup: () => void;
}

@register()
class NotificationTracker extends GObject.Object {
    context: GSound.Context;

    #widgets: Map<number, WidgetEntry>;

    @signal(Object)
    declare create: (widget: WidgetEntry) => void;

    @signal(Object, Object)
    declare replace: (prev: WidgetEntry, curr: WidgetEntry) => void;

    @signal(Object)
    declare destroy: (widget: WidgetEntry) => void;

    playSoundFor(notification: AstalNotifd.Notification) {
        if (notification.suppressSound) {
            return;
        }

        if (notification.soundFile) {
            this.context.play_simple({ [GSound.ATTR_MEDIA_FILENAME]: notification.soundFile }, null);
        } else {
            this.context.play_simple({ [GSound.ATTR_EVENT_ID]: notification.soundName ?? "message" }, null);
        }
    }

    constructor() {
        super();
        this.context = getSoundContext();
        this.#widgets = new Map();

        const notifd = AstalNotifd.get_default();
        // This is handled by the notifications themselves.
        notifd.set_ignore_timeout(true);

        notifd.connect("notified", (_, id) => {
            console.log("notification created", id);
            const notification = notifd.get_notification(id);
            dumpNotification(notification);

            const existingWidget = this.#widgets.get(id);
            const newWidget = NotificationWrapper({
                notification,
            });
            this.#widgets.set(id, newWidget);

            if (existingWidget) {
                this.emit("replace", existingWidget, newWidget);
            } else {
                this.playSoundFor(notification);
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

    const windowVisible = Variable(false);
    const box = (<box vertical={true} spacing={12} noImplicitDestroy={true}></box>) as Astal.Box;

    notifs.connect("create", (_, entry: WidgetEntry) => {
        if (box.get_children().length == 0) {
            windowVisible.set(true);
        }

        box.prepend(entry.widget);
    });
    notifs.connect("replace", (_, prev: WidgetEntry, curr: WidgetEntry) => {
        box.insert_child_after(curr.widget, prev.widget);
        box.remove(prev.widget);
        prev.cleanup();
    });
    notifs.connect("destroy", (_, entry: WidgetEntry) => {
        box.remove(entry.widget);
        entry.cleanup();
        if (box.get_first_child() == null) {
            windowVisible.set(false);
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
            visible={windowVisible()}
            // This causes the window to be able to shrink back down when the notification is destroyed.
            // But only if it isn't transparent.
            defaultWidth={1}
            defaultHeight={1}
            onDestroy={() => windowVisible.drop()}
        >
            {box}
        </window>
    );
};

// This widget provides the constant parts of the notification.
// It also chooses a suitable layout for the notification.
function NotificationWrapper({ notification }: { notification: AstalNotifd.Notification }): WidgetEntry {
    // TODO: animations
    // TODO: urgency (low: dimmed progress bar, normal: regular progress bar, critical: red border?)
    // TODO: move into notification center

    console.log("got notification! timeout:", notification.expireTimeout);
    const NOTIFICATION_WIDTH = 400;

    // TODO: Replace this with the frame clock?
    const timer = new Timer(notification.expireTimeout == -1 ? DEFAULT_TIMEOUT : notification.expireTimeout);
    const progressBar = new Gtk.ProgressBar({ fraction: 1 });
    const cleanup = timer.subscribe(() => {
        progressBar.fraction = 1 - timer.timeLeft / timer.timeout;

        if (timer.timeLeft <= 0) {
            // notifications with a timeout must stay for the correct length of time,
            // so they need to be deleted instead of stored
            if (notification.expireTimeout != -1 || notification.transient) {
                notification.dismiss();
            } else {
                // TODO: Move to notification center
                notification.dismiss();
            }
        }
    });

    function handleBackgroundClick(event: Gdk.ButtonEvent) {
        const button = event.get_button();
        if (button == Gdk.BUTTON_PRIMARY) {
            const action = notification.get_actions().find((action) => action.id == "default");
            console.log("primary click", action);
            if (action) {
                notification.invoke("default");
            }
        } else if (button == Gdk.BUTTON_SECONDARY) {
            timer.cancel();
            notification.dismiss();
        }
    }

    function setPauseState(value: boolean) {
        // notifications with a set expire timeout need to expire precisely
        if (notification.expireTimeout != -1) {
            return;
        }
        timer.isPaused = value;
    }

    let icon: Gtk.Widget | null;
    if (notification.appIcon) {
        if (fileExists(notification.appIcon)) {
            icon = Gtk.Image.new_from_file(notification.appIcon);
        } else {
            icon = Gtk.Image.new_from_icon_name(notification.appIcon);
        }
    } else if (isIcon(notification.desktopEntry)) {
        icon = Gtk.Image.new_from_icon_name(notification.desktopEntry);
    } else {
        icon = Gtk.Image.new_from_icon_name("dialog-information-symbolic");
    }

    const actionButtons: Gtk.Widget[] = [];
    for (const action of notification.get_actions()) {
        if (action.id != "default") {
            actionButtons.push(
                <button onButtonPressed={() => notification.invoke(action.id)} hexpand={true}>
                    {action.label}
                </button>
            );
        }
    }

    const actionBox =
        actionButtons.length > 0 ? (
            <box spacing={8} cssClasses={["actions"]} layoutManager={new FlexBoxLayout({ spacing: 8 })}>
                {actionButtons}
            </box>
        ) : null;

    return {
        cleanup,
        widget: (
            <box
                onHoverEnter={() => setPauseState(true)}
                onHoverLeave={() => setPauseState(false)}
                onButtonReleased={(_box, event) => handleBackgroundClick(event)}
                vertical={true}
                hexpand={false}
                widthRequest={NOTIFICATION_WIDTH}
                cssClasses={["notification"]}
                overflow={Gtk.Overflow.HIDDEN}
            >
                <box cssClasses={["header"]} spacing={8}>
                    {icon}
                    <label label={notification.appName} halign={Gtk.Align.START} hexpand={true} />
                    <button
                        halign={Gtk.Align.END}
                        iconName="window-close-symbolic"
                        cssClasses={["close-button"]}
                        onClicked={() => {
                            notification.dismiss();
                        }}
                    />
                </box>
                <Gtk.Separator orientation={Gtk.Orientation.HORIZONTAL} cssClasses={["header-separator"]} />
                <NotificationLayoutProfile notification={notification} />
                {actionBox}
                {progressBar}
            </box>
        ),
    };
}

interface NotificationLabelProps {
    label: string;
    lines: number;
    useMarkup?: boolean;
    cssClasses?: string[];
}

function NotificationLabel(props: NotificationLabelProps) {
    // Sometimes there's extra whitespace, especially with KDE Connect
    props.label = props.label.trim();
    // Use U+2028 LINE SEPARATOR in order to not introduce paragraph breaks
    props.label = props.label.replaceAll("\n", "\u2028");
    return (
        <label
            {...props}
            wrap={true}
            ellipsize={Pango.EllipsizeMode.MIDDLE}
            // Setting this to a value that is definitely smaller than the box width
            // causes the label to expand to that size.
            maxWidthChars={5}
            halign={Gtk.Align.FILL}
            valign={Gtk.Align.CENTER}
            xalign={0}
            visible={Boolean(props.label)}
        />
    );
}

function NotificationImage({
    notification,
    ...props
}: Partial<Gtk.Image.ConstructorProps> & { notification: AstalNotifd.Notification }) {
    const path =
        notification.image && notification.image.startsWith("file://")
            ? notification.image.slice("file://".length)
            : notification.image;

    if (!path) {
        return null;
    } else if (fileExists(path)) {
        return <image {...props} file={path} cssClasses={["icon"]} />;
    } else if (isIcon(notification.image)) {
        return <image {...props} iconName={path} cssClasses={["icon"]} />;
    } else {
        return null;
    }
}

const NotificationLayoutProfile = ({ notification }: { notification: AstalNotifd.Notification }) => {
    const imageWidget = NotificationImage({ notification, pixelSize: 24 });

    return (
        <box hexpand={false} vertical={true} cssClasses={["layout", "layout-profile"]} spacing={4}>
            <box spacing={8}>
                {imageWidget ? (
                    <box cssClasses={["rounded-wrapper"]} valign={Gtk.Align.CENTER} overflow={Gtk.Overflow.HIDDEN}>
                        {imageWidget}
                    </box>
                ) : null}
                <NotificationLabel label={notification.summary} lines={2} cssClasses={["title"]} />
            </box>
            <NotificationLabel label={notification.body} lines={5} cssClasses={["description"]} useMarkup={true} />
        </box>
    );
};
