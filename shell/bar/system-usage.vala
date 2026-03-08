[GtkTemplate(ui = "/land/mabi/shell/ui/bar/cpu-indicator.ui")]
class CpuIndicator : LevelBin {
    internal SystemUsageService service { get; private set; }

    construct {
        service = SystemUsageService.get_default();
    }

    public override void dispose() {
        dispose_template(typeof(CpuIndicator));
        base.dispose();
    }

    [GtkCallback]
    string format_percentage(double value) {
        var percent = Math.round(value * 100);
        return @"$percent%";
    }
}

[GtkTemplate(ui = "/land/mabi/shell/ui/bar/memory-indicator.ui")]
class MemoryIndicator : LevelBin {
    internal SystemUsageService service { get; private set; }

    construct {
        service = SystemUsageService.get_default();
        service.notify["memory"].connect(update_tooltip);
        update_tooltip();
    }

    public override void dispose() {
        dispose_template(typeof(MemoryIndicator));
        base.dispose();
    }

    [GtkCallback]
    string format_percentage(double value) {
        var percent = Math.round(value * 100);
        return @"$percent%";
    }

    void update_tooltip() {
        tooltip_text = format_memory_usage(service.memory_total_kib, service.memory_available_kib);
    }

    string format_memory_usage(int64 total_kib, int64 available_kib) {

        var used_gib = format_gib(total_kib - available_kib);
        var total_gib = format_gib(total_kib);
        return @"$used_gib / $total_gib GiB used";
    }

    string format_gib(int64 kib) {
        var gib = kib / 1024.0 / 1024.0;
        var text = "%.1f".printf(gib);
        return text;
    }
}
