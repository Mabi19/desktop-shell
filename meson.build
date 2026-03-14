project('mabi-shell', 'vala', default_options: ['warning_level=3'], version: '0.1')

prefix = get_option('prefix')
pkgdatadir = prefix / get_option('datadir') / meson.project_name()
bindir = prefix / get_option('bindir')

gtk4_layer_shell_dep = dependency('gtk4-layer-shell-0')
gtk4_dep = dependency('gtk4')
astal4_dep = dependency('astal-4-4.0')
astalio_dep = dependency('astal-io-0.1')
astal_battery_dep = dependency('astal-battery-0.1')
astal_hyprland_dep = dependency('astal-hyprland-0.1')
astal_hyprland_focus_grab_dep = dependency('astal-hyprland-focus-grab-4-0.1')
astal_tray_dep = dependency('astal-tray-0.1')
astal_wp_dep = dependency('astal-wireplumber-0.1')
adw_dep = dependency('libadwaita-1')
gee_dep = dependency('gee-0.8')
glycin_dep = dependency('glycin-2')
glycin_gtk4_dep = dependency('glycin-gtk4-2')
gsound_dep = dependency('gsound')
json_glib_dep = dependency('json-glib-1.0')

vapi_dir = meson.current_source_dir() / 'vapi'
add_project_arguments(['--vapidir', vapi_dir], language: 'vala')
style_context_shim_dep = meson.get_compiler('vala').find_library('style-context-shim', dirs: vapi_dir)

subdir('shell')

install_data(files('hyprland.conf'), install_dir: pkgdatadir)
install_data(files('mabictl.sh'), rename: 'mabictl', install_dir: bindir)
