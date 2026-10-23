#!/usr/bin/env bash
# Pone en rojo (el mismo que el botón de cerrar de gtk-compacto.sh, #e5484d) el fondo del botón
# de apagar del menú de Ajustes rápidos (con el icono en blanco) y el botón de confirmar de dos tipos de diálogo de GNOME Shell:
#   - Apagar, Reiniciar y Cerrar sesión
#   - Ventanas de contraseña (clase prompt-dialog): la de autenticación de administrador
#     (polkit) y también la del llavero, la de una wifi y la de montar un disco; por CSS no
#     se pueden distinguir
#
# Esos diálogos no son GTK sino de GNOME Shell, así que gtk.css no les afecta: el estilo va
# en una mini-extensión propia (botones-sesion@pandi.local) que solo trae un stylesheet.css.
# Sus botones no llevan ninguna clase distintiva; "Cancelar" es siempre el primero, así que
# se pintan de rojo todos menos el primero (también "Opciones de arranque", que sale con Alt).
#
# Uso:  botones-sesion-rojos.sh                    instala/actualiza la mini-extensión y la activa
#       botones-sesion-rojos.sh --color '#c01c28'  con otro color
#       botones-sesion-rojos.sh --quitar           la desinstala
#
# Independiente: todo va dentro de este script (Fedora y Ubuntu, GNOME 46–50). La primera vez
# hay que cerrar sesión para que GNOME cargue la extensión; después, los cambios de color se
# aplican al momento.

set -euo pipefail

UUID="botones-sesion@pandi.local"
DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
COLOR="#e5484d"

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
cargada() { gnome-extensions info "$UUID" 2>/dev/null | grep -iE 'ACTIVE|ACTIVA' >/dev/null; }

case "${1:-}" in
    --quitar)
        activar "$UUID" false
        rm -rf "$DIR"
        echo "Botones rojos quitados. Cierra sesión para que desaparezcan del todo."
        exit 0
        ;;
    --color)
        [[ "${2:-}" =~ ^#[0-9a-fA-F]{6}$ ]] || { echo "Color no válido: usa el formato #rrggbb" >&2; exit 1; }
        COLOR="$2"
        ;;
    "") ;;
    *)
        echo "Uso: $(basename "$0") [--color '#rrggbb' | --quitar]" >&2
        exit 1
        ;;
esac

tono() { # tono <#rrggbb> <factor>: multiplica cada canal, con tope en 255
    python3 -c "import sys; c=sys.argv[1]; f=float(sys.argv[2]); print('#'+''.join('%02x'%min(255,round(int(c[i:i+2],16)*f)) for i in (1,3,5)))" "$1" "$2"
}
CLARO="$(tono "$COLOR" 1.06)"
OSCURO="$(tono "$COLOR" 0.87)"

reglas() { # reglas <selector de botón>: rojo en todos menos el primero (Cancelar)
    local P="$1"
    cat <<EOF
$P {
  color: #ffffff;
  background-color: $COLOR;
}

$P:hover,
$P:focus:hover {
  background-color: $CLARO;
}

$P:active,
$P:active:hover,
$P:active:focus {
  background-color: $OSCURO;
}

$P:focus {
  background-color: $COLOR;
}

/* Cancelar */
$P:first-child {
  background-color: rgba(255, 255, 255, 0.1);
}

$P:first-child:hover {
  background-color: rgba(255, 255, 255, 0.13);
}

$P:first-child:active {
  background-color: rgba(255, 255, 255, 0.16);
}

$P:first-child:focus {
  background-color: st-mix(st-mix(-st-accent-color, #ffffff, 60%), rgba(255, 255, 255, 0.1), 5%);
}
EOF
}

mkdir -p "$DIR"
cat > "$DIR/metadata.json" <<'EOF'
{
  "uuid": "botones-sesion@pandi.local",
  "name": "Botones de sesión rojos",
  "description": "Icono de apagar del menú y botón de confirmar de los diálogos de Apagar, Reiniciar, Cerrar sesión y contraseña en rojo. Extensión local, solo añade stylesheet.css (la crea botones-sesion-rojos.sh).",
  "shell-version": ["46", "47", "48", "49", "50"]
}
EOF
cat > "$DIR/extension.js" <<'EOF'
// Sin lógica: GNOME Shell carga stylesheet.css mientras la extensión está activa.
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

export default class BotonesSesion extends Extension {
    enable() {}
    disable() {}
}
EOF
{
    cat <<EOF
/* Botón de confirmar en rojo ($COLOR). Generado por botones-sesion-rojos.sh.
   "Cancelar" es siempre el primer botón y conserva el estilo normal de GNOME
   (valores del tema oscuro de GNOME Shell 50). */

/* Apagar / Reiniciar / Cerrar sesión */
EOF
    reglas ".modal-dialog.end-session-dialog .modal-dialog-button-box .modal-dialog-button"
    echo
    echo "/* Ventanas de contraseña: autenticación (polkit), llavero, wifi, montar discos */"
    reglas ".modal-dialog.prompt-dialog .modal-dialog-button-box .modal-dialog-button"
    cat <<EOF

/* Botón de apagar del menú de Ajustes rápidos (el último de la fila de arriba): fondo rojo e
   icono blanco, como el botón de cerrar ventanas */
.quick-settings-system-item > StBoxLayout > .icon-button:last-child {
  color: #ffffff;
  background-color: $COLOR;
}

.quick-settings-system-item > StBoxLayout > .icon-button:last-child:hover,
.quick-settings-system-item > StBoxLayout > .icon-button:last-child:focus {
  background-color: $CLARO;
}

.quick-settings-system-item > StBoxLayout > .icon-button:last-child:active,
.quick-settings-system-item > StBoxLayout > .icon-button:last-child:checked {
  background-color: $OSCURO;
}
EOF
} > "$DIR/stylesheet.css"

activar "$UUID" true
if cargada; then
    # Ya cargada: desactivar y activar hace que GNOME vuelva a leer el stylesheet.css
    # (y luego se deja la lista de extensiones activas en su orden original)
    LISTA="$(gsettings get org.gnome.shell enabled-extensions)"
    gnome-extensions disable "$UUID" && gnome-extensions enable "$UUID"
    gsettings set org.gnome.shell enabled-extensions "$LISTA"
    echo "Botones de confirmar en rojo ($COLOR): aplicado ya."
else
    echo "Botones de confirmar en rojo ($COLOR): cierra sesión y vuelve a entrar para que GNOME cargue la extensión."
fi
