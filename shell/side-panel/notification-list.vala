enum NotificationListType {
    POPUPS,
    STORAGE,
}

/**
 * A box which makes widgets out of NotificationService messages.
 */
class NotificationList : Gtk.Box {
    private NotificationService service;
    private NotificationListType type;
    private Gee.HashMap<uint, Gtk.Widget> widgets;

    public NotificationList(NotificationListType type) {
        orientation = VERTICAL;

        this.type = type;
        service = NotificationService.get_default();
        widgets = new Gee.HashMap<uint, Gtk.Widget>();

        if (type == POPUPS) {
            service.popup_set.connect(this.handle_set);
            service.popup_remove.connect(this.handle_remove);
        } else {
            // TODO: Also ask the notification service for the current list of notifications.
            // This means the service may need an OrderedMap for storage.
            service.stored_set.connect(this.handle_set);
            service.stored_remove.connect(this.handle_remove);
        }

        var test_button = new Gtk.Button.with_label("test button");
        test_button.clicked.connect(() => print("test button\n"));
        append(test_button);
    }

    private bool handle_set(NotificationProxy proxy) {
        // TODO: replace this with the actual notification widgets
        // TODO: replace the target widget's content instead of recreating it

        if (widgets.has_key(proxy.id)) {
            // replace
            var new_widget = new Gtk.Button.with_label(proxy.notification.summary);
            var old_widget = widgets.get(proxy.id);
            widgets.set(proxy.id, new_widget);
            insert_child_after(new_widget, old_widget);
        } else {
            // new
            var widget = new Gtk.Button.with_label(proxy.notification.summary);
            widgets.set(proxy.id, widget);
            this.append(widget);
        }

        return true;
    }

    private void handle_remove(NotificationProxy proxy) {
        Gtk.Widget widget = null;
        widgets.unset(proxy.id, out widget);
        if (widget == null) {
            warning("Tried to remove widget for notification %u, but it doesn't exist!", proxy.id);
        }
        remove(widget);
    }
}
