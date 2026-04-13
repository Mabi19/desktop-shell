namespace NotificationFormatting {
void terminate_line(CMark.Node node, StringBuilder sb) {
    // U+2028 in UTF-8 is E2 80 A8
    // We shouldn't start the document or any sub-blocks (like blockquotes or list items) with newlines.
    if (node.previous() != null && (sb.len < 3 || sb.data[sb.len - 1] != 0xa8 || sb.data[sb.len - 2] != 0x80 || sb.data[sb.len - 3] != 0xe2)) {
        sb.append("\u2028");
    }
}

void flatten_cmark_children(CMark.Node parent, StringBuilder sb, Pango.AttrList attrs) {
    unowned CMark.Node? node = parent.first_child();
    while (node != null) {
        flatten_cmark(node, sb, attrs);
        node = node.next();
    }
}

void flatten_cmark_list(CMark.Node list, StringBuilder sb, Pango.AttrList attrs) {
    unowned CMark.Node? list_item = list.first_child();
    var type = list.get_list_type();
    var counter = list.get_list_start();
    var delimiter_type = list.get_list_delim();
    unowned string delimiter = "";
    switch (delimiter_type) {
    case PERIOD_DELIM:
        delimiter = ".";
        break;
    case PAREN_DELIM:
        delimiter = ")";
        break;
    default:
        break;
    }

    terminate_line(list, sb);
    while (list_item != null) {
        if (list_item.get_type() != ITEM) {
            warning("Expected list child to be list item, but got %s instead", list_item.get_type_string());
            list_item = list_item.next();
            continue;
        }
        terminate_line(list_item, sb);
        switch (type) {
        case BULLET_LIST:
            sb.append("\u2022 ");
            break;
        case ORDERED_LIST:
            sb.append_printf("%d%s ", counter, delimiter);
            counter++;
            break;
        default:
            break;
        }
        flatten_cmark_children(list_item, sb, attrs);

        list_item = list_item.next();
    }
}

void flatten_cmark(CMark.Node node, StringBuilder sb, Pango.AttrList attrs) {
    var type = node.get_type();
    switch (type) {
    case CMark.NodeType.DOCUMENT:
        flatten_cmark_children(node, sb, attrs);
        break;
    case CMark.NodeType.LIST:
        flatten_cmark_list(node, sb, attrs);
        break;
    // Block format nodes
    case CMark.NodeType.CODE_BLOCK: {
        terminate_line(node, sb);
        var attr = Pango.attr_family_new("Monospace");
        attr.start_index = (uint)sb.len;
        sb.append(node.get_literal().chomp().replace("\n", "\u2028"));
        attr.end_index = (uint)sb.len;
        attrs.change((owned)attr);
        break;
    }
    case CMark.NodeType.PARAGRAPH:
        terminate_line(node, sb);
        flatten_cmark_children(node, sb, attrs);
        break;
    case CMark.NodeType.HEADING: {
        terminate_line(node, sb);
        var attr = Pango.attr_weight_new(Pango.Weight.BOLD);
        attr.start_index = (uint)sb.len;
        flatten_cmark_children(node, sb, attrs);
        if (node.next() != null) {
            sb.append("\u2028");
        }
        attr.end_index = (uint)sb.len;
        attrs.change((owned)attr);
        break;
    }
    // Inline format nodes
    case STRONG:
    case EMPH: {
        Pango.Attribute? attr = null;
        if (type == STRONG) {
            attr = Pango.attr_weight_new(Pango.Weight.BOLD);
        } else {
            attr = Pango.attr_style_new(Pango.Style.ITALIC);
        }
        attr.start_index = (uint)sb.len;
        flatten_cmark_children(node, sb, attrs);
        attr.end_index = (uint)sb.len;
        attrs.change((owned)attr);
        break;
    }
    // Leaf nodes
    case TEXT:
        sb.append(node.get_literal());
        break;
    case SOFTBREAK:
    case LINEBREAK:
        // Unicode line break instead of \n, because Pango interprets \n's as paragraph breaks
        // (which messes with ellipsization)
        sb.append("\u2028");
        break;
    case THEMATIC_BREAK:
        terminate_line(node, sb);
        sb.append("---");
        break;
    case CODE: {
        var attr = Pango.attr_family_new("Monospace");
        attr.start_index = (uint)sb.len;
        sb.append(node.get_literal());
        attr.end_index = (uint)sb.len;
        attrs.change((owned)attr);
        break;
    }
    // Unsupported nodes
    case IMAGE:
        sb.append("<image>");
        break;
    case LINK:
        sb.append(node.get_literal());
        break;
    case BLOCK_QUOTE:
        terminate_line(node, sb);
        sb.append("> ");
        flatten_cmark_children(node, sb, attrs);
        break;
    case HTML_BLOCK:
    case HTML_INLINE:
        sb.append(node.get_literal());
        break;
    default:
        warning("Unknown CMark node type %s", node.get_type_string());
        sb.append(node.get_literal());
        break;
    }
}

FormattedText parse_markdown(string raw_markdown) {
    var markdown = raw_markdown.strip();
    var root = CMark.parse_document(markdown, markdown.length, CMark.Option.DEFAULT);
    var sb = new StringBuilder();
    var attrs = new Pango.AttrList();

    flatten_cmark(root, sb, attrs);

    var result = FormattedText() {
        text = sb.free_and_steal(),
        attributes = attrs,
    };
    return result;
}
}
