import { ConstructProps, Gtk, astalify } from "astal/gtk4";
import GObject from "gi://GObject";

export class Calendar extends astalify(Gtk.Calendar) {
    static {
        GObject.registerClass(this);
    }

    constructor(props: ConstructProps<Calendar, Gtk.Calendar.ConstructorProps, {}>) {
        super(props as any);
    }
}
