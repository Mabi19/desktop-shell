import { Variable } from "astal";
import GLib from "gi://GLib?version=2.0";

export const currentTime = Variable(new Date()).poll(1000, () => new Date());

// this is a very rough approximation of converting POSIX locales into BCP 47 tags
const languageTag =
    (GLib.getenv("LC_ALL") || GLib.getenv("LC_TIME") || GLib.getenv("LANG"))?.replaceAll("_", "-")?.split(".")?.[0] ??
    undefined;

export function makeDateTimeFormat(options: Intl.DateTimeFormatOptions) {
    return new Intl.DateTimeFormat(languageTag, options);
}
