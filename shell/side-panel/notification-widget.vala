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

class NotificationHeader : Gtk.Box {
    private NotificationProxy proxy;

    private static Gtk.IconTheme icon_theme;

    static construct {
        icon_theme = Gtk.IconTheme.get_for_display(Gdk.Display.get_default());
    }

    public NotificationHeader(NotificationProxy proxy, NotificationWidgetType type) {
        this.proxy = proxy;

        orientation = Gtk.Orientation.HORIZONTAL;
        spacing = 8;
        add_css_class("header");

        Gtk.Image icon;
        var app_icon = proxy.notification.app_icon;
        var desktop_entry = proxy.notification.desktop_entry;
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

        var app_name = new Gtk.Label(proxy.notification.app_name);
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
            ActionEntry action_entries[] = {};
            var action_group = new SimpleActionGroup();
            action_group.add_action_entries(action_entries, this);
            debug_button.insert_action_group("notification", action_group);
            var menu_model = new Menu();
            menu_model.insert(0, "Copy as JSON", "copy-json");
            debug_button.set_menu_model(menu_model);

            append(debug_button);
        }

        var close_button = new Gtk.Button.from_icon_name("window-close-symbolic");
        close_button.add_css_class("close-button");
        close_button.clicked.connect(this.handle_closed_click);
        append(close_button);
    }

    private void handle_closed_click() {
        proxy.notification.dismiss();
    }
}

class NotificationWidget : Gtk.Widget {
    private Gtk.Widget child;

    private NotificationProxy _proxy;
    public NotificationProxy proxy {
        get {
            return _proxy;
        }
        set {
            _proxy = value;

            // (re) start transfer timeout
            if (widget_type == POPUPS && (value.urgency != CRITICAL || value.expire_timeout > 0)) {
                last_tick_time = get_monotonic_time();
                timeout_elapsed = 0;
                if (timeout_tick_id == 0) {
                    timeout_tick_id = add_tick_callback(this.handle_tick);
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

    private uint timeout_tick_id;
    private int64 last_tick_time;
    private int64 timeout_elapsed;
    public double timeout_fraction { get; set; default = 0; }
    private bool is_hovered;

    public NotificationWidget(NotificationProxy proxy, NotificationWidgetType type) {
        Object(widget_type: type, proxy: proxy);
    }

    static construct {
        set_css_name("notification");
    }

    private bool handle_tick(Gtk.Widget widget, Gdk.FrameClock frame_clock) {
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
        proxy.notification.invoke(action_id);
        if (!proxy.notification.resident) {
            proxy.notification.dismiss();
        }
    }

    private Gtk.Label make_content_label(string text) {
        // trim whitespace and replace \n's with unicode line separators
        // (pango treats \n as a paragraph break)
        var label_text = text.strip().replace("\n", "\u2028");
        var label = new Gtk.Label(label_text);
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
        var summary = make_content_label(proxy.notification.summary);
        summary.add_css_class("title");
        summary.lines = 2;
        content.attach(summary, 0, 0);
        // TODO: handle markup / parse markdown / whatever
        var body = make_content_label(proxy.notification.body);
        body.add_css_class("description");
        body.lines = 4;
        content.attach(body, 0, 1);
        result.append(content);

        var button_box = new Adw.WrapBox();
        button_box.child_spacing = 8;
        button_box.line_spacing = 8;
        button_box.justify = Adw.JustifyMode.FILL;
        button_box.justify_last_line = true;
        button_box.visible = false;
        button_box.add_css_class("actions");
        foreach (var action in proxy.notification.actions) {
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
        dismiss_controller.released.connect(proxy.notification.dismiss);
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


        if (widget_type == POPUPS && proxy.urgency != CRITICAL) {
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

        child.measure(orientation, for_size, out minimum, out natural, out minimum_baseline, out natural_baseline);
        minimum_baseline = -1;
        natural_baseline = -1;
    }

    public override void size_allocate(int width, int height, int baseline) {
        child.allocate(width, height, baseline, null);
    }
}
