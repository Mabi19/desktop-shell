import { Variable, interval } from "astal";
import Geoclue from "gi://Geoclue?version=2.0";

export const currentLocation = Variable<Geoclue.Location | null>(null);

Geoclue.Simple.new("mabi-shell", Geoclue.AccuracyLevel.CITY, null, (geoclue, result) => {
    Geoclue.Simple.new_finish(result);
    if (!geoclue) {
        console.error(
            "GeoClue service is not available. Make sure that GeoClue is configured correctly and an agent is running."
        );
        return;
    }

    // TODO: poll every 5 minutes and check if it's been an hour instead of this
    // since this doesn't always tick when suspended
    interval(1000 * 60 * 60, () => {
        console.log("fetching location");
        const newLocation = geoclue.get_location();
        console.log(`lat: ${newLocation?.latitude}, lon: ${newLocation?.longitude}, acc: ${newLocation?.accuracy}`);
        currentLocation.set(newLocation);
    });
});
