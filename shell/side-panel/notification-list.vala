/**
 * A box which makes widgets out of NotificationService messages.
 */
class NotificationList : Gtk.Box {
    private NotificationService service;
    private Gee.HashMap<uint, NotificationWidget> widgets;
    private Adw.StatusPage empty_status_page;

    public NotificationWidgetType widget_type { get; construct; }

    public NotificationList(NotificationWidgetType type) {
        Object(widget_type: type);
    }

    construct {
        orientation = VERTICAL;

        service = NotificationService.get_default();
        widgets = new Gee.HashMap<uint, NotificationWidget>();

        if (widget_type == STORAGE) {
            empty_status_page = new Adw.StatusPage();
            empty_status_page.hexpand = true;
            empty_status_page.vexpand = true;
            empty_status_page.icon_name = "fa-bell-symbolic";
            empty_status_page.title = "No Notifications";
            append(empty_status_page);
        } else {
            empty_status_page = null;
        }

        if (widget_type == POPUPS) {
            service.popup_set.connect(this.handle_set);
            service.popup_remove.connect(this.handle_remove);
        } else {
            foreach (var notif in service.stored_notifs.values) {
                handle_set(notif);
            }
            service.stored_set.connect(this.handle_set);
            service.stored_remove.connect(this.handle_remove);
        }
    }

    private bool handle_set(Notification proxy) {
        if (widgets.has_key(proxy.id)) {
            // replace content
            var widget = widgets.get(proxy.id);
            widget.proxy = proxy;
        } else {
            // new
            var widget = new NotificationWidget(proxy, widget_type);
            widget.finish_remove.connect(this.handle_widget_finish_remove);
            widgets.set(proxy.id, widget);
            if (widget_type == POPUPS) {
                this.append(widget);
            } else {
                this.prepend(widget);
            }
            if (empty_status_page != null) {
                empty_status_page.visible = false;
            }
        }

        return true;
    }

    private void handle_remove(Notification proxy) {
        var widget = widgets.get(proxy.id);
        if (widget == null) {
            warning("Tried to remove widget for notification %u, but it doesn't exist!", proxy.id);
            return;
        }
        widget.begin_remove();
    }

    private void handle_widget_finish_remove(NotificationWidget widget) {
        if (!widgets.unset(widget.proxy.id)) {
            warning("Tried to destroy widget for notification %u, but it doesn't exist!", widget.proxy.id);
            return;
        }
        remove(widget);
        if (widgets.size == 0 && empty_status_page != null) {
            empty_status_page.visible = true;
        }
    }
}
