namespace NotificationFormatting {
interface Token : Object {
    public abstract FormattingNode to_node();
    public abstract string repr();
}

class TextToken : Token, Object {
    private string data;
    public TextToken(string data) {
        assert_nonnull(data);
        this.data = data;
    }

    public FormattingNode to_node() {
        return new FormattingNode(TEXT, data);
    }

    public string repr() {
        return @"Text(\"$data\")";
    }
}

class TagToken : Token, Object {
    public bool is_opening;
    public bool is_closing;
    public string tag_name;
    public string original;
    public TagToken(bool is_opening, bool is_closing, string tag_name, string original) {
        this.is_opening = is_opening;
        this.is_closing = is_closing;
        this.tag_name = tag_name;
        this.original = original;
    }

    public FormattingNodeType get_formatting_type() {
        switch (tag_name) {
        case "b":
            return BOLD;
        case "i":
            return ITALIC;
        case "u":
            return UNDERLINE;
        default:
            assert_not_reached();
        }
    }

    public FormattingNode to_node() {
        assert(is_opening);
        return new FormattingNode(get_formatting_type(), original);
    }

    public string repr() {
        return @"Tag(open=$is_opening, close=$is_closing, name=$tag_name, original=$original)";
    }
}

internal void literalize_top_of_stack(Gee.ArrayList<FormattingNode> stack) {
    var popped = stack.remove_at(stack.size - 1);
    var parent = stack[stack.size - 1];
    // transform it into a text node and move children into parent
    // This is quite gnarly. Thankfully it only happens in the bad case
    popped.type = TEXT;
    int popped_idx = -1;
    for (int j = 0; j < parent.children.length; j++) {
        if (parent.children[j] == popped) {
            popped_idx = j;
        }
    }
    assert(popped_idx != -1);
    parent.children.resize(parent.children.length + popped.children.length);
    parent.children.move(popped_idx + 1, popped_idx + 1 + popped.children.length, parent.children.length - popped_idx - 1);
    for (int j = 0; j < popped.children.length; j++) {
        parent.children[popped_idx + 1 + j] = popped.children[j];
    }
    popped.children.resize(0);
}

FormattedText parse(string markup) {
    var tokens = new Gee.ArrayList<Token>();
    int i = 0;
    int buffer_start = 0;

    while (i < markup.length) {
        if (markup[i] == '<') {
            if (buffer_start < i) {
                tokens.add(new TextToken(markup[buffer_start: i]));
            }

            int tag_end = i;
            char quote = '\0';
            while (tag_end < markup.length) {
                if (quote == '\0') {
                    if (markup[tag_end] == '>') {
                        break;
                    } else if (markup[tag_end] == '"') {
                        quote = '"';
                    } else if (markup[tag_end] == '\'') {
                        quote = '\'';
                    }
                } else {
                    if (markup[tag_end] == quote) {
                        quote = '\0';
                    }
                }
                tag_end++;
            }

            if (tag_end >= markup.length) {
                tokens.add(new TextToken(markup[i:]));
            } else {
                var tag = markup[i:tag_end + 1];
                bool is_opening;
                bool is_closing;
                var name_start = 1;
                if (tag.has_prefix("</")) {
                    is_opening = false;
                    is_closing = true;
                    name_start = 2;
                } else if (tag.has_suffix("/>")) {
                    is_opening = true;
                    is_closing = true;
                } else {
                    is_opening = true;
                    is_closing = false;
                }
                var name_end = name_start;
                while (tag[name_end] != ' ' && tag[name_end] != '>' && tag[name_end] != '/') {
                    name_end++;
                }
                var name = tag[name_start:name_end].ascii_down();

                tokens.add(new TagToken(is_opening, is_closing, name, tag));
            }

            i = tag_end + 1;
            buffer_start = i;
        } else {
            i++;
        }
    }
    if (buffer_start < i) {
        tokens.add(new TextToken(markup[buffer_start:]));
    }

    print("[");
    for (int j = 0; j < tokens.size; j++) {
        if (j > 0) {
            print(", ");
        }
        print("%s", tokens[j].repr());
    }
    print("]\n");

    var stack = new Gee.ArrayList<FormattingNode>();
    stack.add(new FormattingNode(ROOT, ""));

    foreach (var token in tokens) {
        assert(stack.size > 0);
        var parent = stack[stack.size - 1];

        if (token is TextToken) {
            parent.children += token.to_node();
        } else if (token is TagToken) {
            var tag = (TagToken)token;
            switch (tag.tag_name) {
            case "a":
            case "img":
                // completely ignore hyperlinks and images
                continue;
            case "b":
            case "i":
            case "u":
                // manipulate the formatting stack
                if (tag.is_opening && tag.is_closing) {
                    // the only self-closing tag that affects content is <img>, which we ignore
                    continue;
                } else if (tag.is_opening) {
                    var node = tag.to_node();
                    parent.children += node;
                    stack.add(node);
                } else if (tag.is_closing) {
                    var target_type = tag.get_formatting_type();
                    int last_idx = -1;
                    for (int j = stack.size - 1; j > 0; j--) {
                        if (stack[j].type == target_type) {
                            last_idx = j;
                            break;
                        }
                    }

                    if (last_idx == -1) {
                        // no matching open tag, so literalize this one
                        parent.children += new FormattingNode(TEXT, tag.original);
                    } else {
                        // flush nodes above last_idx
                        while (stack.size - 1 > last_idx) {
                            literalize_top_of_stack(stack);
                        }

                        // now, a correct node is at the top of the stack, so close it
                        stack.remove_at(stack.size - 1);
                    }
                } else {
                    warning("A non-opening and non-closing tag token was found. This is a bug.");
                }
                break;
            default:
                // unknown tag, emit original
                parent.children += new FormattingNode(TEXT, tag.original);
                break;
            }
        }
    }
    // literalize any remaining open nodes
    while (stack.size > 1) {
        literalize_top_of_stack(stack);
    }
    stack[0].print_repr();

    return stack[0].flatten();
}
}
