gnome = import('gnome')
sass = find_program('sass', required: true)
blueprint = find_program('blueprint-compiler', required: true)

scss_src = files(
    'style/bar.scss',
    'style/notification.scss',
    'style/osd.scss',
    'style/side-panel.scss',
    'style.scss',
)
compiled_styles = custom_target(
    'scss',
    input: scss_src,
    output: 'shell-styles.css',
    command: [sass, '@CURRENT_SOURCE_DIR@' / 'style.scss', '@OUTPUT@'],
)

blueprint_src = files(
    'bar/audio-button.blp',
    'bar/bar.blp',
    'bar/battery.blp',
    'bar/cpu-indicator.blp',
    'bar/memory-indicator.blp',
    'bar/power-button.blp',
    'bar/time-button.blp',
    'bar/tray-item.blp',
    'bar/workspace-button.blp',
    'side-panel/precise-clock.blp',
    'side-panel/side-panel.blp',
)
compiled_ui = custom_target(
    'blueprint',
    input: blueprint_src,
    output: '.',
    command: [
        blueprint,
        'batch-compile',
        '@OUTPUT@',
        '@CURRENT_SOURCE_DIR@',
        '@INPUT@',
    ],
)

resource = gnome.compile_resources(
    'shell-data',
    files('mabi-shell.gresource.xml'),
    dependencies: [compiled_styles, compiled_ui],
    source_dir: meson.current_build_dir(),
)

shell_src = files(
    'bar/audio.vala',
    'bar/bar.vala',
    'bar/battery.vala',
    'bar/power-button.vala',
    'bar/system-usage.vala',
    'bar/time-button.vala',
    'bar/tray.vala',
    'bar/workspaces.vala',
    'osd/osd.vala',
    'service/notification.vala',
    'service/notification/daemon.vala',
    'service/notification/markup.vala',
    'service/notification/rules.vala',
    'service/notification/tree.vala',
    'service/notification/types.vala',
    'service/sound.vala',
    'service/system-usage.vala',
    'service/time.vala',
    'service/workspace.vala',
    'side-panel/notification-list.vala',
    'side-panel/notification-widget.vala',
    'side-panel/precise-clock.vala',
    'side-panel/side-panel.vala',
    'utils/color.vala',
    'utils/easing.vala',
    'utils/texture-cache.vala',
    'widgets/level-bin.vala',
    'app.vala',
    'config.vala',
    'ipc.vala',
    'style.vala',
)

executable(
    'mabi-shell',
    sources: [shell_src, resource],
    dependencies: [
        gtk4_layer_shell_dep,
        astal4_dep,
        astalio_dep,
        astal_battery_dep,
        astal_hyprland_dep,
        astal_tray_dep,
        astal_wp_dep,
        adw_dep,
        gee_dep,
        glycin_dep,
        glycin_gtk4_dep,
        gtk4_dep,
        gsound_dep,
        json_glib_dep,
        style_context_shim_dep,
    ],
    c_args: ['-w'],
    link_args: ['-lm'],
    install: true,
)
