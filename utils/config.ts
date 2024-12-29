import { bind } from "astal";
import { readFile } from "astal/file";
import { App } from "astal/gtk4";
import AstalHyprland from "gi://AstalHyprland";

const hyprland = AstalHyprland.get_default();

export const CONFIG: {
    primary_monitor: string;
} = JSON.parse(readFile("./config.json"));

const primaryMonitorModel = bind(hyprland, "monitors").as(
    (monitorList) =>
        monitorList.find((mon) => mon.name == CONFIG.primary_monitor)?.model ?? monitorList[0].model
);

export const primaryMonitor = bind(primaryMonitorModel).as((primaryModel) =>
    App.get_monitors().find((mon) => primaryModel == mon.model)
);
