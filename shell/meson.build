shell_src = files('app.vala')

executable(
    'mabi-shell',
    shell_src,
    dependencies: [gtk4_dep, astal4_dep, astalio_dep, adw_dep],
    c_args: ['-w'],
)
