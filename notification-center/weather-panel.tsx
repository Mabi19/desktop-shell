import { bind } from "astal";
import { Gtk } from "astal/gtk4";
import GLib from "gi://GLib?version=2.0";
import { weatherData } from "../utils/weather";

const nbsp = "\u202f";
const endash = "\u2013";

function formatUnixTimestamp(timestamp: number) {
    return GLib.DateTime.new_from_unix_utc(timestamp).format("%R");
}

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
                                    label={`${Math.floor(data.min_temperature)}${endash}${Math.ceil(
                                        data.max_temperature
                                    )}${nbsp}${data.temperature_range_unit}`}
                                    cssClasses={["temperature-range"]}
                                    valign={Gtk.Align.BASELINE}
                                />
                            </box>

                            <label
                                label={`feels like <b>${Math.round(data.current.apparent_temperature)}${nbsp}${
                                    data.current.units.apparent_temperature
                                }</b>`}
                                useMarkup={true}
                                halign={Gtk.Align.START}
                            />

                            <box spacing={4}>
                                <image iconName="weather-windy-symbolic" />
                                <label label={`${data.current.wind_speed}${nbsp}${data.current.units.wind_speed}`} />
                            </box>

                            <box spacing={8}>
                                <label
                                    label={`${formatUnixTimestamp(data.in_6h.timestamp)}:`}
                                    cssClasses={["timestamp"]}
                                />
                                <box spacing={4}>
                                    <image iconName="weather-clear-symbolic" />
                                    <label
                                        label={`${Math.round(data.in_6h.temperature)}${nbsp}${
                                            data.in_6h.units.temperature
                                        } (${Math.round(data.in_6h.apparent_temperature)}${nbsp}${
                                            data.in_6h.units.apparent_temperature
                                        })`}
                                    />
                                </box>
                                <box spacing={4}>
                                    <image iconName="weather-windy-symbolic" />
                                    <label label={`${data.in_6h.wind_speed}${nbsp}${data.in_6h.units.wind_speed}`} />
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
