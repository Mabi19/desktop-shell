using AstalHyprland;

// A class that provides workspace tracking functionality.
class WorkspaceService : Object {
    private static WorkspaceService instance;
    public static WorkspaceService get_default() {
        if (instance == null) {
            debug("initializing WorkspaceService");
            instance = new WorkspaceService();
        }
        return instance;
    }

    public Hyprland hyprland;
    public ListStore workspaces;

    construct {
        hyprland = Hyprland.get_default();
        workspaces = new ListStore(typeof(Workspace));
        foreach (var workspace in hyprland.workspaces) {
            insert_workspace(workspace);
        }

        hyprland.workspace_added.connect(insert_workspace);
        hyprland.workspace_removed.connect(remove_workspace);
    }

    private void insert_workspace(Workspace workspace) {
        print("insert_workspace %p\n", workspace);
        workspaces.insert_sorted(workspace, (a, b) => {
            return ((Workspace)a).id - ((Workspace)b).id;
        });
    }

    private void remove_workspace(int id) {
        Workspace? workspace = null;
        int i = 0;
        while ((workspace = (Workspace?)workspaces.get_item(i)) != null) {
            if (workspace.id == id) {
                workspaces.remove(i);
                break;
            }
            i++;
        }
    }
}
