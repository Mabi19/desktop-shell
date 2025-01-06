import { bind } from "astal";
import { Gdk, Gtk, hook } from "astal/gtk4";
import AstalTray from "gi://AstalTray";

const tray = AstalTray.get_default();

export const SystemTray = () => {
    return (
        <box spacing={12}>
            {bind(tray, "items").as((items) => {
                return items
                    .toSorted((a, b) => a.title.localeCompare(b.title))
                    .map((item) => {
                        let menu = Gtk.PopoverMenu.new_from_model(item.menuModel);
                        menu.insert_action_group("dbusmenu", item.actionGroup);

                        const button = (
                            <button
                                cssClasses={["tray-item"]}
                                tooltipText={bind(item, "tooltip_markup")}
                                onButtonPressed={(self, event) => {
                                    const button = event.get_button();
                                    const [_, x, y] = event.get_position();

                                    if (button == Gdk.BUTTON_PRIMARY) {
                                        item.activate(x, y);
                                    } else if (button == Gdk.BUTTON_MIDDLE) {
                                        item.secondary_activate(x, y);
                                    } else if (button == Gdk.BUTTON_SECONDARY) {
                                        menu.popup();
                                    }
                                }}
                            >
                                <image gicon={bind(item, "gicon")} />
                            </button>
                        );
                        menu.set_parent(button);
                        hook(button, item, "notify::menu-model", () => {
                            menu.menuModel = item.menuModel;
                        });
                        hook(button, item, "notify::action-group", () => {
                            menu.insert_action_group("dbusmenu", null);
                            menu.insert_action_group("dbusmenu", item.actionGroup);
                        });

                        return button;
                    });
            })}
        </box>
    );
};
