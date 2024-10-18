import { ConstructProps, Gtk, Widget, astalify } from "astal/gtk3";
import GObject from "gi://GObject";

export class Separator extends astalify(Gtk.Separator) {
    static {
        GObject.registerClass(this);
    }

    constructor(props: ConstructProps<Separator, Gtk.Separator.ConstructorProps, {}>) {
        super(props as any);
    }
}
