import { property, register } from "astal/gobject";
import { Gtk } from "astal/gtk4";
import Adw from "gi://Adw?version=1";
import AstalMpris from "gi://AstalMpris?version=0.1";
import Gio from "gi://Gio?version=2.0";
import GObject from "gi://GObject?version=2.0";
import Template from "./media.blp";

interface CoverArtPictureConstructorProps extends Gtk.Widget.ConstructorProps {
    path: string;
}

@register({ GTypeName: "CoverArtPicture", CssName: "cover-art-picture" })
class CoverArtPicture extends Gtk.Widget {
    @property(String)
    declare path: string;

    picture: Gtk.Picture;
    constructor(props?: Partial<CoverArtPictureConstructorProps>) {
        super(props);
        this.overflow = Gtk.Overflow.HIDDEN;

        this.picture = new Gtk.Picture({
            contentFit: Gtk.ContentFit.COVER,
        });
        // @ts-expect-error types broken (?)
        this.bind_property_full(
            "path",
            this.picture,
            "file",
            GObject.BindingFlags.SYNC_CREATE,
            (_b, value: string) => [true, Gio.File.new_for_path(value)],
            null
        );
        this.picture.set_parent(this);
    }

    get_cover_art_file(_self: CoverArtPicture, path: string) {
        return Gio.File.new_for_path(path);
    }

    vfunc_get_request_mode() {
        return Gtk.SizeRequestMode.CONSTANT_SIZE;
    }

    vfunc_measure(orientation: Gtk.Orientation, for_size: number): [number, number, number, number] {
        return [96, 96, -1, -1];
    }

    vfunc_size_allocate(width: number, height: number, baseline: number): void {
        this.picture.allocate(width, height, -1, null);
    }

    vfunc_dispose() {
        this.picture.unparent();
    }
}

interface MediaPlayerConstructorProps extends Gtk.Widget.ConstructorProps {
    player: AstalMpris.Player;
}

@register({ GTypeName: "MediaPlayer", CssName: "media-player", Template })
export class MediaPlayer extends Gtk.Widget {
    @property(AstalMpris.Player)
    declare player: AstalMpris.Player;

    constructor(props?: Partial<MediaPlayerConstructorProps>) {
        super(props);
        this.player.connect("notify::artist", () => this.notify);
    }

    get_progress_fraction(_self: MediaPlayer, position: number, length: number) {
        return Math.max(0, Math.min(position / length, 1));
    }

    format_timecode(_self: MediaPlayer, timecode: number) {
        timecode = Math.round(timecode);
        const seconds = timecode % 60;
        timecode = (timecode - seconds) / 60;
        const minutes = timecode % 60;
        timecode = (timecode - minutes) / 60;
        const hours = timecode;

        if (hours > 0) {
            return `${hours}:${minutes.toString().padStart(2, "0")}:${seconds.toString().padStart(2, "0")}`;
        } else {
            return `${minutes}:${seconds.toString().padStart(2, "0")}`;
        }
    }

    build_artist_line() {
        const parts = [];
        if (this.player.artist) {
            parts.push(this.player.artist);
        }
        if (this.player.album) {
            parts.push(this.player.album);
        }
        return parts.length > 0 ? parts.join(" • ") : "Unknown";
    }

    seek_prev() {
        this.player.previous();
    }

    seek_next() {
        this.player.next();
    }

    play_pause() {
        this.player.play_pause();
    }

    raise() {
        this.player.raise();
    }

    get_playback_icon(_self: MediaPlayer, status: AstalMpris.PlaybackStatus) {
        return status == AstalMpris.PlaybackStatus.PLAYING
            ? "media-playback-pause-symbolic"
            : "media-playback-start-symbolic";
    }

    to_title_case(_self: MediaPlayer, text: string) {
        return (text ?? "").replace(/\w\S*/g, (word) => word.charAt(0).toUpperCase() + word.substring(1).toLowerCase());
    }

    vfunc_dispose() {
        this.dispose_template(MediaPlayer.$gtype);
        super.vfunc_dispose();
    }
}
