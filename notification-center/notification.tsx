import { bind } from "astal";
import GObject, { register, signal } from "astal/gobject";
import { App, Astal, Gdk, Gtk } from "astal/gtk4";
import AstalNotifd from "gi://AstalNotifd";
import GLib from "gi://GLib?version=2.0";
import Pango from "gi://Pango?version=1.0";
import { primaryMonitor } from "../utils/config";
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
    #widgets: Map<number, WidgetEntry>;

    @signal(Object)
    declare create: (widget: WidgetEntry) => void;

    @signal(Object, Object)
    declare replace: (prev: WidgetEntry, curr: WidgetEntry) => void;

    @signal(Object)
    declare destroy: (widget: WidgetEntry) => void;

    constructor() {
        super();
        this.#widgets = new Map();

        const notifd = AstalNotifd.get_default();

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

    notifs.connect("create", (_, entry: WidgetEntry) => {
        box.add_css_class("notification-box-active");
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

// This widget provides the constant parts of the notification.
// It also chooses a suitable layout for the notification.
function NotificationWrapper({
    notification,
}: {
    notification: AstalNotifd.Notification;
}): WidgetEntry {
    // TODO: animations
    // TODO: urgency (low: dimmed progress bar, normal: regular progress bar, critical: red border?)
    // TODO: move into notification center

    console.log("got notification! timeout:", notification.expireTimeout);
    const NOTIFICATION_WIDTH = 400;

    // TODO: Replace this with the frame clock?
    const timer = new Timer(
        notification.expireTimeout == -1 ? DEFAULT_TIMEOUT : notification.expireTimeout
    );
    const progressBar = new Gtk.ProgressBar({ fraction: 1 });
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
        icon = null;
    }

    let actions: Gtk.Widget | null;
    if (notification.get_actions().length > 0) {
        // actions = new Gtk.FlowBox({
        //     rowSpacing: 8,
        //     columnSpacing: 8,
        //     cssClasses: ["actions"],
        //     selectionMode: Gtk.SelectionMode.NONE,
        //     maxChildrenPerLine: 3,
        // });
        // for (const action of notification.get_actions()) {
        //     actions.append(
        //         <Gtk.FlowBoxChild>
        //             <button onButtonPressed={() => notification.invoke(action.id)}>
        //                 {action.label}
        //             </button>
        //         </Gtk.FlowBoxChild>
        //     );
        // }
        // TODO: Use the fancy FlexBoxLayout here
        actions = (
            <box
                spacing={8}
                cssClasses={["actions"]}
                layoutManager={new FlexBoxLayout({ spacing: 8 })}
            >
                {notification.actions.map((action) => (
                    <button onButtonPressed={() => notification.invoke(action.id)} hexpand={true}>
                        {action.label}
                    </button>
                ))}
            </box>
        );
    } else {
        actions = null;
    }

    return {
        cleanup,
        widget: (
            <box
                onHoverEnter={() => timer.pauseCount++}
                onHoverLeave={() => timer.pauseCount--}
                onButtonPressed={(_box, event) => handleDefaultClick(event)}
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
                <Gtk.Separator
                    orientation={Gtk.Orientation.HORIZONTAL}
                    cssClasses={["header-separator"]}
                />
                <NotificationLayoutProfile notification={notification} />
                {actions}
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
    // Use U+2028 LINE SEPARATOR in order to not introduce paragraph breaks
    props.label = props.label.replaceAll("\n", "\u2028");
    return (
        <label
            {...props}
            wrap={true}
            ellipsize={Pango.EllipsizeMode.END}
            // Setting this to a value that is definitely smaller than the box width
            // causes the label to expand to that size.
            maxWidthChars={5}
            halign={Gtk.Align.FILL}
            xalign={0}
        />
    );
}

const NotificationLayoutProfile = ({
    notification,
}: {
    notification: AstalNotifd.Notification;
}) => {
    return (
        <box hexpand={false} vertical={true} cssClasses={["layout", "layout-profile"]} spacing={4}>
            <box spacing={8}>
                {/* TODO: test if that's a file or a named icon (see example) */}
                <image
                    iconName="dialog-information-symbolic"
                    visible={Boolean(notification.image)}
                />
                <NotificationLabel label={notification.summary} lines={2} cssClasses={["title"]} />
            </box>
            <NotificationLabel
                label={notification.body}
                lines={5}
                cssClasses={["description"]}
                useMarkup={true}
            />
        </box>
    );
};
