import { bind, Binding, Variable } from "astal";
import { Gdk, Gtk, hook, Widget } from "astal/gtk4";
import AstalHyprland from "gi://AstalHyprland";
import Gio from "gi://Gio?version=2.0";
import GLib from "gi://GLib?version=2.0";

const hyprland = AstalHyprland.get_default();

const WORKSPACE_MIME_TYPE = "application/x.mabi-workspace";

Gio._promisify(Gdk.Drop.prototype, "read_async", "read_finish");
Gio._promisify(Gio.InputStream.prototype, "read_bytes_async", "read_bytes_finish");

// This widget doesn't use `hook` or bind props, so it can be used with manual child management.
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

    const button = (
        // Buttons break after getting drag'n'dropped. So make a fake button out of a box instead
        // The active class is updated later by the workspace wrapper.
        <box
            cssClasses={active.get() == workspace.id ? ["active", "workspace"] : ["workspace"]}
            name={`workspace-${workspace.id}`}
            hexpandSet={true}
        >
            <label label={workspace.id.toString()} hexpand={true} valign={Gtk.Align.CENTER} />
        </box>
    );
    const clickGesture = new Gtk.GestureClick();
    clickGesture.connect("released", clickHandler);
    button.add_controller(clickGesture);

    const dragSource = new Gtk.DragSource();
    dragSource.connect("prepare", () => {
        console.log("prepare");
        return Gdk.ContentProvider.new_for_bytes(
            WORKSPACE_MIME_TYPE,
            new Uint8Array([workspace.id])
        );
    });
    dragSource.connect("drag-begin", (source) => {
        console.log("drag-begin");
        button.add_css_class("dragging");
        source.set_icon(new Gtk.WidgetPaintable({ widget: button }), 0, 0);
    });
    dragSource.connect("drag-end", () => {
        console.log("drag-end");
        button.remove_css_class("dragging");
    });
    dragSource.connect("drag-cancel", () => {
        console.log("drag-cancel");
        button.remove_css_class("dragging");
    });

    button.add_controller(dragSource);

    return button;
};

export const Workspaces = ({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) => {
    // TODO: check for the reshuffling bug if it happens again
    const hyprlandMonitor = hyprland.get_monitors().find((mon) => mon.name == gdkmonitor.connector);
    if (!hyprlandMonitor) {
        throw new Error("Couldn't find matching Hyprland monitor");
    }

    const activeWorkspace = Variable<number | null>(hyprlandMonitor.active_workspace?.id);

    let buttons: ReturnType<typeof Widget.Box> | null = (
        <box
            name="workspaces"
            spacing={4}
            onDestroy={() => activeWorkspace.drop()}
            setup={(self) => {
                const dropTarget = new Gtk.DropTargetAsync({
                    actions: Gdk.DragAction.COPY,
                    formats: new Gdk.ContentFormats([WORKSPACE_MIME_TYPE]),
                });
                dropTarget.connect("drop", (_dropTarget, drop) => {
                    drop.read_async([WORKSPACE_MIME_TYPE], GLib.PRIORITY_DEFAULT, null)
                        .then(([stream, _mime]) => {
                            return stream?.read_bytes_async(1, GLib.PRIORITY_DEFAULT, null);
                        })
                        .then((bytes) => {
                            const byte = bytes?.get_data()?.[0];
                            if (typeof byte != "number") return;
                            // make it signed again
                            const movedWorkspaceId = new Int8Array([byte])[0];

                            const isOnDifferentMonitor = !buttons
                                ?.get_children()
                                ?.find((btn) => btn.name == `workspace-${movedWorkspaceId}`);
                            if (isOnDifferentMonitor) {
                                hyprland.dispatch(
                                    "moveworkspacetomonitor",
                                    `${movedWorkspaceId} ${hyprlandMonitor.id}`
                                );
                            }
                            // TODO: Finishing a drop causes the next click to not go through. Try finding a workaround for this perhaps
                        })
                        .catch(logError);

                    drop.finish(Gdk.DragAction.COPY);
                    return true;
                });
                self.add_controller(dropTarget);
            }}
        >
            {createWorkspaceButtons()}
        </box>
    ) as ReturnType<typeof Widget.Box>;

    function createWorkspaceButtons() {
        return hyprland
            .get_workspaces()
            .filter((ws) => ws?.monitor.id == hyprlandMonitor!.id)
            .toSorted((a, b) => a.id - b.id)
            .map((ws) => <WorkspaceButton active={bind(activeWorkspace)} workspace={ws} />);
    }

    function handleWorkspaceScroll(_dx: number, dy: number) {
        const direction = Math.sign(dy);

        if (direction != 0) {
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
        const newButton = <WorkspaceButton active={bind(activeWorkspace)} workspace={workspace} />;
        const previousButton = buttons?.get_children().findLast((btn) => {
            const num = parseInt(btn.name.slice("workspace-".length));
            return num < workspace.id;
        });
        buttons?.insert_child_after(newButton, previousButton ?? null);
    }

    function removeWorkspaceButton(workspaceId: string) {
        const button = buttons
            ?.get_children()
            ?.find((btn) => btn.name == `workspace-${workspaceId}`);
        if (button) {
            buttons?.remove(button);
        }
    }

    function cleanup() {
        buttons = null;
    }

    hook(buttons, hyprland, "event", (_h, event: string, args: string) => {
        if (event == "workspacev2") {
            const [idString, _name] = args.split(",");
            const workspace = hyprland.get_workspace(parseInt(idString));
            if (workspace?.monitor?.id == hyprlandMonitor.id) {
                buttons
                    ?.get_children()
                    ?.find((btn) => btn.name == `workspace-${activeWorkspace.get()}`)
                    ?.remove_css_class("active");
                buttons
                    ?.get_children()
                    ?.find((btn) => btn.name == `workspace-${workspace.id}`)
                    ?.add_css_class("active");

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
        <box onScroll={(_box, dx, dy) => handleWorkspaceScroll(dx, dy)} onDestroy={() => cleanup()}>
            {buttons}
        </box>
    );
};
