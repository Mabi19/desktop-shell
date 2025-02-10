# My Desktop Shell
*Now with GTK 4!*

This is my bar & other assorted widgets that I use on my Linux desktop.
Not particularly customizable; see [Configuration section](#configuration) for more details.

It has some features I think are neat, notably dynamically colored system usage widgets,
workspace widget scrolling, and workspace drag'n'drop (to move them between monitors).

Required things:
- AGS v2 (for build only)
- libastal (+ some of its extra libraries)
- Hyprland (0.47.2+)
- GNOME System Monitor
- pavucontrol
- geoclue (and an agent running; in the future this may become an agent itself, use `/usr/lib/geoclue-2.0/demos/agent` for now)

## Installation
Included is a `meson.build` file allowing this project to be bundled and installed with Meson.
When using this way to run it, a `config.json` needs to exist in `~/.config/mabi-shell`,
and a Hyprland configuration file should be sourced from `(INSTALL PREFIX)/share/mabi-shell/hyprland.conf`
(where `INSTALL_PREFIX` is `/usr/local` by default)

Running in development mode involves running `./run-dev.sh`
and sourcing the Hyprland configuration directly from the source directory.

In the future, I may make a PKGBUILD for this or something.

## Configuration
This isn't particularly customizable, but some options do exist (they should live in `~/.config/mabi-shell/config.json`).
See `config.json.example` for an example.
```ts
interface OklabColor {
    l: number;
    a: number;
    b: number;
}

interface Config {
    /** Override for the primary monitor. Useful if you don't have one set as primary. */
    primary_monitor?: string;
    /** Whether to enable notifications. */
    enable_notifications: boolean;
    /** The network usage considered to be 100%. In bytes per second. */
    max_network_usage: number;
    /** The first theme color, used for inactive workspace buttons and badges with 0 usage. */
    theme_inactive: OklabColor;
    /** The second theme color, used for active workspace buttons and badges with maximum usage. */
    theme_active: OklabColor;
}
```

## Dispatchers
Some actions may be dispatched to the running instance via the `astal` CLI.
- `capslock_update`: update Caps Lock status.
- `osdn <icon-name: string> <value: number>`: show OSD with the specified icon and bar fullness.
- `osdt <icon-name: string> <text: string>`: show OSD with the specified icon and text (no level bar).
- `wpctl <args...>`: execute a `wpctl` command, then show OSD for the default audio sink
- `quit`: exit.

## TODO
- Notification animations
- Make notification center actually usable
