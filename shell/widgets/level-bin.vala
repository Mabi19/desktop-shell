class LevelBin : Adw.Bin {
    private double display_level = 0;
    private double _level = 0;
    public double level {
        get {
            return _level;
        }

        set {
            if ((value - display_level).abs() < 0.02) {
                anim_running = false;
                display_level = value;
                queue_draw();
            } else {
                // trigger animation
                anim_from = display_level;
                anim_start_time = get_monotonic_time();

                if (!anim_running) {
                    add_tick_callback(this.animation_tick);
                    anim_running = true;
                }
            }
            _level = value;
        }
    }

    private bool anim_running = false;
    private int64 anim_start_time;
    private double anim_from;
    private bool animation_tick(Gtk.Widget widget, Gdk.FrameClock clock) {
        if (!anim_running) {
            return Source.REMOVE;
        }
        var now = clock.get_frame_time();
        var elapsed = now - anim_start_time;
        var progress = elapsed / 200000.0f;
        if (progress >= 1.0) {
            display_level = level;
            queue_draw();
            anim_running = false;
            return Source.REMOVE;
        } else {
            display_level = anim_from + Easing.ease_in_out_quad(progress) * (level - anim_from);
            queue_draw();
            return Source.CONTINUE;
        }
    }

    static construct {
        set_css_name("levelbin");
    }
    public override void snapshot(Gtk.Snapshot snapshot) {
        var full_bounds = Graphene.Rect() {
            origin = { 0, 0 },
            size = { get_width(), get_height() }
        };
        var clip_bounds = Gsk.RoundedRect().init_from_rect(
            full_bounds,
            6
            );

        snapshot.push_rounded_clip(clip_bounds);
        // TODO: queue redraws when the theme colors change
        var factor = (float)Math.pow(display_level, 0.75);
        var color = Color.lerp(
            MabiShell.config.theme_inactive,
            MabiShell.config.theme_active,
            factor
            );
        snapshot.append_color(color.rgba, full_bounds);
        snapshot.pop();

        var child = get_child();
        if (child != null) {
            snapshot_child(child, snapshot);
        }

    }
}
