#!/usr/bin/env bash
# Quita lo que instala Evilnagi GNOME Team (el tema y/o los scripts).
#   ./bin/desinstalar.sh            pregunta antes de cada bloque
#   ./bin/desinstalar.sh --si       sin preguntar
#   ./bin/desinstalar.sh --todo     además borra los entornos de Python y la config
set -euo pipefail

RAIZ="$(cd "$(dirname "$(realpath "$0")")/.." && pwd)"
# shellcheck source=../lib/comun.sh
. "$RAIZ/lib/comun.sh"

TODO=0
while (( $# )); do
    case "$1" in
        --si|-y) ASUMIR=1 ;;
        --todo)  TODO=1 ;;
        -h|--ayuda) echo "Uso: desinstalar.sh [--si] [--todo]"; exit 0 ;;
        *) morir "opción desconocida: $1" ;;
    esac
    shift
done

paso "Desinstalar Evilnagi GNOME Team"
if (( ASUMIR == 0 )); then
    preguntar_si "¿Quitar el tema y los scripts instalados? [s/N]" n || { echo "Cancelado."; exit 0; }
fi

quitar_script() { # quitar_script <archivo.sh>
    local s="$RAIZ/scripts/tema/$1"
    [[ -f $s ]] && bash "$s" --quitar || true
}

paso "Extensiones y ajustes visuales"
quitar_script papelera-tela.sh
quitar_script instalar-morewaita.sh
quitar_script terminal-msx.sh
quitar_script barra-dock-gris.sh
quitar_script botones-sesion-rojos.sh
quitar_script boton-aplicaciones.sh
quitar_script clic-bandeja.sh
quitar_script instalar-transparencias.sh
quitar_script gtk-compacto.sh
quitar_script nautilus-compacto.sh
quitar_script dialogos-confirmacion.sh

paso "Archivos del tema"
rm -rf "$HOME/.local/share/gnome-shell/extensions/barra-nautilus@pandi.local" \
       "$HOME/.local/share/gnome-shell/extensions/boton-aplicaciones@pandi.local" \
       "$HOME/.local/share/gnome-shell/extensions/botones-sesion@pandi.local" \
       "$HOME/.local/share/gnome-shell/extensions/clic-bandeja@pandi.local" \
       "$HOME/.local/share/gnome-shell/extensions/transparencias@pandi.local"
rm -f "$NPY_DIR/abrir-con-gthumb.py" "$NPY_DIR/panel-lateral-estrecho.py" "$NPY_DIR/opacidad-nautilus.py"

# Scripts del tema y de descargas (solo los nuestros)
for f in gtk-compacto nautilus-compacto dialogos-confirmacion instalar-morewaita \
         papelera-tela instalar-transparencias blur-ventanas barra-dock-gris \
         reborde-ventanas botones-sesion-rojos terminal-msx extensiones \
         icono-app clic-bandeja boton-aplicaciones; do
    rm -f "$HOME/scripts/$f.sh"
done
rm -f "$HOME/scripts"/{ydl,yda,xdl,twitter,r34dl,allr34dl,r34html.py}

# Bloques del PATH y de los alias en ~/.bashrc
if grep -qE '# >>> evilnagi-gnome-team( aliases)? >>>' "$HOME/.bashrc" 2>/dev/null; then
    respaldar "$HOME/.bashrc"
    sed -i \
        -e '/^# >>> evilnagi-gnome-team >>>$/,/^# <<< evilnagi-gnome-team <<<$/d' \
        -e '/^# >>> evilnagi-gnome-team aliases >>>$/,/^# <<< evilnagi-gnome-team aliases <<<$/d' \
        "$HOME/.bashrc"
    ok "Bloques del PATH y de los alias quitados de ~/.bashrc"
fi

paso "Tracker"
rm -rf "$HOME/.local/share/trackerplay-app"
rm -f "$HOME/.local/bin/tracker"

if (( TODO )); then
    paso "Entornos de Python y configuración"
    rm -rf "$HOME/.local/share/gallery-dl-venv" \
           "$HOME/.local/share/trackerplay-venv" \
           "$CONFIG_DIR"
    ok "Entornos y configuración borrados"
else
    info "Se conservan los entornos de Python y $CONFIG_DIR (usa --todo para borrarlos)"
    info "También se conservan ~/Descargas y la biblioteca de tracker"
fi

paso "Listo"
info "Los ajustes de dconf (extensiones, dock, fondo…) no se revierten solos."
info "Si quieres volver al aspecto por defecto: Ajustes → Apariencia, y desactiva las extensiones."
info "Cierra sesión para que desaparezcan las extensiones."
