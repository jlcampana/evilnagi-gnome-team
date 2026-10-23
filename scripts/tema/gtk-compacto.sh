#!/usr/bin/env bash
# Ajustes visuales de GTK para GNOME, estilo macOS, vía CSS de usuario:
#   GTK 3 y 4: barras de título compactas (30px) con botones más pequeños
#   GTK 4:     botón de cerrar rojo, pestañas (AdwTabBar) más bajas y
#              Ptyxis sin el subtítulo (ruta) bajo el título
# (El aspecto de los diálogos de confirmación va aparte: dialogos-confirmacion.sh)
# Si hay Flatpak, da permiso a todas las apps para leer estos CSS.
#
# Uso:  gtk-compacto.sh          aplica (o actualiza) los ajustes
#       gtk-compacto.sh --quitar elimina los ajustes
#
# Independiente: solo toca su propio bloque entre marcadores dentro de cada
# gtk.css, así que se puede ejecutar varias veces y convive con otras reglas
# (p. ej. las de nautilus-compacto.sh).

set -euo pipefail

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
INICIO="/* >>> gtk-compacto >>> */"
FIN="/* <<< gtk-compacto <<< */"

quitar_bloque() { # quitar_bloque <gtk.css>
    [[ -f "$1" ]] || return 0
    awk -v ini="$INICIO" -v fin="$FIN" '
        $0 == ini { dentro = 1; next }
        $0 == fin { dentro = 0; next }
        !dentro
    ' "$1" > "$1.tmp"
    # Quita líneas en blanco sobrantes al principio y al final
    sed -i -e '/./,$!d' -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$1.tmp"
    mv "$1.tmp" "$1"
}

poner_bloque() { # poner_bloque <gtk.css>  (el CSS llega por stdin)
    mkdir -p "$(dirname "$1")"
    [[ -f "$1" ]] && cp "$1" "$1.bak"
    quitar_bloque "$1"
    {
        [[ -s "$1" ]] && echo
        echo "$INICIO"
        cat
        echo "$FIN"
    } >> "$1"
    echo "Ajustes aplicados en $1"
}

case "${1:-}" in
    --quitar)
        quitar_bloque "$CFG/gtk-3.0/gtk.css"
        quitar_bloque "$CFG/gtk-4.0/gtk.css"
        echo "Ajustes eliminados. Las apps vuelven a su aspecto normal al reabrirlas."
        exit 0
        ;;
    "") ;;
    *)
        echo "Uso: $(basename "$0") [--quitar]" >&2
        exit 1
        ;;
esac

poner_bloque "$CFG/gtk-3.0/gtk.css" <<'EOF'
/* Barras de título compactas (estilo macOS) */
headerbar,
.titlebar:not(headerbar) {
  min-height: 30px;
  padding-top: 0;
  padding-bottom: 0;
}

headerbar button,
.titlebar button {
  min-height: 22px;
  min-width: 22px;
  padding: 0 4px;
  margin-top: 2px;
  margin-bottom: 2px;
}

headerbar button.titlebutton,
.titlebar button.titlebutton {
  min-height: 20px;
  min-width: 20px;
  padding: 0;
  margin: 0 1px;
}

headerbar entry,
headerbar spinbutton,
headerbar switch {
  min-height: 22px;
  margin-top: 2px;
  margin-bottom: 2px;
}
EOF

poner_bloque "$CFG/gtk-4.0/gtk.css" <<'EOF'
/* Barras de título compactas (estilo macOS) */
headerbar {
  min-height: 30px;
  padding: 0 4px;
}

headerbar button,
headerbar menubutton > button,
headerbar splitbutton > button {
  min-height: 22px;
  min-width: 22px;
  padding: 0 4px;
  margin-top: 2px;
  margin-bottom: 2px;
}

windowcontrols button {
  min-height: 20px;
  min-width: 20px;
  padding: 0;
  margin: 0 1px;
}

windowcontrols button > image {
  padding: 2px;
}

headerbar .title {
  font-size: 0.95em;
}

/* Pestañas (AdwTabBar) más bajas */
tabbar tabbox {
  min-height: 0;
  padding-top: 2px;
  padding-bottom: 2px;
}

tabbar .start-action,
tabbar .end-action {
  padding-top: 2px;
  padding-bottom: 2px;
}

tabbar tab,
dnd tab {
  min-height: 20px;
  padding: 1px 4px;
  border-radius: 6px;
}

tabbar tab button.image-button,
dnd tab button.image-button {
  min-width: 18px;
  min-height: 18px;
}

tabbar tab indicator {
  transform: translateY(2px);
}

/* Ptyxis: ocultar el subtítulo (path) bajo el título; el título ya muestra user@host:dir */
window.ptyxis-window headerbar.main-header-bar windowtitle .subtitle {
  font-size: 0;
  min-height: 0;
  margin: 0;
  padding: 0;
  opacity: 0;
}

/* Botón de cerrar con fondo rojo (estilo macOS).
   Adwaita dibuja el círculo en el image, no en el button (que se estira a la
   altura de la barra), así que el color va en el image para que sea redondo. */
windowcontrols button.close > image {
  background-color: #e5484d;
  color: white;
  border-radius: 9999px;
}

windowcontrols button.close:hover > image {
  background-color: #f2555a;
}

windowcontrols button.close:active > image {
  background-color: #c93a3f;
}

EOF

# Las apps Flatpak no ven ~/.config: permiso de solo lectura a los CSS para todas
if command -v flatpak >/dev/null; then
    flatpak override --user --filesystem=xdg-config/gtk-3.0:ro --filesystem=xdg-config/gtk-4.0:ro
    echo "Permiso Flatpak concedido (las apps Flatpak también usarán estos CSS)."
fi

echo "Las apps cogen los cambios al volver a abrirlas (o al cerrar e iniciar sesión)."
