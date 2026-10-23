#!/usr/bin/env bash
# Evilnagi GNOME Team — instalador de un solo uso.
#
#   curl -fsSL https://raw.githubusercontent.com/jlcampana/evilnagi-gnome-team/main/install.sh | bash
#
# Descarga el repo (sin git, con el tarball de GitHub) a una carpeta temporal y
# ejecuta bin/instalar.sh. Si ya estás dentro de un clon, usa el clon local.
#
# Todo va dentro de main() para que bash termine de leer el script antes de
# ejecutarlo: así funciona con `curl | bash` sin que las preguntas se coman
# las líneas que faltan (se leen por /dev/tty).
set -euo pipefail

REPO="${EVILNAGI_REPO:-jlcampana/evilnagi-gnome-team}"
RAMA="${EVILNAGI_RAMA:-main}"
TARBALL="${EVILNAGI_TARBALL:-https://codeload.github.com/$REPO/tar.gz/refs/heads/$RAMA}"

main() {
    local origen="" tmp="" estado=0

    # 1. ¿Estamos dentro de un clon?
    if [[ -n ${EVILNAGI_SOURCE:-} && -f "${EVILNAGI_SOURCE}/bin/instalar.sh" ]]; then
        origen="$EVILNAGI_SOURCE"
    elif [[ -n ${BASH_SOURCE[0]:-} && -f ${BASH_SOURCE[0]} ]]; then
        local aqui
        aqui="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        [[ -f "$aqui/bin/instalar.sh" ]] && origen="$aqui"
    fi

    # 2. Si no, descargar el tarball del repo
    if [[ -z $origen ]]; then
        command -v curl >/dev/null 2>&1 ||
            { echo "ERROR: hace falta curl para descargar el instalador." >&2; exit 1; }
        tmp="$(mktemp -d "${TMPDIR:-/tmp}/evilnagi-gnome-team.XXXXXX")"
        trap 'rm -rf "$TMP_REPO"' EXIT
        TMP_REPO="$tmp"

        printf '\033[1m== Evilnagi GNOME Team\033[0m\n'
        printf '   Descargando el tema de GitHub…\n'
        if ! curl -fsSL --retry 3 --retry-delay 2 "$TARBALL" -o "$tmp/repo.tar.gz"; then
            if command -v git >/dev/null 2>&1; then
                git clone -q --depth=1 --branch "$RAMA" "https://github.com/$REPO.git" "$tmp/repo" ||
                    { echo "ERROR: no se pudo descargar https://github.com/$REPO" >&2; exit 1; }
                origen="$tmp/repo"
            else
                echo "ERROR: no se pudo descargar https://github.com/$REPO" >&2
                exit 1
            fi
        else
            mkdir -p "$tmp/repo"
            tar -xzf "$tmp/repo.tar.gz" -C "$tmp/repo" --strip-components=1 ||
                { echo "ERROR: el archivo descargado no es válido" >&2; exit 1; }
            origen="$tmp/repo"
        fi
    fi

    bash "$origen/bin/instalar.sh" "$@" || estado=$?
    return "$estado"
}

main "$@"
