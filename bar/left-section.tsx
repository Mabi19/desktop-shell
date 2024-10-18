import { Variable, readFileAsync } from "astal";
import { Gdk, Gtk } from "astal/gtk3";

interface CpuStats {
    idle: number;
    total: number;
}

const cpu = Variable(0);
let lastStats: CpuStats | null = null;
async function recalculateCpuUsage() {
    const statFile = await readFileAsync("/proc/stat");
    console.assert(statFile.startsWith("cpu "), "couldn't parse /proc/stat");
    const cpuLine = statFile.slice(4, statFile.indexOf("\n")).trim();
    const stats = cpuLine.split(" ").map((part) => parseInt(part));
    // idle and iowait
    const idle = stats[3] + stats[4];
    const total = stats.reduce((subtotal, curr) => subtotal + curr, 0);

    if (lastStats != null) {
        const deltaIdle = idle - lastStats.idle;
        const deltaTotal = total - lastStats.total;
        cpu.set(1 - deltaIdle / deltaTotal);
    }

    lastStats = { idle, total };
}

const memoryAvailable = Variable(0);
const memoryTotal = Variable(0);
const memoryUsage = Variable(0);
const memoryTooltip = Variable.derive(
    [memoryAvailable, memoryTotal],
    (available, total) => `${((total - available) / 1024 / 1024).toFixed(1)} GiB used`
);
async function recalculateMemoryUsage() {
    const meminfo = await readFileAsync("/proc/meminfo");
    let total = null;
    let available = null;
    for (const line of meminfo.split("\n")) {
        if (!line) continue;

        if (total && available) {
            // we have everything
            break;
        }

        let [label, rest] = line.split(":");
        rest = rest.trim();
        console.assert(rest.endsWith("kB"), "memory stat has unexpected unit");
        rest = rest.slice(0, -3);
        const amount = parseInt(rest);

        if (label == "MemTotal") {
            total = amount;
        } else if (label == "MemAvailable") {
            available = amount;
        }
    }

    if (!total || !available) {
        console.error("couldn't parse /proc/meminfo");
        return;
    }

    memoryAvailable.set(available);
    memoryTotal.set(total);
    memoryUsage.set(1 - available / total);
}

setInterval(() => {
    recalculateCpuUsage();
    recalculateMemoryUsage();
}, 2000);

function mixUsageBadgeColor(usagePercent: number) {
    usagePercent = Math.pow(usagePercent, 0.75);

    const min = [192, 99, 201];
    const max = [134, 67, 181];
    const mixed = [0, 0, 0];
    for (let i = 0; i < 3; i++) {
        mixed[i] = Math.round(min[i] * (1 - usagePercent) + max[i] * usagePercent);
    }

    return `rgb(${mixed[0]}, ${mixed[1]}, ${mixed[2]})`;
}

const CpuIndicator = () => {
    return (
        <label
            label={cpu((usage) => `\uf2db ${Math.floor(usage * 100)}%`)}
            className="usage-badge"
            css={cpu((usage) => `background-color: ${mixUsageBadgeColor(usage)}`)}
        />
    );
};

const MemoryIndicator = () => {
    return (
        <label
            label={memoryUsage((usage) => `\uf538 ${Math.floor(usage * 100)}%`)}
            tooltipText={memoryTooltip()}
            className="usage-badge"
            css={memoryUsage((usage) => `background-color: ${mixUsageBadgeColor(usage)}`)}
        />
    );
};

const CapsIndicator = () => {
    const capsLockActive = Variable(true);

    const label = (
        <label
            label={"\uf071 CAPS"}
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

export const LeftSection = ({ monitor }: { monitor: number }) => (
    <box halign={Gtk.Align.START} spacing={8}>
        <CpuIndicator />
        <MemoryIndicator />
        <CapsIndicator />
    </box>
);
