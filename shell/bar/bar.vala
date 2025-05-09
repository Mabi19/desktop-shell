[GtkTemplate (ui = "/land/mabi/shell/ui/bar/bar.ui")]
class Bar : Astal.Window {
    public Bar () {
        anchor = TOP | LEFT | RIGHT;
        exclusivity = EXCLUSIVE;
        present ();
    }
}
