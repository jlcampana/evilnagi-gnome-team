#!/usr/bin/env bash
# Utilidades comunes del instalador y de los scripts del tema.
# Se carga con: . "$(dirname "$0")/../lib/comun.sh"

# RAIZ: carpeta del repo (la calcula quien carga este archivo si no viene puesta)
if [[ -z ${RAIZ:-} ]]; then
    RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
export RAIZ

REPO="${REPO:-jlcampana/evilnagi-gnome-team}"
RAMA="${RAMA:-main}"
RAW="https://raw.githubusercontent.com/$REPO/$RAMA"
TARBALL="https://codeload.github.com/$REPO/tar.gz/refs/heads/$RAMA"

EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
NPY_DIR="$HOME/.local/share/nautilus-python/extensions"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/evilnagi-gnome-team"
BACKUP="$HOME/backups/evilnagi-gnome-team-$(date +%F-%H%M%S)"
ASUMIR="${ASUMIR:-0}"       # 1 = no preguntar (--si)
EQUIPO="${EQUIPO:-}"        # portatil | sobremesa

# --- Salida ---------------------------------------------------------------
if [[ -t 1 ]]; then
    _V=$'\033[1m'; _N=$'\033[0m'; _R=$'\033[31m'; _A=$'\033[33m'; _G=$'\033[32m'
else
    _V=""; _N=""; _R=""; _A=""; _G=""
fi
paso()  { printf '\n%s== %s%s\n' "$_V" "$*" "$_N"; }
info()  { printf '   %s\n' "$*"; }
ok()    { printf '   %s✓%s %s\n' "$_G" "$_N" "$*"; }
aviso() { printf '   %sAVISO:%s %s\n' "$_A" "$_N" "$*" >&2; }
error() { printf '%sERROR:%s %s\n' "$_R" "$_N" "$*" >&2; }
morir() { error "$*"; exit 1; }

# --- Preguntas (siempre por el terminal, no por stdin: curl | bash) -------
# Leer de /dev/tty permite que el instalador funcione con `curl ... | bash`
# sin que las preguntas se coman el resto del script.
leer_tty() { # leer_tty <variable> <mensaje> <valor por defecto>
    local __var="$1" __msg="$2" __def="${3:-}" __resp=""
    if (( ASUMIR )); then
        printf -v "$__var" '%s' "$__def"
        return 0
    fi
    if [[ -r /dev/tty ]]; then
        printf '%s' "$__msg" > /dev/tty
        IFS= read -r __resp < /dev/tty || __resp=""
    fi
    [[ -n $__resp ]] || __resp="$__def"
    printf -v "$__var" '%s' "$__resp"
}

preguntar_si() { # preguntar_si <mensaje> <s|n por defecto>
    local msg="$1" def="${2:-s}" r=""
    (( ASUMIR )) && { [[ $def == s ]]; return; }
    leer_tty r "$msg " "$def"
    [[ ${r,,} == s* ]]
}

# --- Root -----------------------------------------------------------------
como_root() {
    if (( EUID == 0 )); then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    elif command -v pkexec >/dev/null 2>&1; then
        pkexec "$@"
    else
        morir "hace falta root y no hay sudo ni pkexec"
    fi
}

# --- Distro / GNOME -------------------------------------------------------
detectar_sistema() {
    [[ -r /etc/os-release ]] || morir "no encuentro /etc/os-release"
    # shellcheck disable=SC1091
    . /etc/os-release
    PRETTY="${PRETTY_NAME:-$ID}"
    case " $ID ${ID_LIKE:-} " in
        *" fedora "*|*" rhel "*|*" centos "*) DISTRO=fedora ;;
        *" ubuntu "*|*" debian "*)             DISTRO=ubuntu ;;
        *) morir "distro no soportada: $PRETTY (solo Fedora y Ubuntu/Debian)" ;;
    esac
    command -v gnome-shell >/dev/null 2>&1 || morir "no parece un escritorio GNOME (falta gnome-shell)"
    VER_GNOME="$(gnome-shell --version 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)"
    [[ -n $VER_GNOME ]] || VER_GNOME=0
    [[ $VER_GNOME -ge 46 ]] || aviso "GNOME $VER_GNOME es antiguo; el tema está probado en GNOME 46-50"
    info "Sistema: $PRETTY · GNOME $VER_GNOME · $DISTRO"
}

elegir_equipo() {
    [[ -n $EQUIPO ]] && return 0
    local supuesto=sobremesa r=""
    compgen -G '/sys/class/power_supply/BAT*' >/dev/null && supuesto=portatil
    if (( ! ASUMIR )) && [[ -r /dev/tty ]]; then
        leer_tty r "¿Es un portátil o un sobremesa? [p/s] (Intro = $supuesto): " "$supuesto"
        case ${r,,} in p*) EQUIPO=portatil ;; s*) EQUIPO=sobremesa ;; *) EQUIPO=$supuesto ;; esac
    else
        EQUIPO=$supuesto
    fi
    info "Equipo: $EQUIPO"
}

# --- Copias de seguridad --------------------------------------------------
respaldar() { # respaldar <ruta existente>
    local ruta="$1"
    [[ -e $ruta ]] || return 0
    mkdir -p "$BACKUP/$(dirname "${ruta#"$HOME"/}")"
    cp -a "$ruta" "$BACKUP/${ruta#"$HOME"/}"
}

poner() { # poner <origen> <destino>
    respaldar "$2"
    mkdir -p "$(dirname "$2")"
    cp -a "$1" "$2"
}

# --- Alias de ~/.bashrc ---------------------------------------------------
# Añade alias cómodos sin duplicarlos ni pisar los que ya existan. Va en un
# bloque marcado para que el desinstalador sepa quitarlos.
configurar_alias_bashrc() {
    local bashrc="$HOME/.bashrc" add_reload=0 add_open=0 nombres=""
    grep -q '# >>> evilnagi-gnome-team aliases >>>' "$bashrc" 2>/dev/null && return 0
    grep -qE '^[[:space:]]*alias[[:space:]]+reload=' "$bashrc" 2>/dev/null || add_reload=1
    grep -qE '^[[:space:]]*alias[[:space:]]+open=' "$bashrc" 2>/dev/null || add_open=1
    (( add_reload || add_open )) || return 0
    (( add_reload )) && nombres="reload"
    (( add_open )) && nombres="${nombres:+$nombres, }open"
    respaldar "$bashrc"
    {
        echo
        echo '# >>> evilnagi-gnome-team aliases >>>'
        echo '# Alias cómodos (los añade el instalador)'
        if (( add_reload )); then
            echo 'alias reload="source $HOME/.bashrc"'
        fi
        if (( add_open )); then
            echo "alias open='xdg-open'"
        fi
        echo '# <<< evilnagi-gnome-team aliases <<<'
    } >> "$bashrc"
    ok "Alias añadidos a ~/.bashrc: $nombres"
}

# --- Descargas ------------------------------------------------------------
descargar() { # descargar <url> <destino>
    mkdir -p "$(dirname "$2")"
    curl -fsSL --retry 3 --retry-delay 2 "$1" -o "$2"
}

# --- Extensiones de GNOME -------------------------------------------------
extension_instalada() {
    [[ -d "$EXT_DIR/$1" || -d "/usr/share/gnome-shell/extensions/$1" ]]
}

instalar_extension_ego() { # instalar_extension_ego <uuid>
    local uuid="$1" tmp url
    extension_instalada "$uuid" && return 0
    tmp="$(mktemp -d)"
    url="$(curl -fsS --retry 2 "https://extensions.gnome.org/extension-info/?uuid=$uuid&shell_version=$VER_GNOME" 2>/dev/null |
           python3 -c 'import json,sys; print(json.load(sys.stdin).get("download_url",""))' 2>/dev/null || true)"
    if [[ -z $url ]]; then
        rm -rf "$tmp"
        aviso "$uuid no está disponible para GNOME $VER_GNOME en extensions.gnome.org"
        return 1
    fi
    if curl -fsSL --retry 2 "https://extensions.gnome.org$url" -o "$tmp/$uuid.zip" &&
       gnome-extensions install --force "$tmp/$uuid.zip" >/dev/null 2>&1; then
        rm -rf "$tmp"
        ok "Extensión instalada: $uuid"
        return 0
    fi
    rm -rf "$tmp"
    aviso "no se pudo instalar $uuid"
    return 1
}

# Activa o desactiva una extensión en enabled-extensions sin cambiar el orden
# del resto. Vale aunque GNOME todavía no conozca la extensión.
activar_extension() { # activar_extension <uuid> true|false
    python3 - "$1" "$2" <<'PY'
import ast, subprocess, sys
uuid, on = sys.argv[1], sys.argv[2] == "true"
k = ["org.gnome.shell", "enabled-extensions"]
v = subprocess.check_output(["gsettings", "get", *k], text=True).replace("@as ", "")
lista = ast.literal_eval(v)
nueva = (lista + [uuid] if uuid not in lista else lista) if on else [u for u in lista if u != uuid]
if nueva != lista:
    subprocess.check_call(["gsettings", "set", *k, str(nueva)])
PY
}

extension_cargada() {
    gnome-extensions info "$1" 2>/dev/null | grep -iqE 'ACTIVE|ACTIVA'
}

# --- gsettings tolerante --------------------------------------------------
gs() { gsettings set "$@" 2>/dev/null || true; }
