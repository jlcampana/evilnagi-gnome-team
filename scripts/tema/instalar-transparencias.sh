#!/usr/bin/env bash
# Instala la extensión de GNOME "Transparencias" (transparencias@pandi.local): un botón en
# Ajustes rápidos con la opacidad y el blur de Nautilus, Ptyxis y el resto de apps GTK.
#
# Instala:
#   - la extensión de GNOME Shell (~/.local/share/gnome-shell/extensions/transparencias@pandi.local)
#   - opacidad-nautilus.py, extensión de nautilus-python que aplica la opacidad dentro de Nautilus
#   - lo que necesita, si falta: nautilus-python (dnf en Fedora / python3-nautilus con apt en Ubuntu)
#   (el blur lo hace la propia extensión; no necesita Blur my Shell)
#
# Los archivos los coge del repo evilnagi-gnome-team: del clon local si el script está
# dentro de él, y si no, los baja de GitHub (el repo es público).
#
# Uso:  instalar-transparencias.sh            instala o actualiza
#       instalar-transparencias.sh --quitar   la desinstala

set -euo pipefail

UUID="transparencias@pandi.local"
REPO="jlcampana/evilnagi-gnome-team"
RAW="https://raw.githubusercontent.com/$REPO/main"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
NPY_DIR="$HOME/.local/share/nautilus-python/extensions"
ARCHIVOS=(
    "extensiones-locales/$UUID/metadata.json"
    "extensiones-locales/$UUID/extension.js"
    "extensiones-locales/$UUID/prefs.js"
    "extensiones-locales/$UUID/schemas/org.gnome.shell.extensions.transparencias.gschema.xml"
    "nautilus-python/opacidad-nautilus.py"
)

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

if [[ "${1:-}" == "--quitar" ]]; then
    activar "$UUID" false
    rm -rf "$EXT_DIR" "$NPY_DIR/opacidad-nautilus.py"
    echo "Transparencias desinstalada. Cierra sesión para que desaparezca el botón."
    exit 0
fi

# Origen: clon local del repo o GitHub
R="$(cd "$(dirname "$(realpath "$0")")/../.." && pwd)"
if [[ -f "$R/tema/extensiones-locales/$UUID/extension.js" ]]; then
    ORIGEN="$R/tema"
    echo "Usando los archivos del repo local: $R"
else
    ORIGEN="$(mktemp -d)"; trap 'rm -rf "$ORIGEN"' EXIT
    echo "Descargando de GitHub ($REPO)…"
    for f in "${ARCHIVOS[@]}"; do
        mkdir -p "$ORIGEN/$(dirname "$f")"
        curl -fsSL --retry 3 "$RAW/tema/$f" -o "$ORIGEN/$f" ||
            { echo "No se pudo descargar tema/$f" >&2; exit 1; }
    done
fi

# Extensión de GNOME Shell
rm -rf "$EXT_DIR"; mkdir -p "$EXT_DIR/schemas"
cp "$ORIGEN/extensiones-locales/$UUID/"{metadata.json,extension.js,prefs.js} "$EXT_DIR/"
cp "$ORIGEN/extensiones-locales/$UUID/schemas/"*.gschema.xml "$EXT_DIR/schemas/"
glib-compile-schemas "$EXT_DIR/schemas"
activar "$UUID" true
echo "Extensión instalada y activada: $EXT_DIR"

# Opacidad dentro de Nautilus
mkdir -p "$NPY_DIR"
cp "$ORIGEN/nautilus-python/opacidad-nautilus.py" "$NPY_DIR/"
echo "Extensión de Nautilus instalada: $NPY_DIR/opacidad-nautilus.py"

# Lo que necesita: nautilus-python (paquete de la distro). El blur lo hace la propia extensión.
. /etc/os-release
case " $ID ${ID_LIKE:-} " in
    *" fedora "*) DISTRO=fedora; PAQ_NPY=nautilus-python ;;
    *" ubuntu "*|*" debian "*) DISTRO=ubuntu; PAQ_NPY=python3-nautilus ;;
    *) DISTRO=otra ;;
esac
como_root() { if command -v sudo >/dev/null 2>&1; then sudo "$@"; else pkexec "$@"; fi; }
instalado() { case $DISTRO in fedora) rpm -q "$1" &>/dev/null ;; ubuntu) dpkg -s "$1" &>/dev/null ;; *) true ;; esac; }
if [[ $DISTRO != otra ]] && ! instalado "$PAQ_NPY"; then
    echo "Instalando $PAQ_NPY (para la opacidad de Nautilus)…"
    case $DISTRO in
        fedora) como_root dnf install -y "$PAQ_NPY" ;;
        ubuntu) como_root sh -c "apt-get update -q && apt-get install -y $PAQ_NPY" ;;
    esac || echo "AVISO: no se pudo instalar $PAQ_NPY; sin él no cambia la opacidad de Nautilus."
elif [[ $DISTRO == otra ]]; then
    echo "AVISO: distro no reconocida ($ID); instala nautilus-python a mano."
fi

gsettings list-schemas | grep -x org.gnome.Ptyxis >/dev/null ||
    echo "AVISO: Ptyxis no está instalado; el control de la terminal no aparecerá."

nautilus -q 2>/dev/null || true
echo "Listo. Cierra sesión y vuelve a entrar para que aparezca el botón Transparencias en Ajustes rápidos."
