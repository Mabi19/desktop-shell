import { App, Astal, Gdk, Gtk } from "astal/gtk4";
import { Variable } from "astal/variable";
import cairo from "gi://cairo?version=1.0";
import type GdkWayland from "gi://GdkWayland?version=4.0";

const clickCallback = new Variable<(() => void) | null>(null);

function handleCaptureClick() {
    const func = clickCallback.get();
    if (!func) {
        return;
    }
    clickCallback.set(null);
    func();
}

export function ClickCaptureWindow(monitor: Gdk.Monitor) {
    return (
        <window
            cssClasses={["click-capture-window"]}
            namespace={"click-capture"}
            gdkmonitor={monitor}
            exclusivity={Astal.Exclusivity.NORMAL}
            layer={Astal.Layer.TOP}
            anchor={
                Astal.WindowAnchor.TOP | Astal.WindowAnchor.LEFT | Astal.WindowAnchor.BOTTOM | Astal.WindowAnchor.RIGHT
            }
            application={App}
            visible={clickCallback().as(Boolean)}
            setup={(self) => {
                const gesture = new Gtk.GestureClick({ button: Gdk.BUTTON_PRIMARY });
                gesture.connect("released", handleCaptureClick);
                self.add_controller(gesture);
            }}
        ></window>
    );
}

export function setupClickCapture(callback: () => void) {
    // dismiss the previous thing
    const oldCallback = clickCallback.get();
    if (oldCallback) {
        oldCallback();
    }
    clickCallback.set(callback);
}

export function cancelClickCapture() {
    clickCallback.set(null);
}
