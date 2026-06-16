/**
 * A notification received from the D-Bus notification interface.
 * All properties are mutable so that notification rules can modify them.
 */
class Notification : Object {
    public uint32 id;
    public NotificationLayout layout;
    public string timestamp;

    public string summary;
    public string body;
    public Gdk.Texture? image;
    public string category;
    public string app_name;
    public string app_icon;
    public string desktop_entry;
    public int32 expire_timeout;
    public bool transient;
    public bool resident;
    public NotificationUrgency urgency;
    public bool action_icons;
    public string? sound_file;
    public string? sound_name;
    public bool suppress_sound;

    public Gee.List<NotificationAction> actions;
    public NotificationFormatMethod format_method;
    public NotificationFormatting.FormattedText formatted_body;

    static TextureCache image_cache = new TextureCache();

    /**
     * Construct a Notification directly from the D-Bus Notify method parameters.
     */
    public async Notification.from_dbus_async(
        uint32 id,
        string app_name,
        string app_icon,
        string summary,
        string body,
        string[] action_list,
        HashTable<string, Variant> hints,
        int32 expire_timeout
        ) {
        this.id = id;
        this.layout = DEFAULT;
        this.format_method = STANDARD;
        this.timestamp = new GLib.DateTime.now_local().format(MabiShell.config.time_format_short);
        this.summary = summary;
        this.body = body;
        this.app_name = app_name;
        this.app_icon = app_icon;
        this.expire_timeout = expire_timeout;

        // Parse hints
        this.category = get_hint_string(hints, "category") ?? "";
        this.desktop_entry = get_hint_string(hints, "desktop-entry") ?? "";
        this.action_icons = get_hint_bool(hints, "action-icons");
        this.transient = get_hint_bool(hints, "transient");
        this.resident = get_hint_bool(hints, "resident");
        this.suppress_sound = get_hint_bool(hints, "suppress-sound");
        this.sound_file = get_hint_string(hints, "sound-file");
        this.sound_name = get_hint_string(hints, "sound-name");

        var urgency_byte = get_hint_byte(hints, "urgency");
        if (urgency_byte >= 0 && urgency_byte <= 2) {
            this.urgency = (NotificationUrgency)urgency_byte;
        } else {
            this.urgency = NotificationUrgency.NORMAL;
        }

        // Parse actions: list of pairs [id, label, id, label, ...]
        this.actions = new Gee.ArrayList<NotificationAction>();
        for (int i = 0; i + 1 < action_list.length; i += 2) {
            this.actions.add(new NotificationAction(action_list[i], action_list[i + 1]));
        }

        this.image = yield load_image_from_hints(hints);

        // custom hints
        var layout_str = get_hint_string(hints, "x-mabi-shell.layout");
        switch (layout_str) {
        case "message":
            this.layout = MESSAGE;
            break;
        case "default":
        default:
            this.layout = DEFAULT;
            break;
        }

        var format_method_str = get_hint_string(hints, "x-mabi-shell.format_method");
        switch (format_method_str) {
        case "markdown":
            this.format_method = MARKDOWN;
            break;
        case "standard":
        default:
            this.format_method = STANDARD;
            break;
        }

        debug("evaluating rules for notification %u", id);
        foreach (var rule in MabiShell.config.notification_rules) {
            rule.evaluate(this);
        }

        switch (format_method) {
        case STANDARD:
            this.formatted_body = NotificationFormatting.parse_standard(this.body);
            break;
        case MARKDOWN:
            this.formatted_body = NotificationFormatting.parse_markdown(this.body);
            break;
        }
    }

    /**
     * Load an image from notification hints, following the spec's priority order:
     * 1. image-data / image_data / icon_data (raw pixel data)
     * 2. image-path / image_path (file path or URI)
     */
    private static async Gdk.Texture? load_image_from_hints(HashTable<string, Variant> hints) {
        // Try raw image data hints (current, deprecated, and legacy names)
        string[] image_data_keys = { "image-data", "image_data", "icon_data" };
        foreach (var key in image_data_keys) {
            var data_variant = hints.lookup(key);
            if (data_variant != null) {
                var texture = decode_image_data(data_variant);
                if (texture != null) {
                    return texture;
                }
            }
        }

        // Try image path hints
        string[] image_path_keys = { "image-path", "image_path" };
        foreach (var key in image_path_keys) {
            var path_str = get_hint_string(hints, key);
            if (path_str != null && path_str.length > 0) {
                return yield load_image_from_path(path_str);
            }
        }

        return null;
    }

    /**
     * Decode raw pixel data from the image-data hint.
     * The variant type is (iiibiiay): width, height, rowstride, has_alpha, bits_per_sample, channels, data.
     */
    private static Gdk.Texture? decode_image_data(Variant variant) {
        if (!variant.is_of_type(new VariantType("(iiibiiay)"))) {
            warning("image-data hint has unexpected type: %s", variant.get_type_string());
            return null;
        }

        int width = variant.get_child_value(0).get_int32();
        int height = variant.get_child_value(1).get_int32();
        int rowstride = variant.get_child_value(2).get_int32();
        bool has_alpha = variant.get_child_value(3).get_boolean();
        int bits_per_sample = variant.get_child_value(4).get_int32();
        int channels = variant.get_child_value(5).get_int32();
        Variant data_variant = variant.get_child_value(6);

        if (width <= 0 || height <= 0 || bits_per_sample != 8) {
            warning("image-data hint has invalid dimensions or unsupported bit depth: %dx%d, %d bps",
                    width, height, bits_per_sample);
            return null;
        }

        var data = data_variant.get_data_as_bytes();
        Gdk.MemoryFormat format;
        if (has_alpha && channels == 4) {
            format = Gdk.MemoryFormat.R8G8B8A8;
        } else if (!has_alpha && channels == 3) {
            format = Gdk.MemoryFormat.R8G8B8;
        } else {
            warning("image-data hint has unsupported channel configuration: %d channels, has_alpha=%s",
                    channels, has_alpha.to_string());
            return null;
        }

        // Check cache before creating a texture to avoid redundant VRAM allocations.
        // Mix in image metadata so that identical bytes with different dimensions don't collide.
        var header = "%dx%d/%d/%d/%d/%s".printf(width, height, rowstride, bits_per_sample, channels,
                                                has_alpha.to_string());
        var checksum = new Checksum(ChecksumType.SHA256);
        checksum.update(header.data, header.data.length);
        checksum.update(data.get_data(), data.get_size());
        var key = "data:" + checksum.get_string();

        var cached = image_cache.lookup(key);
        if (cached != null) {
            return cached;
        }

        return image_cache.store(key, new Gdk.MemoryTexture(width, height, format, data, rowstride));
    }

    /** Load an image from a file path or file:// URI. */
    private static async Gdk.Texture? load_image_from_path(string path) {
        string file_path;
        if (path.has_prefix("file://")) {
            file_path = path[7 :];
        } else {
            file_path = path;
        }

        try {
            return yield image_cache.load_file(File.new_for_path(file_path));
        } catch (Error e) {
            warning("Error loading notification image from %s: %s", file_path, e.message);
            return null;
        }
    }

    private static string? get_hint_string(HashTable<string, Variant> hints, string key) {
        var v = hints.lookup(key);
        if (v != null && v.is_of_type(VariantType.STRING)) {
            return v.get_string();
        }
        return null;
    }

    private static bool get_hint_bool(HashTable<string, Variant> hints, string key) {
        var v = hints.lookup(key);
        if (v != null && v.is_of_type(VariantType.BOOLEAN)) {
            return v.get_boolean();
        }
        return false;
    }

    /** Returns -1 if the hint is not present or not a byte. */
    private static int get_hint_byte(HashTable<string, Variant> hints, string key) {
        var v = hints.lookup(key);
        if (v != null && v.is_of_type(VariantType.BYTE)) {
            return v.get_byte();
        }
        return -1;
    }

    public Json.Node to_json() {
        return new Json.Builder()
               .begin_object()
               .set_member_name("id").add_int_value(id)
               .set_member_name("timestamp").add_string_value(timestamp)
               .set_member_name("summary").add_string_value(summary)
               .set_member_name("body").add_string_value(body)
               .set_member_name("category").add_string_value(category)
               .set_member_name("app_name").add_string_value(app_name)
               .set_member_name("app_icon").add_string_value(app_icon)
               .set_member_name("desktop_entry").add_string_value(desktop_entry)
               .set_member_name("expire_timeout").add_int_value(expire_timeout)
               .set_member_name("transient").add_boolean_value(transient)
               .set_member_name("resident").add_boolean_value(resident)
               .set_member_name("urgency").add_int_value(urgency)
               .set_member_name("action_icons").add_boolean_value(action_icons)
               .set_member_name("sound_file").add_string_value(sound_file)
               .set_member_name("sound_name").add_string_value(sound_name)
               .set_member_name("suppress_sound").add_boolean_value(suppress_sound)
               .set_member_name("layout").add_int_value(layout)
               .set_member_name("format_method").add_int_value(format_method)
               .end_object()
               .get_root();
    }
}

/**
 * Central notification service that manages popup and stored notification state.
 * All visual notification changes are steered by this service object's logical state.
 */
class NotificationService : Object {
    private static NotificationService instance = null;
    public static NotificationService get_default() {
        if (instance == null) {
            debug("initializing NotificationService");
            instance = new NotificationService();
        }
        return instance;
    }

    private NotificationDaemon daemon;
    public Gee.HashMap<uint, Notification> popup_notifs;
    public Gee.TreeMap<uint, Notification> stored_notifs;
    private SoundService sound_service;

    public uint stored_count { get; private set; default = 0; }
    public bool dont_disturb { get; set; default = false; }

    public NotificationService() {
        assert_null(instance);
        daemon = new NotificationDaemon();

        popup_notifs = new Gee.HashMap<uint, Notification>();
        stored_notifs = new Gee.TreeMap<uint, Notification>();

        sound_service = SoundService.get_default();

        daemon.notified.connect(this.handle_notified);
        daemon.resolved.connect(this.handle_resolved);

        daemon.register();
    }

    private void handle_notified(Notification notification) {
        var id = notification.id;

        // If this notification is currently stored, remove it.
        Notification? stale_stored = null;
        stored_notifs.unset(id, out stale_stored);
        if (stale_stored != null) {
            stored_remove(stale_stored);
            stored_count = stored_notifs.size;
        }

        if (dont_disturb && notification.urgency != CRITICAL) {
            // In DND mode: store immediately, no popup or sound.
            // Transient notifications are discarded,
            // because they can't go in storage by definition.
            if (!notification.transient) {
                stored_notifs.set(id, notification);
                stored_set(notification);
                stored_count = stored_notifs.size;
            } else {
                dismiss(notification.id);
            }
            return;
        }

        if (!popup_notifs.has_key(id)) {
            play_sound_for(notification);
        }

        popup_notifs.set(id, notification);
        if (!popup_set(notification)) {
            warning("Notification with ID %u wasn't handled!", id);
        }
    }

    private void handle_resolved(uint32 id, NotificationClosedReason reason) {
        Notification? removed_popup = null;
        popup_notifs.unset(id, out removed_popup);
        if (removed_popup != null) {
            popup_remove(removed_popup);
        }

        Notification? removed_stored = null;
        stored_notifs.unset(id, out removed_stored);
        if (removed_stored != null) {
            stored_remove(removed_stored);
            stored_count = stored_notifs.size;
        }
    }

    private void play_sound_for(Notification notification) {
        if (notification.suppress_sound) {
            return;
        }

        // Prefer sound_name, then sound_file, then fallback to "message"
        if (notification.sound_name != null && notification.sound_name.strip() != "") {
            sound_service.play_deduped(notification.sound_name, GSound.Attribute.EVENT_ID);
        } else if (notification.sound_file != null && notification.sound_file.strip() != "") {
            sound_service.play_deduped(notification.sound_file, GSound.Attribute.MEDIA_FILENAME);
        } else {
            sound_service.play_deduped("message", GSound.Attribute.EVENT_ID);
        }
    }

    /** Transfer a notification from popups to storage, if the notification allows it. */
    public void transfer(Notification notification) {
        var id = notification.id;
        if (!popup_notifs.has_key(id)) {
            warning("Attempted to transfer notification %u to storage, but it wasn't a popup", id);
            return;
        }

        // Transient notifications are explicitly specified to not get stored.
        // To honor set expire timeouts, the notification needs to be closed once that's up.
        if (notification.transient || notification.expire_timeout > 0) {
            daemon.expire(id);
        } else {
            popup_notifs.unset(id);
            popup_remove(notification);
            stored_notifs.set(id, notification);
            stored_set(notification);
            stored_count = stored_notifs.size;
        }
    }

    /** Dismiss a notification by ID (user-initiated close). */
    public void dismiss(uint32 id) {
        daemon.dismiss(id);
    }

    /** Invoke an action on a notification. */
    public void invoke_action(uint32 id, string action_key) {
        daemon.invoke(id, action_key);

        var notification = popup_notifs.get(id);
        if (notification == null) {
            notification = stored_notifs.get(id);
        }
        if (notification != null && !notification.resident) {
            daemon.dismiss(id);
        }
    }

    /** Dismiss all stored notifications. */
    public void clear_stored() {
        var to_dismiss = stored_notifs.values.to_array();
        freeze_notify();
        foreach (var notification in to_dismiss) {
            daemon.dismiss(notification.id);
        }
        thaw_notify();
    }

    /**
     * Handlers for this signal should always return true, so that any notifications lost
     * due to lack of popups widget at that moment are tracked.
     * Conceptually this should use the `true_handled` accumulator, but there's no way to
     * specify signal accumulators in Vala.
     */
    public signal bool popup_set(Notification notification);
    public signal void popup_remove(Notification notification);
    /** This signal returns bool so that the same handler can be used as for popup_set. */
    public signal bool stored_set(Notification notification);
    public signal void stored_remove(Notification notification);
}
