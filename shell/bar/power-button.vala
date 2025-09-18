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
        try {
            Pid pid;
            Process.spawn_async(null, {"systemctl", command}, null, SpawnFlags.SEARCH_PATH, null, out pid);
            Process.close_pid(pid);
        } catch (SpawnError e) {
            critical("Error spawning systemctl: %s", e.message);
        }
    }
}
