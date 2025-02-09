import { Astal, Gtk } from "astal/gtk4";
import type { GLib } from "gi://GLib?version=2.0";

let osdWindow: Gtk.Window | null = null;
function OnScreenDisplay({ icon, value }: { icon: string; value: number }) {
    return (
        <window cssClasses={["osd-window"]}>
            <box vertical={true} cssClasses={["osd", "osd-box"]} spacing={8}>
                <image iconName={icon} cssClasses={["osd-icon"]} pixelSize={128} />
                <levelbar value={value} cssClasses={["osd-bar"]} />
                <label label={`${Math.round(value * 100)}%`} />
            </box>
        </window>
    ) as Gtk.Window;
}

let timeoutSource: GLib.Source | null = null;
function updateOSDWindow() {
    osdWindow?.present();

    if (timeoutSource) {
        clearTimeout(timeoutSource);
    }

    timeoutSource = setTimeout(() => {
        timeoutSource = null;
        osdWindow?.hide();
    }, 3000);
}

export function setOSD(icon: string, value: number) {
    if (osdWindow) {
        const box = osdWindow.get_child() as Gtk.Box;
        const image = box.get_first_child() as Gtk.Image;
        const bar = image.get_next_sibling() as Gtk.LevelBar;
        const label = bar.get_next_sibling() as Gtk.Label;
        image.iconName = icon;
        bar.value = value;
        label.label = `${Math.round(value * 100)}%`;
        updateOSDWindow();
    } else {
        osdWindow = OnScreenDisplay({ icon, value });
        updateOSDWindow();
    }
}
