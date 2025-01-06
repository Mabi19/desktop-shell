# My Desktop Shell

This is my bar & other assorted widgets that I use on my Linux desktop.
Not particularly customizable; see config.json.example for the available options.

It has some features I think are neat, notably dynamically colored system usage widgets,
workspace widget scrolling, and workspace drag'n'drop (to move them between monitors).

Required things:
- AGS v2
- Hyprland (0.45)
- GNOME System Monitor (soon)
- pavucontrol

In the root of the repository is a `hyprland.conf` file that needs to be sourced from the main Hyprland configuration for everything to work properly.

## TODO
- Notifications
- Make notification center actually usable
- GTK 4:
    - Figure out why windows start visible=false
    - Fix all the CSS
    - Figure out how to do color shifting without dynamic CSS (predefined steps? custom drawing?)
    - Add all the functionality back in
