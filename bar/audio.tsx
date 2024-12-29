import { bind, execAsync } from "astal";
import AstalWp from "gi://AstalWp";

const audio = AstalWp.get_default()!.audio;

const AudioPart = ({ device }: { device: AstalWp.Endpoint }) => {
    return (
        <box spacing={4}>
            <image iconName={bind(device, "volumeIcon")} />
            <label label={bind(device, "volume").as((vol) => `${Math.round(vol * 100)}%`)} />
        </box>
    );
};

export const AudioIndicator = () => {
    return (
        <button name="audio" onButtonPressed={() => execAsync("pavucontrol")}>
            <box spacing={8}>
                {bind(audio, "defaultSpeaker").as((speaker) => (
                    <AudioPart device={speaker} />
                ))}
                {bind(audio, "defaultMicrophone").as((microphone) => (
                    <AudioPart device={microphone} />
                ))}
            </box>
        </button>
    );
};
