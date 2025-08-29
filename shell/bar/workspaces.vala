using AstalHyprland;

[GtkTemplate(ui = "/land/mabi/shell/ui/bar/workspace-button.ui")]
class WorkspaceButton : Adw.Bin {
    public Workspace workspace { get; construct; }
    public Monitor monitor { get; construct; }
    internal bool is_on_this_monitor { get; private set; }

    public WorkspaceButton(Workspace workspace, Monitor monitor) {
        Object(workspace: workspace, monitor: monitor);
    }

    construct {
        print("construct WorkspaceButton\n");
        // the monitor never changes: a workspace widget stays on its bar
        // when it moves, a new workspace widget is created
        monitor.notify["active-workspace"].connect(update_active);
        workspace.notify["monitor"].connect(update_monitor_flag);
        update_active();
        update_monitor_flag();
    }

    private void update_active() {
        bool is_active = monitor.active_workspace.id == workspace.id;
        if (is_active) {
            add_css_class("active");
        } else {
            remove_css_class("active");
        }
    }

    private void update_monitor_flag() {
        is_on_this_monitor = workspace.monitor.id == monitor.id;
    }

    [GtkCallback]
    void handle_click() {
        workspace.focus();
    }

    [GtkCallback]
    string format_workspace_id(int workspace_id) {
        return workspace_id.to_string();
    }
}

class WorkspaceBox : Gtk.Box {
    private WorkspaceService service;
    private Monitor hyprmonitor;
    private ulong monitor_match_conn_id = 0;
    private Gee.ArrayList<WorkspaceButton> widgets;
    public Gdk.Monitor gdkmonitor { get; set; }

    construct {
        this.set_name("workspaces");
        this.add_css_class("icon-view-box");
        service = WorkspaceService.get_default();
        widgets = new Gee.ArrayList<WorkspaceButton>();

        match_monitors();
        notify["gdkmonitor"].connect(() => {
            match_monitors();
        });
    }

    private void match_monitors() {
        if (gdkmonitor == null) {
            return;
        }

        if (monitor_match_conn_id > 0) {
            service.hyprland.disconnect(monitor_match_conn_id);
            monitor_match_conn_id = 0;
        }
        if (!try_get_hyprmonitor()) {
            assert(monitor_match_conn_id == 0);
            monitor_match_conn_id = service.hyprland.notify["monitors"].connect(() => {
                print("hyprland monitors updated\n");
                if (try_get_hyprmonitor()) {
                    service.hyprland.disconnect(monitor_match_conn_id);
                    monitor_match_conn_id = 0;
                }
            });
        } else {
            init_workspaces();
        }
    }

    private bool try_get_hyprmonitor() {
        var result = service.hyprland.get_monitor_by_name(gdkmonitor.get_connector());
        if (result != null) {
            hyprmonitor = result;
            return true;
        } else {
            return false;
        }
    }

    private void init_workspaces() {
        Workspace? workspace = null;
        int i = 0;
        while ((workspace = (Workspace?)service.workspaces.get_item(i)) != null) {
            var button = new WorkspaceButton(workspace, hyprmonitor);
            this.append(button);
            widgets.add(button);
            i++;
        }
        service.workspaces.items_changed.connect((position, removed, added) => {
            print("workspaces changed: pos = %u, -%u, +%u\n", position, removed, added);
            for (uint j = position; j < position + removed; j++) {
                // removing shifts all the further elements back,
                // so removeat position removed times
                this.remove(widgets[(int)position]);
                widgets.remove_at((int)position);
            }

            // the widget that was originally one before position
            var anchor_widget = position == 0 ? null : widgets[(int)position - 1];
            for (uint j = position; j < position + added; j++) {
                var new_ws = (Workspace)service.workspaces.get_item(j);
                var new_button = new WorkspaceButton(new_ws, hyprmonitor);
                this.insert_child_after(new_button, anchor_widget);
                widgets.insert((int)j, new_button);
                anchor_widget = new_button;
            }

            print("state of widgets afterwards:\n");
            foreach (var widget in widgets) {
                print("%d ", widget.workspace.id);
            }
            print("\n");
        });
    }
}
