class SidePanel : Gtk.Box {
    static construct {
        set_css_name("side-panel");
        print("sidepanel layout manager: %s\n", get_layout_manager_type().name());
    }

    construct {
        append(new Gtk.Label("label 1"));
        append(new Gtk.Label("label 2"));
        append(new Gtk.Label("label 3"));
    }
}

// Potentially useful resources for making this widget:
// https://gitlab.gnome.org/GNOME/gtk/-/blob/main/gtk/gtkrevealer.c
// https://docs.gtk.org/gtk4/method.Widget.set_child_visible.html
// https://docs.gtk.org/gtk4/vfunc.Widget.measure.html
// https://docs.gtk.org/gtk4/vfunc.Widget.size_allocate.html
// https://blog.gtk.org/2020/04/27/custom-widgets-in-gtk-4-layout/

/**
 * This is the content of the RightPopupWindow. It includes the side panel and optionally notifications.
 * It also serves as a revealer for the side panel widget.
 */
class RightPopupContent : Gtk.Widget {
    private SidePanel side_panel;
    private bool is_side_panel_shown;

    construct {
        side_panel = new SidePanel();
        side_panel.set_parent(this);
        is_side_panel_shown = false;
    }

    public override void measure(Gtk.Orientation orientation, int for_size, out int minimum, out int natural, out int minimum_baseline, out int natural_baseline) {
        side_panel.measure(orientation, for_size, out minimum, out natural, null, null);

        minimum_baseline = -1;
        natural_baseline = -1;
    }

    public override void size_allocate(int width, int height, int baseline) {
        side_panel.allocate(width, height, -1, new Gsk.Transform().translate(Graphene.Point() {
            x = width * 0.1f, y = 0
        }));
    }

    public override void dispose() {
        side_panel.unparent();
        side_panel = null;
        base.dispose();
    }
}

/**
 * Manages the right popup layer surface, which includes the side panel itself and sometimes also notifications.
 */
class RightPopupWindow : Astal.Window {
    private RightPopupContent content;

    private bool _side_panel_shown = false;
    public bool side_panel_shown {
        get { return _side_panel_shown; }
        set {
            _side_panel_shown = value;
            print("side panel toggled! new state: %b\n", value);
        }
    }

    static construct {
        set_css_name("popup-window");
    }

    public RightPopupWindow(Gdk.Monitor monitor) {
        Object(gdkmonitor: monitor);
    }

    construct {
        layer = OVERLAY;
        @namespace = "side-panel";
        anchor = TOP | RIGHT | BOTTOM;
        default_width = 8;

        content = new RightPopupContent();
        set_child(content);
    }
}
