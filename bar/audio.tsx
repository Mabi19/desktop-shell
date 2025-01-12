import { bind, execAsync } from "astal";
import { Gtk, hook } from "astal/gtk4";
import AstalWp from "gi://AstalWp";
import Pango from "gi://Pango?version=1.0";
import { ToggleButton } from "../widgets/toggle-button";

const audio = AstalWp.get_default()!.audio;

const VolumeSlider = ({ device }: { device: AstalWp.Endpoint }) => {
    const adjustment = new Gtk.Adjustment({
        lower: 0,
        upper: 1,
        value: device.volume,
        stepIncrement: 0.01,
        pageIncrement: 0.05,
    });
    const scale = new Gtk.Scale({
        adjustment,
        hexpand: true,
    });
    scale.connect("change-value", (_, _type, value) => {
        value = Math.round(Math.max(0, Math.min(value * 100, 100))) / 100;
        device.volume = value;
        // TODO: play sounds here if this is a speaker
    });
    hook(scale, device, "notify::volume", () => {
        const volume = device.volume;
        if (Math.abs(adjustment.value - volume) > 0.001) {
            adjustment.value = volume;
        }
    });
    hook(scale, device, "notify::mute", (scale) => {
        scale.sensitive = !device.mute;
    });

    return scale;
};

const AudioPopover = () => {
    function openMixer() {
        execAsync("pavucontrol");
        popover.popdown();
    }

    const speaker = audio.defaultSpeaker;
    const microphone = audio.defaultMicrophone;

    const popover = (
        <popover name="audio-quick-menu">
            <box vertical={true}>
                <box spacing={4}>
                    <ToggleButton
                        active={bind(speaker, "mute")}
                        onClicked={() => speaker.set_mute(!speaker.mute)}
                        cssClasses={["mute-button"]}
                    >
                        <image
                            iconName={bind(speaker, "mute").as((muted) =>
                                muted ? "audio-volume-muted-symbolic" : "audio-speakers-symbolic"
                            )}
                        />
                    </ToggleButton>
                    <label
                        label={bind(speaker, "description").as((desc) => desc ?? "Speaker")}
                        ellipsize={Pango.EllipsizeMode.END}
                        maxWidthChars={32}
                    />
                </box>
                <box>
                    <VolumeSlider device={speaker} />
                    <label
                        label={bind(speaker, "volume").as((vol) => `${Math.round(vol * 100)}%`)}
                        widthChars={5}
                        xalign={0}
                    />
                </box>
                <box spacing={4}>
                    <ToggleButton
                        active={bind(microphone, "mute")}
                        onClicked={() => microphone.set_mute(!microphone.mute)}
                        cssClasses={["mute-button"]}
                    >
                        <image
                            iconName={bind(microphone, "mute").as((muted) =>
                                muted
                                    ? "microphone-sensitivity-muted-symbolic"
                                    : "audio-input-microphone-symbolic"
                            )}
                        />
                    </ToggleButton>
                    <label
                        label={bind(microphone, "description").as((desc) => desc ?? "Microphone")}
                        ellipsize={Pango.EllipsizeMode.END}
                        maxWidthChars={32}
                    />
                </box>
                <box>
                    <VolumeSlider device={microphone} />
                    <label
                        label={bind(microphone, "volume").as((vol) => `${Math.round(vol * 100)}%`)}
                        widthChars={5}
                        xalign={0}
                    />
                </box>

                <button onClicked={openMixer}>Open Audio Mixer</button>
            </box>
        </popover>
    ) as Gtk.Popover;
    return popover;
};

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
        <menubutton name="audio" popover={(<AudioPopover />) as Gtk.Popover}>
            <box spacing={8}>
                {bind(audio, "defaultSpeaker").as((speaker) => (
                    <AudioPart device={speaker} />
                ))}
                {bind(audio, "defaultMicrophone").as((microphone) => (
                    <AudioPart device={microphone} />
                ))}
            </box>
        </menubutton>
    );
};
