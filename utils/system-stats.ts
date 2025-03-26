import { interval, Variable } from "astal";
import { readFileAsync } from "astal/file";

const UPDATE_INTERVAL = 2000;

export const cpuUsage = Variable(0);

export const memoryAvailable = Variable(0);
export const memoryTotal = Variable(0);
export const memoryUsage = Variable(0);

/// A device name -> total network received / transmitted bytes per second
type NetworkStats = Record<string, { rx: number; tx: number }>;
export const networkStats = Variable<NetworkStats>({});

let lastCpuInfo: { idle: number; total: number } | null = null;
async function recalculateCpuUsage() {
    const statFile = await readFileAsync("/proc/stat");
    console.assert(statFile.startsWith("cpu "), "couldn't parse /proc/stat");
    const cpuLine = statFile.slice(4, statFile.indexOf("\n")).trim();
    const stats = cpuLine.split(" ").map((part) => parseInt(part));
    // idle and iowait
    const idle = stats[3] + stats[4];
    const total = stats.reduce((subtotal, curr) => subtotal + curr, 0);

    if (lastCpuInfo != null) {
        const deltaIdle = idle - lastCpuInfo.idle;
        const deltaTotal = total - lastCpuInfo.total;
        cpuUsage.set(1 - deltaIdle / deltaTotal);
    }

    lastCpuInfo = { idle, total };
}

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
        console.assert(rest.endsWith("kB"), "memory stat has unexpected unit " + rest);
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

let lastNetworkInfo: Record<string, { rx: number; tx: number }> | null = null;
async function recalculateNetworkUsage() {
    const netFile = await readFileAsync("/proc/net/dev");
    const lines = netFile.split("\n").slice(1, -1);
    const [rxLabels, txLabels] = lines[0]
        .split("|")
        .slice(1)
        .map((str) => str.trim().split(/\W+/));

    const rxBytesIdx = rxLabels.indexOf("bytes");
    const txBytesIdx = rxLabels.length + txLabels.indexOf("bytes");

    const rawStats = lines.slice(1).map((line) => line.trim().split(/\W+/));
    const networkInfo: Record<string, { rx: number; tx: number }> = {};
    for (const data of rawStats) {
        networkInfo[data[0]] = {
            rx: parseInt(data[rxBytesIdx + 1]),
            tx: parseInt(data[txBytesIdx + 1]),
        };
    }

    if (lastNetworkInfo != null) {
        const newNetStats: NetworkStats = {};
        for (const [device, { rx, tx }] of Object.entries(networkInfo)) {
            const lastDeviceInfo = lastNetworkInfo[device];
            if (!lastDeviceInfo) {
                // device is newly connected, delay
                lastNetworkInfo = networkInfo;
                return;
            }

            // we need bytes per second
            newNetStats[device] = {
                rx: (rx - lastDeviceInfo.rx) / (UPDATE_INTERVAL / 1000),
                tx: (tx - lastDeviceInfo.tx) / (UPDATE_INTERVAL / 1000),
            };
        }
        networkStats.set(newNetStats);
    }

    lastNetworkInfo = networkInfo;
}

interval(UPDATE_INTERVAL, () => {
    recalculateCpuUsage();
    recalculateMemoryUsage();
    recalculateNetworkUsage();
});
