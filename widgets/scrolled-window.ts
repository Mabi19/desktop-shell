import { astalify, Gtk } from "astal/gtk4";

export const ScrolledWindow = astalify<Gtk.ScrolledWindow, Gtk.ScrolledWindow.ConstructorProps>(Gtk.ScrolledWindow, {
    setChildren(widget, children) {
        widget.set_child(children[0]);
    },
    getChildren(widget) {
        const child = widget.get_child();
        if (!child) {
            return [];
        }
        if (child instanceof Gtk.Viewport) {
            const viewportChild = child.get_child();
            return viewportChild ? [viewportChild] : [];
        }
        return [child];
    },
});
