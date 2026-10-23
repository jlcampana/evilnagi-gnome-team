#!/usr/bin/env bash
# Cambia el icono de una aplicación concreta, sin tocar el tema de iconos.
#
# Copia el lanzador de la app (.desktop) a ~/.local/share/applications, que tiene prioridad sobre
# el del sistema, con Icon= apuntando al SVG elegido (guardado en ~/.local/share/icons/apps-propias/).
# Se ve en el dock, la cuadrícula de aplicaciones y al cambiar de ventana.
#
# Uso:  icono-app.sh <id de la app> <URL o ruta del SVG>    pone el icono
#       icono-app.sh <id de la app> --quitar                vuelve al icono normal
#       icono-app.sh --retoques                             Retoques con el icono de Reversal
#       icono-app.sh --1password-bandeja                    icono de 1Password de la bandeja en blanco
#
# --1password-bandeja: el icono de 1Password de la barra superior (bandeja, extensión AppIndicator)
# sale en colores. Se cambia por el simbólico de MoreWaita pintado de blanco, como los demás, con
# el ajuste custom-icons de AppIndicator. Va con ruta completa: AppIndicator no busca los nombres
# de icono en el tema puesto, solo en la carpeta de la app y en hicolor.
#
# El id es el nombre del .desktop sin la extensión (p. ej. org.gnome.tweaks). Vale también para
# apps Flatpak. Ojo: mientras exista la copia local, si la app se actualiza y cambia su lanzador,
# se sigue usando la copia; vuelve a ejecutar el script para regenerarla.
#
# Independiente: Fedora y Ubuntu (necesita curl si el icono es una URL).

set -euo pipefail

APPS="$HOME/.local/share/applications"
ICONOS="$HOME/.local/share/icons/apps-propias"
REPO="jlcampana/evilnagi-gnome-team"
RAW="https://raw.githubusercontent.com/$REPO/main"
RETOQUES_URL="https://raw.githubusercontent.com/yeyushengfan258/Reversal-icon-theme/master/src/apps/scalable/gnome-tweak-tool.svg"

if [[ "${1:-}" == "--1password-bandeja" ]]; then
    DESTINO="$ICONOS/1password-bandeja.svg"
    ORIGEN_MW="$HOME/.local/share/icons/MoreWaita/symbolic/apps/1password-symbolic.svg"
    mkdir -p "$ICONOS"
    if [[ -f "$ORIGEN_MW" ]]; then
        sed '0,/<svg/s/<svg/<svg fill="#ffffff"/' "$ORIGEN_MW" > "$DESTINO"
    else
        # Copia del repo (ya en blanco); si el script no está en un clon, se baja.
        R="$(cd "$(dirname "$(realpath "$0")")/../.." && pwd)"
        if [[ -f "$R/tema/iconos/apps-propias/1password-bandeja.svg" ]]; then
            cp "$R/tema/iconos/apps-propias/1password-bandeja.svg" "$DESTINO"
        else
            curl -fsSL --retry 3 "$RAW/tema/iconos/apps-propias/1password-bandeja.svg" -o "$DESTINO" ||
                { echo "No se pudo obtener el icono de 1Password." >&2; exit 1; }
        fi
    fi
    gsettings set org.gnome.shell.extensions.appindicator custom-icons \
        "[('1Password_status_icon_1', '$DESTINO', '')]" 2>/dev/null ||
        echo "AVISO: AppIndicator no acepta custom-icons en este sistema (¿Ubuntu AppIndicators?)." >&2
    echo "Icono de 1Password de la bandeja en blanco ($DESTINO)."
    exit 0
fi
if [[ "${1:-}" == "--retoques" ]]; then
    set -- org.gnome.tweaks "$RETOQUES_URL"
fi
[[ $# -eq 2 ]] || { echo "Uso: $(basename "$0") <id de la app> <URL o ruta del SVG | --quitar> | --retoques" >&2; exit 1; }
ID="$1"; ORIGEN_ICONO="$2"
COPIA="$APPS/$ID.desktop"

if [[ "$ORIGEN_ICONO" == "--quitar" ]]; then
    if grep -x '# icono-app.sh' "$COPIA" >/dev/null 2>&1; then
        rm -f "$COPIA"
    fi
    rm -f "$ICONOS/$ID.svg"
    update-desktop-database "$APPS" 2>/dev/null || true
    echo "$ID vuelve a su icono normal."
    exit 0
fi

# Lanzador original del sistema (paquete o Flatpak)
ORIGINAL=""
for d in /usr/share/applications /usr/local/share/applications \
         /var/lib/flatpak/exports/share/applications "$HOME/.local/share/flatpak/exports/share/applications"; do
    [[ -f "$d/$ID.desktop" ]] && { ORIGINAL="$d/$ID.desktop"; break; }
done
[[ -n "$ORIGINAL" ]] || { echo "No encuentro el lanzador $ID.desktop (¿está instalada la app?)" >&2; exit 1; }

# Icono
mkdir -p "$ICONOS" "$APPS"
if [[ "$ORIGEN_ICONO" =~ ^https?:// ]]; then
    curl -fsSL "$ORIGEN_ICONO" -o "$ICONOS/$ID.svg"
else
    cp "$ORIGEN_ICONO" "$ICONOS/$ID.svg"
fi

# Copia del lanzador con el icono cambiado (en todas sus secciones, p. ej. acciones)
{
    echo "# icono-app.sh"
    sed "s|^Icon=.*|Icon=$ICONOS/$ID.svg|" "$ORIGINAL"
} > "$COPIA"
update-desktop-database "$APPS" 2>/dev/null || true
echo "$ID: icono cambiado ($ICONOS/$ID.svg). Si la app está abierta, se verá al volver a abrirla."
