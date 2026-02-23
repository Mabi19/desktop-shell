// This shim adds an alternative way to call Gtk.StyleContext.add_provider_for_display.
// This is because just mentioning the StyleContext prints a deprecation warning, even though
// the function itself is explicitly NOT deprecated.

[CCode(cheader_filename = "gtk/gtk.h", lower_case_cprefix = "gtk_style_context_")]
namespace StyleContextShim {
void add_provider_for_display(Gdk.Display display, Gtk.StyleProvider provider, uint priority);
}
