namespace NotificationFormatting {
enum FormattingNodeType {
    ROOT,
    TEXT,
    BOLD,
    ITALIC,
    UNDERLINE,
}

struct FormattedText {
    string text;
    Pango.AttrList attributes;
}

class FormattingNode {
    public FormattingNodeType type;
    public FormattingNode[] children;
    public string text;

    public FormattingNode(FormattingNodeType type, string text) {
        this.type = type;
        this.text = text;
        this.children = {};
    }

    public void print_repr() {
        switch (type) {
        case TEXT:
            print("\"%s\"", this.text);
            break;
        case ROOT:
        case BOLD:
        case ITALIC:
        case UNDERLINE:
            if (type != ROOT) {
                var str = type.to_string();
                str = str.slice(str.last_index_of_char('_', 0) + 1, str.length);
                print("%s(", str);
            }
            for (int i = 0; i < children.length; i++) {
                if (i > 0) {
                    print(", ");
                }
                children[i].print_repr();
            }
            if (type != ROOT) {
                print(")");
            } else {
                print("\n");
            }
            break;
        }
    }

    private int flatten_internal(StringBuilder sb, Pango.AttrList attrs, int offset) {
        if (type == TEXT) {
            sb.append(text);
            offset += text.length;
        } else {
            var start = offset;
            foreach (var child in children) {
                offset = child.flatten_internal(sb, attrs, offset);
            }
            var end = offset;
            Pango.Attribute? attribute = null;
            switch (type) {
            case BOLD:
                attribute = Pango.attr_weight_new(Pango.Weight.BOLD);
                break;
            case ITALIC:
                attribute = Pango.attr_style_new(Pango.Style.ITALIC);
                break;
            case UNDERLINE:
                attribute = Pango.attr_underline_new(Pango.Underline.SINGLE);
                break;
            case ROOT:
                // a root node does not carry formatting, only its children
                break;
            default:
                assert_not_reached();
            }

            if (attribute != null) {
                attribute.start_index = start;
                attribute.end_index = end;
                attrs.change((owned)attribute);
            }
        }

        return offset;
    }

    public FormattedText flatten() {
        assert(type == ROOT);
        var sb = new StringBuilder();
        var attrs = new Pango.AttrList();

        flatten_internal(sb, attrs, 0);

        var result = FormattedText() {
            text = sb.free_and_steal(), attributes = attrs
        };
        return result;
    }
}
}
