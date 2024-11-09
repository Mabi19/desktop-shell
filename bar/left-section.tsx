import { Variable } from "astal";
import { Gdk, Gtk } from "astal/gtk3";
import { cpuUsage, memoryAvailable, memoryTotal, memoryUsage } from "../utils/system-stats";
import { mixUsageBadgeColor } from "../utils/usage-badge";
import { NetworkIndicator } from "./network";

const memoryTooltip = Variable.derive(
    [memoryAvailable, memoryTotal],
    (available, total) => `${((total - available) / 1024 / 1024).toFixed(1)} GiB used`
);

const CpuIndicator = () => {
    return (
        <box
            name="cpu-badge"
            className="usage-badge"
            css={cpuUsage((usage) => `background-color: ${mixUsageBadgeColor(usage)}`)}
            spacing={4}
        >
            <icon icon="fa-microchip-symbolic" />
            <label label={cpuUsage((usage) => `${Math.floor(usage * 100)}%`)} />
        </box>
    );
};

const MemoryIndicator = () => {
    return (
        <box
            name="cpu-badge"
            tooltipText={memoryTooltip()}
            className="usage-badge"
            css={memoryUsage((usage) => `background-color: ${mixUsageBadgeColor(usage)}`)}
            spacing={4}
        >
            <icon icon="fa-memory-symbolic" />
            <label label={memoryUsage((usage) => `${Math.floor(usage * 100)}%`)} />
        </box>
    );
};

// TODO: rework to use the Hyprland interface once 0.45 comes out
const CapsIndicator = () => {
    const capsLockActive = Variable(true);

    const label = (
        <label
            label={"[!] CAPS"}
            visible={capsLockActive()}
            onDestroy={() => capsLockActive.drop()}
        />
    );

    // This doesn't work :(
    // The get_caps_lock_state function seems to always return false.
    label.connect("realize", () => {
        const keymap = Gdk.Keymap.get_for_display(label.get_display());
        capsLockActive.set(keymap.get_caps_lock_state());
        capsLockActive.observe(keymap, "state-changed", () => keymap.get_caps_lock_state());
    });

    return label;
};

export const LeftSection = () => (
    <box halign={Gtk.Align.START} spacing={8}>
        <CpuIndicator />
        <MemoryIndicator />
        <NetworkIndicator />
        <CapsIndicator />
    </box>
);
