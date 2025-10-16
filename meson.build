project('mabi-shell', 'vala', default_options: ['warning_level=3'], version: '0.1')

prefix = get_option('prefix')
pkgdatadir = prefix / get_option('datadir') / meson.project_name()
bindir = prefix / get_option('bindir')

gtk4_layer_shell_dep = dependency('gtk4-layer-shell-0')
gtk4_dep = dependency('gtk4')
astal4_dep = dependency('astal-4-4.0')
astalio_dep = dependency('astal-io-0.1')
astal_hyprland_dep = dependency('astal-hyprland-0.1')
astal_notifd_dep = dependency('astal-notifd-0.1')
astal_tray_dep = dependency('astal-tray-0.1')
astal_wp_dep = dependency('astal-wireplumber-0.1')
adw_dep = dependency('libadwaita-1')
gee_dep = dependency('gee-0.8')
gsound_dep = dependency('gsound')
json_glib_dep = dependency('json-glib-1.0')

subdir('shell')

install_data(files('hyprland.conf'), install_dir: pkgdatadir)
install_data(files('mabictl.sh'), rename: 'mabictl', install_dir: bindir)
