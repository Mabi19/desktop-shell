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

enum NotificationFormatMethod {
    /** Standard markup, as in the FDO notification specification, version 1.2. */
    STANDARD,
    /** A markdown parser based on commonmark. */
    MARKDOWN,
}

class NotificationAction : Object {
    public string id { get; set; }
    public string label { get; set; }

    public NotificationAction(string id, string label) {
        Object(id: id, label: label);
    }
}
