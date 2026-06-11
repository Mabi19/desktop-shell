vapigen = find_program('vapigen')
g_ir_dep = dependency('gobject-introspection-1.0')
gir_dir = g_ir_dep.get_variable('girdir')

# A fake target to build a custom libnma-gtk4 VAPI, because the packaged one is wrong.
custom_target(
    'libnma-gtk4-vapi',
    command: [
        vapigen,
        gir_dir / 'NMA4-1.0.gir',
        '--library=libnma-gtk4',
        '--pkg=gtk4',
        '--pkg=libnm',
        '--directory=@0@'.format(meson.current_build_dir()),
        '--metadatadir=@0@'.format(meson.current_source_dir()),
        '--vapidir=@0@'.format(meson.current_build_dir()),
    ],
    output: 'libnma-gtk4.vapi',
    build_by_default: true,
)

add_project_arguments(['--vapidir', meson.current_build_dir()], language: 'vala')
