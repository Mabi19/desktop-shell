import { bind, Binding, Variable } from "astal";
import { Astal, Gdk, Gtk, Widget } from "astal/gtk4";
import AstalHyprland from "gi://AstalHyprland";

const hyprland = AstalHyprland.get_default();

const DRAG_DATA = {
    modifier: Gdk.ModifierType.BUTTON1_MASK,
    entries: [Gtk.TargetEntry.new("x-mabi-desktop-shell/workspace", 0, 0)],
    action: Gdk.DragAction.COPY,
    atom: Gdk.atom_intern("x-mabi-desktop-shell/workspace", false),
};
/** This is used to enable input on the bar when dragging. */
export const isDraggingWorkspace = Variable(false);

export const WorkspaceButton = ({
    active,
    workspace,
}: {
    active: Binding<number | null>;
    workspace: AstalHyprland.Workspace;
}) => {
    function clickHandler() {
        if (workspace.id != active.get()) {
            hyprland.dispatch("workspace", workspace.id.toString());
        }
    }

    // TODO: add dragging visuals (lower opacity when dragging, perhaps figure out how the dnd tooltip works)
    return (
        <button
            className={active.as((activeId) =>
                activeId == workspace.id ? "workspace active" : "workspace"
            )}
            onClickRelease={clickHandler}
            name={`workspace-${workspace.id}`}
            setup={(self) => {
                self.drag_source_set(DRAG_DATA.modifier, DRAG_DATA.entries, DRAG_DATA.action);
            }}
            onDragDataGet={(_self, _ctx: Gdk.DragContext, data: Gtk.SelectionData) => {
                data.set(DRAG_DATA.atom, 8, new Uint8Array([workspace.id]));
            }}
            onDragBegin={() => {
                isDraggingWorkspace.set(true);
            }}
            onDragEnd={() => {
                isDraggingWorkspace.set(false);
            }}
        >
            <label label={workspace.id.toString()} valign={Gtk.Align.CENTER} />
        </button>
    );
};

export const Workspaces = ({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) => {
    // TODO: check for the reshuffling bug if it happens again
    // TODO(gtk4): Use Gdk.Monitor.connector instead
    const hyprlandMonitor = hyprland.get_monitors().find((mon) => mon.model == gdkmonitor.model);
    if (!hyprlandMonitor) {
        throw new Error("Couldn't find matching Hyprland monitor");
    }

    const activeWorkspace = Variable<number | null>(hyprlandMonitor.active_workspace?.id);

    let buttons: Widget.Box | null = (
        <box
            name="workspaces"
            spacing={4}
            onDestroy={() => activeWorkspace.drop()}
            setup={(self) => {
                self.drag_dest_set(Gtk.DestDefaults.ALL, DRAG_DATA.entries, DRAG_DATA.action);
            }}
            onDragDataReceived={(
                self,
                _ctx: Gdk.DragContext,
                _x: number,
                _y: number,
                data: Gtk.SelectionData
            ) => {
                if (data.get_data_type() == DRAG_DATA.atom) {
                    const movedWorkspaceId = data.get_data()[0];
                    // do not move if on the same monitor
                    const isOnDifferentMonitor = !buttons
                        ?.get_children()
                        ?.find((btn) => btn.name == `workspace-${movedWorkspaceId}`);
                    if (isOnDifferentMonitor) {
                        hyprland.dispatch(
                            "moveworkspacetomonitor",
                            `${movedWorkspaceId} ${hyprlandMonitor.id}`
                        );
                    }
                }
            }}
        >
            {createWorkspaceButtons()}
        </box>
    ) as Widget.Box;

    function createWorkspaceButtons() {
        return hyprland
            .get_workspaces()
            .filter((ws) => ws?.monitor.id == hyprlandMonitor!.id)
            .toSorted((a, b) => a.id - b.id)
            .map((ws) => <WorkspaceButton active={bind(activeWorkspace)} workspace={ws} />);
    }

    function handleWorkspaceScroll(event: Astal.ScrollEvent) {
        let direction: -1 | 1 | null = null;
        if (event.direction == Gdk.ScrollDirection.SMOOTH) {
            direction = Math.sign(event.delta_y) as -1 | 1;
        } else if (event.direction == Gdk.ScrollDirection.UP) {
            direction = -1;
        } else if (event.direction == Gdk.ScrollDirection.DOWN) {
            direction = 1;
        }

        if (direction != null) {
            const buttonsChildren = buttons?.get_children() ?? [];
            const workspaceIndex = buttonsChildren.findIndex(
                (btn) => btn.name == `workspace-${activeWorkspace.get()}`
            );
            if (workspaceIndex == -1) {
                console.warn("Couldn't find current workspace");
                console.log(activeWorkspace.get());
                for (const btn of buttonsChildren) {
                    console.log(btn.name);
                }
                return;
            }
            let newIndex = workspaceIndex + direction;
            // do not scroll outside
            if (newIndex < 0 || newIndex >= buttonsChildren.length) {
                return;
            }

            const targetWorkspaceId = buttonsChildren[newIndex].name.slice("workspace-".length);
            hyprland.dispatch("workspace", targetWorkspaceId);
        }
    }

    function addWorkspaceButton(workspace: AstalHyprland.Workspace) {
        // TODO(gtk4): Use `insert_child_after`
        // TODO: before gtk4, use a grid for its `attach` method
        const newButton = <WorkspaceButton active={bind(activeWorkspace)} workspace={workspace} />;
        const lastId = buttons?.get_children()?.at(-1)?.name?.slice("workspace-".length);
        if (lastId && workspace.id > parseInt(lastId)) {
            // adding it at the end works
            buttons?.add(newButton);
        } else {
            // recreate list
            if (buttons) {
                buttons.children = createWorkspaceButtons();
            }
        }
    }

    function removeWorkspaceButton(workspaceId: string) {
        buttons
            ?.get_children()
            ?.find((btn) => btn.name == `workspace-${workspaceId}`)
            ?.destroy();
    }

    function cleanup() {
        buttons = null;
        // we don't need to destroy it, it will be cleaned up by the eventbox (I think)
    }

    buttons.hook(hyprland, "event", (_h, event: string, args: string) => {
        if (event == "workspacev2") {
            const [idString, _name] = args.split(",");
            const workspace = hyprland.get_workspace(parseInt(idString));
            if (workspace?.monitor?.id == hyprlandMonitor.id) {
                activeWorkspace.set(workspace.id);
            }
        } else if (event == "createworkspacev2") {
            const [idString, _name] = args.split(",");
            const workspace = hyprland.get_workspace(parseInt(idString));
            if (workspace?.monitor?.id == hyprlandMonitor.id) {
                addWorkspaceButton(workspace);
            }
        } else if (event == "destroyworkspacev2") {
            const [idString, _name] = args.split(",");
            // this workspace no longer exists, so we can't check if it's on this monitor
            // overzealous deletion is good anyway
            removeWorkspaceButton(idString);
        } else if (event == "moveworkspacev2") {
            const [workspaceIdString, _workspaceName, monitorName] = args.split(",");
            const monitorId = hyprland.get_monitor_by_name(monitorName)?.id;

            if (hyprlandMonitor.id == monitorId) {
                // moved to here, add
                const ws = hyprland.get_workspace(parseInt(workspaceIdString));
                addWorkspaceButton(ws);
                // workspacev2 is emitted before this, so manually set the active workspace
                activeWorkspace.set(hyprlandMonitor.active_workspace.id);
            } else {
                // possibly moved away from here, remove if present
                removeWorkspaceButton(workspaceIdString);
            }
        }
    });

    return (
        <eventbox
            onScroll={(_eventBox, event) => handleWorkspaceScroll(event)}
            onDestroy={() => cleanup()}
        >
            {buttons}
        </eventbox>
    );
};
