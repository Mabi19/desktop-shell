[GtkTemplate(ui = "/land/mabi/shell/ui/bar/power-button.ui")]
class PowerButton : Adw.Bin {
    construct {
        ActionEntry powermenu_entries[] = {
            {"suspend", () => this.exec_systemctl("suspend")},
            {"hibernate", () => this.exec_systemctl("hibernate")},
            {"shutdown", () => this.exec_systemctl("shutdown")},
            {"reboot", () => this.exec_systemctl("reboot")},
        };
        var action_group = new SimpleActionGroup();
        action_group.add_action_entries(powermenu_entries, this);

        this.insert_action_group("powermenu", action_group);
    }

    private void exec_systemctl(string command) {
        AstalIO.Process.exec_asyncv.begin({"systemctl", command}, (obj, res) => {
            try {
                AstalIO.Process.exec_asyncv.end(res);
            } catch (Error e) {
                critical("Couldn't spawn systemctl process: %s", e.message);
            }
        });
    }
}
