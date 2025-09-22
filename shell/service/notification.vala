enum NotificationLayout {
    MESSAGE,
}

class NotificationProxy : Object {
    public AstalNotifd.Notification notification;
    public NotificationLayout layout;

    public uint id {
        get {
            return notification.id;
        }
    }

    public NotificationProxy(AstalNotifd.Notification notification) {
        layout = MESSAGE;
        this.notification = notification;
    }
}

// All visual notification changes are be steered by the service object's logical state.
// With multiple stored notification lists, this makes it way simpler.
// TODO: consider manipulating internal maps using default signal handlers? this would work if the default handlers can cancel
// TODO: read the notification spec again and ensure all the required properties are handled
// I can think of "transient" right now, but there may be more
class NotificationService : Object {
    private static NotificationService instance = null;
    public static NotificationService get_default() {
        if (instance == null) {
            debug("initializing NotificationService");
            instance = new NotificationService();
        }
        return instance;
    }

    private AstalNotifd.Notifd notifd;
    private Gee.HashMap<uint, NotificationProxy> popup_notifs;
    private Gee.HashMap<uint, NotificationProxy> stored_notifs;

    public NotificationService() {
        assert_null(instance);
        notifd = AstalNotifd.get_default();
        notifd.ignore_timeout = true;

        popup_notifs = new Gee.HashMap<uint, NotificationProxy>();
        stored_notifs = new Gee.HashMap<uint, NotificationProxy>();

        notifd.notified.connect(this.handle_notified);
        notifd.resolved.connect(this.handle_resolved);
    }

    private void handle_notified(uint id) {
        var proxy = new NotificationProxy(notifd.get_notification(id));

        // if this notification is currently stored, remove it.
        NotificationProxy? stale_stored = null;
        stored_notifs.unset(id, out stale_stored);
        if (stale_stored != null) {
            stored_remove(stale_stored);
        }

        popup_notifs.set(id, proxy);
        if (!popup_set(proxy)) {
            warning("Notification with ID %u wasn't handled!", id);
        }
    }

    private void handle_resolved(uint id, AstalNotifd.ClosedReason reason) {
        NotificationProxy? removed_popup = null;
        popup_notifs.unset(id, out removed_popup);
        if (removed_popup != null) {
            popup_remove(removed_popup);
        }

        NotificationProxy? removed_stored = null;
        stored_notifs.unset(id, out removed_stored);
        if (removed_stored != null) {
            stored_remove(removed_stored);
        }
    }

    /** Transfer a notification from popups to storage, if the notification allows it. */
    public void transfer(NotificationProxy proxy) {
        // TODO: handle transient hint

        var id = proxy.id;
        if (!popup_notifs.has_key(id)) {
            warning("Attempted to transfer notification %u to storage, but it wasn't a popup", id);
            return;
        }

        popup_notifs.unset(id);
        popup_remove(proxy);
        stored_notifs.set(id, proxy);
        stored_set(proxy);
    }

    /** Dismiss a notification, removing it from both popups and storage. */
    public void dismiss(NotificationProxy proxy) {
        proxy.notification.dismiss();
    }

    /**
     * Handlers for this signal should always return true, so that any notifications lost due to lack of popups widget at that moment are tracked.
     * Conceptually this should use the `true_handled` accumulator, but there's no way to specify signal accumulators in Vala.
     */
    public signal bool popup_set(NotificationProxy proxy);
    public signal void popup_remove(NotificationProxy proxy);
    /** Similarly */
    public signal bool stored_set(NotificationProxy proxy);
    public signal void stored_remove(NotificationProxy proxy);
}
