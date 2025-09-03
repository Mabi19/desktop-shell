// TODO
// Open Audio Mixer button
// scroll on audio button to change volume
// volume change sounds

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
                SoundService.get_default().play_deduped("audio-volume-change");
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
    // TODO: Properly source this from the config once that exists
    private Gdk.RGBA background_color;

    static construct {
        typeof(VolumeSlider).ensure();
    }

    construct {
        service = AstalWp.get_default();
        speaker = service.get_default_speaker();
        microphone = service.get_default_microphone();
        background_color = Gdk.RGBA();
        background_color.parse("#c063c9");
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
        snapshot.append_color(background_color, full_bounds);
        snapshot.pop();

        var child = get_child();
        if (child != null) {
            snapshot_child(child, snapshot);
        }

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
}
