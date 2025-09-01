[GtkTemplate(ui = "/land/mabi/shell/ui/bar/audio-button.ui")]
class AudioButton : Adw.Bin {
    internal AstalWp.Wp service;
    public AstalWp.Endpoint speaker { get; construct; }
    public AstalWp.Endpoint microphone { get; construct; }
    // TODO: Properly source this from the config once that exists
    private Gdk.RGBA background_color;

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
}
