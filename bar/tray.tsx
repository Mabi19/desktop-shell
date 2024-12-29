import { bind } from "astal";
import { Astal, Gdk, Gtk } from "astal/gtk4";
import AstalTray from "gi://AstalTray";
import type Gio from "gi://Gio";

const tray = AstalTray.get_default();

function createMenu(menuModel: Gio.MenuModel, actionGroup: Gio.ActionGroup): Gtk.Menu {
    const menu = Gtk.PopoverMenu.new_from_model(menuModel);
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
                                cssClasses={["tray-item"]}
                                tooltipText={bind(item, "tooltip_markup")}
                                onDestroy={() => menu.destroy()}
                                onButtonPressed={(self, event) => {
                                    const button = event.get_button();

                                    if (button == Gdk.BUTTON_PRIMARY) {
                                        console.log("primary activate");
                                        // item.activate(event.x, event.y);
                                    } else if (button == Gdk.BUTTON_MIDDLE) {
                                        console.log("secondary activate");
                                        // item.secondary_activate(event.x, event.y);
                                    } else if (button == Gdk.BUTTON_SECONDARY) {
                                        console.log("menu activate");
                                        // menu.popup_at_widget(
                                        //     self,
                                        //     Gdk.Gravity.SOUTH,
                                        //     Gdk.Gravity.NORTH,
                                        //     null
                                        // );
                                    }
                                }}
                            >
                                <image gicon={bind(item, "gicon")} />
                            </button>
                        );
                    });
            })}
        </box>
    );
};
