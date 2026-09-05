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
    'bar/battery.blp',
    'bar/bluetooth/menu.blp',
    'bar/cpu-indicator.blp',
    'bar/memory-indicator.blp',
    'bar/network/menu.blp',
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
    # We include the NMA VAPI as a dependency here.
    # Including it in the executable or declared dependency means that it'll be put into the source list,
    # which makes valac emit a warning.
    # Depending on it here still makes the dependency work,
    # but the vapi file does not do anything for resource generation.
    dependencies: [compiled_styles, compiled_ui, libnma_gtk4_vapi],
    source_dir: meson.current_build_dir(),
)

shell_src = files(
    'bar/audio.vala',
    'bar/bar.vala',
    'bar/battery.vala',
    'bar/bluetooth/bluetooth.vala',
    'bar/bluetooth/button-item.vala',
    'bar/bluetooth/menu.vala',
    'bar/idle-inhibit.vala',
    'bar/network/connectivity.vala',
    'bar/network/ethernet.vala',
    'bar/network/menu.vala',
    'bar/network/wifi.vala',
    'bar/power-button.vala',
    'bar/system-usage.vala',
    'bar/time-button.vala',
    'bar/tray.vala',
    'bar/workspaces.vala',
    'osd/osd.vala',
    'service/bluetooth.vala',
    'service/idle.vala',
    'service/network.vala',
    'service/notification.vala',
    'service/notification/daemon.vala',
    'service/notification/markdown.vala',
    'service/notification/markup.vala',
    'service/notification/rules.vala',
    'service/notification/tree.vala',
    'service/notification/types.vala',
    'service/sound.vala',
    'service/system-usage.vala',
    'service/time.vala',
    'service/wifi-network.vala',
    'side-panel/notification-list.vala',
    'side-panel/notification-widget.vala',
    'side-panel/precise-clock.vala',
    'side-panel/side-panel.vala',
    'utils/color.vala',
    'utils/easing.vala',
    'utils/model-box-binding.vala',
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
        astal_bluetooth_dep,
        astal_cava_dep,
        astal_battery_dep,
        astal_tray_dep,
        astal_wl_dep, # Not needed once the deps files come in I think.
        astal_wl4_dep,
        wl_dep, # Same as above.
        gtk_wl_dep, # For debugging.
        astal_workspace_dep,
        astal_wp_dep,
        adw_dep,
        gee_dep,
        glycin_dep,
        glycin_gtk4_dep,
        gtk4_dep,
        gsound_dep,
        json_glib_dep,
        libcmark_dep,
        libnm_dep,
        libnma_gtk4_dep,
        style_context_shim_dep,
    ],
    c_args: ['-w'],
    link_args: ['-lm'],
    install: true,
)
