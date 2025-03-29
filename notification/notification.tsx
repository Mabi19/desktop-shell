import { Gdk, Gtk } from "astal/gtk4";
import Adw from "gi://Adw?version=1";
import AstalNotifd from "gi://AstalNotifd";
import GLib from "gi://GLib?version=2.0";
import Pango from "gi://Pango?version=1.0";
import { Timer } from "../utils/timer";
import { WrapBox } from "../widgets/wrap-box";

const DEFAULT_TIMEOUT = 5000;

const iconTheme = Gtk.IconTheme.get_for_display(Gdk.Display.get_default()!);
const isIcon = (name: string | null) => name && iconTheme.has_icon(name);

const fileExists = (path: string | null) => path && GLib.file_test(path, GLib.FileTest.EXISTS);

export interface NotificationWidgetEntry {
    widget: Gtk.Widget;
    cleanup: () => void;
}

// This widget provides the constant parts of the notification.
// It also chooses a suitable layout for the notification.
export function NotificationWrapper({
    notification,
}: {
    notification: AstalNotifd.Notification;
}): NotificationWidgetEntry {
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
                <button onClicked={() => notification.invoke(action.id)} hexpand={true}>
                    {action.label}
                </button>
            );
        }
    }

    const actionBox =
        actionButtons.length > 0 ? (
            <WrapBox childSpacing={8} lineSpacing={8} justify={Adw.JustifyMode.FILL} cssClasses={["actions"]}>
                {actionButtons}
            </WrapBox>
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
