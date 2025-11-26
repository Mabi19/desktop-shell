[GtkTemplate(ui = "/land/mabi/shell/ui/bar/tray-item.ui")]
class TrayItem : Adw.Bin {
    public AstalTray.TrayItem item { get; construct; }
    [GtkChild]
    private unowned Gtk.MenuButton button;

    public TrayItem(AstalTray.TrayItem item) {
        Object(item: item);
    }

    construct {
        button.insert_action_group("dbusmenu", item.action_group);
        item.notify["action-group"].connect(() => {
            button.insert_action_group("dbusmenu", item.action_group);
        });
    }

    public override void dispose() {
        base.dispose();
        dispose_template(typeof(TrayItem));
    }

    [GtkCallback]
    public bool handle_event(Gdk.Event event) {
        if (event.get_surface() != get_native().get_surface()) {
            // this controller sometimes captures events on the popover
            return false;
        }

        var type = event.get_event_type();
        if (type == Gdk.EventType.BUTTON_PRESS) {
            var mouse_button = ((Gdk.ButtonEvent)event).get_button();
            if (mouse_button == Gdk.BUTTON_SECONDARY || (item.is_menu && mouse_button == Gdk.BUTTON_PRIMARY)) {
                // doing this earlier prevents some flash-of-invalid-content
                item.about_to_show();
            }
            return true;
        } else if (type == Gdk.EventType.BUTTON_RELEASE) {
            var button_event = (Gdk.ButtonEvent)event;
            var mouse_button = button_event.get_button();

            if (mouse_button == Gdk.BUTTON_PRIMARY) {
                if (item.is_menu) {
                    button.popup();
                } else {
                    item.activate(0, 0);
                }
            } else if (mouse_button == Gdk.BUTTON_MIDDLE) {
                item.secondary_activate(0, 0);
            } else {
                button.popup();
            }
            return true;
        }
        return false;
    }
}


class TrayBox : Gtk.Box {
    internal AstalTray.Tray service { get; private set; }
    private Gee.HashMap<string, TrayItem> items;

    construct {
        service = AstalTray.get_default();
        items = new Gee.HashMap<string, TrayItem>();
        spacing = 12;

        foreach (var item in service.items) {
            on_added(item.item_id);
        }

        service.item_added.connect(on_added);
        service.item_removed.connect(on_removed);
    }

    void on_added(string id) {
        if (items.has_key(id)) {
            return;
        }
        var item = service.get_item(id);
        var widget = new TrayItem(item);
        // maintain a consistent order
        TrayItem? largest_smaller_widget = null;
        foreach (var test_widget in items.values) {
            if (test_widget.item.title < item.title) {
                if (largest_smaller_widget == null || largest_smaller_widget.item.title < test_widget.item.title) {
                    largest_smaller_widget = test_widget;
                }
            }
        }
        items.set(id, widget);
        insert_child_after(widget, largest_smaller_widget);
    }

    void on_removed(string id) {
        TrayItem? item = null;
        var exists = items.unset(id, out item);
        if (!exists) return;
        remove(item);
    }
}
