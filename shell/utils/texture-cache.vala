// TODO: cache the last few images
// TODO: make this async
class TextureCache {
    // TODO: caching.
    // Have a map from identifier to weak TextureCache.Ref,
    // and a small LRU cache which owns its references.
    // The Ref objects will tell the cache when to remove the weak refs from the map.
    [Compact]
    class CachedTextureMeta {
        public unowned TextureCache cache;
        public string cache_key;
    }

    public Gdk.Texture load_file(File file) throws Error {
        print("loading image at path %s\n", file.get_path());
        var loader = new Gly.Loader(file);
        var image = loader.load();
        var frame = image.next_frame();
        var texture = GlyGtk4.frame_get_texture(frame);
        CachedTextureMeta* meta = new CachedTextureMeta();
        meta->cache = this;
        meta->cache_key = file.get_path();
        texture.set_data_full("texture-cache", meta, (data) => {
            CachedTextureMeta* metadata = data;
            metadata->cache.remove_key(metadata->cache_key);
            delete metadata;
        });
        return texture;
    }

    private void remove_key(string key) {
        print("removing %s from cache\n", key);
    }
}
