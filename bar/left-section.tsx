import { Variable, bind, execAsync } from "astal";
import { Gtk } from "astal/gtk4";
import { cpuUsage, memoryAvailable, memoryTotal, memoryUsage } from "../utils/system-stats";
import { BackgroundBin, LevelBadge } from "./badge-widgets";
import { NetworkIndicator } from "./network";

const memoryTooltip = Variable.derive(
    [memoryAvailable, memoryTotal],
    (available, total) => `${((total - available) / 1024 / 1024).toFixed(1)} GiB used`
);

const CpuIndicator = () => {
    return (
        <LevelBadge level={bind(cpuUsage)}>
            <button onClicked={() => execAsync(`gnome-system-monitor -r`)} cssClasses={["usage-badge"]}>
                <box name="cpu-badge" spacing={4}>
                    <image iconName="fa-microchip-symbolic" />
                    <label label={bind(cpuUsage).as((usage) => `${Math.floor(usage * 100)}%`)} />
                </box>
            </button>
        </LevelBadge>
    );
};

const MemoryIndicator = () => {
    return (
        <LevelBadge level={bind(memoryUsage)}>
            <button onClicked={() => execAsync(`gnome-system-monitor -r`)} cssClasses={["usage-badge"]}>
                <box name="memory-badge" tooltipText={memoryTooltip()} spacing={4}>
                    <image iconName="fa-memory-symbolic" />
                    <label label={bind(memoryUsage).as((usage) => `${Math.floor(usage * 100)}%`)} />
                </box>
            </button>
        </LevelBadge>
    );
};

const capsLockActive = Variable(false);
export async function updateCapsLockStatus() {
    const result = JSON.parse(await execAsync(["hyprctl", "devices", "-j"])).keyboards.filter((kb: any) => kb.main);
    if (result.length > 0) {
        capsLockActive.set(result[0].capsLock);
    }
}
updateCapsLockStatus();

const CapsIndicator = () => {
    return (
        <revealer revealChild={capsLockActive()} transitionType={Gtk.RevealerTransitionType.SLIDE_RIGHT}>
            <box spacing={4}>
                <image iconName="dialog-warning-symbolic" />
                <label label="CAPS" />
            </box>
        </revealer>
    );
};

export function LeftSection() {
    return (
        <box halign={Gtk.Align.START} spacing={8}>
            <CpuIndicator />
            <MemoryIndicator />
            <NetworkIndicator />
            <CapsIndicator />
        </box>
    );
}
