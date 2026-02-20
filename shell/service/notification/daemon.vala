/**
 * D-Bus notification server implementing the org.freedesktop.Notifications interface.
 * See: https://specifications.freedesktop.org/notification-spec/latest/
 */
[DBus(name = "org.freedesktop.Notifications")]
class NotificationDaemon : Object {
    private uint32 next_id = 1;
    private uint bus_own_id = 0;

    /** Emitted when a Notify D-Bus call is received. */
    internal signal void notified(Notification notification);
    /** Emitted when a notification is resolved (dismissed, expired, or closed via D-Bus). */
    internal signal void resolved(uint32 id, NotificationClosedReason reason);

    /** Register on the session bus. */
    internal void register() {
        bus_own_id = Bus.own_name(
            BusType.SESSION,
            "org.freedesktop.Notifications",
            BusNameOwnerFlags.REPLACE,
            (conn) => {
            try {
                conn.register_object("/org/freedesktop/Notifications", this);
            } catch (IOError e) {
                error("Failed to register notification D-Bus object: %s", e.message);
            }
        },
            () => {
            debug("Acquired org.freedesktop.Notifications");
        },
            () => {
            warning("Lost org.freedesktop.Notifications bus name");
        }
            );
    }

    ~NotificationDaemon() {
        if (bus_own_id != 0) {
            Bus.unown_name(bus_own_id);
        }
    }

    public string[] get_capabilities() throws DBusError, IOError {
        return {
                   "body",
                   "body-markup",
                   "actions",
                   "icon-static",
                   "action-icons",
                   "sound",
                   "persistence",
        };
    }

    public async new uint32 notify(
        string app_name,
        uint32 replaces_id,
        string app_icon,
        string summary,
        string body,
        string[] actions,
        HashTable<string, Variant> hints,
        int32 expire_timeout
        ) throws DBusError, IOError {
        uint32 id;
        if (replaces_id > 0) {
            id = replaces_id;
        } else {
            id = next_id++;
            // The spec says IDs must always be greater than zero.
            // Guard against overflow wrapping to 0.
            if (next_id == 0) {
                next_id = 1;
            }
        }

        var notification = yield new Notification.from_dbus_async(
            id, app_name, app_icon, summary, body, actions, hints, expire_timeout
            );
        notified(notification);
        return id;
    }

    public void close_notification(uint32 id) throws DBusError, IOError {
        emit_closed(id, NotificationClosedReason.CLOSED);
    }

    public void get_server_information(
        out string name,
        out string vendor,
        out string version,
        out string spec_version
        ) throws DBusError, IOError {
        name = "mabi-shell";
        vendor = "mabi";
        version = "0.1";
        spec_version = "1.3";
    }

    public signal void notification_closed(uint32 id, uint32 reason);
    public signal void action_invoked(uint32 id, string action_key);

    /** Dismiss a notification (user-initiated). */
    internal void dismiss(uint32 id) {
        emit_closed(id, NotificationClosedReason.DISMISSED_BY_USER);
    }

    /** Expire a notification (timeout). */
    internal void expire(uint32 id) {
        emit_closed(id, NotificationClosedReason.EXPIRED);
    }

    /** Invoke a notification action. */
    internal void invoke(uint32 id, string action_key) {
        action_invoked(id, action_key);
    }

    private void emit_closed(uint32 id, NotificationClosedReason reason) {
        notification_closed(id, (uint32)reason);
        resolved(id, reason);
    }
}
