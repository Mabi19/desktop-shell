[GtkTemplate(ui = "/land/mabi/shell/ui/bar/bar.ui")]
class Bar : Astal.Window {
    internal Config config { get; private set; }
    internal int outer_margin { get; private set; }

    static construct {
        typeof(CpuIndicator).ensure();
        typeof(MemoryIndicator).ensure();
        typeof(ConnectivityIndicator).ensure();
        typeof(BluetoothIndicator).ensure();
        typeof(IdleInhibitIndicator).ensure();
        typeof(WorkspaceBox).ensure();
        typeof(PowerButton).ensure();
        typeof(TimeButton).ensure();
        typeof(AudioButton).ensure();
        typeof(BatteryIndicator).ensure();
        typeof(TrayBox).ensure();
    }

    public Bar(Gdk.Monitor monitor) {
        Object(gdkmonitor: monitor);
    }

    construct {
        anchor = TOP | LEFT | RIGHT;
        config = MabiShell.config;
        update_style();
        config.notify["bar-style"].connect(this.update_style);
    }

    public override void dispose() {
        dispose_template(typeof(Bar));
        base.dispose();
    }

    private void update_style() {
        if (config.bar_style == BarStyle.FLOATING) {
            this.add_css_class("floating");
            outer_margin = 4;
        } else {
            this.remove_css_class("floating");
            outer_margin = 0;
        }
    }
}
