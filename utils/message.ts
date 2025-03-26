import { App } from "astal/gtk4";
import { updateCapsLockStatus } from "../bar/left-section";
import { toggleNotificationCenter } from "../notification-center/notification-center";
import { execWrappedWpCommand } from "../osd/listener-wireplumber";
import { setOSD } from "../osd/osd";

export function handleMessage(request: string, respond: (res: any) => void) {
    if (request == "capslock_update") {
        updateCapsLockStatus();
        respond("ok");
    } else if (/^osdn \S+ [0-9.]+%?$/g.test(request)) {
        const [_, icon, strValue] = request.split(" ");
        const value = strValue.endsWith("%") ? parseFloat(strValue.slice(0, -1)) * 100 : parseFloat(strValue);
        setOSD(icon, value);
        respond("ok");
    } else if (/^osdt \S+ \S/g.test(request)) {
        const [_, icon, ...rest] = request.split(" ");
        const text = rest.join(" ");
        setOSD(icon, text);
        respond("ok");
    } else if (request == "notification-center") {
        toggleNotificationCenter();
        respond("ok");
    } else if (request.startsWith("wpctl")) {
        execWrappedWpCommand(request);
        respond("ok");
    } else if (request == "quit") {
        respond("ok");
        App.quit();
    } else {
        console.log(request);
        respond("invalid message");
    }
}
