gnome = import('gnome')
sass = find_program('sass', required: true)
blueprint = find_program('blueprint-compiler', required: true)

scss_src = files(
    'style/bar.scss',
    'style/click-capture.scss',
    'style/notification-center.scss',
    'style/notification.scss',
    'style/osd.scss',
    'style.scss',
)
compiled_styles = custom_target(
    'scss',
    input: scss_src,
    output: 'shell-styles.css',
    command: [sass, '@CURRENT_SOURCE_DIR@' / 'style.scss', '@OUTPUT@'],
)

blueprint_src = files('bar/bar.blp', 'bar/time-button.blp')
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
    'bar/bar.vala',
    'bar/time-button.vala',
    'service/time.vala',
    'app.vala',
    'ipc.vala',
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
    dependencies: [gtk4_layer_shell_dep, astal4_dep, astalio_dep, adw_dep, style_dep],
    c_args: ['-w'],
)
