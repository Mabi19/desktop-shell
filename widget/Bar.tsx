import { App, Astal, Gtk, Variable } from "astal";

const time = Variable<string>("").poll(1000, "date");

export default function Bar(monitor: number) {
    return (
        <window
            className="bar"
            monitor={monitor}
            exclusivity={Astal.Exclusivity.EXCLUSIVE}
            anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.LEFT | Astal.WindowAnchor.RIGHT}
            application={App}
        >
            <centerbox>
                <button onClicked="echo hello" halign={Gtk.Align.CENTER}>
                    Welcome to AGS!
                </button>
                <box />
                <button onClick={() => print("hello")} halign={Gtk.Align.CENTER}>
                    <label label={time()} />
                </button>
            </centerbox>
        </window>
    );
}
