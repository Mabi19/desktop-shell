class WifiNetwork : Object {
    public Bytes ssid { get; construct; }
    public string display_ssid { get; construct; }

    public uint8 best_strength { get; private set; default = 0; }
    public NM.AccessPoint? best_ap { get; private set; default = null; }
    public NM.RemoteConnection? connection { get; set; default = null; }

    private Gee.ArrayList<NM.AccessPoint> _access_points;

    public int ap_count {
        get { return _access_points.size; }
    }

    construct {
        _access_points = new Gee.ArrayList<NM.AccessPoint>();
    }

    public WifiNetwork(Bytes ssid) {
        Object(ssid: ssid, display_ssid: NM.Utils.ssid_to_utf8(ssid.get_data()));
    }

    public void add_ap(NM.AccessPoint ap) {
        _access_points.add(ap);
        ap.notify["strength"].connect(on_ap_strength_changed);
        update_best();
    }

    public void remove_ap(NM.AccessPoint ap) {
        ap.notify["strength"].disconnect(on_ap_strength_changed);
        _access_points.remove(ap);
        update_best();
    }

    private void on_ap_strength_changed() {
        update_best();
    }

    private void update_best() {
        NM.AccessPoint? best = null;
        uint8 best_str = 0;
        foreach (var ap in _access_points) {
            if (ap.strength > best_str) {
                best_str = ap.strength;
                best = ap;
            }
        }
        best_strength = best_str;
        best_ap = best;
    }
}
