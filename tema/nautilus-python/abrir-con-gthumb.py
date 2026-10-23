# Extensión de Nautilus (requiere el paquete nautilus-python):
# añade "Abrir con gThumb" al menú contextual de carpetas e imágenes, y del fondo de la vista.
import subprocess

from gi.repository import GObject, Nautilus


def abrir(uris):
    subprocess.Popen(["gthumb", *uris], start_new_session=True)


class AbrirConGthumb(GObject.GObject, Nautilus.MenuProvider):
    def get_file_items(self, files):
        # Carpetas e imágenes; no cambia la app por defecto de nada
        if not files or not all(f.is_directory() or f.get_mime_type().startswith("image/") for f in files):
            return []
        item = Nautilus.MenuItem(name="AbrirConGthumb::archivos", label="Abrir con gThumb")
        item.connect("activate", lambda *_: abrir([f.get_uri() for f in files]))
        return [item]

    def get_background_items(self, folder):
        item = Nautilus.MenuItem(name="AbrirConGthumb::fondo", label="Abrir esta carpeta con gThumb")
        item.connect("activate", lambda *_: abrir([folder.get_uri()]))
        return [item]
