#!/usr/bin/env bash
# Activa o quita el desenfoque (blur) detrás de las ventanas transparentes de Nautilus y Ptyxis. El blur lo hace la extensión Transparencias (transparencias@pandi.local):
# este script solo cambia sus ajustes, igual que los interruptores de su menú.
# La transparencia en sí no la toca.
#
# Uso:  blur-ventanas.sh              blur en Nautilus y Ptyxis
#       blur-ventanas.sh nautilus     solo en Nautilus
#       blur-ventanas.sh ptyxis       solo en Ptyxis
#       blur-ventanas.sh --nivel 30   intensidad del blur (0-100; por defecto 21)
#       blur-ventanas.sh --quitar     lo quita de todas
#       blur-ventanas.sh --estado     muestra cómo está

set -euo pipefail

DIR="$HOME/.local/share/gnome-shell/extensions/transparencias@pandi.local/schemas"
[[ -d "$DIR" ]] || { echo "Falta la extensión Transparencias (instalar-transparencias.sh)." >&2; exit 1; }
G() { gsettings --schemadir "$DIR" "$1" org.gnome.shell.extensions.transparencias "${@:2}"; }

case "${1:-todas}" in
    todas)    G set nautilus-blur true;  G set ptyxis-blur true ;;
    nautilus) G set nautilus-blur true;  G set ptyxis-blur false ;;
    ptyxis)   G set nautilus-blur false; G set ptyxis-blur true ;;
    --nivel)
        [[ "${2:-}" =~ ^[0-9]+$ && "$2" -le 100 ]] || { echo "Nivel no válido: 0-100" >&2; exit 1; }
        G set blur-nivel "$2" ;;
    --quitar) G set nautilus-blur false; G set ptyxis-blur false ;;
    --estado) ;;
    *)
        echo "Uso: $(basename "$0") [nautilus|ptyxis|--nivel N|--quitar|--estado]" >&2
        exit 1 ;;
esac
echo "Blur: Nautilus $(G get nautilus-blur) · Terminal $(G get ptyxis-blur) · nivel $(G get blur-nivel)"
