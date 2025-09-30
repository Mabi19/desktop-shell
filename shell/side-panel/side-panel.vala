[GtkTemplate(ui = "/land/mabi/shell/ui/side-panel/side-panel.ui")]
class SidePanel : Gtk.Box {
    private bool _active;

    // Whether the side panel should be updating.
    public bool active {
        get {
            return _active;
        }
        set {
            _active = value;
            if (value) {
                calendar.select_day(new DateTime.now());
            }
        }
    }

    [GtkChild]
    private unowned Gtk.Calendar calendar;

    static construct {
        set_css_name("side-panel");
        typeof(PreciseClock).ensure();
        typeof(NotificationList).ensure();
    }

    construct {
        _active = false;
    }
}

// Potentially useful resources for making this widget:
// https://gitlab.gnome.org/GNOME/gtk/-/blob/main/gtk/gtkrevealer.c
// https://docs.gtk.org/gtk4/method.Widget.set_child_visible.html
// https://docs.gtk.org/gtk4/vfunc.Widget.measure.html
// https://docs.gtk.org/gtk4/vfunc.Widget.size_allocate.html
// https://blog.gtk.org/2020/04/27/custom-widgets-in-gtk-4-layout/

enum SidePanelAnimationState {
    SHOWN,
    HIDDEN,
    ANIMATING_IN,
    ANIMATING_OUT,
}

/**
 * This is the content of the RightPopupWindow. It includes the side panel and optionally notifications.
 * It also serves as a revealer for the side panel widget.
 */
class RightPopupContent : Gtk.Widget {
    const float ANIMATION_DURATION = 0.4f;
    // The panel is sized so that notifications are full-width.
    const int NOTIFICATION_SIZE = 400;
    const int NOTIFICATION_POPUP_SIZE = NOTIFICATION_SIZE + 8;
    const int SIDE_PANEL_SIZE = NOTIFICATION_SIZE + 24;

    private Gdk.Monitor monitor;
    private NotificationList? notification_popups;
    private SidePanel side_panel;
    private SidePanelAnimationState side_panel_state;
    private float side_panel_anim_progress;
    private int64 last_frame_time;
    private uint anim_tick_id;
    private Cairo.Region? last_input_region;

    public RightPopupContent(Gdk.Monitor monitor) {
        this.monitor = monitor;
        notification_popups = null;

        side_panel = new SidePanel();
        side_panel.set_child_visible(false);
        side_panel.set_parent(this);
        side_panel_state = HIDDEN;
        side_panel_anim_progress = 0.0f;
        last_frame_time = 0;
        anim_tick_id = 0;
        last_input_region = null;

        assert_nonnull(monitor);
        if (monitor == MabiShell.instance.primary_monitor) {
            change_active_monitor(true);
        }
        MabiShell.instance.notify["primary-monitor"].connect(() => {
            change_active_monitor(monitor == MabiShell.instance.primary_monitor);
        });
    }

    public void set_side_panel_state(bool visible) {
        SidePanelAnimationState new_state = side_panel_state;
        // change_state will adjust the time accordingly
        switch (side_panel_state) {
        case SHOWN:
        case ANIMATING_IN:
            if (!visible) {
                new_state = ANIMATING_OUT;
            }
            break;
        case HIDDEN:
        case ANIMATING_OUT:
            if (visible) {
                new_state = ANIMATING_IN;
            }
            break;
        }

        change_state(new_state);
    }

    private void change_state(SidePanelAnimationState new_state) {
        if (side_panel_state != new_state) {
            if (new_state == HIDDEN) {
                // going to hidden
                side_panel.set_child_visible(false);
                side_panel.active = false;
            }
            if (side_panel_state == HIDDEN) {
                // going away from hidden
                side_panel.set_child_visible(true);
                side_panel.active = true;
            }

            if (new_state == ANIMATING_IN || new_state == ANIMATING_OUT) {
                if (side_panel_state == ANIMATING_IN || side_panel_state == ANIMATING_OUT) {
                    // direction switch: set the time to when the other direction would be here
                    // This formula took a surprisingly high amount of effort to figure out.
                    side_panel_anim_progress = 1.0f - Math.cbrtf(Math.powf(side_panel_anim_progress - 1.0f, 3.0f) + 1.0f);
                } else {
                    // start new
                    side_panel_anim_progress = 0.0f;
                }

                if (anim_tick_id == 0) {
                    // if the animation was ever inactive, reset the frame time
                    last_frame_time = 0;
                    // this gets cleared by the animation callback itself
                    anim_tick_id = add_tick_callback(this.animation_tick);
                }
            }

            side_panel_state = new_state;
            print("state change: %s\n", new_state.to_string());
            queue_allocate();
        }
    }

    private bool animation_tick(Gtk.Widget widget, Gdk.FrameClock frame_clock) {
        if (side_panel_state != ANIMATING_IN && side_panel_state != ANIMATING_OUT) {
            return false;
        }

        var frame_time = frame_clock.get_frame_time();
        if (last_frame_time == 0) {
            last_frame_time = frame_time;
        }

        var delta_micros = frame_time - last_frame_time;
        last_frame_time = frame_time;
        var delta_seconds = (float)delta_micros / 1000000.0f;
        var delta_progress = delta_seconds / ANIMATION_DURATION;
        side_panel_anim_progress = (side_panel_anim_progress + delta_progress).clamp(0, 1);
        if (side_panel_anim_progress >= 1.0f) {
            // animation ends!
            if (side_panel_state == ANIMATING_IN) {
                change_state(SHOWN);
            } else if (side_panel_state == ANIMATING_OUT) {
                change_state(HIDDEN);
            }
            anim_tick_id = 0;
            return false;
        } else {
            queue_allocate();
            return true;
        }
    }

    private static float ease_out_cubic(float x) {
        var m = 1.0f - x;
        return 1.0f - m * m * m;
    }

    public override void measure(Gtk.Orientation orientation, int for_size, out int minimum, out int natural, out int minimum_baseline, out int natural_baseline) {
        if (orientation == VERTICAL) {
            // Computing height.
            side_panel.measure(orientation, for_size, out minimum, out natural, null, null);
        } else {
            // Computing width.
            if (notification_popups != null) {
                minimum = NOTIFICATION_POPUP_SIZE + SIDE_PANEL_SIZE;
                natural = NOTIFICATION_POPUP_SIZE + SIDE_PANEL_SIZE;
            } else {
                minimum = SIDE_PANEL_SIZE;
                natural = SIDE_PANEL_SIZE;
            }
        }

        minimum_baseline = -1;
        natural_baseline = -1;
    }

    public override void size_allocate(int width, int height, int baseline) {
        float anim_x_offset = 0.0f;
        switch (side_panel_state) {
        case SHOWN:
            anim_x_offset = 0.0f;
            break;
        case ANIMATING_IN:
            anim_x_offset = SIDE_PANEL_SIZE * (1.0f - ease_out_cubic(side_panel_anim_progress));
            break;
        case ANIMATING_OUT:
            anim_x_offset = SIDE_PANEL_SIZE * ease_out_cubic(side_panel_anim_progress);
            break;
        case HIDDEN:
            anim_x_offset = SIDE_PANEL_SIZE;
            break;
        }

        var input_region = new Cairo.Region();

        float notification_popup_offset = 0.0f;
        if (notification_popups != null) {
            notification_popups.allocate(NOTIFICATION_POPUP_SIZE, height, -1, new Gsk.Transform().translate(Graphene.Point() {
                x = anim_x_offset, y = 0
            }));
            notification_popup_offset = NOTIFICATION_POPUP_SIZE;

            int popups_height;
            int dummy;
            notification_popups.measure(VERTICAL, NOTIFICATION_POPUP_SIZE, out dummy, out popups_height, out dummy, out dummy);
            popups_height = int.min(popups_height, height);
            print("popups_height: %d\n", popups_height);
            input_region.union_rectangle(Cairo.RectangleInt() {
                x = (int)anim_x_offset, y = 0, width = NOTIFICATION_POPUP_SIZE, height = popups_height
            });
        }

        if (side_panel_state != HIDDEN) {
            side_panel.allocate(SIDE_PANEL_SIZE, height, -1, new Gsk.Transform().translate(Graphene.Point() {
                x = anim_x_offset + notification_popup_offset, y = 0
            }));

            input_region.union_rectangle(Cairo.RectangleInt() {
                x = (int)(anim_x_offset + notification_popup_offset), y = 0, width = SIDE_PANEL_SIZE, height = height
            });
        }

        if (!input_region.equal(last_input_region)) {
            var native = get_native();
            if (native != null) {
                var surface = native.get_surface();
                if (surface != null) {
                    print("applying input region\n");
                    surface.set_input_region(input_region);
                    last_input_region = input_region;
                }
            }
        }
    }

    public override void snapshot(Gtk.Snapshot snapshot) {
        if (notification_popups != null) {
            snapshot_child(notification_popups, snapshot);
        }
        snapshot_child(side_panel, snapshot);
        // fake render node to prevent GTK bug with completely empty windows
        var transparent = Gdk.RGBA() {
            red = 0.0f, green = 0.0f, blue = 0.0f, alpha = 0.0f
        };
        snapshot.append_color(transparent, Graphene.Rect.zero());
    }

    private void change_active_monitor(bool is_active) {
        var old_state = notification_popups != null;
        if (old_state == is_active) {
            return;
        }

        if (is_active) {
            // create
            notification_popups = new NotificationList(POPUPS);
            notification_popups.set_parent(this);
        } else {
            // destroy
            notification_popups.unparent();
            notification_popups = null;
        }

        queue_resize();
    }

    public override void dispose() {
        side_panel.unparent();
        side_panel = null;

        if (notification_popups != null) {
            notification_popups.unparent();
            notification_popups = null;
        }

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
            content.set_side_panel_state(value);
        }
    }

    static construct {
        set_css_name("popup-window");
    }

    public RightPopupWindow(Gdk.Monitor monitor) {
        gdkmonitor = monitor;
        layer = OVERLAY;
        @namespace = "side-panel";
        anchor = TOP | RIGHT | BOTTOM;
        default_width = 8;

        content = new RightPopupContent(monitor);
        set_child(content);
    }
}
