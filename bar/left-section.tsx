import { Variable, bind, execAsync } from "astal";
import { Gtk } from "astal/gtk4";
import { cpuUsage, memoryAvailable, memoryTotal, memoryUsage } from "../utils/system-stats";
import { getUsageBadgeClass } from "../utils/usage-badge";
import { NetworkIndicator } from "./network";

const memoryTooltip = Variable.derive(
    [memoryAvailable, memoryTotal],
    (available, total) => `${((total - available) / 1024 / 1024).toFixed(1)} GiB used`
);

const CpuIndicator = () => {
    return (
        <box
            name="cpu-badge"
            cssClasses={bind(cpuUsage).as((usage) => ["usage-badge", getUsageBadgeClass(usage)])}
            spacing={4}
        >
            <image iconName="fa-microchip-symbolic" />
            <label label={cpuUsage((usage) => `${Math.floor(usage * 100)}%`)} />
        </box>
    );
};

const MemoryIndicator = () => {
    return (
        <box
            name="memory-badge"
            tooltipText={memoryTooltip()}
            cssClasses={bind(memoryUsage).as((usage) => ["usage-badge", getUsageBadgeClass(usage)])}
            spacing={4}
        >
            <image iconName="fa-memory-symbolic" />
            <label label={memoryUsage((usage) => `${Math.floor(usage * 100)}%`)} />
        </box>
    );
};

const capsLockActive = Variable(false);
export async function updateCapsLockStatus() {
    const result = JSON.parse(await execAsync(["hyprctl", "devices", "-j"])).keyboards.filter(
        (kb: any) => kb.main
    );
    if (result.length > 0) {
        capsLockActive.set(result[0].capsLock);
    }
}
updateCapsLockStatus();

const CapsIndicator = () => {
    return (
        <revealer
            revealChild={capsLockActive()}
            transitionType={Gtk.RevealerTransitionType.SLIDE_RIGHT}
        >
            <box spacing={4}>
                <image iconName="dialog-warning-symbolic" />
                <label label="CAPS" />
            </box>
        </revealer>
    );
};

export const LeftSection = () => (
    <box halign={Gtk.Align.START} spacing={8}>
        <CpuIndicator />
        <MemoryIndicator />
        <NetworkIndicator />
        <CapsIndicator />
    </box>
);
