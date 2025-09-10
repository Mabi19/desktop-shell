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

    construct {
        side_panel = new SidePanel();
        side_panel.set_parent(this);
    }

    public override void dispose() {
        side_panel.unparent();
        side_panel = null;
        base.dispose();
    }

    // TODO: implement measure and size_allocate
}

/**
 * Manages the right popup layer surface, which includes the side panel itself and sometimes also notifications.
 */
class RightPopupWindow : Astal.Window {
    private RightPopupContent content;

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
