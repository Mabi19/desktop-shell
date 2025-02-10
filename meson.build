project('mabi-shell', version: '0.1')

prefix = get_option('prefix')
pkgdatadir = prefix / get_option('datadir') / meson.project_name()
bindir = prefix / get_option('bindir')

install_data(
    files('hyprland.conf'),
    install_dir: pkgdatadir,
)

install_subdir('icons', install_dir: pkgdatadir)

sources = files([
    'app.ts',
    'bar/audio.tsx',
    'bar/badge-widgets.ts',
    'bar/battery.tsx',
    'bar/left-section.tsx',
    'bar/network.tsx',
    'bar/right-section.tsx',
    'bar/tray.tsx',
    'bar/workspaces.tsx',
    'notification/flexbox-layout.ts',
    'notification/notification-dump.ts',
    'notification/notification.tsx',
    'notification-center/notification-center.tsx',
    'notification-center/weather-panel.tsx',
    'osd/listener-brightness.ts',
    'osd/listener-wireplumber.ts',
    'osd/listeners.ts',
    'osd/osd.tsx',
    'style.scss',
    'style/bar.scss',
    'style/notification-center.scss',
    'style/notification.scss',
    'style/osd.scss',
    'utils/color.ts',
    'utils/config.ts',
    'utils/location.ts',
    'utils/message.ts',
    'utils/notifier.ts',
    'utils/system-stats.ts',
    'utils/timer.ts',
    'utils/weather.ts',
    'widgets/calendar.ts',
    'widgets/regular-window.ts',
    'widgets/toggle-button.ts',
])

custom_target(
    command: [
        find_program('ags'),
        'bundle',
        '--define', 'DATADIR="' + pkgdatadir + '"',
        '--root', meson.project_source_root(),
        meson.project_source_root() / 'app.ts',
        'mabi-shell.js',
    ],
    output: 'mabi-shell.js',
    input: sources,
    install: true,
    install_dir: pkgdatadir,
)

configure_file(
    input: files('run.template.sh'),
    output: meson.project_name(),
    configuration: {
        'JS_BUNDLE_FILE': pkgdatadir / 'mabi-shell.js',
        'LAYER_SHELL_LIBDIR': dependency('gtk4-layer-shell-0').get_variable('libdir'),
    },
    install: true,
    install_mode: 'rwxr-xr-x',
    install_dir: get_option('prefix') / get_option('bindir'),
)
