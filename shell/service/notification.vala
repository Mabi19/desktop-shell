enum NotificationLayout {
    MESSAGE,
}

/**
 * A proxy object for an AstalNotifd notification.
 * It tracks its own copies of most notification properties, so that they can be modified by rules.
 */
class NotificationProxy : Object {
    public AstalNotifd.Notification notification;
    public NotificationLayout layout;
    public string timestamp;

    public uint id;
    public int expire_timeout;
    public bool transient;
    public AstalNotifd.Urgency urgency;
    public bool action_icons;
    public string? sound_file;
    public string? sound_name;
    public bool suppress_sound;

    public NotificationProxy(AstalNotifd.Notification notification) {
        layout = MESSAGE;
        this.notification = notification;
        timestamp = new GLib.DateTime.now_local().format(MabiShell.config.time_format_short);
        id = notification.id;
        expire_timeout = notification.expire_timeout;
        transient = notification.transient;
        urgency = notification.urgency;
        action_icons = notification.action_icons;
        sound_file = notification.sound_file;
        sound_name = notification.sound_name;
        suppress_sound = notification.suppress_sound;
    }
}

// All visual notification changes are be steered by the service object's logical state.
// With multiple stored notification lists, this makes it way simpler.
// TODO: consider manipulating internal maps using default signal handlers? this would work if the default handlers can cancel
// TODO: read the notification spec again and ensure all the required properties are handled
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
    private SoundService sound_service;

    public uint stored_count { get; private set; default = 0; }

    public NotificationService() {
        assert_null(instance);
        notifd = AstalNotifd.get_default();
        notifd.ignore_timeout = true;

        popup_notifs = new Gee.HashMap<uint, NotificationProxy>();
        stored_notifs = new Gee.HashMap<uint, NotificationProxy>();

        sound_service = SoundService.get_default();

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
            stored_count = stored_notifs.size;
        }

        if (!popup_notifs.has_key(id)) {
            play_sound_for(proxy);
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
            stored_count = stored_notifs.size;
        }
    }

    private void play_sound_for(NotificationProxy proxy) {
        if (proxy.suppress_sound) {
            return;
        }

        // Prefer sound_name, then sound_file, then fallback to "message"
        if (proxy.sound_name != null && proxy.sound_name.strip() != "") {
            sound_service.play_deduped(proxy.sound_name, GSound.Attribute.EVENT_ID);
        } else if (proxy.sound_file != null && proxy.sound_file.strip() != "") {
            sound_service.play_deduped(proxy.sound_file, GSound.Attribute.MEDIA_FILENAME);
        } else {
            sound_service.play_deduped("message", GSound.Attribute.EVENT_ID);
        }
    }

    /** Transfer a notification from popups to storage, if the notification allows it. */
    public void transfer(NotificationProxy proxy) {
        var id = proxy.id;
        if (!popup_notifs.has_key(id)) {
            warning("Attempted to transfer notification %u to storage, but it wasn't a popup", id);
            return;
        }

        // transient notifications are explicitly specified to not get stored.
        // to honor set expire timeouts, the notification needs to be closed once that's up
        if (proxy.transient || proxy.expire_timeout > 0) {
            // TODO: expire instead once that lands in libastal
            proxy.notification.dismiss();
        } else {
            popup_notifs.unset(id);
            popup_remove(proxy);
            stored_notifs.set(id, proxy);
            stored_set(proxy);
            stored_count = stored_notifs.size;
        }
    }

    /** Dismiss all stored notifications. */
    public void clear_stored() {
        var to_dismiss = stored_notifs.values.to_array();
        foreach (var proxy in to_dismiss) {
            proxy.notification.dismiss();
        }
    }

    /**
     * Handlers for this signal should always return true, so that any notifications lost due to lack of popups widget at that moment are tracked.
     * Conceptually this should use the `true_handled` accumulator, but there's no way to specify signal accumulators in Vala.
     */
    public signal bool popup_set(NotificationProxy proxy);
    public signal void popup_remove(NotificationProxy proxy);
    /** This signal returns bool so that the same handler can be used as for popup_set. */
    public signal bool stored_set(NotificationProxy proxy);
    public signal void stored_remove(NotificationProxy proxy);
}
