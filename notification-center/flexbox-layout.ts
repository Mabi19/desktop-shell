import { register } from "astal/gobject";
import { Gtk } from "astal/gtk4";

// A multiline box layout.
// Fits as many children on a line as possible,
// then lets them expand to fill each line.
// TODO: make this
// The Gtk.Box layout manager impl may be helpful here: https://gitlab.gnome.org/GNOME/gtk/-/blob/main/gtk/gtkboxlayout.c?ref_type=heads
@register()
export class FlexBoxLayout extends Gtk.LayoutManager {
    vfunc_allocate(widget: Gtk.Widget, width: number, height: number, baseline: number): void {
        console.log("allocate", width, height, baseline);

        throw new Error("Unimplemented");
    }

    vfunc_measure(
        widget: Gtk.Widget,
        orientation: Gtk.Orientation,
        for_size: number
    ): [number, number, number, number] {
        console.log("measure", orientation, for_size);

        throw new Error("Unimplemented");
    }
}
