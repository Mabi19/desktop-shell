import { ConstructProps, Gtk, astalify } from "astal/gtk3";
import GObject from "gi://GObject";

export class PlainWindow extends astalify(Gtk.Window) {
    static {
        GObject.registerClass(this);
    }

    constructor(props: ConstructProps<PlainWindow, Gtk.Window.ConstructorProps, {}>) {
        super(props as any);
    }
}
