/**
 * A box which makes widgets out of NotificationService messages.
 */
class NotificationList : Gtk.Box {
    private NotificationService service;
    private Gee.HashMap<uint, NotificationWidget> widgets;

    public NotificationWidgetType widget_type { get; construct; }

    public NotificationList(NotificationWidgetType type) {
        Object(widget_type: type);
    }

    construct {
        orientation = VERTICAL;

        service = NotificationService.get_default();
        widgets = new Gee.HashMap<uint, NotificationWidget>();

        if (widget_type == POPUPS) {
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
        if (widgets.has_key(proxy.id)) {
            // replace content
            var widget = widgets.get(proxy.id);
            widget.proxy = proxy;
        } else {
            // new
            var widget = new NotificationWidget(proxy, widget_type);
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
