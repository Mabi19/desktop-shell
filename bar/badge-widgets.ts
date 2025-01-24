import { property, register } from "astal/gobject";
import { Gdk, Gtk, astalify } from "astal/gtk4";
import Adw from "gi://Adw?version=1";
import GLib from "gi://GLib?version=2.0";
import Graphene from "gi://Graphene?version=1.0";
import Gsk from "gi://Gsk?version=4.0";
import { convertOklabToGdk } from "../utils/color";
import { CONFIG } from "../utils/config";

@register({
    CssName: "background-bin",
})
export class BackgroundBin extends Adw.Bin {
    constructor(props?: Partial<Gtk.Widget.ConstructorProps>) {
        super(props);

        this.set_layout_manager(new Gtk.BinLayout());
    }

    draw(snapshot: Gtk.Snapshot, fullRect: Graphene.Rect) {
        const color = new Gdk.RGBA({ red: 1, green: 1, blue: 1, alpha: 1 });
        const roundedRect = new Gsk.RoundedRect().init_from_rect(fullRect, fullRect.get_height() / 2);

        snapshot.push_rounded_clip(roundedRect);
        snapshot.append_node(Gsk.ColorNode.new(color, fullRect));
        snapshot.pop();
    }

    vfunc_snapshot(snapshot: Gtk.Snapshot): void {
        const width = this.get_width();
        const height = this.get_height();

        const fullRect = new Graphene.Rect({
            origin: new Graphene.Point({ x: 0, y: 0 }),
            size: new Graphene.Size({ width, height }),
        });
        this.draw(snapshot, fullRect);

        for (let child = this.get_first_child(); child != null; child = child.get_next_sibling()) {
            this.snapshot_child(child, snapshot);
        }
    }
}

function lerp(min: number, max: number, factor: number) {
    return min * (1 - factor) + max * factor;
}

// in microseconds
const ANIMATION_LENGTH = 200_000;

interface LevelBinConstructorProps extends Adw.Bin.ConstructorProps {
    level: number;
}

@register()
export class LevelBin extends BackgroundBin {
    #animStartTime: number | null;
    #animStartLevel: number | null;
    #animTargetLevel: number | null;
    #level: number;

    constructor(props?: Partial<LevelBinConstructorProps>) {
        super(props);
        this.#level = props?.level ?? 0;
        this.#animStartTime = null;
        this.#animStartLevel = null;
        this.#animTargetLevel = null;
    }

    #stopAnimation() {
        this.#animStartTime = null;
        this.#animStartLevel = null;
        this.#animTargetLevel = null;
    }

    #animationTick(frameClock: Gdk.FrameClock): boolean {
        if (this.#animStartTime == null || this.#animStartLevel == null || this.#animTargetLevel == null) {
            this.#stopAnimation();
            return GLib.SOURCE_REMOVE;
        }

        const timeSinceStart = frameClock.get_frame_time() - this.#animStartTime;
        if (timeSinceStart >= ANIMATION_LENGTH) {
            this.#level = this.#animTargetLevel;
            this.queue_draw();
            this.#stopAnimation();
            return GLib.SOURCE_REMOVE;
        } else {
            // TODO: fancier curve here?
            this.#level = lerp(this.#animStartLevel, this.#animTargetLevel, timeSinceStart / ANIMATION_LENGTH);
            this.queue_draw();
            return GLib.SOURCE_CONTINUE;
        }
    }

    @property(Number)
    set level(value: number) {
        // do not animate if it would be unnoticeable
        if (Math.abs(value - this.#level) < 0.01) {
            this.#stopAnimation();
            this.#level = value;
            return;
        }

        // start animating
        const shouldStartClock = this.#animStartTime == null;
        this.#animStartTime = GLib.get_monotonic_time();
        this.#animStartLevel = this.#level;
        this.#animTargetLevel = value;

        if (shouldStartClock) {
            this.add_tick_callback((_self, frameClock) => this.#animationTick(frameClock));
        }
    }

    get level() {
        return this.#level;
    }

    draw(snapshot: Gtk.Snapshot, fullRect: Graphene.Rect) {
        // clamp
        let blendFactor = Math.max(Math.min(this.#level, 1), 0);
        // change curve to emphasize changes at small amounts
        blendFactor = Math.pow(blendFactor, 0.75);

        const min = CONFIG.theme_inactive;
        const max = CONFIG.theme_active;
        const mixed = {
            l: lerp(min.l, max.l, blendFactor),
            a: lerp(min.a, max.a, blendFactor),
            b: lerp(min.b, max.b, blendFactor),
        };

        const color = convertOklabToGdk(mixed);
        const roundedRect = new Gsk.RoundedRect().init_from_rect(fullRect, fullRect.get_height() / 2);

        snapshot.push_rounded_clip(roundedRect);
        snapshot.append_color(color, fullRect);
        snapshot.pop();
    }
}

export const LevelBadge = astalify<LevelBin, LevelBinConstructorProps>(LevelBin, {
    getChildren(widget) {
        return [widget.child];
    },
    setChildren(widget, children) {
        widget.child = children[0];
    },
});

const themeColorInactive = convertOklabToGdk(CONFIG.theme_inactive);
const themeColorActive = convertOklabToGdk(CONFIG.theme_active);

interface GraphBinConstructorProps extends Adw.Bin.ConstructorProps {
    values: number[];
}

@register()
export class GraphBin extends BackgroundBin {
    #values!: number[];

    @property(Object)
    set values(data: number[]) {
        this.#values = data;
        this.queue_draw();
    }

    get values() {
        return this.#values;
    }

    constructor(props?: Partial<GraphBinConstructorProps>) {
        super(props);
        if (!this.values) {
            this.values = [];
        }
    }

    draw(snapshot: Gtk.Snapshot, fullRect: Graphene.Rect) {
        const width = fullRect.get_width();
        const height = fullRect.get_height();
        const roundedRect = new Gsk.RoundedRect().init_from_rect(fullRect, height / 2);

        snapshot.push_rounded_clip(roundedRect);
        // the background
        snapshot.append_color(themeColorInactive, fullRect);
        // ... and the graph
        if (this.values.length > 0) {
            const builder = new Gsk.PathBuilder();
            builder.move_to(0, height);
            for (let i = 0; i < this.#values.length; i++) {
                const adjustedValue = Math.pow(Math.max(Math.min(1, this.#values[i]), 0), 0.75);

                builder.line_to(width * (i / (this.#values.length - 1)), height * (1 - adjustedValue));
            }
            builder.line_to(width, height);
            builder.close();
            const path = builder.to_path();
            snapshot.append_fill(path, Gsk.FillRule.EVEN_ODD, themeColorActive);
        }
        snapshot.pop();
    }
}

export const GraphBadge = astalify<GraphBin, GraphBinConstructorProps>(GraphBin, {
    getChildren(widget) {
        return [widget.child];
    },
    setChildren(widget, children) {
        widget.child = children[0];
    },
});
