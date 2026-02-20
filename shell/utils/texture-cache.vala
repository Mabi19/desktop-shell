// TODO: keep references to the last few images in an array (LRU)
// so that common images (for example, profile pictures) don't need to be re-parsed all the time
// TODO: actually cache stuff in a hashmap
// TODO: also cache memory textures (generate keys by hashing?)
class TextureCache {
    [Compact]
    class CachedTextureMeta {
        public unowned TextureCache cache;
        public string cache_key;
    }

    public async Gdk.Texture load_file(File file) throws Error {
        print("loading image at path %s\n", file.get_path());
        var loader = new Gly.Loader(file);
        var image = yield loader.load_async(null);
        var frame = yield image.next_frame_async(null);
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
