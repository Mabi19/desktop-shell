import { register } from "astal/gobject";
import { App, Astal, Gdk, Gtk } from "astal/gtk4";
import Graphene from "gi://Graphene?version=1.0";

let clickCallback: (() => void) | null = null;
let captureWindows = new Map<Gdk.Monitor, Astal.Window>();

function openCaptureWindows() {
    for (const monitor of App.get_monitors()) {
        captureWindows.set(monitor, ClickCaptureWindow(monitor) as Astal.Window);
        const id = monitor.connect("invalidate", () => {
            console.log("monitor invalidated, closing corresponding ctc");
            captureWindows.get(monitor)?.destroy();
            captureWindows.delete(monitor);
            monitor.disconnect(id);
        });
    }
}

function closeCaptureWindows() {
    for (const window of captureWindows.values()) {
        window.destroy();
    }
    captureWindows.clear();
}

export function setupClickCapture(callback: () => void) {
    // dismiss the previous thing if it exists
    if (clickCallback) {
        clickCallback();
    } else {
        openCaptureWindows();
    }
    clickCallback = callback;
}

export function cancelClickCapture() {
    closeCaptureWindows();
    clickCallback = null;
}

function handleCaptureClick() {
    if (!clickCallback) {
        return;
    }
    const func = clickCallback;
    cancelClickCapture();
    func();
}

// filler widget so that the ctc windows aren't empty
// (empty windows don't receive events)
@register({
    CssName: "ctc-filler",
})
class FillerWidget extends Gtk.Widget {
    constructor(props?: Partial<Gtk.Widget.ConstructorProps>) {
        super(props);
    }

    vfunc_snapshot(snapshot: Gtk.Snapshot): void {
        // transpare
        snapshot.append_color(
            new Gdk.RGBA({ red: 0.0, blue: 0.0, green: 0.0, alpha: 0.0 }),
            new Graphene.Rect({
                origin: new Graphene.Point({ x: 0, y: 0 }),
                size: new Graphene.Size({ width: 100, height: 100 }),
            })
        );
    }
}

function ClickCaptureWindow(monitor: Gdk.Monitor) {
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
            visible={true}
            setup={(self) => {
                const gesture = new Gtk.GestureClick({ button: Gdk.BUTTON_PRIMARY });
                gesture.connect("released", handleCaptureClick);
                self.add_controller(gesture);
            }}
            onDestroy={() => console.log("click capture window destroyed")}
        >
            <FillerWidget />
        </window>
    );
}
