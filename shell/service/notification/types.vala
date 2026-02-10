enum NotificationUrgency {
    LOW = 0,
    NORMAL = 1,
    CRITICAL = 2,
}

enum NotificationClosedReason {
    EXPIRED = 1,
    DISMISSED_BY_USER = 2,
    CLOSED = 3,
    UNDEFINED = 4,
}

enum NotificationLayout {
    DEFAULT,
    MESSAGE,
}

class NotificationAction : Object {
    public string id { get; set; }
    public string label { get; set; }

    public NotificationAction(string id, string label) {
        Object(id: id, label: label);
    }
}
