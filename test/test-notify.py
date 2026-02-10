#!/usr/bin/env python3
"""Send a test notification with image-data over D-Bus.

Generates a small gradient image in memory and sends it as an
image-data hint to org.freedesktop.Notifications.Notify.

Usage:
    ./test-notify.py          # RGBA (4 channels, with alpha gradient)
    ./test-notify.py --rgb    # RGB  (3 channels, no alpha)
"""

import argparse
import dbus


def make_gradient(width: int, height: int, has_alpha: bool) -> bytes:
    """Generate a simple gradient image as raw pixel bytes.

    Top-left is red, top-right is blue, bottom is green.
    If has_alpha, alpha fades from opaque (top) to semi-transparent (bottom).
    """
    channels = 4 if has_alpha else 3
    pixels = bytearray(width * height * channels)
    for y in range(height):
        for x in range(width):
            fx = x / (width - 1)
            fy = y / (height - 1)
            r = int(255 * (1 - fx) * (1 - fy))
            g = int(255 * fy)
            b = int(255 * fx * (1 - fy))
            off = (y * width + x) * channels
            pixels[off] = r
            pixels[off + 1] = g
            pixels[off + 2] = b
            if has_alpha:
                pixels[off + 3] = int(255 * (1 - 0.6 * fy))
    return bytes(pixels)


def main():
    parser = argparse.ArgumentParser(description="Send a test notification with image-data.")
    parser.add_argument("--rgb", action="store_true", help="Use RGB (3 channels) instead of RGBA (4 channels)")
    parser.add_argument("--size", type=int, default=64, help="Image width and height in pixels (default: 64)")
    args = parser.parse_args()

    has_alpha = not args.rgb
    w = h = args.size
    channels = 4 if has_alpha else 3
    bits_per_sample = 8
    rowstride = w * channels

    pixel_data = make_gradient(w, h, has_alpha)

    # image-data hint: (iiibiiay)
    image_data = (
        dbus.Int32(w),
        dbus.Int32(h),
        dbus.Int32(rowstride),
        dbus.Boolean(has_alpha),
        dbus.Int32(bits_per_sample),
        dbus.Int32(channels),
        dbus.ByteArray(pixel_data),
    )

    bus = dbus.SessionBus()
    proxy = bus.get_object("org.freedesktop.Notifications", "/org/freedesktop/Notifications")
    iface = dbus.Interface(proxy, "org.freedesktop.Notifications")

    mode = "RGB" if args.rgb else "RGBA"
    notification_id = iface.Notify(
        "test-notify",                          # app_name
        dbus.UInt32(0),                         # replaces_id
        "",                                     # app_icon (empty — use image-data)
        f"Test image-data ({mode})",            # summary
        f"{w}x{h} gradient, {channels}ch",     # body
        dbus.Array([], signature="s"),          # actions
        dbus.Dictionary(                        # hints
            {"image-data": image_data},
            signature="sv",
        ),
        dbus.Int32(5000),                       # expire_timeout ms
    )

    print(f"Sent notification id={notification_id} ({mode}, {w}x{h})")


if __name__ == "__main__":
    main()
