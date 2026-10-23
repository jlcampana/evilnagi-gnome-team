#!/usr/bin/env bash
# Deja las extensiones de GNOME del tema evilnagi-gnome-team:
#   1. instala desde extensions.gnome.org las que falten (las "de usuario" de la lista)
#   2. activa y desactiva cada una igual que en el equipo original
#   3. copia sus ajustes (dconf /org/gnome/shell/extensions/: posición del dock, Just Perfection…)
#
# La lista (tema/extensiones.txt: "uuid activa|inactiva usuario|sistema") y los ajustes
# (tema/dconf/extensiones.dconf) están en el repo. Se cogen del clon local si el script
# está dentro de él y, si no, de GitHub (el repo es público, sin gh).
#
# Notas:
#   - Las propias (*@pandi.local) no se bajan: las crean sus scripts (barra-dock-gris.sh,
#     botones-sesion-rojos.sh, instalar-transparencias.sh). Aquí solo se activan o desactivan.
#   - Las de sistema que no estén instaladas se saltan (vienen con paquetes de la distro).
#   - En Ubuntu no se instala ni activa Dash to Dock: chocaría con Ubuntu Dock, que usa los
#     mismos ajustes (así que el dock queda igual igualmente).
#   - Las extensiones que este equipo tenga y no estén en la lista no se tocan.
#   - Pregunta si es un portátil o un sobremesa. En un portátil no instala las de SOLO_SOBREMESA
#     (Soft Brightness Plus: atenúa la pantalla por software y choca con el brillo del portátil)
#     y las desactiva si estaban activas. Sin terminal (p. ej. desde Claude Code) no pregunta:
#     lo deduce de si hay batería (/sys/class/power_supply/BAT*).
#
# Uso:  extensiones.sh                instala, activa/desactiva y copia ajustes (pregunta el equipo)
#       extensiones.sh --sin-ajustes  sin copiar los ajustes de las extensiones
#       extensiones.sh --portatil | --sobremesa   sin preguntar el tipo de equipo
#
# Hay que cerrar sesión y volver a entrar para que GNOME cargue las extensiones nuevas.

set -euo pipefail

REPO="jlcampana/evilnagi-gnome-team"
RAW="https://raw.githubusercontent.com/$REPO/main"
EXT="$HOME/.local/share/gnome-shell/extensions"
AJUSTES=1
EQUIPO=""
# Extensiones que solo tienen sentido en el sobremesa (separadas por espacios)
SOLO_SOBREMESA="soft-brightness-plus@joelkitching.com"
for a in "$@"; do
    case $a in
        --sin-ajustes) AJUSTES=0 ;;
        --portatil) EQUIPO=portatil ;;
        --sobremesa) EQUIPO=sobremesa ;;
        *) echo "Opción desconocida: $a" >&2; exit 1 ;;
    esac
done

# --- ¿Portátil o sobremesa?
if [[ -z "$EQUIPO" ]]; then
    compgen -G '/sys/class/power_supply/BAT*' >/dev/null && SUPUESTO=portatil || SUPUESTO=sobremesa
    if [[ -t 0 ]]; then
        read -rp "¿Es un portátil o un sobremesa? [p/s] (Intro = $SUPUESTO): " r
        case ${r,,} in p*) EQUIPO=portatil ;; s*) EQUIPO=sobremesa ;; *) EQUIPO=$SUPUESTO ;; esac
    else
        EQUIPO=$SUPUESTO
    fi
fi
echo "Equipo: $EQUIPO"
solo_sobremesa() { [[ $EQUIPO == portatil && " $SOLO_SOBREMESA " == *" $1 "* ]]; }

. /etc/os-release
case " $ID ${ID_LIKE:-} " in *" ubuntu "*|*" debian "*) UBUNTU=1 ;; *) UBUNTU=0 ;; esac
VER="$(gnome-shell --version | grep -oE '[0-9]+' | head -1)"

# --- Lista y ajustes: clon local o GitHub (repo público)
R="$(cd "$(dirname "$(realpath "$0")")/../.." && pwd)"
if [[ -f "$R/tema/extensiones.txt" ]]; then
    LISTA="$R/tema/extensiones.txt"; DCONF="$R/tema/dconf/extensiones.dconf"
else
    T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
    LISTA="$T/extensiones.txt"; DCONF="$T/extensiones.dconf"
    curl -fsSL --retry 3 "$RAW/tema/extensiones.txt" -o "$LISTA" ||
        { echo "No se pudo descargar la lista de extensiones de $REPO" >&2; exit 1; }
    curl -fsSL --retry 3 "$RAW/tema/dconf/extensiones.dconf" -o "$DCONF" ||
        { echo "No se pudieron descargar los ajustes de las extensiones" >&2; exit 1; }
fi

instalada() { [[ -d "$EXT/$1" || -d "/usr/share/gnome-shell/extensions/$1" ]]; }

# --- 1. Instalar las que falten
while read -r uuid estado origen; do
    [[ -z "$uuid" || "$origen" != usuario || "$uuid" == *@pandi.local ]] && continue
    [[ $UBUNTU == 1 && "$uuid" == dash-to-dock@* ]] && continue
    solo_sobremesa "$uuid" && { echo "Portátil: no se instala $uuid"; continue; }
    instalada "$uuid" && continue
    url="$(curl -fsS "https://extensions.gnome.org/extension-info/?uuid=$uuid&shell_version=$VER" |
           python3 -c 'import json,sys; print(json.load(sys.stdin).get("download_url",""))' 2>/dev/null || true)"
    if [[ -n "$url" ]] && curl -fsSL "https://extensions.gnome.org$url" -o "/tmp/$uuid.zip" &&
       gnome-extensions install --force "/tmp/$uuid.zip" 2>/dev/null; then
        echo "Instalada: $uuid"
    else
        echo "AVISO: $uuid no está disponible para GNOME $VER; se salta."
    fi
    rm -f "/tmp/$uuid.zip"
done < "$LISTA"

# --- 2. Ajustes (antes de activar, para que arranquen ya configuradas)
if (( AJUSTES )); then
    dconf load /org/gnome/shell/extensions/ < "$DCONF"
    echo "Ajustes de las extensiones copiados."
fi

# --- 3. Activar / desactivar como en el sobremesa, sin tocar las que no están en la lista
python3 - "$LISTA" "$UBUNTU" "$EXT" "$([[ $EQUIPO == portatil ]] && echo "$SOLO_SOBREMESA")" <<'PY'
import ast, os, subprocess, sys
lista, ubuntu, ext = sys.argv[1], sys.argv[2] == "1", sys.argv[3]
solo_sobremesa = sys.argv[4].split()  # vacío en el sobremesa
def leer(k):
    v = subprocess.check_output(["gsettings", "get", "org.gnome.shell", k], text=True).replace("@as ", "")
    return ast.literal_eval(v)
activas, inactivas = leer("enabled-extensions"), leer("disabled-extensions")
n_act, n_inact = list(activas), list(inactivas)
cambios = []
for linea in open(lista):
    partes = linea.split()
    if len(partes) != 3:
        continue
    uuid, estado, _ = partes
    if ubuntu and uuid.startswith("dash-to-dock@"):
        continue
    instalada = os.path.isdir(f"{ext}/{uuid}") or os.path.isdir(f"/usr/share/gnome-shell/extensions/{uuid}")
    if uuid in solo_sobremesa:
        estado = "inactiva"
    if estado == "activa":
        if not instalada:
            continue
        if uuid not in n_act:
            n_act.append(uuid); cambios.append(f"activada: {uuid}")
        n_inact = [u for u in n_inact if u != uuid]
    else:
        if uuid in n_act:
            n_act.remove(uuid); cambios.append(f"desactivada: {uuid}")
        if instalada and uuid not in n_inact:
            n_inact.append(uuid)
if n_act != activas:
    subprocess.check_call(["gsettings", "set", "org.gnome.shell", "enabled-extensions", str(n_act)])
if n_inact != inactivas:
    subprocess.check_call(["gsettings", "set", "org.gnome.shell", "disabled-extensions", str(n_inact)])
print("\n".join(cambios) if cambios else "Activación de extensiones: ya estaba como en el sobremesa.")
PY

echo "Listo. Cierra sesión y vuelve a entrar para que GNOME cargue las extensiones nuevas."
