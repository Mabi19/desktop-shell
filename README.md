# My Desktop Shell
*Now with Vala!*

This is my bar & other assorted widgets that I use on my Linux desktop.
Not particularly customizable; see [Configuration section](#configuration) for more details.

It has some features I think are neat, notably dynamically colored system usage widgets,
workspace widget scrolling, and workspace drag'n'drop (to move them between monitors).

Required things:
- libastal (+ some of its extra libraries)
- libgee
- glycin & glycin-gtk4
- json-glib
- GSound
- Hyprland (0.53+)
- GNOME System Monitor
- pavucontrol

## Installation
Included is a `meson.build` file allowing this project to be built and installed with Meson.
A Hyprland configuration file should be sourced from `(INSTALL PREFIX)/share/mabi-shell/hyprland.conf`
(where `INSTALL_PREFIX` is `/usr/local` by default)

and sourcing the Hyprland configuration directly from the source directory.

In the future, I may make a PKGBUILD for this or something.

## Configuration
This isn't particularly customizable, but some options do exist (they should live in `~/.config/mabi-shell/config.json`).
A configuration file is not required; all options have defaults (documented below).
The "color" type accepts #rrggbb\[aa\], rgb\[a\](), hsl\[a\](), and named colors.
```jsonc
{
    /** Override for the primary monitor. Useful if you don't have one set as primary. */
    "primary_monitor": null, // string | null
    /** The network usage considered to be 100%. In bytes per second. */
    "max_network_usage": 12500000, // number
    /** Whether to show Hibernate in the power menu. */
    "power_menu_hibernate": false, // boolean
    /** The first theme color, used for inactive workspace buttons and badges with 0 usage. */
    "theme_inactive": "#c063c9", // color
    /** The second theme color, used for active workspace buttons and badges with maximum usage. */
    "theme_active": "#8643b5", // color
    /** The style of the bar. "floating" is rounded with a margin, "attached" has no margins */
    "bar_style": "floating", // "floating" | "attached"
    /** The bar clock's time format. */
    "time_format_short": "%H:%M", // string
    /** The side panel clock's time format. */
    "time_format_long": "%c", // string
    /** Show a debug menu on notifications. */
    "notification_debug_menu": false, // boolean
    /** The command to execute when the "Open Audio Mixer" button is clicked. */
    "audio_mixer_command": "pavucontrol", // string
    /** Notification rules (see below) */
    "notification_rules": [
        {
            "if": { "app_name": "^vesktop$" },
            "then": { "app_name": "Vesktop", "layout": "message" }
        }
    ]
}
```
In addition, if a `~/.config/mabi-shell/overrides.css` file exists, it will be loaded as extra CSS
if you want to customize further (but this is in no way stable and may change at any time)

### Notification rules
These allow for making modifications to matched notifications.
They're mostly useful for selecting the layout you want, but they can modify most notification properties.
A rule is a JSON object with `if` (condition) and `then` (effect) keys.
The condition object can have any subset of these properties
(every property specified in an `if` object must match for the rule to take effect):
- summary (regex)
- body (regex)
- category (regex)
- app_name (regex)
- desktop_entry (regex)
- urgency ("low" | "normal" | "critical")

The effect object can have any subset of these properties:
- layout ("default" | "message")
- category (string)
- app_name (string)
- transient (boolean)
- resident (boolean)
- urgency (boolean)
- action_icons (boolean)
- suppress_sound (boolean)

## Dispatchers
Some actions may be dispatched to the running instance via the `mabictl` CLI.
- `inspect`: open the GTK Inspector
- `quit`: exit
