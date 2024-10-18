import { App } from "astal/gtk3"
import { Bar } from "./bar/bar"
import style from "./style.scss"

App.start({
    css: style,
    main() {
        Bar(0)
        Bar(1)
    },
})
