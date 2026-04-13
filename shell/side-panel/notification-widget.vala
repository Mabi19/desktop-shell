// A notification consists of several parts:
// 1. header (time label only in storage)
// 2. separator
// 3. content area (always a grid with the same elements, but how they're attached depends on selected layout)
// 4. actions (only if they exist)
// 5. timeout progress bar (unless in storage)

enum NotificationWidgetType {
    POPUPS,
    STORAGE,
}

enum NotificationWidgetAnimationState {
    // Not animating.
    IDLE,
    // The content's X position depends on the timer. (-> IDLE)
    SLIDE_IN,
    // The content's X position depends on the timer. (-> COLLAPSE)
    SLIDE_OUT,
    // The height allocated to the widget shrinks to 0. (-> remove widget)
    COLLAPSE,
}

class NotificationHeader : Gtk.Box {
    private Notification proxy;

    private static Gtk.IconTheme icon_theme;

    static construct {
        icon_theme = Gtk.IconTheme.get_for_display(Gdk.Display.get_default());
    }

    public NotificationHeader(Notification proxy, NotificationWidgetType type) {
        this.proxy = proxy;

        orientation = Gtk.Orientation.HORIZONTAL;
        spacing = 8;
        add_css_class("header");

        Gtk.Image icon;
        var app_icon = proxy.app_icon;
        var desktop_entry = proxy.desktop_entry;
        if (app_icon.length > 0) {
            if (app_icon.has_prefix("file://")) {
                var path = app_icon[7 :];
                icon = new Gtk.Image.from_file(path);
            } else {
                icon = new Gtk.Image.from_icon_name(app_icon);
            }
        } else if (desktop_entry != null && desktop_entry.length > 0 && icon_theme.has_icon(desktop_entry)) {
            icon = new Gtk.Image.from_icon_name(desktop_entry);
        } else {
            icon = new Gtk.Image.from_icon_name("dialog-information-symbolic");
        }
        append(icon);

        var app_name = new Gtk.Label(proxy.app_name);
        app_name.halign = Gtk.Align.START;
        app_name.hexpand = true;
        append(app_name);

        if (type == STORAGE) {
            var timestamp = new Gtk.Label(proxy.timestamp);
            append(timestamp);
        }

        if (MabiShell.config.notification_debug_menu) {
            var debug_button = new Gtk.MenuButton();
            debug_button.set_child(new Gtk.Image.from_icon_name("open-menu-symbolic"));
            debug_button.add_css_class("flat");
            debug_button.add_css_class("debug-button");
            ActionEntry action_entries[] = {
                { "copy-json", () => this.copy_json() }
            };
            var action_group = new SimpleActionGroup();
            action_group.add_action_entries(action_entries, this);
            debug_button.insert_action_group("notification", action_group);
            var menu_model = new Menu();
            menu_model.insert(0, "Copy as JSON", "notification.copy-json");
            debug_button.set_menu_model(menu_model);

            append(debug_button);
        }

        var close_button = new Gtk.Button.from_icon_name("window-close-symbolic");
        close_button.add_css_class("close-button");
        close_button.clicked.connect(this.handle_closed_click);
        append(close_button);
    }

    private void handle_closed_click() {
        NotificationService.get_default().dismiss(proxy.id);
    }

    private void copy_json() {
        var gen = new Json.Generator();
        gen.pretty = true;
        gen.indent = 4;
        gen.set_root(proxy.to_json());
        var json_str = gen.to_data(null);
        MabiShell.display.get_clipboard().set_text(json_str);
    }
}

class NotificationImage : Gtk.Widget {
    private Gtk.Picture picture;
    private NotificationLayout layout;

    static construct {
        set_css_name("notification-image");
    }

    public NotificationImage(Gdk.Texture texture, NotificationLayout layout) {
        hexpand = false;
        vexpand = false;
        this.layout = layout;
        switch (layout) {
        case DEFAULT:
            add_css_class("layout-default");
            break;
        case MESSAGE:
            add_css_class("layout-message");
            break;
        }
        picture = new Gtk.Picture();
        picture.set_paintable(texture);
        picture.content_fit = CONTAIN;
        picture.set_parent(this);
    }

    public override Gtk.SizeRequestMode get_request_mode() {
        return Gtk.SizeRequestMode.CONSTANT_SIZE;
    }

    public override void measure(Gtk.Orientation orientation, int for_size, out int minimum, out int natural, out int minimum_baseline, out int natural_baseline) {
        int min, nat, min_base, nat_base;
        switch (layout) {
        case DEFAULT:
            picture.measure(orientation, 80, out min, out nat, out min_base, out nat_base);
            natural = int.min(nat, 80);
            break;
        case MESSAGE:
            natural = 24;
            break;
        default:
            assert_not_reached();
        }

        minimum = natural;
        minimum_baseline = -1;
        natural_baseline = -1;
    }

    public override void size_allocate(int width, int height, int baseline) {
        int min, nat_width, nat_height, min_base, nat_base;
        picture.measure(HORIZONTAL, height, out min, out nat_width, out min_base, out nat_base);
        picture.measure(VERTICAL, width, out min, out nat_height, out min_base, out nat_base);

        int image_width = int.min(width, nat_width);
        int image_height = int.min(height, nat_height);
        var transform = new Gsk.Transform().translate(Graphene.Point() {
            x = (width - image_width) / 2,
            y = (height - image_height) / 2,
        });
        picture.allocate(image_width, image_height, baseline, transform);
    }

    public override void dispose() {
        picture.unparent();
        picture = null;
    }
}

class NotificationWidget : Gtk.Widget {
    const float ANIMATION_DURATION = 0.35f;

    private Gtk.Widget child;

    private Notification _proxy;
    public Notification proxy {
        get {
            return _proxy;
        }
        set {
            _proxy = value;

            if (animation_state != IDLE) {
                change_animation_state(SLIDE_IN);
            }

            // (re) start transfer timeout
            if (widget_type == POPUPS && (value.urgency != CRITICAL || value.expire_timeout > 0)) {
                last_tick_time = get_monotonic_time();
                timeout_elapsed = 0;
                if (timeout_tick_id == 0) {
                    timeout_tick_id = add_tick_callback(this.handle_timeout_tick);
                }
            } else {
                // if a notification becomes critical, stop its transfer timeout
                if (timeout_tick_id != 0) {
                    remove_tick_callback(timeout_tick_id);
                    timeout_tick_id = 0;
                }
            }

            if (child != null) {
                child.unparent();
            }
            child = build_widgets();
            child.set_parent(this);
        }
    }
    public NotificationWidgetType widget_type { get; construct; }

    // Timeout tracking state.
    private uint timeout_tick_id;
    private int64 last_tick_time;
    private int64 timeout_elapsed;
    public double timeout_fraction { get; set; default = 0; }
    private bool is_hovered;

    // Animation tracking state.
    // Some of this is duplicated from the timeout state for simplicity.
    private NotificationWidgetAnimationState animation_state = IDLE;
    private uint animation_tick_id;
    private int64 last_animation_tick_time;
    private float animation_time_elapsed;


    public NotificationWidget(Notification proxy, NotificationWidgetType type) {
        Object(widget_type: type, proxy: proxy);
    }

    static construct {
        set_css_name("notification");
    }

    construct {
        if (widget_type == POPUPS) {
            change_animation_state(SLIDE_IN);
        }
    }

    private bool handle_timeout_tick(Gtk.Widget widget, Gdk.FrameClock frame_clock) {
        bool can_pause = false;
        double expire_timeout = proxy.expire_timeout;
        if (expire_timeout <= 0) {
            expire_timeout = 5000.0;
            // if there is a set timeout, honor it exactly
            can_pause = true;
        }

        var now = frame_clock.get_frame_time();
        var since_last_tick = now - last_tick_time;
        last_tick_time = now;

        if (can_pause && is_hovered) {
            return Source.CONTINUE;
        }

        timeout_elapsed += since_last_tick;
        var progress = (double)timeout_elapsed / 1000.0 / expire_timeout;
        timeout_fraction = progress;
        if (progress >= 1.0) {
            timeout_tick_id = 0;
            NotificationService.get_default().transfer(proxy);
            return Source.REMOVE;
        }

        return Source.CONTINUE;
    }

    private void invoke_action(string action_id) {
        NotificationService.get_default().invoke_action(proxy.id, action_id);
    }

    private Gtk.Label make_content_label(string text) {
        var label = new Gtk.Label(text);
        label.wrap = true;
        label.wrap_mode = Pango.WrapMode.WORD_CHAR;
        label.ellipsize = Pango.EllipsizeMode.MIDDLE;
        label.xalign = 0;
        return label;
    }

    private Gtk.Widget build_widgets() {
        var result = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        result.overflow = Gtk.Overflow.HIDDEN;
        result.add_css_class("notification");
        switch (widget_type) {
        case POPUPS:
            result.add_css_class("popup");
            break;
        case STORAGE:
            result.add_css_class("stored");
            break;
        }
        if (proxy.urgency == CRITICAL) {
            result.add_css_class("critical");
        }

        result.append(new NotificationHeader(proxy, widget_type));
        var separator = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
        separator.add_css_class("header-separator");
        result.append(separator);

        var content = new Gtk.Grid();
        content.add_css_class("content");
        content.column_spacing = 8;
        content.row_spacing = 4;
        var summary = make_content_label(proxy.summary);
        summary.add_css_class("title");
        summary.lines = 2;
        var body = make_content_label(proxy.formatted_body.text);
        body.set_attributes(proxy.formatted_body.attributes);
        body.add_css_class("description");
        body.lines = 4;
        var image = proxy.image != null ? new NotificationImage(proxy.image, proxy.layout) : null;

        if (image == null) {
            // only one imageless layout
            content.attach(summary, 0, 0);
            content.attach(body, 0, 1);
        } else {
            switch (proxy.layout) {
            case DEFAULT:
                content.attach(image, 0, 0, 1, 2);
                content.attach(summary, 1, 0);
                body.vexpand = true;
                body.yalign = 0;
                content.attach(body, 1, 1);
                break;
            case MESSAGE:
                content.attach(image, 0, 0);
                summary.hexpand = true;
                content.attach(summary, 1, 0);
                content.attach(body, 0, 1, 2, 1);
                break;
            default:
                assert_not_reached();
            }

        }
        result.append(content);

        var button_box = new Adw.WrapBox();
        button_box.child_spacing = 8;
        button_box.line_spacing = 8;
        button_box.justify = Adw.JustifyMode.FILL;
        button_box.justify_last_line = true;
        button_box.visible = false;
        button_box.add_css_class("actions");
        foreach (var action in proxy.actions) {
            if (action.id == "default") {
                var controller = new Gtk.GestureClick();
                controller.released.connect(() => {
                    invoke_action("default");
                });
                result.add_controller(controller);
            } else {
                var button = new Gtk.Button();
                Gtk.Widget button_content;
                if (proxy.action_icons) {
                    button_content = new Gtk.Image.from_icon_name(action.id);
                } else {
                    button_content = new Gtk.Label(action.label);
                }
                button.set_child(button_content);

                button.clicked.connect(() => {
                    invoke_action(action.id);
                });
                button_box.append(button);
                button_box.visible = true;
            }
        }
        result.append(button_box);

        var dismiss_controller = new Gtk.GestureClick();
        dismiss_controller.button = Gdk.BUTTON_SECONDARY;
        dismiss_controller.released.connect(() => {
            NotificationService.get_default().dismiss(proxy.id);
        });
        result.add_controller(dismiss_controller);

        if (widget_type == POPUPS) {
            var hover_controller = new Gtk.EventControllerMotion();
            hover_controller.enter.connect(() => {
                is_hovered = true;
            });
            hover_controller.leave.connect(() => {
                is_hovered = false;
            });
            result.add_controller(hover_controller);
        }


        if (widget_type == POPUPS && (proxy.urgency != CRITICAL || proxy.expire_timeout > 0)) {
            var timeout_progress_bar = new Gtk.ProgressBar();
            bind_property("timeout-fraction", timeout_progress_bar, "fraction", BindingFlags.DEFAULT);
            result.append(timeout_progress_bar);
        }

        return result;
    }

    public override void dispose() {
        if (child != null) {
            child.unparent();
            child = null;
        }
    }

    private void change_animation_state(NotificationWidgetAnimationState new_state) {
        if (animation_state == new_state) {
            return;
        }

        if (new_state == IDLE) {
            animation_tick_id = 0;
        } else {
            last_animation_tick_time = get_monotonic_time();

            // If a notification wants to start sliding out while it's still sliding in,
            // we can at least make the transition smooth.
            if (animation_state == SLIDE_IN && new_state == SLIDE_OUT) {
                animation_time_elapsed = ANIMATION_DURATION * Easing.ease_out_cubic_invert(animation_time_elapsed / ANIMATION_DURATION);
            } else {
                animation_time_elapsed = 0;
            }

            if (animation_tick_id == 0) {
                animation_tick_id = add_tick_callback(handle_animation_tick);
            }
        }
        animation_state = new_state;
        queue_resize();
    }

    private bool handle_animation_tick(Gtk.Widget widget, Gdk.FrameClock frame_clock) {
        if (animation_state == IDLE) {
            animation_tick_id = 0;
            return Source.REMOVE;
        }

        var now = frame_clock.get_frame_time();
        var since_last_tick = (float)(now - last_animation_tick_time) / 1000000.0f;
        last_animation_tick_time = now;

        animation_time_elapsed = float.min(animation_time_elapsed + since_last_tick, ANIMATION_DURATION);
        // only collapsing requires new measure calls
        if (animation_state == COLLAPSE) {
            queue_resize();
        } else {
            queue_allocate();
        }
        if (animation_time_elapsed >= ANIMATION_DURATION) {
            switch (animation_state) {
            case SLIDE_IN:
                change_animation_state(IDLE);
                return Source.REMOVE;
            case SLIDE_OUT:
                if (get_next_sibling() != null) {
                    change_animation_state(COLLAPSE);
                    return Source.CONTINUE;
                } else {
                    // no need to do the collapsing, since there's no next widget
                    finish_remove();
                    animation_tick_id = 0;
                    return Source.REMOVE;
                }
            case COLLAPSE:
                // stay in this state until the widget's removed
                finish_remove();
                animation_tick_id = 0;
                return Source.REMOVE;
            default:
                assert_not_reached();
            }
        }

        return Source.CONTINUE;
    }

    public void begin_remove() {
        if (timeout_tick_id != 0) {
            remove_tick_callback(timeout_tick_id);
            timeout_tick_id = 0;
        }

        if (widget_type == POPUPS) {
            change_animation_state(SLIDE_OUT);
        } else {
            finish_remove();
        }
    }
    public signal void finish_remove();

    public override Gtk.SizeRequestMode get_request_mode() {
        return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
    }

    public override void measure(Gtk.Orientation orientation, int for_size, out int minimum, out int natural, out int minimum_baseline, out int natural_baseline) {
        if (child == null) {
            minimum = 0;
            natural = 0;
            minimum_baseline = -1;
            natural_baseline = -1;
            return;
        }

        int child_min, child_nat;
        child.measure(orientation, for_size, out child_min, out child_nat, out minimum_baseline, out natural_baseline);
        if (orientation == VERTICAL && animation_state == COLLAPSE) {
            var height_mult = 1 - Easing.ease_in_out_quad(animation_time_elapsed / ANIMATION_DURATION);
            child_min = (int)(child_min * height_mult);
            child_nat = (int)(child_nat * height_mult);
        }
        minimum = child_min;
        natural = child_nat;
        minimum_baseline = -1;
        natural_baseline = -1;
    }

    public override void size_allocate(int width, int height, int baseline) {
        int child_min, child_nat, child_min_base, child_nat_base;
        child.measure(Gtk.Orientation.VERTICAL, width, out child_min, out child_nat, out child_min_base, out child_nat_base);

        Gsk.Transform? transform = null;
        var anim_progress = animation_time_elapsed / ANIMATION_DURATION;
        switch (animation_state) {
        case IDLE:
            transform = null;
            break;
        case SLIDE_IN:
            transform = new Gsk.Transform().translate(Graphene.Point() {
                x = (1.0f - Easing.ease_out_cubic(anim_progress)) * width,
                y = 0,
            });
            break;
        case SLIDE_OUT:
            transform = new Gsk.Transform().translate(Graphene.Point() {
                x = Easing.ease_out_cubic(anim_progress) * width,
                y = 0,
            });
            break;
        case COLLAPSE:
            // TODO: don't allocate the child at all
            transform = new Gsk.Transform().translate(Graphene.Point() {
                x = width,
                y = 0,
            });
            break;
        }

        child.allocate(width, int.max(height, child_min), baseline, transform);
    }
}
