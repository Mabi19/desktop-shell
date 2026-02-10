[GtkTemplate(ui = "/land/mabi/shell/ui/bar/battery.ui")]
class BatteryIndicator : LevelBin {
    internal AstalBattery.Device device { get; private set; }

    static construct {
        typeof(AstalBattery.Device).ensure();
    }

    construct {
        device = AstalBattery.get_default();
        device.bind_property("is-present", this, "visible", BindingFlags.SYNC_CREATE, null, null);

        device.notify["energy-rate"].connect(update_tooltip);
        device.notify["state"].connect(update_tooltip);
        update_tooltip();
    }

    public override void dispose() {
        dispose_template(typeof(BatteryIndicator));
        base.dispose();
    }

    [GtkCallback]
    string format_percentage(double value) {
        var percent = Math.round(value * 100);
        return @"$percent%";
    }

    void update_tooltip() {
        tooltip_text = format_usage(device.state, device.energy_rate);
    }

    string format_usage(AstalBattery.State state, double usage) {
        var rate = "%.1f".printf(usage.abs());
        if (rate.has_suffix("0")) {
            rate = rate[0 : -2];
        }

        switch ((AstalBattery.State)state) {
        case CHARGING:
            return @"Charging at $rate\u202fW";
        case DISCHARGING:
            return @"Using $rate\u202fW";
        case EMPTY:
            return "Empty";
        case FULLY_CHARGED:
            return "Fully charged";
        case PENDING_CHARGE:
            return "Pending charge";
        case PENDING_DISCHARGE:
            return "Pending discharge";
        case UNKNOWN:
            return "Unknown";
        }
        return "Unknown";
    }
}
