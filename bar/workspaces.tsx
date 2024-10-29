import { bind, Binding, Variable } from "astal";
import { Astal, Gdk, Widget } from "astal/gtk3";
import AstalHyprland from "gi://AstalHyprland";

const hyprland = AstalHyprland.get_default();
hyprland.connect("urgent", (_h, client) => {
    // TODO
    console.log(`client ${client.title} became urgent!`);
});

export const WorkspaceButton = ({
    active,
    workspace,
}: {
    active: Binding<number>;
    workspace: AstalHyprland.Workspace;
}) => {
    function clickHandler() {
        if (workspace.id != active.get()) {
            hyprland.dispatch("workspace", workspace.id.toString());
        }
    }

    return (
        <button
            className={active.as((activeId) =>
                activeId == workspace.id ? "workspace active" : "workspace"
            )}
            onClick={clickHandler}
            name={`workspace-${workspace.id}`}
        >
            {workspace.id}
        </button>
    );
};

export const Workspaces = ({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) => {
    // TODO: check for reshuffling if it happens again
    // TODO(gtk4): Use Gdk.Monitor.connector instead
    const hyprlandMonitor = hyprland.get_monitors().find((mon) => mon.model == gdkmonitor.model);
    if (!hyprlandMonitor) {
        throw new Error("Couldn't find matching Hyprland monitor");
    }

    const activeWorkspace = Variable(hyprlandMonitor.active_workspace.id);

    // TODO: drag'n'drop between monitors (?)

    const buttons = (
        <box name="workspaces" spacing={4} onDestroy={() => activeWorkspace.drop()}>
            {createWorkspaceButtons()}
        </box>
    ) as Widget.Box;

    function createWorkspaceButtons() {
        return hyprland
            .get_workspaces()
            .filter((ws) => ws.monitor.id == hyprlandMonitor!.id)
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
            const buttonsChildren = buttons.get_children();
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
        const lastId = buttons.get_children().at(-1)?.name?.slice("workspace-".length);
        if (lastId && workspace.id > parseInt(lastId)) {
            // adding it at the end works
            buttons.add(newButton);
        } else {
            // recreate list
            buttons.children = createWorkspaceButtons();
        }
    }

    function removeWorkspaceButton(workspaceId: string) {
        buttons
            .get_children()
            .find((btn) => btn.name == `workspace-${workspaceId}`)
            ?.destroy();
    }

    buttons.hook(hyprland, "event", (_h, event: string, args: string) => {
        if (event == "workspacev2") {
            const [idString, _name] = args.split(",");
            const workspace = hyprland.get_workspace(parseInt(idString));
            if (workspace.monitor.id == hyprlandMonitor.id) {
                activeWorkspace.set(workspace.id);
            }
        } else if (event == "createworkspacev2") {
            const [idString, _name] = args.split(",");
            const workspace = hyprland.get_workspace(parseInt(idString));
            if (workspace.monitor.id == hyprlandMonitor.id) {
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
                activeWorkspace.set(ws.id);
            } else {
                // possibly moved away from here, remove if present
                removeWorkspaceButton(workspaceIdString);
            }
        }
    });

    return (
        <eventbox onScroll={(_eventBox, event) => handleWorkspaceScroll(event)}>{buttons}</eventbox>
    );
};