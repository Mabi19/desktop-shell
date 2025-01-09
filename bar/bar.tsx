import { bind } from "astal";
import { App, Astal, Gdk } from "astal/gtk4";
import { LeftSection } from "./left-section";
import { RightSection } from "./right-section";
import { Workspaces } from "./workspaces";

export const Bar = (monitor: Gdk.Monitor) => (
    <window
        cssClasses={["bar"]}
        gdkmonitor={monitor}
        exclusivity={Astal.Exclusivity.EXCLUSIVE}
        anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.LEFT | Astal.WindowAnchor.RIGHT}
        application={App}
        visible={true}
    >
        <centerbox>
            <LeftSection />
            <Workspaces gdkmonitor={monitor} />
            <RightSection monitor={monitor} />
        </centerbox>
    </window>
);
