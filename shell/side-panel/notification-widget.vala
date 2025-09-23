class NotificationWidget : Gtk.Widget {
    private Gtk.Widget child;
    private Gtk.Builder builder;

    private NotificationProxy _proxy;
    public NotificationProxy proxy {
        get {
            return _proxy;
        }
        set {
            _proxy = value;
            print("setting proxy");
        }
    }

    construct {
        child = new Gtk.Button.with_label("test button");
        child.set_parent(this);
    }

    public override void dispose() {
        if (child != null) {
            child.unparent();
            child = null;
        }
    }


    public override Gtk.SizeRequestMode get_request_mode() {
        return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
    }

    public override void measure(Gtk.Orientation orientation, int for_size, out int minimum, out int natural, out int minimum_baseline, out int natural_baseline) {
        if (child == null) {
            minimum = 0;
            natural = 0;
            minimum_baseline = -1;
            natural_baseline = -1;
            return;
        }

        child.measure(orientation, for_size, out minimum, out natural, out minimum_baseline, out natural_baseline);
        print("notif measure: orient %s, for_size %d, min %d, nat %d\n", orientation.to_string(), for_size, minimum, natural);
        minimum_baseline = -1;
        natural_baseline = -1;
    }

    public override void size_allocate(int width, int height, int baseline) {
        child.allocate(width, height, baseline, null);
    }
}
