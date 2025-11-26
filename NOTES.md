# Notes

- Due to https://gitlab.gnome.org/GNOME/vala/-/issues/1515, `[GtkTemplate]` widgets need to explicitly override `dispose`, like this:
    ```vala
    public override void dispose() {
        dispose_template(typeof(MyWidget));
        base.dispose();
    }
    ```
