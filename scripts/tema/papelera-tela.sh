#!/usr/bin/env bash
# Cambia solo el icono de la papelera (vacía y llena) por el de Tela-circle, variante círculo
# (https://github.com/vinceliuice/Tela-circle-icon-theme), sin tocar el resto de iconos.
#
# Crea un mini-tema de iconos "Papelera-Tela" en ~/.local/share/icons que solo trae la papelera
# y hereda todo lo demás del tema de iconos que esté puesto (p. ej. MoreWaita), y lo activa.
#
# El símbolo de reciclar, que en el original es gris (vacía) y rojo (llena), se pone verde
# en las dos con los verdes de la paleta de GNOME (#26a269 y #57e389).
#
# En el escritorio la papelera sale más pequeña que en el dock: el dibujo de Tela ocupa todo el
# lienzo y allí se veía más grande que el resto de iconos. El escritorio (DING) pide el icono a su
# tamaño (64 px en "estándar") y el dock a otro (32 px), así que el mini-tema trae, además de la
# versión normal (scalable), una reducida solo para el tamaño de DING (directorio de tamaño fijo).
#
# Uso:  papelera-tela.sh               aplica (o actualiza) y activa el mini-tema, con el símbolo verde
#       papelera-tela.sh --original    con los colores originales de Tela (gris / rojo)
#       ESCRITORIO=70 papelera-tela.sh con otro tamaño en el escritorio (% del lienzo; 100 = como en el dock)
#       TAMANO=85 papelera-tela.sh     con el dibujo más pequeño en todas partes (% del lienzo)
# Si cambias el tamaño de los iconos del escritorio (ajustes de DING), vuelve a ejecutarlo.
#       papelera-tela.sh --quitar   vuelve al tema de iconos de base y borra el mini-tema
#
# Independiente: vale para Fedora y Ubuntu con GNOME (necesita curl). Si cambias de tema de
# iconos (p. ej. con instalar-morewaita.sh), vuelve a ejecutarlo para que lo tome como base.

set -euo pipefail

NOMBRE="Papelera-Tela"
DEST="$HOME/.local/share/icons/$NOMBRE"
URL="https://raw.githubusercontent.com/vinceliuice/Tela-circle-icon-theme/master/src/scalable/places-circle"
VERDE_OSCURO="#26a269"   # GNOME green 5
VERDE_CLARO="#57e389"    # GNOME green 3
TAMANO="${TAMANO:-100}"      # % del lienzo que ocupa el dibujo en el tema (dock, Nautilus…)
ESCRITORIO="${ESCRITORIO:-80}"  # % en el tamaño de icono del escritorio (DING)
# Tamaño al que DING pide los iconos (sus valores: tiny 36, small 48, standard 64, large 96)
case "$(dconf read /org/gnome/shell/extensions/ding/icon-size 2>/dev/null | tr -d "'")" in
    tiny) PX_ESC=36 ;; small) PX_ESC=48 ;; large) PX_ESC=96 ;; *) PX_ESC=64 ;;
esac

actual="$(gsettings get org.gnome.desktop.interface icon-theme | tr -d "'")"


if [[ "${1:-}" == "--quitar" ]]; then
    base="$(sed -n 's/^X-Base=//p' "$DEST/index.theme" 2>/dev/null || true)"
    [[ "$actual" == "$NOMBRE" ]] && gsettings set org.gnome.desktop.interface icon-theme "${base:-Adwaita}"
    rm -rf "$DEST"
    echo "Papelera de Tela quitada; tema de iconos: $(gsettings get org.gnome.desktop.interface icon-theme)"
    exit 0
fi

# Tema de base: el que esté puesto (o el que ya usaba el mini-tema si está activo)
if [[ "$actual" == "$NOMBRE" ]]; then
    base="$(sed -n 's/^X-Base=//p' "$DEST/index.theme" 2>/dev/null || true)"
    base="${base:-Adwaita}"
else
    base="$actual"
fi

mkdir -p "$DEST/scalable/places"
for icono in user-trash user-trash-full; do
    curl -fsSL "$URL/$icono.svg" -o "$DEST/scalable/places/$icono.svg"
done
# Símbolo de reciclar en verde: vacía #888/#bebebe (gris), llena #df5656/#ff9292 (rojo)
if [[ "${1:-}" != "--original" ]]; then
    sed -i -e "s/fill=\"#888\"/fill=\"$VERDE_OSCURO\"/g" -e "s/fill=\"#bebebe\"/fill=\"$VERDE_CLARO\"/g" \
        "$DEST/scalable/places/user-trash.svg"
    sed -i -e "s/fill=\"#df5656\"/fill=\"$VERDE_OSCURO\"/g" -e "s/fill=\"#ff9292\"/fill=\"$VERDE_CLARO\"/g" \
        "$DEST/scalable/places/user-trash-full.svg"
fi
# Reducir el dibujo dentro del lienzo de 64x64 (centrado)
reducir() { # reducir <svg origen> <svg destino> <porcentaje>
    python3 - "$1" "$2" "$3" <<'PY'
import re, sys
origen, destino, tam = sys.argv[1], sys.argv[2], float(sys.argv[3]) / 100
svg = open(origen).read()
if tam != 1:
    abre = re.search(r"<svg[^>]*>", svg)
    svg = (svg[:abre.end()] + f'<g transform="translate(32 32) scale({tam}) translate(-32 -32)">'
           + svg[abre.end():].replace("</svg>", "</g></svg>"))
open(destino, "w").write(svg)
PY
}
P="$DEST/scalable/places"
FIJO_ESC="${PX_ESC}x${PX_ESC}/places"
rm -rf "$DEST"/[0-9]*x[0-9]*   # versiones de tamaño fijo anteriores
mkdir -p "$DEST/$FIJO_ESC"
reducir "$P/user-trash.svg" "$DEST/$FIJO_ESC/user-trash.svg" "$ESCRITORIO"
reducir "$P/user-trash-full.svg" "$DEST/$FIJO_ESC/user-trash-full.svg" "$ESCRITORIO"
reducir "$P/user-trash.svg" "$P/user-trash.svg" "$TAMANO"
reducir "$P/user-trash-full.svg" "$P/user-trash-full.svg" "$TAMANO"

cat > "$DEST/index.theme" <<EOF
[Icon Theme]
Name=$NOMBRE
Comment=Papelera de Tela-circle (círculo) sobre $base
Inherits=$base,Adwaita,AdwaitaLegacy,hicolor
Directories=$FIJO_ESC,scalable/places
X-Base=$base

[$FIJO_ESC]
Size=$PX_ESC
Context=Places
Type=Fixed

[scalable/places]
Size=128
MinSize=8
MaxSize=512
Context=Places
Type=Scalable
EOF

gtk-update-icon-cache -q -f -t "$DEST" 2>/dev/null || true
# Si ya estaba puesto, GNOME no recarga los iconos al poner el mismo nombre: se cambia un
# momento al tema de base para que los vuelva a leer
if [[ "$actual" == "$NOMBRE" ]]; then
    gsettings set org.gnome.desktop.interface icon-theme "$base"
    sleep 1
fi
gsettings set org.gnome.desktop.interface icon-theme "$NOMBRE"
echo "Papelera de Tela-circle activada (mini-tema $NOMBRE sobre $base)."

# Las apps Flatpak no ven ~/.local/share/icons sin permiso
command -v flatpak >/dev/null && flatpak override --user --filesystem=xdg-data/icons:ro || true
