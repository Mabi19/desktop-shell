using AstalHyprland;

class WorkspaceBox : Gtk.Box {
    private WorkspaceService service;
    construct {
        service = WorkspaceService.get_default();
        this.set_name("workspaces");
    }
}
