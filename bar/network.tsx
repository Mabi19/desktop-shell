import { bind } from "astal";
import { Gtk } from "astal/gtk4";
import AstalNetwork from "gi://AstalNetwork";
import { networkStats } from "../utils/system-stats";
import { getUsageBadgeClass, mixUsageBadgeColor } from "../utils/usage-badge";

const network = AstalNetwork.get_default();

const primary = bind(network, "primary").as((id) => {
    if (id == AstalNetwork.Primary.WIRED || id == AstalNetwork.Primary.UNKNOWN) {
        return "wired";
    } else {
        return "wifi";
    }
});

const INTERNET_STATE_NAMES = {
    [AstalNetwork.Internet.CONNECTED]: "Connected",
    [AstalNetwork.Internet.CONNECTING]: "Connecting...",
    [AstalNetwork.Internet.DISCONNECTED]: "D/C",
};

// How much usage means maximum utilization. Used to generate the badge color. In bytes per second
const MAX_NETWORK_USAGE = 12_500_000;

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

const NetworkUsage = ({ iface }: { iface: string }) => {
    return (
        <label
            label={bind(networkStats).as(
                (stats) => `${formatNetworkThroughput(getTotalNetworkThroughput(stats[iface]))}`
            )}
        />
    );
};

const NetworkIndicatorWired = ({ iface }: { iface?: string }) => {
    const status = bind(network.wired, "internet").as((state) => {
        if (state == AstalNetwork.Internet.CONNECTED && iface) {
            return <NetworkUsage iface={iface} />;
        } else {
            return <label label={INTERNET_STATE_NAMES[state]} />;
        }
    });

    return (
        <box spacing={4}>
            <image iconName={bind(network.wired, "icon_name")} />
            {status}
        </box>
    );
};

const NetworkIndicatorWifi = ({ iface }: { iface?: string }) => {
    const status = bind(network.wifi, "internet").as((state) => {
        if (state == AstalNetwork.Internet.CONNECTED) {
            return (
                <>
                    <label label={bind(network.wifi, "ssid").as((val) => val ?? "[null]")} />
                    {iface ? <NetworkUsage iface={iface} /> : null}
                </>
            );
        } else if (state == AstalNetwork.Internet.CONNECTING) {
            return <label label={bind(network.wifi, "ssid").as((val) => val ?? "[null]")} />;
        } else {
            return <label label={INTERNET_STATE_NAMES[state]} />;
        }
    });

    return (
        <box spacing={4}>
            <image iconName={bind(network.wifi, "icon_name")} />
            {status}
        </box>
    );
};

export const NetworkIndicator = () => {
    // TODO: steal
    // And figure out what I want
    // This is a usage badge, so definitely display the speed
    // But also figure out how to cleanly display all the state
    // perhaps [network-wired] <SPEED or state, like D/C> | [network-wifi] <SSID>
    // first indicator would be the one that is primary
    // there are only two types of connection - ethernet and wifi - so no complex logic is required here
    // although if there is only one type of network interface, stuff might break here
    // show usage only for primary network interface

    return (
        //! This is a hack to allow getting the stats reactively
        <box>
            {primary.as((type) => (
                <box>
                    {bind(network[type], "device").as((device) => (
                        <box>
                            {bind(device, "interface").as((iface) => (
                                <button
                                    cssClasses={bind(networkStats).as((stats) => [
                                        "usage-badge",
                                        getUsageBadgeClass(
                                            getTotalNetworkThroughput(stats[iface]) /
                                                MAX_NETWORK_USAGE
                                        ),
                                    ])}
                                    name="network-badge"
                                >
                                    {type == "wired" ? (
                                        <box spacing={8}>
                                            <NetworkIndicatorWired iface={iface} />
                                            <Gtk.Separator orientation={Gtk.Orientation.VERTICAL} />
                                            <NetworkIndicatorWifi />
                                        </box>
                                    ) : (
                                        <box spacing={8}>
                                            <NetworkIndicatorWifi iface={iface} />
                                            <Gtk.Separator orientation={Gtk.Orientation.VERTICAL} />
                                            <NetworkIndicatorWired />
                                        </box>
                                    )}
                                </button>
                            ))}
                        </box>
                    ))}
                </box>
            ))}
        </box>
    );
};
