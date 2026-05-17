import { Astal, Gtk, Gdk } from "astal/gtk4" // Asegúrate de usar astal/gtk4 si estás en v2
import Notifd from "gi://AstalNotifd"
import { Variable, bind } from "astal" // <--- AQUÍ ESTABA EL ERROR
import { App } from "astal/gtk4"

// 1. Obtenemos el servicio
const notifd = Notifd.get_default()

function NotificationItem(n: Notifd.Notification) {
    return (
        <box cssClasses={["Notification"]} vertical>
            <box cssClasses={["Header"]}>
                <icon icon={n.appIcon || "dialog-information"} />
                <label label={n.summary} truncate hexpand halign={Gtk.Align.START} />
            </box>
            <label label={n.body} wrap halign={Gtk.Align.START} />
        </box>
    )
}

export default function NotificationPopups(gdkmonitor: Gdk.Monitor) {
    const { TOP, RIGHT } = Astal.WindowAnchor

    return (
        <window
            name={`notifications-${gdkmonitor}`}
            gdkmonitor={gdkmonitor}
            exclusivity={Astal.Exclusivity.NONE}
            layer={Astal.Layer.OVERLAY}
            anchor={TOP | RIGHT}
            application={App}
            // En GTK4 css se usa cssClasses o un archivo css externo, 'css' inline a veces falla en ventana
        >
            <box vertical cssClasses={["NotificationList"]}>
                {/* 
                    OPTIMIZACIÓN:
                    En lugar de crear una Variable manual, usamos bind() directamente 
                    sobre la propiedad "notifications" del servicio Notifd.
                    Astal se encarga de escuchar las señales automáticamente.
                */}
                {bind(notifd, "notifications").as(list => 
                    list.map(n => NotificationItem(n))
                )}
            </box>
        </window>
    )
}
