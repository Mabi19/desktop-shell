// This thing needs to be designed.
// It should probably emit signals like the old NotificationTracker.
// But yeeting callbacks over signals is very meh.
// And it shouldn't store widgets, just notification proxies.
// Also I'm not sure if it's worth it to have limbo anymore.

// All visual notification changes should be steered by the service object.
// With multiple stored notification lists, this is gonna make it way simpler.

enum NotificationLayout {
    MESSAGE,
}

class NotificationProxy : Object {
    public AstalNotifd.Notification notification;
    public NotificationLayout layout;

    public NotificationProxy(AstalNotifd.Notification notification) {
        layout = MESSAGE;
        this.notification = notification;
    }
}

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
        // this is gonna vary.
        // if it's in the popups area: replace the widget content and reset timer
        // but take care if it's animating out!
        // previously this was the job of limbo, but now I think actually cancelling the animation would be better.
        // if it's in the stored popup area, take it out of there (always).
        // if something was in popup_notifs, then send a replace, otherwise send an add.
        // or actually we could just do one signal and let the popups widget handle the logic
        // and not even care about whether it was replaced.
    }

    private void handle_resolved(uint id, AstalNotifd.ClosedReason reason) {

    }

    /** Transfer a notification from popups to storage. */
    public void transfer(NotificationProxy proxy) {

    }

    /** Dismiss a notification, removing it from both popups and storage. */
    public void dismiss(NotificationProxy proxy) {

    }

    /**
     * Handlers for this signal should always return true, so that any notifications lost due to lack of popups widget at that moment are tracked.
     * Conceptually this should use the `true_handled` accumulator, but there's no way to specify signal accumulators in Vala.
     */
    public signal bool popup_set(NotificationProxy proxy);
    public signal void popup_remove(NotificationProxy proxy);
    public signal void stored_set(NotificationProxy proxy);
    public signal void stored_remove(NotificationProxy proxy);
}
