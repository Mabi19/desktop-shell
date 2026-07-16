---
name: check-c-code
description: Check the Vala compiler's generated C code. Useful to verify correctness of lower-level constructs and reference counting.
---

When using Meson (as mabi-shell does), the Vala compiler emits its intermediary C files in the build/ directory.
A file at `shell/(PATH).vala` can be found at `build/shell/mabi-shell.p/(PATH).c`.
You can read them to check that, for example, low-level constructs like plain arrays have correct memory management, and that the automatic reference counting is correct.
The C code contains #line directives on most lines mapping it back to the Vala code only in debug mode (which should be the default).
