import { bind } from "astal";
import { Gtk } from "astal/gtk4";
import { weatherData } from "../utils/weather";

const nbsp = "\u202f";
const endash = "\u2013";

export function WeatherPanel() {
    return (
        <box spacing={8} cssClasses={["panel", "weather"]} widthRequest={400}>
            {bind(weatherData).as((data) =>
                data ? (
                    <>
                        <image
                            iconName="weather-clear-symbolic"
                            pixelSize={72}
                            cssClasses={["big-icon"]}
                            vexpand={false}
                            valign={Gtk.Align.CENTER}
                        />
                        <box vertical={true}>
                            <box spacing={8}>
                                <label
                                    label={`${data.current.temperature}${nbsp}${data.current.units.temperature}`}
                                    cssClasses={["temperature-main"]}
                                    valign={Gtk.Align.BASELINE}
                                />
                                <label
                                    label={`-21${endash}37${nbsp}${data.current.units.temperature}`}
                                    cssClasses={["temperature-range"]}
                                    valign={Gtk.Align.BASELINE}
                                />
                            </box>

                            <label
                                label={`feels like <b>2${nbsp}${data.current.units.temperature}</b>`}
                                useMarkup={true}
                                halign={Gtk.Align.START}
                            />

                            <box spacing={4}>
                                <image iconName="weather-windy-symbolic" />
                                <label label={`${data.current.wind_speed}${nbsp}${data.current.units.wind_speed}`} />
                            </box>

                            <box spacing={8}>
                                <label label="14:00:" cssClasses={["timestamp"]} />
                                <box spacing={4}>
                                    <image iconName="weather-clear-symbolic" />
                                    <label label={`7${nbsp}°C (3${nbsp}°C)`} />
                                </box>
                                <box spacing={4}>
                                    <image iconName="weather-windy-symbolic" />
                                    <label label={`3${nbsp}m/s`} />
                                </box>
                            </box>
                        </box>
                    </>
                ) : (
                    <label label="Weather unavailable" halign={Gtk.Align.CENTER} />
                )
            )}
        </box>
    );
}
