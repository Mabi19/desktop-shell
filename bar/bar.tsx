import { Variable } from "astal";
import { App, Astal } from "astal/gtk3";
import { LeftSection } from "./left-section";
import { RightSection } from "./right-section";
import { Workspaces } from "./workspaces";

const time = Variable<string>("").poll(1000, "date");

export const Bar = (monitor: number) => (
    <window
        className="bar"
        monitor={monitor}
        exclusivity={Astal.Exclusivity.EXCLUSIVE}
        anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.LEFT | Astal.WindowAnchor.RIGHT}
        application={App}
    >
        <centerbox>
            <LeftSection monitor={monitor} />
            <Workspaces monitor={monitor} />
            <RightSection monitor={monitor} />
        </centerbox>
    </window>
);
