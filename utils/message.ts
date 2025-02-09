import { App } from "astal/gtk4";
import { updateCapsLockStatus } from "../bar/left-section";
import { setOSD } from "../osd/osd";

export function handleMessage(request: string, respond: (res: any) => void) {
    if (request == "capslock_update") {
        updateCapsLockStatus();
        respond("ok");
    } else if (/^osd:[^:]+:[0-9.]+%?$/g.test(request)) {
        const [_, icon, strValue] = request.split(":");
        const value = strValue.endsWith("%") ? parseFloat(strValue.slice(0, -1)) * 100 : parseFloat(strValue);
        setOSD(icon, value);
        respond("ok");
    } else if (request == "quit") {
        respond("ok");
        App.quit();
    } else {
        console.log(request);
        respond("invalid message");
    }
}
