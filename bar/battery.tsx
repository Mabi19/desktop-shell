import { bind } from "astal";
import AstalBattery from "gi://AstalBattery?version=0.1";
import { LevelBadge } from "./badge-widgets";

const CHARGING_MESSAGES = [
    "Charging at {rate}\u202fW",
    "Charging at {rate}\u202fW",
    "Charging at {rate}\u202fW",
    "Charging at {rate}\u202fW",
    "Charging at {rate}\u202fW. Yummy!",
];

const DISCHARGING_MESSAGES = [
    "Using {rate}\u202fW",
    "Using {rate}\u202fW",
    "Using {rate}\u202fW",
    "Using {rate}\u202fW",
    "Using {rate}\u202fW",
    "Consuming {rate}\u202fW",
    "Consuming {rate}\u202fW",
    "Slurping up {rate}\u202fW",
    "Devouring {rate}\u202fW",
    "Feasting on {rate}\u202fW",
];

const chargeMessage = CHARGING_MESSAGES[Math.floor(Math.random() * CHARGING_MESSAGES.length)];
const dischargeMessage = DISCHARGING_MESSAGES[Math.floor(Math.random() * DISCHARGING_MESSAGES.length)];

function buildEnergyRateText(rate: number) {
    if (rate > 0) {
        return dischargeMessage.replace("{rate}", `${rate}`);
    } else {
        return chargeMessage.replace("{rate}", `${-rate}`);
    }
}

export function BatteryIndicator() {
    const battery = AstalBattery.get_default();
    return (
        <LevelBadge
            level={bind(battery, "percentage")}
            tooltipText={bind(battery, "energyRate").as(buildEnergyRateText)}
            visible={bind(battery, "isPresent")}
        >
            <box spacing={4} cssClasses={["usage-badge"]}>
                <image iconName={bind(battery, "batteryIconName")} />
                <label label={bind(battery, "percentage").as((value) => `${value * 100}%`)} />
            </box>
        </LevelBadge>
    );
}
