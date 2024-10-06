import { App } from "astal"
import style from "./style.scss"
import Bar from "./widget/Bar"

App.start({
    css: style,
    main() {
        Bar(0)
        Bar(1)
    },
})
