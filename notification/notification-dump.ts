import AstalNotifd from "gi://AstalNotifd?version=0.1";

const URGENCY_NAMES: Record<AstalNotifd.Urgency, string> = {
    [AstalNotifd.Urgency.LOW]: "low",
    [AstalNotifd.Urgency.NORMAL]: "normal",
    [AstalNotifd.Urgency.CRITICAL]: "critical",
};

export function dumpNotification(notification: AstalNotifd.Notification): void {
    console.log({
        id: notification.id,
        time: notification.time,
        expireTimeout: notification.expireTimeout,
        category: notification.category,
        appName: notification.appName,
        appIcon: notification.appIcon,
        summary: notification.summary,
        body: notification.body,
        image: notification.image,
        actions: notification.actions.map((action) => ({
            id: action.id,
            label: action.label,
        })),
        actionIcons: notification.actionIcons,
        desktopEntry: notification.desktopEntry,
        resident: notification.resident,
        soundFile: notification.soundFile,
        soundName: notification.soundName,
        suppressSound: notification.suppressSound,
        transient: notification.transient,
        x: notification.x,
        y: notification.y,
        urgency: URGENCY_NAMES[notification.urgency],
    });
}
