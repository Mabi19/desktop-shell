import GObject, { register, signal } from "astal/gobject";
import AstalNotifd from "gi://AstalNotifd?version=0.1";
import GSound from "gi://GSound";
import { getSoundContext } from "../utils/sound";
import { NotificationWidget, type NotificationWidgetEntry } from "./notification";

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

export interface NotificationMeta {
    layout: "profile";
}

let trackerInstance: NotificationTracker | null;

@register()
export class NotificationTracker extends GObject.Object {
    private context: GSound.Context;

    // The widgets logically visible as popups.
    private popupWidgets: Map<number, NotificationWidgetEntry>;
    // Widgets which aren't anywhere logically, but are still attached to the popups window
    // (i.e. they're animating out)
    private limboWidgets: Map<number, NotificationWidgetEntry>;
    // The widgets logically in the notification center.
    private storedWidgets: Map<number, NotificationWidgetEntry>;

    @signal(Object)
    declare popup_add: (widget: NotificationWidgetEntry) => void;
    @signal(Object, Object)
    declare popup_replace: (prev: NotificationWidgetEntry, curr: NotificationWidgetEntry) => void;
    @signal(Object, Object)
    declare popup_remove: (widget: NotificationWidgetEntry, finishCallback: () => void) => void;

    @signal(Object)
    declare stored_add: (widget: NotificationWidgetEntry) => void;
    @signal(Object, Object)
    declare stored_replace: (prev: NotificationWidgetEntry, curr: NotificationWidgetEntry) => void;
    @signal(Object)
    declare stored_remove: (widget: NotificationWidgetEntry) => void;

    private playSoundFor(notification: AstalNotifd.Notification) {
        if (notification.suppressSound) {
            return;
        }

        if (notification.soundFile) {
            this.context.play_simple({ [GSound.ATTR_MEDIA_FILENAME]: notification.soundFile }, null);
        } else {
            this.context.play_simple({ [GSound.ATTR_EVENT_ID]: notification.soundName ?? "message" }, null);
        }
    }

    private transferToStorage(id: number) {
        const popupWidget = this.popupWidgets.get(id);
        if (!popupWidget) {
            return;
        }

        this.popupWidgets.delete(id);
        this.limboWidgets.set(id, popupWidget);
        this.emit("popup-remove", popupWidget, () => {
            const limboWidget = this.limboWidgets.get(id);
            if (!limboWidget) {
                // this might happen if the widget's dismissed while it's animating out
                return;
            }
            this.limboWidgets.delete(id);
            this.storedWidgets.set(id, limboWidget);
            limboWidget.patchForStorage();
            this.emit("stored-add", limboWidget);
        });
    }

    constructor() {
        super();
        this.context = getSoundContext();
        this.popupWidgets = new Map();
        this.limboWidgets = new Map();
        this.storedWidgets = new Map();

        const notifd = AstalNotifd.get_default();
        // This is handled by the notification widget.
        notifd.set_ignore_timeout(true);

        notifd.connect("notified", (_, id) => {
            console.log("notification created", id);
            const notification = notifd.get_notification(id);
            // translateNotification(notification);
            const newWidget = NotificationWidget({
                notification,
                transfer: () => this.transferToStorage(id),
                meta: {
                    layout: "profile",
                },
            });

            const popupWidget = this.popupWidgets.get(id);
            const limboWidget = this.limboWidgets.get(id);
            const storedWidget = this.storedWidgets.get(id);

            this.popupWidgets.set(id, newWidget);
            if (popupWidget) {
                // existing popup: stop it, replace
                popupWidget.stopTimer();
                this.emit("popup-replace", popupWidget, newWidget);
            } else if (limboWidget) {
                // in limbo: treat it as new
                // (cancelling the animation would be better, but it's hard for little benefit)
                this.limboWidgets.delete(id);
                this.emit("popup-add", newWidget);
            } else if (storedWidget) {
                // in storage: different windows, so remove and add
                // since it wasn't previously a popup, play its sound again
                this.storedWidgets.delete(id);
                this.playSoundFor(notification);
                this.emit("stored-remove", storedWidget);
                this.emit("popup-add", newWidget);
            } else {
                // not an existing widget
                this.playSoundFor(notification);
                this.emit("popup-add", newWidget);
            }
        });

        notifd.connect("resolved", (_, id) => {
            console.log("notification resolved", id);

            const popupWidget = this.popupWidgets.get(id);
            if (popupWidget) {
                this.popupWidgets.delete(id);
                popupWidget.stopTimer();
                // The widget is just gone, so it doesn't need to go into limbo
                // so there's no need to run code after it's removed from the popups
                this.emit("popup-remove", popupWidget, () => {});
                return;
            }

            const limboWidget = this.limboWidgets.get(id);
            if (limboWidget) {
                // The widget will be removed from the popups window eventually.
                this.limboWidgets.delete(id);
                return;
            }

            const storedWidget = this.storedWidgets.get(id);
            if (storedWidget) {
                this.storedWidgets.delete(id);
                this.emit("stored-remove", storedWidget);
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
