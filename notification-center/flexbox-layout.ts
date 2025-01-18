import { property, register } from "astal/gobject";
import { Gdk, Gtk } from "astal/gtk4";

interface FlexBoxLayoutProps extends Gtk.LayoutManager.ConstructorProps {
    spacing: number;
}

type FlexLineEntry = {
    x: number;
    y: number;
    minWidth: number;
    minHeight: number;
    child: Gtk.Widget;
};

// A multiline box layout.
// Fits as many children on a line as possible,
// then lets them expand to fill each line (if they have hexpand set).
@register()
export class FlexBoxLayout extends Gtk.LayoutManager {
    @property(Number)
    declare spacing: number;

    constructor(props?: Partial<FlexBoxLayoutProps>) {
        props = props ?? {};
        super({ spacing: 0, ...props });
    }

    vfunc_get_request_mode(): Gtk.SizeRequestMode {
        return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
    }

    #allocate_line(line: FlexLineEntry[], width: number) {
        const lastEntry = line.at(-1)!;
        const spaceLeft = width - (lastEntry.x + lastEntry.minWidth);
        console.log("spaceLeft:", spaceLeft);

        const expandableChildren = line
            .map((entry) => entry.child)
            .filter((child) => child.hexpand);
        const extraSpacePerChild = spaceLeft / expandableChildren.length;

        let currentX = 0;
        // This is sub-pixel precise
        let expansionUsed = 0;
        for (const entry of line) {
            let actualWidth = entry.minWidth;
            if (entry.child.hexpand) {
                const lastStop = Math.round(expansionUsed);
                expansionUsed += extraSpacePerChild;
                const thisStop = Math.round(expansionUsed);
                console.log(`giving child ${thisStop - lastStop} of extra space`);
                actualWidth += thisStop - lastStop;
            }
            console.log("total expansion used:", expansionUsed);

            const allocation = new Gdk.Rectangle({
                x: currentX,
                y: entry.y,
                width: actualWidth,
                height: entry.minHeight,
            });
            entry.child.size_allocate(allocation, -1);

            currentX += actualWidth + this.spacing;
        }
    }

    vfunc_allocate(widget: Gtk.Widget, width: number, height: number, baseline: number): void {
        console.log("allocate", widget, width, height, baseline);

        let thisLineHeight = 0;
        let thisLineUsedSpace = 0;
        let thisLineOffset = 0;
        let thisLineContent: FlexLineEntry[] = [];

        for (
            let child = widget.get_first_child();
            child != null;
            child = child!.get_next_sibling()
        ) {
            if (!child.should_layout()) {
                continue;
            }

            const [childMinWidth, childNatWidth] = child.measure(Gtk.Orientation.HORIZONTAL, -1);
            const [childMinHeight, childNatHeight] = child.measure(
                Gtk.Orientation.VERTICAL,
                childMinWidth
            );

            if (thisLineUsedSpace + childMinWidth > width) {
                // allocate this line's widgets
                this.#allocate_line(thisLineContent, width);

                // set up a new line
                thisLineOffset += thisLineHeight + this.spacing;
                thisLineHeight = 0;
                thisLineUsedSpace = 0;
                thisLineContent = [];
            }

            thisLineContent.push({
                x: thisLineUsedSpace,
                y: thisLineOffset,
                minWidth: childMinWidth,
                minHeight: childNatHeight,
                child,
            });
            thisLineHeight = Math.max(thisLineHeight, childNatHeight);
            // it does not matter if we add an extra padding on the last item in a line,
            // it's not gonna get used
            thisLineUsedSpace += childMinWidth + this.spacing;
        }
        // allocate any leftover widgets
        if (thisLineContent.length > 0) {
            this.#allocate_line(thisLineContent, width);
        }
    }

    vfunc_measure(
        widget: Gtk.Widget,
        orientation: Gtk.Orientation,
        for_size: number
    ): [number, number, number, number] {
        console.log("measure", widget, orientation, for_size);
        if (orientation == Gtk.Orientation.VERTICAL) {
            // height-for-width request, for_size is width
            // Minimum height is all on one line
            // Natural height is wrapped
            if (for_size < 0) {
                console.warn("for_size is negative, so IDK how much space to give");
            }

            let minimum = 0;
            let thisLineHeight = 0;
            let thisLineUsedSpace = 0;
            let thisLineOffset = 0;

            for (
                let child = widget.get_first_child();
                child != null;
                child = child!.get_next_sibling()
            ) {
                if (!child.should_layout()) {
                    continue;
                }

                const [childMinWidth, childNatWidth] = child.measure(
                    Gtk.Orientation.HORIZONTAL,
                    -1
                );
                const [childMinHeight, childNatHeight] = child.measure(
                    Gtk.Orientation.VERTICAL,
                    childMinWidth
                );

                if (thisLineUsedSpace + childMinWidth > for_size) {
                    // set up a new line
                    thisLineOffset += thisLineHeight + this.spacing;
                    thisLineHeight = 0;
                    thisLineUsedSpace = 0;
                }

                minimum = Math.max(minimum, childMinHeight);
                thisLineHeight = Math.max(thisLineHeight, childNatHeight);
                // Only add padding if there's already a child to pad from
                const usedPadding = thisLineUsedSpace > 0 ? this.spacing : 0;
                thisLineUsedSpace += childMinWidth + usedPadding;
            }

            const natural = thisLineOffset + thisLineHeight;
            console.log({ minimum, natural });
            return [minimum, natural, -1, -1];
        } else {
            // width-for-height request
            // Minimum width is max(min widths)
            // Natural width is max(nat widths)
            let minimum = 0;
            let natural = 0;
            for (
                let child = widget.get_first_child();
                child != null;
                child = child!.get_next_sibling()
            ) {
                if (!child.should_layout()) {
                    continue;
                }

                const [child_min, child_nat, _child_min_baseline, _child_nat_baseline] =
                    child.measure(Gtk.Orientation.HORIZONTAL, for_size);
                minimum = Math.max(minimum, child_min);
                natural = Math.max(natural, child_nat);
            }

            console.log({ minimum, natural });
            return [minimum, natural, -1, -1];
        }
    }
}
