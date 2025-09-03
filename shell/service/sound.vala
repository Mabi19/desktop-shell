class SoundService : Object {
    private static SoundService instance = null;
    public static SoundService get_default() {
        if (instance == null) {
            debug("initializing SoundService");
            instance = new SoundService();
        }
        return instance;
    }

    public GSound.Context context { get; construct; }
    private Gee.HashSet<string> currently_playing;

    construct {
        assert_null(instance);
        currently_playing = new Gee.HashSet<string>();
        try {
            context = new GSound.Context();
            context.init();
        } catch (Error e) {
            context = null;
            warning("Couldn't initialize GSound, sounds will not work: %s", e.message);
        }
    }

    public void play_deduped(string sound_id) {
        if (context == null) {
            return;
        }
        if (sound_id in currently_playing) {
            return;
        }

        currently_playing.add(sound_id);
        context.play_full.begin(null, (obj, res) => {
            try {
                context.play_full.end(res);
            } catch (Error e) {
                warning("Couldn't play sound: %s", e.message);
            }
            currently_playing.remove(sound_id);
        }, GSound.Attribute.EVENT_ID, sound_id);
    }
}
