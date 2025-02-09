import { execAsync } from "astal";
import AstalWp from "gi://AstalWp?version=0.1";
import { setOSD } from "./osd";

export function execWrappedWpCommand(command: string) {
    execAsync(command.split(" ")).then(() => {
        const wp = AstalWp.get_default();
        const speaker = wp?.get_default_speaker();
        if (!speaker) {
            console.warn("Couldn't get wireplumber speaker while displaying OSD");
            return;
        }
        setOSD(speaker.volumeIcon, speaker.volume);
    });
}
