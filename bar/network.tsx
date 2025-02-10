import { Variable, bind } from "astal";
import { Gtk } from "astal/gtk4";
import AstalNetwork from "gi://AstalNetwork";
import { CONFIG } from "../utils/config";
import { networkStats } from "../utils/system-stats";
import { LevelBadge } from "./badge-widgets";

const network = AstalNetwork.get_default();

const INTERNET_STATE_NAMES = {
    [AstalNetwork.Internet.CONNECTED]: "Connected",
    [AstalNetwork.Internet.CONNECTING]: "Connecting...",
    [AstalNetwork.Internet.DISCONNECTED]: "D/C",
};

// How much usage means maximum utilization. Used to generate the badge color. In bytes per second

function getTotalNetworkThroughput(stats?: { rx: number; tx: number }) {
    if (!stats) {
        return 0;
    } else {
        return stats.rx + stats.tx;
    }
}

function formatNetworkThroughput(value: number, unitIndex: number = 0) {
    // I don't think anyone has exabit internet yet
    const UNITS = ["B", "kB", "MB", "GB", "TB"];

    // never show in bytes, since it's one letter
    unitIndex += 1;
    value /= 1000;

    if (value < 10) {
        return `${value.toFixed(2)} ${UNITS[unitIndex]}/s`;
    } else if (value < 100) {
        return `${value.toFixed(1)} ${UNITS[unitIndex]}/s`;
    } else if (value < 1000) {
        return `${(value / 1000).toFixed(2)} ${UNITS[unitIndex + 1]}/s`;
    } else {
        // do not increase here since it's done at the start of the function
        return formatNetworkThroughput(value, unitIndex);
    }
}

type AnyNetwork = AstalNetwork.Wired | AstalNetwork.Wifi;

interface NetworkInterfaces {
    primary: AnyNetwork | null;
    other: AnyNetwork[];
}

const networkInterfaces = Variable.derive(
    [bind(network, "primary"), bind(network, "wired"), bind(network, "wifi")],
    (primaryType, wired, wifi): NetworkInterfaces => {
        console.log("Updating networkInterfaces");
        let primaryNetwork;
        if (primaryType == AstalNetwork.Primary.WIFI) {
            primaryNetwork = wifi ?? wired;
        } else {
            primaryNetwork = wired ?? wifi;
        }

        return {
            primary: primaryNetwork,
            other: [wired, wifi].filter((net) => net != primaryNetwork && net != null),
        };
    }
);

const NetworkUsage = ({ network, parenthesize }: { network: AnyNetwork; parenthesize: boolean }) => {
    return (
        <box>
            {bind(network, "device").as((device) => (
                <label
                    label={bind(networkStats).as((stats) => {
                        let result = formatNetworkThroughput(getTotalNetworkThroughput(stats[device.interface]));
                        if (parenthesize) {
                            result = ` (${result})`;
                        }
                        return result;
                    })}
                />
            ))}
        </box>
    );
};

function NetworkPart({ network, primary }: { network: AnyNetwork; primary: boolean }) {
    return (
        <box spacing={4}>
            <image iconName={bind(network, "icon_name")} />
            {bind(network, "internet").as((state) => {
                if (state == AstalNetwork.Internet.CONNECTED) {
                    return (
                        // use a box to remove the spacing
                        <box>
                            {network instanceof AstalNetwork.Wifi ? (
                                <label label={bind(network, "ssid").as((val) => val ?? "[null]")} />
                            ) : null}
                            {primary ? (
                                <NetworkUsage network={network} parenthesize={network instanceof AstalNetwork.Wifi} />
                            ) : null}
                        </box>
                    );
                } else if (state == AstalNetwork.Internet.CONNECTING) {
                    return network instanceof AstalNetwork.Wifi ? (
                        <label label={bind(network, "ssid").as((val) => val ?? "[null]")} />
                    ) : (
                        <label label={INTERNET_STATE_NAMES[state]} />
                    );
                } else {
                    return <label label={INTERNET_STATE_NAMES[state]} />;
                }
            })}
        </box>
    );
}

export const NetworkIndicator = () => {
    return (
        // TODO: Compute the level here.
        // This will be easier when nested bindings are merged, but alas :(
        <LevelBadge level={0}>
            <button cssClasses={["usage-badge"]} name="network-badge">
                {bind(networkInterfaces).as((networks) => (
                    <box spacing={8}>
                        {networks.primary ? <NetworkPart network={networks.primary} primary={true} /> : null}
                        {networks.other.map((net) => (
                            <>
                                <Gtk.Separator orientation={Gtk.Orientation.VERTICAL} />
                                <NetworkPart network={net} primary={false} />
                            </>
                        ))}
                    </box>
                ))}
            </button>
        </LevelBadge>
    );
};
