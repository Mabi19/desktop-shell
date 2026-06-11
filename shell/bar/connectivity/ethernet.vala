class ConnectivityIndicatorEthernet : Gtk.Box {
    private NM.DeviceEthernet? _device;
    private ulong[] _device_handler_ids = {};
    public NM.DeviceEthernet? device {
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
                update_status();
                ulong id;
                id = value.notify["state"].connect(update_status);
                _device_handler_ids += id;
                id = value.notify["ip4-connectivity"].connect(update_status);
                _device_handler_ids += id;
                id = value.notify["ip6-connectivity"].connect(update_status);
                _device_handler_ids += id;
            }
        }
    }

    private Gtk.Image icon;

    private void update_status() {
        string icon_name;
        string tooltip;
        switch (_device.state) {
        case NM.DeviceState.UNKNOWN:
        case NM.DeviceState.UNMANAGED:
            icon_name = "network-wired-no-route-symbolic";
            tooltip = "Unknown";
            break;
        case NM.DeviceState.UNAVAILABLE:
            icon_name = "network-wired-offline-symbolic";
            tooltip = "Unplugged";
            break;
        case NM.DeviceState.DISCONNECTED:
            icon_name = "network-wired-offline-symbolic";
            tooltip = "Disconnected";
            break;
        case NM.DeviceState.PREPARE:
        case NM.DeviceState.CONFIG:
        case NM.DeviceState.IP_CONFIG:
        case NM.DeviceState.IP_CHECK:
        case NM.DeviceState.SECONDARIES:
            icon_name = "network-wired-acquiring-symbolic";
            tooltip = "Connecting...";
            break;
        case NM.DeviceState.NEED_AUTH:
            icon_name = "network-wired-acquiring-symbolic";
            tooltip = "Connecting (authorization needed)...";
            break;
        case NM.DeviceState.ACTIVATED:
            if (_device.ip4_connectivity != FULL && _device.ip6_connectivity != FULL) {
                icon_name = "network-wired-no-route-symbolic";
                tooltip = "Connected (no internet)";
            } else {
                icon_name = "network-wired-symbolic";
                tooltip = "Connected";
            }
            break;
        case NM.DeviceState.DEACTIVATING:
            icon_name = "network-wired-offline-symbolic";
            tooltip = "Disconnecting...";
            break;
        case NM.DeviceState.FAILED:
            icon_name = "network-wired-offline-symbolic";
            tooltip = "Failed to connect";
            break;
        default:
            icon_name = "network-wired-no-route-symbolic";
            tooltip = "Unknown";
            break;
        }
        icon.icon_name = icon_name;
        set_tooltip_text(tooltip);
    }

    construct {
        visible = false;
        icon = new Gtk.Image();
        icon.icon_name = "network-wired-no-route-symbolic";
        append(icon);
    }
}
