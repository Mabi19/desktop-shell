class LevelBin : Adw.Bin {
    private double display_level = 0;
    private double _level = 0;
    public double level {
        get {
            return _level;
        }

        set {
            if ((value - display_level).abs() < 0.02) {
                animation.reset();
                display_level = value;
                queue_draw();
            } else {
                // trigger animation
                animation.value_from = display_level;
                animation.value_to = value;
                animation.play();
            }
            _level = value;
        }
    }
    private Adw.TimedAnimation animation;

    private void animation_tick(double value) {
        display_level = value;
        queue_draw();
    }

    static construct {
        set_css_name("levelbin");
    }

    construct {
        animation = new Adw.TimedAnimation(
            this,
            0, 0,
            200,
            new Adw.CallbackAnimationTarget(this.animation_tick)
        );
        animation.easing = Adw.Easing.EASE_IN_OUT;
    }

    public override void snapshot(Gtk.Snapshot snapshot) {
        var full_bounds = Graphene.Rect() {
            origin = { 0, 0 },
            size = { get_width(), get_height() }
        };
        var clip_bounds = Gsk.RoundedRect().init_from_rect(
            full_bounds,
            full_bounds.get_height() / 2
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
