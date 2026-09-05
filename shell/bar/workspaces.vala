using AstalWorkspace;

[GtkTemplate(ui = "/land/mabi/shell/ui/bar/workspace-button.ui")]
class WorkspaceButton : Adw.Bin {
    public Workspace workspace { get; construct; }

    public WorkspaceButton(Workspace workspace) {
        Object(workspace: workspace);
    }

    construct {
        update_state();
        workspace.notify["state"].connect(update_state);

        var drag_source = new Gtk.DragSource();
        var wrapped_id = new Bytes(workspace.name.to_string().data);
        drag_source.set_content(new Gdk.ContentProvider.for_bytes("application/x.mabi-workspace", wrapped_id));
        drag_source.drag_begin.connect((source, drag) => {
            add_css_class("dragging");
            source.set_icon(new Gtk.WidgetPaintable(this), 0, 0);
        });
        drag_source.drag_end.connect(() => remove_css_class("dragging"));
        add_controller(drag_source);
    }

    public override void dispose() {
        dispose_template(typeof(WorkspaceButton));
        base.dispose();
    }

    private void update_state() {
        // TODO: urgency?

        visible = (workspace.state & WorkspaceState.HIDDEN) == 0;

        if ((workspace.state & WorkspaceState.ACTIVE) != 0) {
            add_css_class("active");
        } else {
            remove_css_class("active");
        }
    }

    [GtkCallback]
    void handle_click() {
        if ((workspace.state & WorkspaceState.ACTIVE) == 0) {
            workspace.activate();
        }
    }
}

class WorkspaceBox : Gtk.Box {
    private WorkspaceManager manager;
    private WorkspaceMonitorView workspaces;
    private Gtk.SortListModel sorted_ws;
    // The SortListModel always returns G_TYPE_OBJECT and not the original type for some reason.
    private ModelBoxBinding<Object> workspace_binding;
    public Gdk.Monitor gdkmonitor { get; construct; }

    public WorkspaceBox(Gdk.Monitor gdkmonitor) {
        Object(gdkmonitor: gdkmonitor);
    }

    construct {
        this.name = "workspaces";
        this.spacing = 4;
        this.add_css_class("icon-view-box");

        var scroll_controller = new Gtk.EventControllerScroll(Gtk.EventControllerScrollFlags.DISCRETE | Gtk.EventControllerScrollFlags.VERTICAL);
        scroll_controller.scroll.connect(this.handle_scroll);
        add_controller(scroll_controller);

        var drop_target = new Gtk.DropTargetAsync(new Gdk.ContentFormats({"application/x.mabi-workspace"}), Gdk.DragAction.COPY);
        drop_target.drop.connect((drop) => {
            handle_drop.begin(drop, (obj, res) => {
                handle_drop.end(res);
            });
            return true;
        });
        add_controller(drop_target);

        manager = AstalWorkspace.get_default();
        AstalWl4.get_wl_output.begin(gdkmonitor, bind_workspaces_finish);
    }

    private void bind_workspaces_finish(Object? o, AsyncResult? res) {
        workspaces = manager.for_output(AstalWl4.get_wl_output.end(res));

        var sorter = new Gtk.StringSorter(new Gtk.PropertyExpression(typeof(Workspace), null, "name"));
        sorter.collation = NONE;
        sorted_ws = new Gtk.SortListModel(workspaces, sorter);

        workspace_binding = new ModelBoxBinding<Object>(this, sorted_ws, create_workspace_button);
    }

    private static Gtk.Widget create_workspace_button(Object obj) {
        var workspace = (Workspace)obj;
        return new WorkspaceButton(workspace);
    }

    private bool handle_scroll(Gtk.EventControllerScroll? _self, double _dx, double dy) {
        print("handle_scroll called %f\n", dy);
        int active_index = -1;
        var count = sorted_ws.get_n_items();
        for (int i = 0; i < count; i++) {
            var ws = (Workspace)sorted_ws.get_item(i);
            if ((ws.state & WorkspaceState.ACTIVE) != 0) {
                active_index = i;
            }
        }
        if (active_index == -1) return false;
        int adjusted_index = active_index + (int)dy;
        if (adjusted_index < 0 || adjusted_index >= count) {
            return false;
        }

        var workspace = (Workspace)sorted_ws.get_item(adjusted_index);
        print("found scrolled workspace with name %s\n", workspace.name);
        // This makes some scroll events wait until something else happens for some reason??
        workspace.activate();

        // Manually calling hyprctl like this makes it work properly.
        //  try {
        //      Process.spawn_command_line_sync(@"hyprctl dispatch workspace $(workspace.name)", null, null, null);
        //  } catch (SpawnError e) {
        //      critical("SpawnError: %s", e.message);
        //  }

        return true;

    }

    private async void handle_drop(Gdk.Drop drop) {
        try {
            var stream = yield drop.read_async({"application/x.mabi-workspace"}, Priority.DEFAULT, null, null);
            uint8 buffer[16];
            size_t bytes_read;
            yield stream.read_all_async(buffer, Priority.DEFAULT, null, out bytes_read);
            drop.finish(Gdk.DragAction.COPY);
            // If the buffer fills exactly, there won't be a null terminator
            if (bytes_read >= buffer.length) {
                warning("Workspace drag'n'drop payload too long");
                return;
            }
            // TODO: transmit pointer instead of name?
            // Transmitting names means that on compositors with non-unique names, this is ambiguous.
            // But transmitting pointers is pointless to processes outside.
            // But no one other than this cares about application/x.mabi-workspace anyway.
            var workspace_name = (string)buffer;
            if (workspaces.groups.length == 0) {
                warning("Workspace drag'n'drop couldn't find workspace group to assign to");
                return;
            }
            foreach (var ws in AstalWorkspace.get_default().workspaces) {
                if (ws.name == workspace_name) {
                    ws.assign_to_group(workspaces.groups[0]);
                    return;
                }
            }
            warning("Workspace drag'n'drop couldn't find dropped workspace");
        } catch (Error e) {
            warning("Workspace drag'n'drop failed: %s\n", e.message);
        }
    }
}
