#!/usr/bin/env bash
# Aspecto de los diálogos de confirmación de GNOME (AdwAlertDialog: "¿Vaciar la papelera?",
# "¿Eliminar permanentemente?"…), vía ~/.config/gtk-4.0/gtk.css:
#   - botones en fila en vez de uno encima de otro: libadwaita los apila si en fila no caben
#     en el ancho mínimo del diálogo; con 400 px de mínimo caben "Cancelar" y "Vaciar la papelera"
#   - botón de la acción destructiva (Vaciar, Eliminar…) de color, por defecto el mismo rojo
#     que el botón de cerrar de gtk-compacto.sh (#e5484d)
#
# Uso:  dialogos-confirmacion.sh                 aplica (o actualiza) los ajustes
#       dialogos-confirmacion.sh --color '#c01c28'  con otro color para el botón destructivo
#       dialogos-confirmacion.sh --quitar        elimina los ajustes
#
# Independiente: solo toca su propio bloque entre marcadores dentro de gtk.css, así que se
# puede ejecutar varias veces y convive con otras reglas del archivo. Las apps lo cogen al
# volver a abrirlas (GTK lee gtk.css al arrancar).

set -euo pipefail

CSS="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-4.0/gtk.css"
INICIO="/* >>> dialogos-confirmacion >>> */"
FIN="/* <<< dialogos-confirmacion <<< */"
COLOR="#e5484d"

quitar_bloque() {
    [[ -f "$CSS" ]] || return 0
    awk -v ini="$INICIO" -v fin="$FIN" '
        $0 == ini { dentro = 1; next }
        $0 == fin { dentro = 0; next }
        !dentro
    ' "$CSS" > "$CSS.tmp"
    # Quita líneas en blanco sobrantes al principio y al final
    sed -i -e '/./,$!d' -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$CSS.tmp"
    mv "$CSS.tmp" "$CSS"
}

case "${1:-}" in
    --quitar)
        quitar_bloque
        echo "Ajustes de los diálogos eliminados de $CSS (se nota al volver a abrir las apps)."
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

# Tonos para pasar el ratón (más claro) y pulsar (más oscuro)
tono() { # tono <#rrggbb> <factor>: multiplica cada canal, con tope en 255
    python3 -c "import sys; c=sys.argv[1]; f=float(sys.argv[2]); print('#'+''.join('%02x'%min(255,round(int(c[i:i+2],16)*f)) for i in (1,3,5)))" "$1" "$2"
}
CLARO="$(tono "$COLOR" 1.06)"
OSCURO="$(tono "$COLOR" 0.87)"

mkdir -p "$(dirname "$CSS")"
[[ -f "$CSS" ]] && cp "$CSS" "$CSS.bak"
quitar_bloque

{
    [[ -s "$CSS" ]] && echo
    cat <<EOF
$INICIO
/* Diálogos de confirmación: botones en fila (libadwaita los apila si no caben en el ancho mínimo) */
dialog.alert .message-area {
  min-width: 400px;
}

/* Botón de la acción destructiva (Vaciar, Eliminar…) */
dialog.alert .response-area > button.destructive-action {
  background-color: $COLOR;
  color: white;
}

dialog.alert .response-area > button.destructive-action:hover {
  background-color: $CLARO;
}

dialog.alert .response-area > button.destructive-action:active {
  background-color: $OSCURO;
}
$FIN
EOF
} >> "$CSS"

echo "Ajustes de los diálogos aplicados en $CSS (botón destructivo: $COLOR)"
[[ -f "$CSS.bak" ]] && echo "Copia del archivo anterior: $CSS.bak"
if pgrep -x nautilus >/dev/null; then
    nautilus -q 2>/dev/null || true
    echo "Nautilus cerrado; se aplicará al volver a abrirlo. Las demás apps, al reabrirlas."
fi
