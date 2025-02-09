import { Astal, Gtk } from "astal/gtk4";
import type { GLib } from "gi://GLib?version=2.0";

function OnScreenDisplay({ icon, value }: { icon: string; value: number }) {
    return (
        <box vertical={true} cssClasses={["osd", "osd-box"]} spacing={8}>
            <image iconName={icon} cssClasses={["osd-icon"]} pixelSize={128} />
            <levelbar value={value} cssClasses={["osd-bar"]} />
            <label label={`${Math.round(value * 100)}%`} />
        </box>
    ) as Gtk.Window;
}

let timeoutSource: GLib.Source | null = null;
let osdWindow: Gtk.Window | null = null;
export function setOSD(icon: string, value: number) {
    if (!osdWindow) {
        osdWindow = new Astal.Window({ cssClasses: ["osd-window"] });
    }

    osdWindow.set_child(OnScreenDisplay({ icon, value }));
    osdWindow.present();

    if (timeoutSource) {
        clearTimeout(timeoutSource);
    }
    timeoutSource = setTimeout(() => {
        timeoutSource = null;
        osdWindow?.hide();
    }, 3000);
}
