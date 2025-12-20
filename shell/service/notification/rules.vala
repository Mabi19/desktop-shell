class NotificationRule : Object {
    public class Condition {
        public Regex? summary;
        public Regex? body;
        public Regex? category;
        public Regex? app_name;
        public Regex? desktop_entry;
        public AstalNotifd.Urgency? urgency;

        public bool matches(NotificationProxy proxy) {
            if (summary != null && !summary.match(proxy.summary)) {
                return false;
            }
            if (body != null && !body.match(proxy.body)) {
                return false;
            }
            if (category != null && !category.match(proxy.category)) {
                return false;
            }
            if (app_name != null && !app_name.match(proxy.app_name)) {
                return false;
            }
            if (desktop_entry != null && !desktop_entry.match(proxy.desktop_entry)) {
                return false;
            }
            if (urgency != null && urgency != proxy.urgency) {
                return false;
            }
            return true;
        }

        public static Condition? from_json(Json.Object obj) {
            var condition = new Condition();

            if (obj.has_member("summary")) {
                var node = obj.get_member("summary");
                if (node.get_value_type() == Type.STRING) {
                    try {
                        condition.summary = new Regex(obj.get_string_member("summary"));
                    } catch (RegexError e) {
                        warning("Config: invalid notification rule (summary regex error: %s)", e.message);
                        return null;
                    }
                } else {
                    warning("Config: invalid notification rule (summary should be string)");
                    return null;
                }
            }
            if (obj.has_member("body")) {
                var node = obj.get_member("body");
                if (node.get_value_type() == Type.STRING) {
                    try {
                        condition.body = new Regex(obj.get_string_member("body"));
                    } catch (RegexError e) {
                        warning("Config: invalid notification rule (body regex error: %s)", e.message);
                        return null;
                    }
                } else {
                    warning("Config: invalid notification rule (body should be string)");
                    return null;
                }
            }
            if (obj.has_member("category")) {
                var node = obj.get_member("category");
                if (node.get_value_type() == Type.STRING) {
                    try {
                        condition.category = new Regex(obj.get_string_member("category"));
                    } catch (RegexError e) {
                        warning("Config: invalid notification rule (category regex error: %s)", e.message);
                        return null;
                    }
                } else {
                    warning("Config: invalid notification rule (category should be string)");
                    return null;
                }
            }
            if (obj.has_member("app_name")) {
                var node = obj.get_member("app_name");
                if (node.get_value_type() == Type.STRING) {
                    try {
                        condition.app_name = new Regex(obj.get_string_member("app_name"));
                    } catch (RegexError e) {
                        warning("Config: invalid notification rule (app_name regex error: %s)", e.message);
                        return null;
                    }
                } else {
                    warning("Config: invalid notification rule (app_name should be string)");
                    return null;
                }
            }
            if (obj.has_member("desktop_entry")) {
                var node = obj.get_member("desktop_entry");
                if (node.get_value_type() == Type.STRING) {
                    try {
                        condition.desktop_entry = new Regex(obj.get_string_member("desktop_entry"));
                    } catch (RegexError e) {
                        warning("Config: invalid notification rule (desktop_entry regex error: %s)", e.message);
                        return null;
                    }
                } else {
                    warning("Config: invalid notification rule (desktop_entry should be string)");
                    return null;
                }
            }
            if (obj.has_member("urgency")) {
                var node = obj.get_member("urgency");
                if (node.get_value_type() == Type.STRING) {
                    var urgency_str = obj.get_string_member("urgency");
                    switch (urgency_str) {
                    case "low":
                        condition.urgency = AstalNotifd.Urgency.LOW;
                        break;
                    case "normal":
                        condition.urgency = AstalNotifd.Urgency.NORMAL;
                        break;
                    case "critical":
                        condition.urgency = AstalNotifd.Urgency.CRITICAL;
                        break;
                        default:
                        warning("Config: invalid notification rule (urgency should be \"low\" | \"normal\" | \"critical\")");
                        return null;
                    }
                } else {
                    warning("Config: invalid notification rule (urgency should be \"low\" | \"normal\" | \"critical\")");
                    return null;
                }
            }

            return condition;
        }
    }

    public class Effect {
        public NotificationLayout? layout;
        public string? category;
        public string? app_name;
        public bool? transient;
        public bool? resident;
        public AstalNotifd.Urgency? urgency;
        public bool? action_icons;
        public bool? suppress_sound;

        public void apply(NotificationProxy proxy) {
            if (layout != null) {
                proxy.layout = layout;
            }
            if (category != null) {
                proxy.category = category;
            }
            if (app_name != null) {
                proxy.app_name = app_name;
            }
            if (transient != null) {
                proxy.transient = transient;
            }
            if (resident != null) {
                proxy.resident = resident;
            }
            if (urgency != null) {
                proxy.urgency = urgency;
            }
            if (action_icons != null) {
                proxy.action_icons = action_icons;
            }
            if (suppress_sound != null) {
                proxy.suppress_sound = suppress_sound;
            }
        }

        public static Effect? from_json(Json.Object obj) {
            var effect = new Effect();

            if (obj.has_member("layout")) {
                var node = obj.get_member("layout");
                if (node.get_value_type() == Type.STRING) {
                    var layout_str = obj.get_string_member("layout");
                    switch (layout_str) {
                    case "default":
                        effect.layout = DEFAULT;
                        break;
                    case "message":
                        effect.layout = MESSAGE;
                        break;
                        default:
                        warning("Config: invalid notification rule (layout should be \"default\" | \"message\"))");
                        return null;
                    }
                } else {
                    warning("Config: invalid notification rule (layout should be \"default\" | \"message\"))");
                    return null;
                }
            }
            if (obj.has_member("category")) {
                var node = obj.get_member("category");
                if (node.get_value_type() == Type.STRING) {
                    effect.category = obj.get_string_member("category");
                } else {
                    warning("Config: invalid notification rule (category should be string)");
                    return null;
                }
            }
            if (obj.has_member("app_name")) {
                var node = obj.get_member("app_name");
                if (node.get_value_type() == Type.STRING) {
                    effect.app_name = obj.get_string_member("app_name");
                } else {
                    warning("Config: invalid notification rule (app_name should be string)");
                    return null;
                }
            }
            if (obj.has_member("transient")) {
                var node = obj.get_member("transient");
                if (node.get_value_type() == Type.BOOLEAN) {
                    effect.transient = obj.get_boolean_member("transient");
                } else {
                    warning("Config: invalid notification rule (transient should be boolean)");
                    return null;
                }
            }
            if (obj.has_member("resident")) {
                var node = obj.get_member("resident");
                if (node.get_value_type() == Type.BOOLEAN) {
                    effect.resident = obj.get_boolean_member("resident");
                } else {
                    warning("Config: invalid notification rule (resident should be boolean)");
                    return null;
                }
            }
            if (obj.has_member("urgency")) {
                var node = obj.get_member("urgency");
                if (node.get_value_type() == Type.STRING) {
                    var urgency_str = obj.get_string_member("urgency");
                    switch (urgency_str) {
                    case "low":
                        effect.urgency = AstalNotifd.Urgency.LOW;
                        break;
                    case "normal":
                        effect.urgency = AstalNotifd.Urgency.NORMAL;
                        break;
                    case "critical":
                        effect.urgency = AstalNotifd.Urgency.CRITICAL;
                        break;
                    default:
                        warning("Config: invalid notification rule (urgency should be \"low\" | \"normal\" | \"critical\")");
                        return null;
                    }
                } else {
                    warning("Config: invalid notification rule (urgency should be \"low\" | \"normal\" | \"critical\")");
                    return null;
                }
            }
            if (obj.has_member("action_icons")) {
                var node = obj.get_member("action_icons");
                if (node.get_value_type() == Type.BOOLEAN) {
                    effect.action_icons = obj.get_boolean_member("action_icons");
                } else {
                    warning("Config: invalid notification rule (action_icons should be boolean)");
                    return null;
                }
            }
            if (obj.has_member("suppress_sound")) {
                var node = obj.get_member("suppress_sound");
                if (node.get_value_type() == Type.BOOLEAN) {
                    effect.suppress_sound = obj.get_boolean_member("suppress_sound");
                } else {
                    warning("Config: invalid notification rule (suppress_sound should be boolean)");
                    return null;
                }
            }

            return effect;
        }
    }

    public Condition? condition { get; set; }
    public Effect effect { get; set; }

    public NotificationRule(Condition? condition, Effect effect) {
        Object(condition: condition, effect: effect);
    }

    public void evaluate(NotificationProxy proxy) {
        if (condition == null || condition.matches(proxy)) {
            debug("rule applies!");
            effect.apply(proxy);
        }
    }

    public static NotificationRule? from_json(Json.Object obj) {
        Condition? cond = null;
        var cond_node = obj.get_member("if");
        if (cond_node != null && !cond_node.is_null()) {
            if (cond_node.get_node_type() == Json.NodeType.OBJECT) {
                cond = Condition.from_json(cond_node.get_object());
            }
        }

        var effect_node = obj.get_member("then");
        if (effect_node == null || effect_node.get_node_type() != Json.NodeType.OBJECT) {
            warning("Config: invalid notification rule (no \"then\" clause)");
            return null;
        }
        var effect = Effect.from_json(effect_node.get_object());
        if (effect == null) {
            return null;
        }

        return new NotificationRule(cond, effect);
    }
}
