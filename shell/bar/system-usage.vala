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
