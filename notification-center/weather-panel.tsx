import { bind } from "astal";
import { Gtk } from "astal/gtk4";
import { weatherData } from "../utils/weather";

export function WeatherPanel() {
    return (
        <box spacing={8} cssClasses={["panel", "weather"]} widthRequest={400}>
            {bind(weatherData).as((data) =>
                data ? (
                    <>
                        <image iconName="weather-clear-symbolic" pixelSize={72} />
                        <box vertical={true}>
                            <label label={`${data.current.temperature}${data.current.units.temperature}`} />
                        </box>
                    </>
                ) : (
                    <label label="Weather unavailable" halign={Gtk.Align.CENTER} />
                )
            )}
        </box>
    );
}
