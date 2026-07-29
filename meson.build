project('mabi-shell', 'vala', default_options: ['warning_level=3'], version: '0.1')

prefix = get_option('prefix')
pkgdatadir = prefix / get_option('datadir') / meson.project_name()
bindir = prefix / get_option('bindir')

vapi_dir = meson.current_source_dir() / 'vapi'
add_project_arguments(['--vapidir', vapi_dir], language: 'vala')
# We need to make the NMA4 VAPI ourselves
subdir('vapi')

gtk4_layer_shell_dep = dependency('gtk4-layer-shell-0')
gtk4_dep = dependency('gtk4')
astal4_dep = dependency('astal-4-4.0')
astalio_dep = dependency('astal-io-0.1')
astal_bluetooth_dep = dependency('astal-bluetooth-0.1')
astal_cava_dep = dependency('astal-cava-0.1')
astal_battery_dep = dependency('astal-battery-0.1')
astal_tray_dep = dependency('astal-tray-0.1')
astal_wl_dep = dependency('astal-wl-0.1')
wl_dep = dependency('wayland-client')
gtk_wl_dep = dependency('gtk4-wayland')
astal_workspace_dep = dependency('astal-workspace-0.1')
astal_wp_dep = dependency('astal-wireplumber-0.1')
adw_dep = dependency('libadwaita-1')
gee_dep = dependency('gee-0.8')
glycin_dep = dependency('glycin-2')
glycin_gtk4_dep = dependency('glycin-gtk4-2')
gsound_dep = dependency('gsound')
json_glib_dep = dependency('json-glib-1.0')
libcmark_dep = dependency('libcmark')
libnm_dep = dependency('libnm')
libnma_gtk4_dep = declare_dependency(dependencies: dependency('libnma-gtk4'))

style_context_shim_dep = meson.get_compiler('vala').find_library('style-context-shim', dirs: vapi_dir)

subdir('shell')

install_data(files('hyprland.conf'), install_dir: pkgdatadir)
install_data(files('mabictl.sh'), rename: 'mabictl', install_dir: bindir)
