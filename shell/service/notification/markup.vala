namespace NotificationMarkup {
interface Token : Object {
    public abstract string to_string();
    public abstract string repr();
}

class TextToken : Token, Object {
    private string data;
    public TextToken(string data) {
        this.data = data;
    }

    public string to_string() {
        return data;
    }

    public string repr() {
        return @"Text(\"$data\")";
    }
}

class TagToken : Token, Object {
    private bool is_opening;
    private bool is_closing;
    private string tag_name;
    private string original;
    public TagToken(bool is_opening, bool is_closing, string tag_name, string original) {
        this.is_opening = is_opening;
        this.is_closing = is_closing;
        this.tag_name = tag_name;
        this.original = original;
    }

    public string to_string() {
        return original;
    }

    public string repr() {
        return @"Tag(open=$is_opening, close=$is_closing, name=$tag_name, original=$original)";
    }
}

void parse(string markup) {
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

            if (tag_end > markup.length) {
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

    // TODO: actually use the tokens to create a PangoAttrList
}
}
