# Extensión de Nautilus (requiere el paquete nautilus-python):
# aplica a las ventanas de Nautilus la opacidad elegida en el botón "Transparencias"
# de Ajustes rápidos (extensión de GNOME transparencias@pandi.local), en directo.
import os

import gi

gi.require_version("Gtk", "4.0")
from gi.repository import Gio, GLib, GObject, Gtk, Nautilus

SCHEMA = "org.gnome.shell.extensions.transparencias"
DIR_SCHEMAS = os.path.expanduser(
    "~/.local/share/gnome-shell/extensions/transparencias@pandi.local/schemas")


def cargar_ajustes():
    if not os.path.isdir(DIR_SCHEMAS):
        return None
    fuente = Gio.SettingsSchemaSource.new_from_directory(
        DIR_SCHEMAS, Gio.SettingsSchemaSource.get_default(), False)
    schema = fuente.lookup(SCHEMA, False)
    return Gio.Settings.new_full(schema, None, None) if schema else None


class OpacidadNautilus(GObject.GObject, Nautilus.MenuProvider):
    def __init__(self):
        super().__init__()
        self.ajustes = cargar_ajustes()
        if self.ajustes is None:
            return
        self.ajustes.connect("changed::nautilus-opacity", lambda *_: self.aplicar())
        Gtk.Window.get_toplevels().connect(
            "items-changed", lambda *_: GLib.idle_add(self.aplicar))
        GLib.idle_add(self.aplicar)

    def aplicar(self, *_):
        opacidad = self.ajustes.get_double("nautilus-opacity")
        ventanas = Gtk.Window.get_toplevels()
        for i in range(ventanas.get_n_items()):
            ventana = ventanas.get_item(i)
            # Solo ventanas de Nautilus (no diálogos ni menús emergentes)
            if ventana.has_css_class("nautilus-window") and ventana.get_opacity() != opacidad:
                ventana.set_opacity(opacidad)
        return GLib.SOURCE_REMOVE
