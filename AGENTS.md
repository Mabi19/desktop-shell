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

### Blueprint Files (.blp)
- Use 4-space indentation
- Use `bind` for reactive properties
- Signal handlers use `=>` syntax: `clicked => $open_audio_mixer();`

## Common Patterns

### Looking up library APIs
Several relatively-unknown libraries (like Astal) are used in this project.
If you don't know a library, you can usually find its VAPI definitions in `/usr/share/vala/vapi` - these contain the library's symbols in Vala syntax, and their GIR metadata files in `/usr/share/gir` - these are XML-based and a lot more verbose, but they also contain doc comments in addition to the pure documentation. You should have read access to both of these directories.

Some very common libraries, like GTK, have their VAPIs shipped with Vala, in `/usr/share/vala-{vala version}/vapi`.

### Accessing singletons
```vala
MabiShell.instance    // The application instance
MabiShell.config      // Global configuration
MabiShell.display     // GDK display
```

### Creating UI with static constructors
Any widgets referenced in a Blueprint file must be registered with the type system in a `static construct` block.
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

### Connecting to signals
Avoid connecting to signals with lambda (`() => {}`) functions. These take hard references on their captures and it's easy to make reference cycles with them. Connecting using a GObject method as the handler instead uses the g_signal_connect_object function, which does not take a reference and the signal handler is automatically cleaned up when either of the objects are destroyed.
