import { property, register } from "astal/gobject";
import { Gdk, Gtk, astalify } from "astal/gtk4";
import Adw from "gi://Adw?version=1";
import Graphene from "gi://Graphene?version=1.0";
import Gsk from "gi://Gsk?version=4.0";

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

interface LevelBinConstructorProps extends Adw.Bin.ConstructorProps {
    level: number;
}

@register()
export class LevelBin extends BackgroundBin {
    #level: number;

    @property(Number)
    set level(value: number) {
        this.#level = value;
        this.queue_draw();
    }

    get level() {
        return this.#level;
    }

    constructor(props?: Partial<LevelBinConstructorProps>) {
        super(props);
        this.#level = 0;
    }

    draw(snapshot: Gtk.Snapshot, fullRect: Graphene.Rect) {
        // clamp
        let blendFactor = Math.max(Math.min(this.#level, 1), 0);
        // change curve to emphasize changes at small amounts
        blendFactor = Math.pow(blendFactor, 0.75);

        // TODO: Transitions
        // TODO: Blend in Oklab
        // TODO: Un-hardcode the colors

        const min = [192, 99, 201];
        const max = [134, 67, 181];
        const mixed = [0, 0, 0];
        for (let i = 0; i < 3; i++) {
            mixed[i] = Math.round(min[i] * (1 - blendFactor) + max[i] * blendFactor);
        }

        const color = new Gdk.RGBA({ red: mixed[0] / 255, green: mixed[1] / 255, blue: mixed[2] / 255, alpha: 1 });
        const roundedRect = new Gsk.RoundedRect().init_from_rect(fullRect, fullRect.get_height() / 2);

        snapshot.push_rounded_clip(roundedRect);
        snapshot.append_node(Gsk.ColorNode.new(color, fullRect));
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
