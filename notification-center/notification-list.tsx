import { Variable, bind } from "astal";
import { Astal, Gtk } from "astal/gtk4";
import Adw from "gi://Adw?version=1";
import type { NotificationWidgetEntry } from "../notification/notification";
import { NotificationTracker } from "../notification/tracker";
import { ScrolledWindow } from "../widgets/scrolled-window";
import { StatusPage } from "../widgets/status-page";

export function NotificationList() {
    const notifs = NotificationTracker.getInstance();
    const notificationBox = (
        <box vertical={true} valign={Gtk.Align.START} noImplicitDestroy={true}></box>
    ) as Astal.Box;
    const hasNotifications = new Variable(false);

    notifs.connect("stored-add", (_, entry: NotificationWidgetEntry) => {
        notificationBox.prepend(entry.widget);
        hasNotifications.set(true);
    });
    notifs.connect("stored-replace", (_, prev: NotificationWidgetEntry, curr: NotificationWidgetEntry) => {
        notificationBox.insert_child_after(curr.widget, prev.widget);
        notificationBox.remove(prev.widget);
    });
    notifs.connect("stored-remove", (_, entry: NotificationWidgetEntry) => {
        notificationBox.remove(entry.widget);
        if (notificationBox.get_first_child() == null) {
            hasNotifications.set(false);
        }
    });

    // TODO: Clear button
    // TODO: Do-not-disturb mode
    return (
        <box vertical={true} spacing={8}>
            <box>
                <label label="Notifications" cssClasses={["heading"]} />
            </box>
            <ScrolledWindow hexpand={true} vexpand={true} visible={hasNotifications()}>
                {notificationBox}
            </ScrolledWindow>
            <StatusPage
                hexpand={true}
                vexpand={true}
                iconName="fa-bell-slash-symbolic"
                title="No notifications"
                visible={bind(hasNotifications).as((value) => !value)}
            />
        </box>
    );
}
