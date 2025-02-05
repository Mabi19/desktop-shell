import { Variable, interval } from "astal";
import Geoclue from "gi://Geoclue?version=2.0";
import GLib from "gi://GLib?version=2.0";

export const currentLocation = Variable<{ latitude: number; longitude: number } | null>(null);

Geoclue.Simple.new("mabi-shell", Geoclue.AccuracyLevel.CITY, null, (geoclue, result) => {
    Geoclue.Simple.new_finish(result);
    if (!geoclue) {
        console.error(
            "GeoClue service is not available. Make sure that GeoClue is configured correctly and an agent is running."
        );
        return;
    }

    // poll every 5 minutes and check if it's been an hour,
    // since `interval` may not tick when suspended
    let lastPollTime = 0;
    interval(300 * 1000, () => {
        // in milliseconds
        const now = GLib.get_real_time() / 1000;
        if (now - lastPollTime < 60 * 60 * 1000) {
            return;
        }
        lastPollTime = now;
        console.log("fetching location");
        const newLocation = geoclue.get_location();
        console.log(`lat: ${newLocation?.latitude}, lon: ${newLocation?.longitude}, acc: ${newLocation?.accuracy}`);
        if (newLocation) {
            currentLocation.set({ latitude: newLocation.latitude, longitude: newLocation.longitude });
        } else {
            currentLocation.set(null);
        }
    });
});
