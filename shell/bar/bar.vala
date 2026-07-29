class Bar : Astal.Window {
    internal Config config { get; private set; }

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

        config = MabiShell.config;

        layer = TOP;
        exclusivity = EXCLUSIVE;
        @namespace = "bar";
        anchor = TOP | LEFT | RIGHT;

        add_css_class("bar");
        update_style();
        config.notify["bar-style"].connect(this.update_style);

        var cbox = new Gtk.CenterBox();
        var start = new Gtk.Box(HORIZONTAL, 6);
        start.append(new CpuIndicator());
        start.append(new MemoryIndicator());
        start.append(new ConnectivityIndicator());
        start.append(new BluetoothIndicator());
        start.append(new IdleInhibitIndicator());
        cbox.set_start_widget(start);

        var workspaces = new WorkspaceBox(gdkmonitor);
        cbox.set_center_widget(workspaces);

        var end = new Gtk.Box(HORIZONTAL, 6);
        end.append(new TrayBox());
        end.append(new BatteryIndicator());
        end.append(new AudioButton());
        end.append(new TimeButton(gdkmonitor));
        end.append(new PowerButton());
        cbox.set_end_widget(end);

        set_child(cbox);
    }

    private void update_style() {
        int outer_margin;
        if (config.bar_style == BarStyle.FLOATING) {
            this.add_css_class("floating");
            outer_margin = 4;
        } else {
            this.remove_css_class("floating");
            outer_margin = 0;
        }
        margin_top = outer_margin;
        margin_left = outer_margin;
        margin_right = outer_margin;
    }
}
