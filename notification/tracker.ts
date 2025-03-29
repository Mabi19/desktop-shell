import GObject, { register, signal } from "astal/gobject";
import AstalNotifd from "gi://AstalNotifd?version=0.1";
import GSound from "gi://GSound";
import { getSoundContext } from "../utils/sound";
import { NotificationWrapper, type NotificationWidgetEntry } from "./notification";

// const notificationProxy = Symbol("notification proxy");
// interface NotificationData {
//     [notificationProxy]: AstalNotifd.Notification;
//     time: number;
//     appName: string | null;
//     appIcon: string | null;
// }

// const URGENCY_NAMES: Record<AstalNotifd.Urgency, string> = {
//     [AstalNotifd.Urgency.LOW]: "low",
//     [AstalNotifd.Urgency.NORMAL]: "normal",
//     [AstalNotifd.Urgency.CRITICAL]: "critical",
// };

// export function translateNotification(notification: AstalNotifd.Notification): NotificationData {
//     return {
//         id: notification.id,
//         time: notification.time,
//         expireTimeout: notification.expireTimeout,
//         category: notification.category,
//         appName: notification.appName,
//         appIcon: notification.appIcon,
//         summary: notification.summary,
//         body: notification.body,
//         image: notification.image,
//         actions: notification.actions.map((action) => ({
//             id: action.id,
//             label: action.label,
//         })),
//         actionIcons: notification.actionIcons,
//         desktopEntry: notification.desktopEntry,
//         resident: notification.resident,
//         soundFile: notification.soundFile,
//         soundName: notification.soundName,
//         suppressSound: notification.suppressSound,
//         transient: notification.transient,
//         x: notification.x,
//         y: notification.y,
//         urgency: URGENCY_NAMES[notification.urgency],
//     };
// }

let trackerInstance: NotificationTracker | null;

@register()
export class NotificationTracker extends GObject.Object {
    private context: GSound.Context;

    private popupWidgets: Map<number, NotificationWidgetEntry>;

    @signal(Object)
    declare popup_add: (widget: NotificationWidgetEntry) => void;

    @signal(Object, Object)
    declare popup_replace: (prev: NotificationWidgetEntry, curr: NotificationWidgetEntry) => void;

    @signal(Object)
    declare popup_remove: (widget: NotificationWidgetEntry) => void;

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
        this.popupWidgets = new Map();

        const notifd = AstalNotifd.get_default();
        // This is handled by the notifications themselves.
        notifd.set_ignore_timeout(true);

        notifd.connect("notified", (_, id) => {
            console.log("notification created", id);
            const notification = notifd.get_notification(id);
            // translateNotification(notification);

            const existingWidget = this.popupWidgets.get(id);
            const newWidget = NotificationWrapper({
                notification,
            });
            this.popupWidgets.set(id, newWidget);

            if (existingWidget) {
                this.emit("popup-replace", existingWidget, newWidget);
            } else {
                this.playSoundFor(notification);
                this.emit("popup-add", newWidget);
            }
        });

        notifd.connect("resolved", (_, id) => {
            console.log("notification resolved", id);

            const widget = this.popupWidgets.get(id);
            if (widget) {
                this.popupWidgets.delete(id);
                this.emit("popup-remove", widget);
            }
        });
    }

    static getInstance(): NotificationTracker {
        if (!trackerInstance) {
            trackerInstance = new NotificationTracker();
        }
        return trackerInstance;
    }
}
