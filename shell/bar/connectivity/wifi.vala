class ConnectivityIndicatorWifi : Gtk.Box {
    private NM.DeviceWifi? _device;
    private ulong[] _device_handler_ids = {};
    public NM.DeviceWifi? device {
        get {
            return _device;
        }
        set {
            if (_device != null) {
                foreach (var handler_id in _device_handler_ids) {
                    SignalHandler.disconnect(_device, handler_id);
                }
            }
            _device_handler_ids = {};
            _device = value;

            visible = (value != null);
            if (value != null) {
                update_icon();
                _device_handler_ids += value.notify["state"].connect(update_icon);
                _device_handler_ids += value.notify["ip4-connectivity"].connect(update_icon);
                _device_handler_ids += value.notify["ip6-connectivity"].connect(update_icon);
                _device_handler_ids += value.notify["active-access-point"].connect(update_icon);
            }
        }
    }

    private Gtk.Image icon;

    private void update_icon() {
        string icon_name;
        string tooltip;
        switch (_device.state) {
        case NM.DeviceState.UNKNOWN:
        case NM.DeviceState.UNMANAGED:
            icon_name = "network-wireless-no-route-symbolic";
            tooltip = "Unknown";
            break;
        case NM.DeviceState.UNAVAILABLE:
            icon_name = "network-wireless-offline-symbolic";
            tooltip = "Unavailable";
            break;
        case NM.DeviceState.DISCONNECTED:
            icon_name = "network-wireless-offline-symbolic";
            tooltip = "Disconnected";
            break;
        case NM.DeviceState.PREPARE:
        case NM.DeviceState.CONFIG:
        case NM.DeviceState.IP_CONFIG:
        case NM.DeviceState.IP_CHECK:
        case NM.DeviceState.SECONDARIES:
            icon_name = "network-wireless-acquiring-symbolic";
            tooltip = "Connecting...";
            break;
        case NM.DeviceState.NEED_AUTH:
            icon_name = "network-wireless-acquiring-symbolic";
            tooltip = "Connecting (authorization needed)...";
            break;
        case NM.DeviceState.ACTIVATED:
            if (_device.ip4_connectivity != FULL && _device.ip6_connectivity != FULL) {
                icon_name = "network-wireless-no-route-symbolic";
                tooltip = "Connected (no internet)";
            } else {
                var ap = _device.active_access_point;
                if (ap == null) {
                    icon_name = "network-wireless-symbolic";
                } else {
                    uint8 strength = ap.strength;
                    if (strength > 75) {
                        icon_name = "network-wireless-signal-excellent-symbolic";
                    } else if (strength > 50) {
                        icon_name = "network-wireless-signal-good-symbolic";
                    } else if (strength > 25) {
                        icon_name = "network-wireless-signal-ok-symbolic";
                    } else if (strength > 0) {
                        icon_name = "network-wireless-signal-weak-symbolic";
                    } else {
                        icon_name = "network-wireless-signal-none-symbolic";
                    }
                }

                if (ap != null && ap.ssid != null) {
                    var ssid_data = ap.ssid.get_data();
                    if (ssid_data != null && ssid_data.length > 0) {
                        tooltip = "Connected to %s".printf(NM.Utils.ssid_to_utf8(ssid_data));
                    } else {
                        tooltip = "Connected";
                    }
                } else {
                    tooltip = "Connected";
                }
            }
            break;
        case NM.DeviceState.DEACTIVATING:
            icon_name = "network-wireless-offline-symbolic";
            tooltip = "Disconnecting...";
            break;
        case NM.DeviceState.FAILED:
            icon_name = "network-wireless-offline-symbolic";
            tooltip = "Failed to connect";
            break;
        default:
            icon_name = "network-wireless-no-route-symbolic";
            tooltip = "Unknown";
            break;
        }
        icon.icon_name = icon_name;
        set_tooltip_text(tooltip);
    }

    construct {
        visible = false;
        icon = new Gtk.Image();
        icon.icon_name = "network-wireless-no-route-symbolic";
        append(icon);
    }
}
