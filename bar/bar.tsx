import { bind } from "astal";
import { App, Astal, Gdk } from "astal/gtk3";
import { LeftSection } from "./left-section";
import { RightSection } from "./right-section";
import { isDraggingWorkspace, Workspaces } from "./workspaces";

export const Bar = (monitor: Gdk.Monitor) => (
    <window
        className="bar"
        gdkmonitor={monitor}
        exclusivity={Astal.Exclusivity.EXCLUSIVE}
        anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.LEFT | Astal.WindowAnchor.RIGHT}
        application={App}
        keymode={bind(isDraggingWorkspace).as((dragging) =>
            dragging ? Astal.Keymode.ON_DEMAND : Astal.Keymode.NONE
        )}
    >
        <centerbox>
            <LeftSection />
            <Workspaces gdkmonitor={monitor} />
            <RightSection monitor={monitor} />
        </centerbox>
    </window>
);
