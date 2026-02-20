class TextureCache {
    [Compact]
    class CachedTextureMeta {
        public unowned TextureCache cache;
        public string cache_key;
    }

    const int LRU_SIZE = 4;

    Gee.HashMap<string, unowned Gdk.Texture> cache = new Gee.HashMap<string, unowned Gdk.Texture>();

    /**
     * Small LRU array that keeps strong references to recently accessed textures,
     * preventing them from being freed and evicted when their last external
     * reference is dropped. lru[0] is the most recently used.
     */
    Gdk.Texture?[] lru = new Gdk.Texture?[LRU_SIZE];

    /** Look up a texture by cache key. Returns null on miss. */
    public Gdk.Texture? lookup(string key) {
        if (cache.has_key(key)) {
            var texture = cache[key];
            touch_lru(texture);
            return texture;
        }
        return null;
    }

    /**
     * Store a texture in the cache under the given key.
     * Attaches an eviction callback so the entry is removed when
     * the texture loses its last external reference.
     * Returns the texture for convenience.
     */
    public Gdk.Texture store(string key, Gdk.Texture texture) {
        CachedTextureMeta* meta = new CachedTextureMeta();
        meta->cache = this;
        meta->cache_key = key;
        texture.set_data_full("texture-cache", meta, (data) => {
            CachedTextureMeta* metadata = data;
            metadata->cache.remove_key(metadata->cache_key);
            delete metadata;
        });
        cache[key] = texture;
        touch_lru(texture);
        return texture;
    }

    public async Gdk.Texture load_file(File file) throws Error {
        var key = "file:" + file.get_path();

        var cached = lookup(key);
        if (cached != null) {
            return cached;
        }

        var loader = new Gly.Loader(file);
        var image = yield loader.load_async(null);
        var frame = yield image.next_frame_async(null);
        var texture = GlyGtk4.frame_get_texture(frame);
        return store(key, texture);
    }

    /**
     * Promote a texture to the front of the LRU. If the texture is already
     * present, it is moved to position 0. Otherwise, it is inserted at
     * position 0 and the least recently used entry is dropped.
     */
    private void touch_lru(Gdk.Texture texture) {
        // Check if already present; if so, note its position.
        int existing = -1;
        for (int i = 0; i < LRU_SIZE; i++) {
            if (lru[i] == texture) {
                existing = i;
                break;
            }
        }

        // Shift elements right to make room at position 0.
        // If already present, shift [0..existing-1] right by one.
        // If not present, shift [0..LRU_SIZE-2] right by one, dropping the tail.
        int shift_end = (existing >= 0) ? existing : LRU_SIZE - 1;
        for (int i = shift_end; i > 0; i--) {
            lru[i] = lru[i - 1];
        }

        lru[0] = texture;
    }

    private void remove_key(string key) {
        cache.unset(key);
    }
}
