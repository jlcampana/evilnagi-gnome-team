#!/usr/bin/env bash
# Pone el botón "Mostrar aplicaciones" de Dash to Dock el primero del dock y con una imagen propia
# (por defecto el avatar de Bubble Bobble, guardado en el repo en tema/iconos/apps-propias/).
#
# Dash to Dock tiene ajustes para mostrar el botón y ponerlo al principio (show-show-apps-button,
# show-apps-at-top), pero no para cambiar su icono: eso lo hace una mini-extensión propia
# (boton-aplicaciones@pandi.local). Busca los docks (los que Dash to Dock añade a la interfaz, uno
# por monitor, que vuelve a crear al cambiar sus ajustes o los monitores) y cambia la función que
# crea el icono del botón por una que usa la imagen. La imagen se copia a
# ~/.local/share/icons/apps-propias/boton-aplicaciones.png.
#
# Uso:  boton-aplicaciones.sh               con la imagen ya copiada (o la de Bubble Bobble del repo)
#       boton-aplicaciones.sh <imagen>      con otra imagen (PNG, SVG o JPG; mejor cuadrada)
#       boton-aplicaciones.sh --quitar      quita la extensión y el botón (vuelve como estaba)
#
# Lo ejecuta el instalador del tema. Los ajustes del dock con el botón también están en
# tema/dconf/extensiones.dconf, así que extensiones.sh lo deja igual.
#
# Independiente: todo va dentro de este script (Fedora y Ubuntu, GNOME 46–50, con Dash to Dock).
# La primera vez hay que cerrar sesión para que GNOME cargue la extensión.

set -euo pipefail

UUID="boton-aplicaciones@pandi.local"
DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
IMG="$HOME/.local/share/icons/apps-propias/boton-aplicaciones.png"
REPO="jlcampana/evilnagi-gnome-team"
RAW="https://raw.githubusercontent.com/$REPO/main"
EN_REPO="tema/iconos/apps-propias/boton-aplicaciones.png"
DOCK=/org/gnome/shell/extensions/dash-to-dock  # con dconf: vale aunque Dash to Dock esté en ~/.local (sin esquema global)

activar() { # activar <uuid> true|false  (en enabled-extensions; vale aunque la shell aún no la conozca)
    python3 - "$1" "$2" <<'PY'
import ast, subprocess, sys
uuid, on = sys.argv[1], sys.argv[2] == "true"
k = ["org.gnome.shell", "enabled-extensions"]
l = ast.literal_eval(subprocess.check_output(["gsettings", "get", *k], text=True).replace("@as ", ""))
n = (l + [uuid] if uuid not in l else l) if on else [u for u in l if u != uuid]  # sin reordenar
if n != l:
    subprocess.check_call(["gsettings", "set", *k, str(n)])
PY
}

if [[ "${1:-}" == "--quitar" ]]; then
    activar "$UUID" false
    rm -rf "$DIR" "$IMG"
    dconf write $DOCK/show-show-apps-button false
    dconf write $DOCK/show-apps-at-top false
    echo "Botón de aplicaciones quitado (la extensión, del todo al cerrar sesión)."
    exit 0
fi

if ! gnome-extensions info dash-to-dock@micxgx.gmail.com >/dev/null 2>&1 &&
   ! gnome-extensions info ubuntu-dock@ubuntu.com >/dev/null 2>&1 &&
   ! gsettings list-schemas 2>/dev/null | grep -qx org.gnome.shell.extensions.dash-to-dock; then
    echo "Dash to Dock / Ubuntu Dock no está instalado." >&2
    exit 1
fi

# --- Imagen
# Sin imagen: la del repo (clon local si el script está dentro de él; si no, de GitHub)
ORIGEN="${1:-}"
if [[ -z "$ORIGEN" && ! -f "$IMG" ]]; then
    R="$(cd "$(dirname "$(realpath "$0")")/../.." && pwd)"
    if [[ -f "$R/$EN_REPO" ]]; then
        ORIGEN="$R/$EN_REPO"
    else
        ORIGEN="$(mktemp --suffix=.png)"; trap 'rm -f "$ORIGEN"' EXIT
        curl -fsSL --retry 3 "$RAW/$EN_REPO" -o "$ORIGEN" ||
            { echo "No se pudo descargar la imagen de $REPO" >&2; exit 1; }
    fi
fi
if [[ -n "$ORIGEN" ]]; then
    [[ -f "$ORIGEN" ]] || { echo "No encuentro la imagen: $ORIGEN" >&2; exit 1; }
    mkdir -p "$(dirname "$IMG")"
    [[ "$(realpath "$ORIGEN")" == "$(realpath -m "$IMG")" ]] || cp "$ORIGEN" "$IMG"
fi

# --- Extensión
mkdir -p "$DIR"
cat > "$DIR/metadata.json" <<'EOF'
{
  "uuid": "boton-aplicaciones@pandi.local",
  "name": "Botón de aplicaciones con imagen",
  "description": "Pone una imagen propia en el botón Mostrar aplicaciones de Dash to Dock. La crea boton-aplicaciones.sh.",
  "shell-version": ["46", "47", "48", "49", "50"]
}
EOF
cat > "$DIR/extension.js" <<'EOF'
// Imagen propia en el botón "Mostrar aplicaciones" de Dash to Dock. Generado por boton-aplicaciones.sh.
// El icono del botón lo crea BaseIcon.createIcon(size) cada vez que cambia el tamaño o el tema de
// iconos: se envuelve esa función para poner la imagen en el St.Icon que devuelve.
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const IMAGEN = GLib.build_filenamev([GLib.get_user_data_dir(), 'icons', 'apps-propias', 'boton-aplicaciones.png']);

export default class BotonAplicaciones extends Extension {
    enable() {
        this._gicon = Gio.FileIcon.new(Gio.File.new_for_path(IMAGEN));
        this._tocados = new Set();   // BaseIcon del botón con createIcon cambiado
        // Dash to Dock añade cada dock a Main.layoutManager.uiGroup (addChrome) y los rehace a menudo
        this._id = Main.layoutManager.uiGroup.connect('child-added', () => this._buscar());
        this._buscar();
    }

    _buscar() {
        for (const hijo of Main.layoutManager.uiGroup.get_children()) {
            const icono = hijo.dash?._showAppsIcon?.icon;
            if (!icono || this._tocados.has(icono))
                continue;
            const original = icono.createIcon;
            icono._createIconOriginal = original;
            icono.createIcon = size => {
                const actor = original(size);
                actor.fallbackIconName = null;
                actor.fallbackGicon = null;
                actor.gicon = this._gicon;
                return actor;
            };
            icono._createIconTexture(icono.iconSize);
            this._tocados.add(icono);
            icono.connect('destroy', () => this._tocados?.delete(icono));
        }
    }

    disable() {
        Main.layoutManager.uiGroup.disconnect(this._id);
        this._tocados.forEach(icono => {
            icono.createIcon = icono._createIconOriginal;
            delete icono._createIconOriginal;
            icono._createIconTexture(icono.iconSize);
        });
        this._tocados = null;
        this._gicon = null;
    }
}
EOF

dconf write $DOCK/show-show-apps-button true
dconf write $DOCK/show-apps-at-top true
activar "$UUID" true
echo "Botón de aplicaciones el primero del dock, con la imagen $IMG."
echo "Cierra sesión y vuelve a entrar para que GNOME cargue la extensión (hasta entonces sale el icono normal)."
