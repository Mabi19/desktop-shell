import { bind } from "astal";
import { readFile } from "astal/file";
import { App } from "astal/gtk4";
import AstalHyprland from "gi://AstalHyprland";

const hyprland = AstalHyprland.get_default();

export const CONFIG: {
    primary_monitor: string;
} = JSON.parse(readFile("./config.json"));

const primaryMonitorName = bind(hyprland, "monitors").as(
    (monitorList) =>
        monitorList.find((mon) => mon.name == CONFIG.primary_monitor)?.name ?? monitorList[0].name
);

export const primaryMonitor = bind(primaryMonitorName).as((primaryName) =>
    App.get_monitors().find((mon) => primaryName == mon.connector)
);
