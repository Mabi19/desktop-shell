class VolumeSlider : Gtk.Scale {
    public AstalWp.Endpoint device { get; set; }
    private Binding bind_mute;
    private AstalWp.Endpoint volume_conn_device;
    private ulong volume_conn;

    construct {
        hexpand = true;
        adjustment = new Gtk.Adjustment(0, 0, 1, 0.01, 0.05, 0);
        volume_conn_device = null;
        notify["device"].connect(setup_connections);
        value_changed.connect(() => {
            if (device != null && adjustment != null && (device.volume - adjustment.value).abs() > 0.001) {
                device.volume = adjustment.value;

                if (device.media_class == AstalWp.MediaClass.AUDIO_SINK) {
                    SoundService.get_default().play_deduped("audio-volume-change");
                }
            }
        });
    }

    void setup_connections() {
        if (device == null) {
            return;
        }

        adjustment.value = device.volume;
        bind_mute = device.bind_property("mute", this, "sensitive", GLib.BindingFlags.INVERT_BOOLEAN);
        if (volume_conn_device != null) {
            volume_conn_device.disconnect(volume_conn);
        }

        volume_conn = device.notify["volume"].connect(handle_volume_change);
        volume_conn_device = device;
    }

    void handle_volume_change() {
        if ((adjustment.value - device.volume).abs() > 0.001) {
            adjustment.value = device.volume;
        }
    }
}

[GtkTemplate(ui = "/land/mabi/shell/ui/bar/audio-button.ui")]
class AudioButton : Adw.Bin {
    internal AstalWp.Wp service;
    public AstalWp.Endpoint speaker { get; construct; }
    public AstalWp.Endpoint microphone { get; construct; }
    private AstalCava.Cava cava;
    private const int BAR_COUNT = 16;

    [GtkChild]
    unowned Gtk.Popover popover;

    static construct {
        typeof(VolumeSlider).ensure();
    }

    construct {
        service = AstalWp.get_default();
        speaker = service.get_default_speaker();
        microphone = service.get_default_microphone();
        cava = AstalCava.get_default();
        cava.bars = BAR_COUNT;
        cava.notify["values"].connect(this.queue_draw);
        MabiShell.config.notify["theme-inactive"].connect(this.queue_draw);
        MabiShell.config.notify["theme-active"].connect(this.queue_draw);
    }

    public override void dispose() {
        dispose_template(typeof(AudioButton));
        base.dispose();
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
        snapshot.append_color(MabiShell.config.theme_inactive.rgba, full_bounds);
        draw_cava(snapshot);
        snapshot.pop();

        var child = get_child();
        if (child != null) {
            snapshot_child(child, snapshot);
        }
    }

    private void draw_cava(Gtk.Snapshot snapshot) {
        // Based on kotontrion's Catmull-Rom spline implementation:
        // https://github.com/kotontrion/kompass/blob/2fbab99ec2e4db81166a570c9e953d295544f83c/libkompass/src/cava.vala#L51

        int width = get_width();
        int height = get_height();
        var raw_values = cava.get_values();
        float values[BAR_COUNT];
        // adjust values to make a nicer graph
        for (int i = 0; i < BAR_COUNT; i++) {
            values[i] = (float)Math.pow(raw_values.index(i).clamp(0.0, 1.0), 0.6);
        }
        uint bars = values.length;
        float bar_width = width / (bars - 1.0f);

        var builder = new Gsk.PathBuilder();
        builder.move_to(0, height * (1.0f - values[0]));
        for (int i = 0; i <= bars - 2; i++) {
            Graphene.Point p0, p3;
            Graphene.Point p1 = { x : i * bar_width, y : height * (1.0f - values[i]) };
            Graphene.Point p2 = { x : (i + 1) * bar_width, y : height * (1.0f - values[i + 1]) };

            if (i == 0) {
                p0 = { x : i * bar_width, y : height * (1.0f - values[i]) };
                p3 = { x : (i + 2) * bar_width, y : height * (1.0f - values[i + 2]) };
            } else if (i == bars - 2) {
                p0 = { x : (i - 1) * bar_width, y : height * (1.0f - values[i - 1]) };
                p3 = { x : (i + 1) * bar_width, y : height * (1.0f - values[i + 1]) };
            } else {
                p0 = { x : (i - 1) * bar_width, y : height * (1.0f - values[i - 1]) };
                p3 = { x : (i + 2) * bar_width, y : height * (1.0f - values[i + 2]) };
            }

            Graphene.Point c1 = { x : p1.x + (p2.x - p0.x) / 6.0f, y : p1.y + (p2.y - p0.y) / 6.0f };
            Graphene.Point c2 = { x : p2.x - (p3.x - p1.x) / 6.0f, y : p2.y - (p3.y - p1.y) / 6.0f };
            builder.cubic_to(c1.x, c1.y, c2.x, c2.y, p2.x, p2.y);
        }

        builder.line_to(width, height);
        builder.line_to(0, height);
        builder.close();
        snapshot.append_fill(builder.to_path(), Gsk.FillRule.WINDING, MabiShell.config.theme_active.rgba);
    }

    [GtkCallback]
    string format_volume(double volume) {
        double percentage = Math.round(volume * 100);
        return @"$percentage%";
    }

    [GtkCallback]
    void toggle_mute_speaker() {
        speaker.mute = !speaker.mute;
    }

    [GtkCallback]
    void toggle_mute_microphone() {
        microphone.mute = !microphone.mute;
    }

    [GtkCallback]
    string get_button_icon(bool is_muted, string if_muted, string if_not_muted) {
        return is_muted ? if_muted : if_not_muted;
    }

    [GtkCallback]
    bool handle_scroll(Gtk.EventControllerScroll controller, double dx, double dy) {
        if (dy == 0.0) {
            return false;
        }
        speaker.volume = (speaker.volume - dy * 0.05).clamp(0, 1);
        SoundService.get_default().play_deduped("audio-volume-change");
        return true;
    }

    [GtkCallback]
    void open_audio_mixer() {
        try {
            Process.spawn_command_line_async(MabiShell.config.audio_mixer_command);
            popover.popdown();
        } catch (SpawnError e) {
            warning("Couldn't spawn audio mixer process: %s\n", e.message);
        }
    }
}
