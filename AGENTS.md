# Agent Guide for mabi-shell

This guide is for coding agents working on **mabi-shell**, a GTK4/Vala desktop shell for Hyprland.

## Commands

### Initial Setup
```bash
# Configure the build (only needed once)
meson setup build

# Reconfigure with different options
meson setup build --reconfigure --prefix=/usr/local
```

### Building
```bash
# Build the project
meson compile -C build

# Clean build artifacts
rm -rf build
```

### Code Quality
```bash
# Format code using uncrustify
uncrustify -c uncrustify.cfg --no-backup --replace shell/**/*.vala
```

## Project Structure

- `shell/` - Main source code directory
  - `bar/` - Top bar widgets (workspaces, audio, battery, etc.)
  - `service/` - Backend services (notifications, sound, system stats)
  - `side-panel/` - Right popup panel (notifications, clock)
  - `utils/` - Utility modules (colors, easing, texture cache)
  - `widgets/` - Reusable widget components
  - `style/` - SCSS stylesheets
  - `*.blp` - Blueprint UI definition files
  - `*.vala` - Vala source files
- `build/` - Meson build output (generated)
- `meson.build` - Build configuration
- `uncrustify.cfg` - Code formatting rules

## Code Style Guidelines

### Naming Conventions
- **Classes**: `PascalCase` (e.g., `WorkspaceButton`, `NotificationRule`)
- **Functions/Methods**: `snake_case` (e.g., `update_active()`, `handle_click()`)
- **Properties**: `snake_case` with hyphens in GObject properties (e.g., `primary_monitor_name`)
- **Constants**: `SCREAMING_SNAKE_CASE` (e.g., `MATRIX_OKLAB_TO_LMS`)
- **Private members**: Prefix with underscore or use `private` keyword
- **Signal handlers**: Prefix with `handle_` (e.g., `handle_scroll()`)
- **GTK callbacks**: Use `[GtkCallback]` attribute

### Type Annotations and Nullability
```vala
// Nullable types use ? suffix
public Gdk.Monitor? primary_monitor { get; private set; }
```

### Error Handling
```vala
// Use errordomain for custom errors
errordomain ConfigError {
    INVALID_STRUCTURE,
}

// Throw errors with descriptive messages
throw new ConfigError.INVALID_STRUCTURE("Root must be object");

// Use warning() for recoverable issues, error() for fatal issues
warning("Config: key '%s' has wrong type (should be string)", key);
error("Couldn't get GDK display");  // This terminates the program
```

### Object Construction
```vala
// Widget subclasses must use GObject-style construction
// (i.e. construct blocks; if any "regular" constructor functions exist, they must call the Object constructor and nothing else)
// This is because widgets are constructed by GTK via reflection, and code in constructor functions does not run.

// BatteryIndicator class
construct {
    device = AstalBattery.get_default();
    // ...
}
```

### GtkTemplate Widgets
**IMPORTANT**: Due to Vala bug #1515, all `[GtkTemplate]` widgets MUST override `dispose()`:

```vala
[GtkTemplate(ui = "/land/mabi/shell/ui/bar/bar.ui")]
class Bar : Astal.Window {
    // ... class content ...

    public override void dispose() {
        dispose_template(typeof(Bar));
        base.dispose();
    }
}
```

### Signals and Properties
```vala
// Connect to property changes
config.notify["primary-monitor-name"].connect(() => {
    recompute_primary_monitor();
});

// Define internal signals
internal signal string handle_dispatch(string[] args);

// Bind properties in Blueprint files
label: bind template.speaker as <AstalWp.Endpoint>.description;
```

### Blueprint Files (.blp)
- Use 4-space indentation
- Use `bind` for reactive properties
- Signal handlers use `=>` syntax: `clicked => $open_audio_mixer();`

### SCSS/Styling
- Organize styles by category (mostly top-level widgets) in `style/` directory
- Main stylesheet: `style.scss` imports all others

## Key Dependencies
- GTK4, Adwaita (libadwaita-1)
- gtk4-layer-shell (for Wayland layer shell)
- Astal libraries (astal-4, astal-io, astal-battery, astal-hyprland, astal-tray, astal-wireplumber)
- libgee-0.8 (collections library)
- glycin & glycin-gtk4 (image loading)
- json-glib-1.0 (JSON parsing)
- gsound (sound effects)

## Configuration
- Config location: `~/.config/mabi-shell/config.json`
- All config is optional; defaults exist for everything
- Config auto-reloads on file changes (500ms debounce)
- See README.md for full config schema

## Testing Notes
There is no automated test suite, since GTK apps' UI can't be automatically tested, and there isn't much else to test here.

## Common Patterns

### Accessing singletons
```vala
MabiShell.instance    // The application instance
MabiShell.config      // Global configuration
MabiShell.display     // GDK display
```

### Creating UI with static constructors
```vala
static construct {
    typeof(CpuIndicator).ensure();
    typeof(WorkspaceBox).ensure();
}
```

This ensures widget types are registered before template instantiation.

### Multi-monitor awareness
Widgets like `Bar` and `SidePanel` are instantiated once per monitor. If multiple widget instances need to reflect the same shared state (like the current time), that state must live in a singleton service (like `NotificationService`), and each widget instance should use a property binding. These are simple in Blueprint UI definitions:
```blp
Label {
    label: bind template.service as <$TimeService>.time_short as <string>;
}
```

If the state is mutable (e.g. a "Do not Disturb" toggle), a **bidirectional property binding** (`GLib.Object.bind_property` with `BIDIRECTIONAL | SYNC_CREATE`) deals with this cleanly (over a signal handler that writes to the service). This keeps all instances in sync automatically.

```vala
// Good: bidirectional binding keeps all instances in sync
var svc = NotificationService.get_default();
svc.bind_property("dont-disturb", dnd_button, "active",
    BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);

// Bad: callback only writes from one instance, doesn't sync others
dnd_button.toggled.connect(() => {
    svc.dont_disturb = dnd_button.active;
});
```
