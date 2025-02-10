import { Variable, interval } from "astal";
import Geoclue from "gi://Geoclue?version=2.0";

export const currentLocation = Variable<{ latitude: number; longitude: number } | null>(null);

Geoclue.Simple.new("mabi-shell", Geoclue.AccuracyLevel.CITY, null, (geoclue, result) => {
    Geoclue.Simple.new_finish(result);
    if (!geoclue) {
        console.error(
            "GeoClue service is not available. Make sure that GeoClue is configured correctly and an agent is running."
        );
        return;
    }

    currentLocation.set({ latitude: geoclue.location.latitude, longitude: geoclue.location.longitude });
    geoclue.connect("notify::location", () => {
        console.log("Location changed!");
        currentLocation.set({ latitude: geoclue.location.latitude, longitude: geoclue.location.longitude });
    });
});
