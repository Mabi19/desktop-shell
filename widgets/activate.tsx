import { Variable, bind } from "astal";
import { App, Astal, Gdk } from "astal/gtk4";
import cairo from "gi://cairo?version=1.0";
import GLib from "gi://GLib?version=2.0";

function isAprilFools() {
    const now = new GLib.DateTime();
    return now.get_month() == 4 && now.get_day_of_month() == 1;
}

export function setAprilFoolsFlag(bit: number, newValue: boolean) {
    let value = shouldDisplayFools.get();
    if (newValue) {
        value |= bit;
    } else {
        value &= ~bit;
    }
    shouldDisplayFools.set(value);
}

// TODO: Don't create the windows at all if it isn't April 1st
// Also, toggling visibility on windows with gdkmonitor set breaks things
export const shouldDisplayFools = new Variable(isAprilFools() ? 1 : 0);
setInterval(() => {
    setAprilFoolsFlag(0x1, isAprilFools());
}, 600000);

export function ActivateWindow(monitor: Gdk.Monitor) {
    return (
        <window
            cssClasses={["activate"]}
            gdkmonitor={monitor}
            exclusivity={Astal.Exclusivity.IGNORE}
            anchor={Astal.WindowAnchor.BOTTOM | Astal.WindowAnchor.RIGHT}
            layer={Astal.Layer.OVERLAY}
            application={App}
            setup={(self) => {
                self.get_surface()?.set_input_region(new cairo.Region());
                self.connect("map", () => {
                    console.log("mapping surface");
                    self.get_surface()?.set_input_region(new cairo.Region());
                });
            }}
            marginBottom={72}
            marginRight={72}
        >
            <box vertical={true} visible={bind(shouldDisplayFools).as(Boolean)}>
                <label label="Activate Linux" cssClasses={["activate-top"]} xalign={0} />
                <label
                    label="Run <tt>systemctl activate</tt> to activate Linux"
                    useMarkup={true}
                    cssClasses={["activate-bottom"]}
                />
            </box>
        </window>
    );
}
