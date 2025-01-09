import { astalify, Gtk } from "astal/gtk4";

// This is mostly here for debugging if something is caused by gtk4-layer-shell right now.
export const RegularWindow = astalify(Gtk.Window);
