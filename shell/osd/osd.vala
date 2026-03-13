class OsdWindow : Astal.Window {
    private Gtk.Image icon;
    private Gtk.Revealer bar_revealer;
    private Gtk.LevelBar bar;
    private Gtk.Label label;

    static construct {
        set_css_name("osd");
    }

    construct {
        @namespace = "osd";
        layer = OVERLAY;
        anchor = BOTTOM;
        margin_bottom = 48;
        default_width = 100;

        var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12);
        box.add_css_class("osd-box");

        icon = new Gtk.Image();
        icon.add_css_class("osd-icon");
        icon.pixel_size = 32;
        box.append(icon);

        bar_revealer = new Gtk.Revealer();
        bar_revealer.transition_type = Gtk.RevealerTransitionType.SWING_RIGHT;
        bar = new Gtk.LevelBar();
        bar.add_css_class("osd-bar");
        bar.hexpand = true;
        bar.valign = Gtk.Align.CENTER;
        bar.width_request = 200;
        bar.remove_offset_value(Gtk.LEVEL_BAR_OFFSET_LOW);
        bar.remove_offset_value(Gtk.LEVEL_BAR_OFFSET_HIGH);
        bar.remove_offset_value(Gtk.LEVEL_BAR_OFFSET_FULL);
        bar_revealer.set_child(bar);
        box.append(bar_revealer);

        label = new Gtk.Label("");
        label.add_css_class("osd-label");
        box.append(label);

        set_child(box);
        Signal.connect_object(this, "realize", (Callback)set_input_region, this, 0);
    }

    private void set_input_region() {
        get_surface()?.set_input_region(new Cairo.Region());
    }

    public void update(string icon_name, double value, string? text, string? style) {
        icon.icon_name = icon_name;

        if (value > 1.0) {
            bar.add_css_class("overfilled");
        } else {
            bar.remove_css_class("overfilled");
        }
        if (style != null) {
            set_css_classes({style});
        } else {
            set_css_classes({});
        }

        if (value.is_nan()) {
            bar_revealer.reveal_child = false;
        } else {
            bar_revealer.reveal_child = true;
            bar.value = value.clamp(0, 1);
        }

        if (text != null) {
            label.label = text;
        } else {
            label.label = "%.0f%%".printf(Math.round(value * 100));
        }
    }
}

class OsdService : Object {
    private static OsdService? instance = null;
    public static OsdService get_default() {
        if (instance == null) {
            instance = new OsdService();
        }
        return instance;
    }

    private OsdWindow? window = null;
    private uint hide_timeout_id = 0;

    construct {
        assert_null(instance);
    }

    public void show(string icon_name, double value, string? text, string? style) {
        if (window == null) {
            window = new OsdWindow();
        }

        window.update(icon_name, value, text, style);
        if (!window.visible) {
            window.present();
        }

        if (hide_timeout_id != 0) {
            Source.remove(hide_timeout_id);
        }

        hide_timeout_id = Timeout.add(2000, () => {
            hide_timeout_id = 0;
            if (window != null) {
                window.hide();
            }
            return Source.REMOVE;
        });
    }

    public void show_value(string icon_name, double value, string? style) {
        show(icon_name, value, null, style);
    }
}
