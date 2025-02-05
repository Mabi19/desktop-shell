import { Variable } from "astal";
import Gio from "gi://Gio?version=2.0";
import GLib from "gi://GLib?version=2.0";
import Soup from "gi://Soup?version=3.0";
import { currentLocation } from "./location";

Gio._promisify(Soup.Session.prototype, "send_and_read_async", "send_and_read_finish");

interface WeatherUnits {
    temperature: string;
    wind_speed: string;
}

interface TimedWeatherInfo {
    temperature: number;
    apparent_temperature: number;
    weather_code: number;
    wind_speed: number;
    units: WeatherUnits;
}

interface WeatherData {
    current: TimedWeatherInfo & { is_day: boolean };
}

export const weatherData = Variable<WeatherData | null>(null);
currentLocation.subscribe((location) => {
    if (!location) {
        weatherData.set(null);
        return;
    }

    const params = {
        latitude: location.latitude,
        longitude: location.longitude,
        current: ["temperature_2m", "apparent_temperature", "is_day", "weather_code", "wind_speed_10m"],
        hourly: ["temperature_2m", "apparent_temperature", "weather_code", "wind_speed_10m"],
        wind_speed_unit: "ms",
        timezone: "auto",
        timeformat: "unixtime",
        forecast_days: 2,
    };

    const paramString = Object.entries(params)
        .map(([key, value]) => {
            let valueString: string;
            if (typeof value == "string") {
                valueString = value;
            } else if (typeof value == "number") {
                valueString = value.toString();
            } else if (Array.isArray(value)) {
                valueString = value.join(",");
            } else {
                throw new Error("Unhandled parameter value");
            }

            return `${key}=${valueString}`;
        })
        .join("&");

    const uri = GLib.uri_build(
        GLib.UriFlags.NONE,
        "https",
        null,
        "api.open-meteo.com",
        -1,
        "/v1/forecast",
        paramString,
        null
    );

    const session = new Soup.Session();
    const message = Soup.Message.new_from_uri("GET", uri);
    session
        .send_and_read_async(message, GLib.PRIORITY_DEFAULT, null)
        .then((data) => {
            const dataString = new TextDecoder().decode(data.toArray());
            const rawObject = JSON.parse(dataString);

            weatherData.set({
                current: {
                    temperature: rawObject.current.temperature_2m,
                    apparent_temperature: rawObject.current.apparent_temperature,
                    is_day: Boolean(rawObject.current.is_day),
                    weather_code: rawObject.current.weather_code,
                    wind_speed: rawObject.current.wind_speed_10m,
                    units: {
                        temperature: rawObject.current_units.temperature_2m,
                        wind_speed: rawObject.current_units.wind_speed_10m,
                    },
                },
            });
            console.log(weatherData.get());
        })
        .catch((reason) => console.log("Couldn't get weather info:", reason));
});
