import GSound from "gi://GSound?version=1.0";

let context: GSound.Context | null;

export function getSoundContext() {
    if (!context) {
        context = new GSound.Context();
        context.init(null);
    }
    return context;
}
