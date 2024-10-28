import { Variable } from "astal";
import { App, Astal, Gdk } from "astal/gtk3";
import { LeftSection } from "./left-section";
import { RightSection } from "./right-section";
import { Workspaces } from "./workspaces";

const time = Variable<string>("").poll(1000, "date");

export const Bar = (monitor: Gdk.Monitor) => (
    <window
        className="bar"
        gdkmonitor={monitor}
        exclusivity={Astal.Exclusivity.EXCLUSIVE}
        anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.LEFT | Astal.WindowAnchor.RIGHT}
        application={App}
    >
        <centerbox>
            <LeftSection />
            <Workspaces gdkmonitor={monitor} />
            <RightSection monitor={monitor} />
        </centerbox>
    </window>
);
