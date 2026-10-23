#!/usr/bin/env bash
# Barra superior y dock del mismo gris que el panel lateral de Nautilus en Adwaita oscuro
# (#2e2e32) al 95 % de opacidad.
#
#   - Dock: ajustes de Dash to Dock (Ubuntu Dock usa el mismo esquema, así que vale igual).
#   - Barra superior: mini-extensión propia barra-nautilus@pandi.local que solo trae un
#     stylesheet.css con la regla de #panel (encima del tema normal de GNOME, sin sustituirlo).
#   - Blur my Shell: se le desactivan el blur y "override-background" de la barra, porque si no
#     le pone la clase transparent-panel y la deja transparente aunque no haya blur.
#
# Uso:  barra-dock-gris.sh                                  aplica con #2e2e32 al 95 %
#       barra-dock-gris.sh --color '#rrggbb' --opacidad 0.9  con otro color u opacidad
#       barra-dock-gris.sh --quitar                         vuelve al dock y la barra de GNOME
#
# Independiente: todo va dentro de este script (Fedora y Ubuntu, GNOME 46–50). La primera vez
# hay que cerrar sesión para que GNOME cargue la extensión de la barra; después, los cambios
# de color se aplican al momento.

set -euo pipefail

UUID="barra-nautilus@pandi.local"
DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
DOCK=/org/gnome/shell/extensions/dash-to-dock
BMS_PANEL=/org/gnome/shell/extensions/blur-my-shell/panel
COLOR="#2e2e32"
OPACIDAD="0.95"

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

while (( $# )); do
    case "$1" in
        --quitar)
            activar "$UUID" false
            rm -rf "$DIR"
            for k in custom-background-color background-color background-opacity transparency-mode; do
                dconf reset "$DOCK/$k"
            done
            echo "Dock y barra superior vuelven a los de GNOME (la barra, del todo al cerrar sesión)."
            exit 0
            ;;
        --color)
            [[ "${2:-}" =~ ^#[0-9a-fA-F]{6}$ ]] || { echo "Color no válido: usa el formato #rrggbb" >&2; exit 1; }
            COLOR="$2"; shift 2 ;;
        --opacidad)
            [[ "${2:-}" =~ ^(0(\.[0-9]+)?|1(\.0+)?)$ ]] || { echo "Opacidad no válida: un número entre 0 y 1" >&2; exit 1; }
            OPACIDAD="$2"; shift 2 ;;
        *)
            echo "Uso: $(basename "$0") [--color '#rrggbb'] [--opacidad 0.95] | --quitar" >&2
            exit 1 ;;
    esac
done

RGB="$(python3 -c "import sys; c=sys.argv[1]; print(','.join(str(int(c[i:i+2],16)) for i in (1,3,5)))" "$COLOR")"

# --- Dock
dconf write "$DOCK/custom-background-color" true
dconf write "$DOCK/background-color" "'rgb($RGB)'"
dconf write "$DOCK/background-opacity" "$OPACIDAD"
dconf write "$DOCK/transparency-mode" "'FIXED'"
echo "Dock: $COLOR al $(python3 -c "print(round($OPACIDAD*100))") %"

# --- Barra superior (mini-extensión)
mkdir -p "$DIR"
cat > "$DIR/metadata.json" <<'EOF'
{
  "uuid": "barra-nautilus@pandi.local",
  "name": "Barra Nautilus",
  "description": "Barra superior del mismo gris que el panel lateral de Nautilus. Extensión local, solo añade stylesheet.css (la crea barra-dock-gris.sh).",
  "shell-version": ["46", "47", "48", "49", "50"]
}
EOF
cat > "$DIR/extension.js" <<'EOF'
// Sin lógica: GNOME Shell carga stylesheet.css mientras la extensión está activa.
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

export default class BarraNautilus extends Extension {
    enable() {}
    disable() {}
}
EOF
cat > "$DIR/stylesheet.css" <<EOF
/* Barra superior del mismo color que el dock ($COLOR al $OPACIDAD). Generado por barra-dock-gris.sh.
   !important y las clases de Blur my Shell (.transparent-panel…) para que
   ninguna otra extensión la vuelva transparente. */
#panel,
#panel.transparent-panel,
#panel.dark-panel,
#panel.light-panel,
#panel.contrasted-panel {
  background-color: rgba($RGB, $OPACIDAD) !important;
}
EOF
activar "$UUID" true

# Blur my Shell no debe volver transparente la barra
dconf write "$BMS_PANEL/blur" false
dconf write "$BMS_PANEL/override-background" false

if cargada; then
    # Ya cargada: desactivar y activar hace que GNOME vuelva a leer el stylesheet.css
    # (y luego se deja la lista de extensiones activas en su orden original)
    LISTA="$(gsettings get org.gnome.shell enabled-extensions)"
    gnome-extensions disable "$UUID" && gnome-extensions enable "$UUID"
    gsettings set org.gnome.shell enabled-extensions "$LISTA"
    echo "Barra superior: $COLOR al $(python3 -c "print(round($OPACIDAD*100))") % (aplicado ya)"
else
    echo "Barra superior: $COLOR al $(python3 -c "print(round($OPACIDAD*100))") % (cierra sesión y vuelve a entrar para verla)"
fi
