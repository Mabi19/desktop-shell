project('mabi-shell', version: '0.1')

prefix = get_option('prefix')
pkgdatadir = prefix / get_option('datadir') / meson.project_name()
bindir = prefix / get_option('bindir')

install_data(
    files('hyprland.conf'),
    install_dir: pkgdatadir,
)

install_subdir('icons', install_dir: pkgdatadir)

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
    input: files('app.ts'),
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
