# Extensión de Nautilus (requiere el paquete nautilus-python):
# estrecha el panel lateral (atajos). Nautilus no deja arrastrarlo: lo fija al 20 %
# de la ventana entre 180 y 240 px. Aquí se cambian esos límites en cada ventana nueva.
import gi

gi.require_version("Adw", "1")
gi.require_version("Gtk", "4.0")
from gi.repository import Adw, GLib, GObject, Gtk, Nautilus

ANCHO_MIN = 150  # px (Nautilus: 180)
ANCHO_MAX = 190  # px (Nautilus: 240)


def buscar_split_view(widget):
    if isinstance(widget, Adw.OverlaySplitView):
        return widget
    hijo = widget.get_first_child()
    while hijo is not None:
        encontrado = buscar_split_view(hijo)
        if encontrado is not None:
            return encontrado
        hijo = hijo.get_next_sibling()
    return None


def ajustar_ventanas(*_):
    ventanas = Gtk.Window.get_toplevels()
    for i in range(ventanas.get_n_items()):
        split = buscar_split_view(ventanas.get_item(i))
        if split is not None and split.props.max_sidebar_width != ANCHO_MAX:
            split.props.min_sidebar_width = ANCHO_MIN
            split.props.max_sidebar_width = ANCHO_MAX
    return GLib.SOURCE_REMOVE


class PanelLateralEstrecho(GObject.GObject, Nautilus.MenuProvider):
    def __init__(self):
        super().__init__()
        # Cada vez que se abre una ventana; idle para que ya tenga sus widgets
        Gtk.Window.get_toplevels().connect(
            "items-changed", lambda *_: GLib.idle_add(ajustar_ventanas))
        GLib.idle_add(ajustar_ventanas)
