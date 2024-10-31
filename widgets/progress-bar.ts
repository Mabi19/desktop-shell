import { ConstructProps, Gtk, astalify } from "astal/gtk3";
import GObject from "gi://GObject";

export class ProgressBar extends astalify(Gtk.ProgressBar) {
    static {
        GObject.registerClass(this);
    }

    constructor(props: ConstructProps<ProgressBar, Gtk.ProgressBar.ConstructorProps, {}>) {
        super(props as any);
    }
}
