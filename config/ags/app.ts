import app from "ags/gtk4/app"
import style from "./style.scss"
import NotificationPopups from "./widget/Notification" // <-- Tu nuevo archivo corregido

app.start({
  css: style,
  main() {
    app.get_monitors().map(NotificationPopups)
  },
})
