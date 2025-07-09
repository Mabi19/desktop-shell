using AstalHyprland;

class WorkspaceService : Object {
    private static WorkspaceService instance;
    public static WorkspaceService get_default() {
        if (instance == null) {
            debug("initializing WorkspaceService");
            instance = new WorkspaceService();
        }
        return instance;
    }

    internal Hyprland hyprland;
    public Gee.HashMap<Monitor, ListModel> workspaces;

    construct {
        hyprland = Hyprland.get_default();
        workspaces = new Gee.HashMap<Monitor, ListModel>();
        foreach (var monitor in hyprland.monitors) {
            workspaces.set(monitor, make_workspace_list(monitor));
        }

        hyprland.monitor_added.connect((monitor) => {
            workspaces.set(monitor, make_workspace_list(monitor));
        });

        hyprland.monitor_removed.connect((id) => {
            Monitor? removed = null;
            foreach (var mon in workspaces.keys) {
                if (mon.id == id) {
                    removed = mon;
                }
            }
            if (removed == null) {
                warning("Removed monitor %d was not tracked", id);
            }
            workspaces.unset(removed);
        });

        hyprland.workspace_added.connect((workspace) => {
            print("workspace added: %d on monitor: %d\n", workspace.id, workspace.monitor.id);
            workspace.notify["monitor"].connect(() => workspace_monitor_changed(workspace));
        });

        hyprland.workspace_removed.connect((id) => {
            print("workspace removed: %d\n", id);
        });
    }

    private void workspace_monitor_changed(Workspace workspace) {
        print("workspace: %d monitor changed: %d\n", workspace.id, workspace.monitor.id);
    }

    private ListStore make_workspace_list(Monitor monitor) {
        var result = new ListStore(typeof(Workspace));
        foreach (var workspace in hyprland.workspaces) {
            if (workspace.monitor == monitor) {
                print("workspace initial: %d on monitor: %d\n", workspace.id, workspace.monitor.id);
                workspace.notify["monitor"].connect(() => workspace_monitor_changed(workspace));
                result.insert_sorted(workspace, (a, b) => {
                    return ((Workspace)a).id - ((Workspace)b).id;
                });
                result.append(workspace);
            }
        }
        return result;
    }
}
