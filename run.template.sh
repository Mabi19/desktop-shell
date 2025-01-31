#!/bin/bash
LD_PRELOAD="@LAYER_SHELL_LIBDIR@/libgtk4-layer-shell.so" gjs -m @JS_BUNDLE_FILE@ $@
