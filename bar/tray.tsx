import { bind } from "astal";
import { Astal, Gdk } from "astal/gtk3";
import AstalTray from "gi://AstalTray";

const tray = AstalTray.get_default();

export const SystemTray = () => {
    return (
        <box spacing={12}>
            {bind(tray, "items").as((items) => {
                return items
                    .toSorted((a, b) => a.title.localeCompare(b.title))
                    .map((item) => {
                        const menu = item.create_menu();

                        return (
                            <button
                                className="tray-item"
                                tooltipText={bind(item, "tooltip_markup")}
                                onDestroy={() => menu?.destroy()}
                                onClick={(self, event) => {
                                    if (event.button == Astal.MouseButton.PRIMARY) {
                                        item.activate(event.x, event.y);
                                    } else if (event.button == Astal.MouseButton.MIDDLE) {
                                        item.secondary_activate(event.x, event.y);
                                    } else if (event.button == Astal.MouseButton.SECONDARY) {
                                        menu?.popup_at_widget(
                                            self,
                                            Gdk.Gravity.SOUTH,
                                            Gdk.Gravity.NORTH,
                                            null
                                        );
                                    }
                                }}
                            >
                                <icon gIcon={bind(item, "gicon")} />
                            </button>
                        );
                    });
            })}
        </box>
    );
};
