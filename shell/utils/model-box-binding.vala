/** A helper object that binds a list model to a regular box. */
class ModelBoxBinding<T> : Object {
    public delegate Gtk.Widget WidgetFactory<T>(T item);

    private Gtk.Box box;
    private ListModel model;
    private unowned WidgetFactory<T> widget_factory;

    private Gtk.Widget[] widgets;

    public ModelBoxBinding(Gtk.Box box, ListModel model, WidgetFactory<T> widget_factory) {
        assert(model.get_item_type() == typeof(T));
        this.box = box;
        this.model = model;
        this.widget_factory = widget_factory;

        var initial_count = model.get_n_items();
        widgets = new Gtk.Widget[initial_count];
        for (var i = 0; i < initial_count; i++) {
            var widget = widget_factory(model.get_item(i));
            widgets[i] = widget;
            box.append(widget);
        }

        model.items_changed.connect(handle_items_changed);
    }

    private void handle_items_changed(uint uposition, uint uremoved, uint uadded) {
        int position = (int)uposition;
        int removed = (int)uremoved;
        int added = (int)uadded;
        for (int i = position; i < position + removed; i++) {
            box.remove(widgets[i]);
            widgets[i] = null;
        }

        var size_delta = added - removed;
        var count_left = widgets.length - position - removed;
        if (size_delta > 0) {
            widgets.resize(widgets.length + size_delta);
            widgets.move(position + removed, position + added, count_left);
        } else {
            widgets.move(position + removed, position + added, count_left);
            widgets.resize(widgets.length + size_delta);
        }

        // Add the widgets in reverse order, so that we don't have to track which one was last
        // (we can always insert after the one before the start of the list)
        var widget_before = position == 0 ? null : widgets[position - 1];
        for (int i = position + added - 1; i >= position; i--) {
            var widget = widget_factory(model.get_item(i));
            widgets[i] = widget;
            box.insert_child_after(widget, widget_before);
        }
    }
}
