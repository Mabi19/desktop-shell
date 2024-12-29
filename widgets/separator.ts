import { ConstructProps, Gtk, astalify } from "astal/gtk4";
import GObject from "gi://GObject";

export class Separator extends astalify(Gtk.Separator) {
    static {
        GObject.registerClass(this);
    }

    constructor(props: ConstructProps<Separator, Gtk.Separator.ConstructorProps, {}>) {
        super(props as any);
    }
}
