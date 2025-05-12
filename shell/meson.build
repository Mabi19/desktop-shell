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
    'style.vala',
)

executable(
    'mabi-shell',
    sources: [shell_src, resource],
    dependencies: [gtk4_layer_shell_dep, astal4_dep, astalio_dep, adw_dep],
    c_args: ['-w'],
)
