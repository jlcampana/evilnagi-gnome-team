#!/usr/bin/env bash
# Ajustes visuales de Nautilus (GNOME / GTK4) vía ~/.config/gtk-4.0/gtk.css:
#   - oculta el título "Archivos" de la cabecera de la barra lateral
#   - letra un poco más pequeña en el panel lateral
#   - filas del panel lateral más bajas, acordes a la letra
#
# Uso:  nautilus-compacto.sh          aplica (o actualiza) los ajustes
#       nautilus-compacto.sh --quitar elimina los ajustes
#
# Independiente: solo toca su propio bloque entre marcadores dentro de gtk.css,
# así que se puede ejecutar varias veces y convive con otras reglas del archivo.

set -euo pipefail

CSS="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-4.0/gtk.css"
INICIO="/* >>> nautilus-compacto >>> */"
FIN="/* <<< nautilus-compacto <<< */"

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

reiniciar_nautilus() {
    if pgrep -x nautilus >/dev/null; then
        nautilus -q 2>/dev/null || true
        echo "Nautilus cerrado; se aplicará al volver a abrirlo."
    fi
}

case "${1:-}" in
    --quitar)
        quitar_bloque
        echo "Ajustes eliminados de $CSS"
        reiniciar_nautilus
        exit 0
        ;;
    "") ;;
    *)
        echo "Uso: $(basename "$0") [--quitar]" >&2
        exit 1
        ;;
esac

mkdir -p "$(dirname "$CSS")"
[[ -f "$CSS" ]] && cp "$CSS" "$CSS.bak"
quitar_bloque

{
    [[ -s "$CSS" ]] && echo
    cat <<EOF
$INICIO
/* Nautilus: ocultar el título "Archivos" de la cabecera de la barra lateral */
window.nautilus-window .sidebar-pane headerbar windowtitle {
  opacity: 0;
}

/* Nautilus: letra algo más pequeña en el panel lateral */
window.nautilus-window .sidebar-pane .navigation-sidebar label {
  font-size: 0.9em;
}

/* Nautilus: filas del panel lateral más bajas (Adwaita: 36px, margen 2px) */
window.nautilus-window .sidebar-pane .navigation-sidebar > row {
  min-height: 30px;
  margin-bottom: 1px;
}

$FIN
EOF
} >> "$CSS"

echo "Ajustes aplicados en $CSS"
[[ -f "$CSS.bak" ]] && echo "Copia del archivo anterior: $CSS.bak"
reiniciar_nautilus
