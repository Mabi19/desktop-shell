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
        // the monitor never changes: a workspace widget stays on its bar
        // when it moves, a new workspace widget is created
        monitor.notify["active-workspace"].connect(update_active);
        workspace.notify["monitor"].connect(update_monitor_flag);
        update_active();
        update_monitor_flag();

        var drag_source = new Gtk.DragSource();
        var wrapped_id = new Bytes(workspace.id.to_string().data);
        drag_source.set_content(new Gdk.ContentProvider.for_bytes("application/x.mabi-workspace", wrapped_id));
        drag_source.drag_begin.connect((source, drag) => {
            add_css_class("dragging");
            source.set_icon(new Gtk.WidgetPaintable(this), 0, 0);
        });
        drag_source.drag_end.connect(() => remove_css_class("dragging"));
        add_controller(drag_source);
    }

    private void update_active() {
        var is_active = monitor.active_workspace.id == workspace.id;
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
        if (workspace.id > 0) {
            workspace.focus();
        }
    }

    [GtkCallback]
    string format_workspace_id(int workspace_id) {
        return workspace_id < 0 ? "S" : workspace_id.to_string();
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

    private bool handle_scroll(Gtk.EventControllerScroll _self, double _dx, double dy) {
        var workspaces_on_monitor = new Gee.ArrayList<Workspace>();
        int active_index = -1;
        for (int i = 0; i < service.workspaces.get_n_items(); i++) {
            var ws = (Workspace)service.workspaces.get_item(i);
            if (ws.monitor.id == hyprmonitor.id) {
                if (hyprmonitor.active_workspace.id == ws.id) {
                    active_index = workspaces_on_monitor.size;
                }
                workspaces_on_monitor.add(ws);
            }
        }
        assert(active_index != -1);
        int adjusted_index = active_index + (int)dy;
        if (adjusted_index < 0 || adjusted_index >= workspaces_on_monitor.size) {
            return false;
        }
        var workspace = workspaces_on_monitor[adjusted_index];
        // Do not enable special workspaces
        if (workspace.id < 0) {
            return false;
        }
        workspace.focus();

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
            if (bytes_read >= 16) {
                warning("Workspace drag'n'drop payload too long");
                return;
            }
            var workspace_id = int.parse((string)buffer);
            service.hyprland.dispatch("moveworkspacetomonitor", @"$workspace_id $(hyprmonitor.id)");
        } catch (Error e) {
            warning("Workspace drag'n'drop failed: %s\n", e.message);
        }
    }
}
