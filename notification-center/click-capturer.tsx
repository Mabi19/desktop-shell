import { register } from "astal/gobject";
import { App, Astal, Gdk, Gtk } from "astal/gtk4";
import Graphene from "gi://Graphene?version=1.0";

const DEBUG_DISABLE_CTC = true;

let clickCallback: (() => void) | null = null;
let captureWindows = new Map<Gdk.Monitor, { window: Astal.Window; monitorConnectID: number }>();

function openCaptureWindows() {
    for (const monitor of App.get_monitors()) {
        const monitorConnectID = monitor.connect("invalidate", () => {
            console.log("monitor invalidated, closing corresponding ctc");
            captureWindows.get(monitor)?.window?.destroy();
            captureWindows.delete(monitor);
            monitor.disconnect(monitorConnectID);
        });
        captureWindows.set(monitor, { window: ClickCaptureWindow(monitor) as Astal.Window, monitorConnectID });
    }
}

function closeCaptureWindows() {
    for (const [monitor, { window, monitorConnectID }] of captureWindows.entries()) {
        window.destroy();
        monitor.disconnect(monitorConnectID);
    }
    captureWindows.clear();
}

export function setupClickCapture(callback: () => void) {
    if (DEBUG_DISABLE_CTC) {
        return;
    }

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
                const gesturePrimary = new Gtk.GestureClick({ button: Gdk.BUTTON_PRIMARY });
                gesturePrimary.connect("released", handleCaptureClick);
                self.add_controller(gesturePrimary);
                const gestureSecondary = new Gtk.GestureClick({ button: Gdk.BUTTON_SECONDARY });
                gestureSecondary.connect("released", handleCaptureClick);
                self.add_controller(gestureSecondary);
            }}
            onDestroy={() => console.log("click capture window destroyed")}
        >
            <FillerWidget />
        </window>
    );
}
