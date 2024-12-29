import { bind } from "astal";
import { Astal, Gdk, Gtk } from "astal/gtk4";
import AstalTray from "gi://AstalTray";
import type Gio from "gi://Gio";

const tray = AstalTray.get_default();

function createMenu(menuModel: Gio.MenuModel, actionGroup: Gio.ActionGroup): Gtk.Menu {
    const menu = Gtk.Menu.new_from_model(menuModel);
    menu.insert_action_group("dbusmenu", actionGroup);
    return menu;
}

export const SystemTray = () => {
    return (
        <box spacing={12}>
            {bind(tray, "items").as((items) => {
                return items
                    .toSorted((a, b) => a.title.localeCompare(b.title))
                    .map((item) => {
                        const menu = createMenu(item.menuModel, item.actionGroup);

                        return (
                            <button
                                className="tray-item"
                                tooltipText={bind(item, "tooltip_markup")}
                                onDestroy={() => menu.destroy()}
                                onClick={(self, event) => {
                                    if (event.button == Astal.MouseButton.PRIMARY) {
                                        item.activate(event.x, event.y);
                                    } else if (event.button == Astal.MouseButton.MIDDLE) {
                                        item.secondary_activate(event.x, event.y);
                                    } else if (event.button == Astal.MouseButton.SECONDARY) {
                                        menu.popup_at_widget(
                                            self,
                                            Gdk.Gravity.SOUTH,
                                            Gdk.Gravity.NORTH,
                                            null
                                        );
                                    }
                                }}
                            >
                                <icon gicon={bind(item, "gicon")} />
                            </button>
                        );
                    });
            })}
        </box>
    );
};
