# My Desktop Shell

This is my bar & other assorted widgets that I use on my Linux desktop.
Not particularly customizable; see config.json.example for the available options.

It has some features I think are neat, notably dynamically colored system usage widgets,
workspace widget scrolling, and workspace drag'n'drop (to move them between monitors).

Required things:
- AGS v2
- Hyprland (0.44; see note below)
- GNOME System Monitor (soon)
- pavucontrol

Currently Hyprland 0.44 works for everything, but 0.45 will add a way to query for Caps Lock status and fix bug #8293,
which makes workspace drag'n'drop awkward.

In the root of the repository is a `hyprland.conf` file that needs to be sourced from the main Hyprland configuration for everything to work properly.

## TODO
- Notifications
- Make notification center actually usable
- app launcher?
