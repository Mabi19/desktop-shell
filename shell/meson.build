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
    'bar/power-button.blp',
    'bar/time-button.blp',
    'bar/tray-item.blp',
    'bar/workspace-button.blp',
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
    'bar/power-button.vala',
    'bar/time-button.vala',
    'bar/tray.vala',
    'bar/workspaces.vala',
    'service/sound.vala',
    'service/time.vala',
    'service/workspace.vala',
    'side-panel/side-panel.vala',
    'utils/color.vala',
    'app.vala',
    'config.vala',
)

style_lib = static_library(
    'mabi-shell-style',
    'style.vala',
    vala_header: 'mabi-shell-style.h',
    vala_vapi: 'mabi-shell-style-1.0.vapi',
    dependencies: [gtk4_dep],
    c_args: ['-w'],
)

style_dep = declare_dependency(link_with: style_lib, include_directories: include_directories('.'))

executable(
    'mabi-shell',
    sources: [shell_src, resource],
    dependencies: [
        gtk4_layer_shell_dep,
        astal4_dep,
        astalio_dep,
        astal_hyprland_dep,
        astal_tray_dep,
        astal_wp_dep,
        adw_dep,
        gee_dep,
        gsound_dep,
        json_glib_dep,
        style_dep,
    ],
    c_args: ['-w'],
    link_args: ['-lm'],
)
