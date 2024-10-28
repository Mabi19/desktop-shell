import { bind, Binding, Variable } from "astal";
import { Widget } from "astal/gtk3";
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

    // TODO: scroll on workspaces widget to switch, drag'n'drop between monitors (?)

    const buttons = (
        <box name="workspaces" spacing={4} onDestroy={() => activeWorkspace.drop()}>
            {hyprland
                .get_workspaces()
                .filter((ws) => ws.monitor.id == monitor)
                .toSorted((a, b) => a.id - b.id)
                .map((ws) => (
                    <WorkspaceButton active={bind(activeWorkspace)} workspace={ws} />
                ))}
        </box>
    ) as Widget.Box;

    function addWorkspaceButton(workspace: AstalHyprland.Workspace) {
        // TODO(gtk4): Use `insert_child_after`
        const newButton = <WorkspaceButton active={bind(activeWorkspace)} workspace={workspace} />;
        buttons.add(newButton);
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

    return buttons;
};
