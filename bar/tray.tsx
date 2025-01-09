import { bind } from "astal";
import { property, register } from "astal/gobject";
import { Gdk, Gtk, hook } from "astal/gtk4";
import AstalTray from "gi://AstalTray";
import Gio from "gi://Gio";

// TODO: try astalifying this
@register()
class TrayButton extends Gtk.Button {
    private declare _menuModel: Gio.MenuModel;
    private declare _actionGroup: Gio.ActionGroup;

    @property(Gio.MenuModel)
    get menuModel() {
        return this._menuModel;
    }
    set menuModel(v: Gio.MenuModel) {
        this._menuModel = v;
        if (this.popover) {
            this.popover.menuModel = v;
        }
    }

    @property(Gio.ActionGroup)
    get actionGroup() {
        return this._actionGroup;
    }
    set actionGroup(v: Gio.ActionGroup) {
        this._actionGroup = v;
        if (this.popover) {
            // This removes it if it already exists.
            // I checked the source code.
            this.popover.insert_action_group("dbusmenu", v);
        }
    }

    private popover: Gtk.PopoverMenu;

    constructor(constructProperties = {}) {
        super(constructProperties);
        this.popover = Gtk.PopoverMenu.new_from_model(this.menuModel);
        this.popover.flags = Gtk.PopoverMenuFlags.NESTED;
        this.popover.insert_action_group("dbusmenu", this.actionGroup);
        // Doing this in `vfunc_root` REALLY breaks things.
        this.popover.set_parent(this);
    }

    activate_popover() {
        this.popover.popup();
    }

    vfunc_unroot() {
        // Overriding `vfunc_dispose` breaks things.
        // I think this is a GJS issue? This is supposed to go in `dispose`
        // Or I just don't understand it well enough.
        // https://discourse.gnome.org/t/gtk4-gtkpopover-finalizing-warning/25881/3
        // https://discourse.gnome.org/t/how-to-not-destroy-a-widget/7449/5
        this.popover.unparent();
        super.vfunc_unroot();
    }
}

const tray = AstalTray.get_default();

export const SystemTray = () => {
    return (
        <box spacing={12}>
            {bind(tray, "items").as((items) => {
                return items
                    .toSorted((a, b) => a.title.localeCompare(b.title))
                    .map((item) => {
                        const button = new TrayButton({
                            cssClasses: ["tray-item"],
                            tooltipText: item.tooltipMarkup,
                            menuModel: item.menuModel,
                            actionGroup: item.actionGroup,
                        });
                        const controller = new Gtk.EventControllerLegacy();
                        controller.connect("event", (_c, event) => {
                            if (event.get_event_type() == Gdk.EventType.BUTTON_PRESS) {
                                const pressEvent = event as Gdk.ButtonEvent;
                                const mouseButton = pressEvent.get_button();
                                const [_, x, y] = pressEvent.get_position();
                                if (mouseButton == Gdk.BUTTON_PRIMARY) {
                                    item.activate(x, y);
                                } else if (mouseButton == Gdk.BUTTON_MIDDLE) {
                                    item.secondary_activate(x, y);
                                } else {
                                    button.activate_popover();
                                }
                            }
                        });
                        button.add_controller(controller);
                        button.child = <image gicon={bind(item, "gicon")} />;

                        hook(button, item, "notify::tooltip-markup", () => {
                            button.tooltipText = item.tooltipMarkup;
                        });
                        hook(button, item, "notify::menu-model", (button) => {
                            button.menuModel = item.menuModel;
                        });
                        hook(button, item, "notify::action-group", (button) => {
                            button.actionGroup = item.actionGroup;
                        });

                        return button;
                    });
            })}
        </box>
    );
};
