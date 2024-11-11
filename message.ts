import { updateCapsLockStatus } from "./bar/left-section";

export function handleMessage(request: string, respond: (res: any) => void) {
    if (request == "capslock_update") {
        updateCapsLockStatus();
        respond("ok");
    } else {
        respond("invalid message");
    }
}
