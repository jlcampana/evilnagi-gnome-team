#!/usr/bin/env bash
# Reborde de 2 px en todas las ventanas (también Brave, VS Code, apps Qt…) con la extensión
# P7 Borders (https://extensions.gnome.org/extension/9064/p7-window-borders/): color de acento
# de GNOME en la ventana activa y el mismo azul al 50 % en las demás.
#
# Uso:  reborde-ventanas.sh                instala P7 Borders si falta, la configura y la activa
#       reborde-ventanas.sh --grosor 3     con otro grosor (px)
#       reborde-ventanas.sh --quitar       desactiva la extensión
#
# Independiente: Fedora y Ubuntu (necesita curl). Si la extensión se instala ahora, hay que
# cerrar sesión para que GNOME la cargue; si ya estaba, los cambios se ven al momento.

set -euo pipefail

UUID="p7-borders@prasannavl.com"
P7=/org/gnome/shell/extensions/p7-borders
GROSOR=2

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

case "${1:-}" in
    --quitar)
        gnome-extensions disable "$UUID" 2>/dev/null || true
        activar "$UUID" false
        echo "Reborde de ventanas desactivado."
        exit 0 ;;
    --grosor)
        [[ "${2:-}" =~ ^[0-9]+$ ]] || { echo "Grosor no válido: un número de píxeles" >&2; exit 1; }
        GROSOR="$2" ;;
    "") ;;
    *)
        echo "Uso: $(basename "$0") [--grosor N | --quitar]" >&2
        exit 1 ;;
esac

if [[ ! -d "$HOME/.local/share/gnome-shell/extensions/$UUID" && ! -d "/usr/share/gnome-shell/extensions/$UUID" ]]; then
    VER="$(gnome-shell --version | grep -oE '[0-9]+' | head -1)"
    URL="$(curl -fsS "https://extensions.gnome.org/extension-info/?uuid=$UUID&shell_version=$VER" |
           python3 -c 'import json,sys; print(json.load(sys.stdin).get("download_url",""))')"
    [[ -n "$URL" ]] || { echo "P7 Borders no está disponible para GNOME $VER." >&2; exit 1; }
    curl -fsSL "https://extensions.gnome.org$URL" -o "/tmp/$UUID.zip"
    gnome-extensions install --force "/tmp/$UUID.zip"; rm -f "/tmp/$UUID.zip"
    echo "P7 Borders instalada (cierra sesión y vuelve a entrar para cargarla)."
fi

dconf write $P7/default-enabled true
dconf write $P7/default-width "$GROSOR"
dconf write $P7/default-active-color "'auto-solid'"                 # acento de GNOME, sólido
dconf write $P7/default-inactive-color "'rgba(53, 132, 228, 0.5)'"  # azul de GNOME al 50 %
activar "$UUID" true
echo "Reborde de ventanas: $GROSOR px, color de acento (activa) y azul al 50 % (inactivas)."
