import { Gtk } from "astal/gtk3";

interface MenuDefinition {
    label: string;
    handler: () => void;
}

export function createMenu(definition: MenuDefinition[]) {
    const result = new Gtk.Menu();

    for (const def of definition) {
        const item = Gtk.MenuItem.new_with_label(def.label);
        item.connect("activate", def.handler);
        item.show();
        result.append(item);
    }

    return result;
}
