#!/usr/bin/env bash
# Instala (o actualiza) el tema de iconos MoreWaita y lo activa.
# MoreWaita = Adwaita ampliado con iconos propios para muchas más apps y tipos de archivo.
# https://github.com/somepaulo/MoreWaita
#
# Uso:  instalar-morewaita.sh            instala/actualiza y lo activa
#       instalar-morewaita.sh --quitar   vuelve a Adwaita y lo desinstala
#
# Independiente: vale para Fedora y Ubuntu con GNOME (instala git si falta).

set -euo pipefail

DEST="$HOME/.local/share/icons/MoreWaita"

if [[ "${1:-}" == "--quitar" ]]; then
    gsettings set org.gnome.desktop.interface icon-theme Adwaita
    rm -rf "$DEST"
    echo "MoreWaita desinstalado; tema de iconos: Adwaita."
    exit 0
fi

# git (para bajar el tema): se instala si falta, con dnf (Fedora) o apt (Ubuntu)
if ! command -v git >/dev/null; then
    . /etc/os-release
    como_root() { if command -v sudo >/dev/null 2>&1; then sudo "$@"; else pkexec "$@"; fi; }
    case " $ID ${ID_LIKE:-} " in
        *" fedora "*) como_root dnf install -y git ;;
        *" ubuntu "*|*" debian "*) como_root sh -c "apt-get update -q && apt-get install -y git" ;;
        *) echo "Falta git; instálalo con el gestor de paquetes de tu distro." >&2; exit 1 ;;
    esac
fi

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
echo "Descargando MoreWaita…"
git clone -q --depth=1 https://github.com/somepaulo/MoreWaita.git "$T/MoreWaita"
rm -rf "$DEST"   # instalación limpia (su instalador solo añade/actualiza archivos)
bash "$T/MoreWaita/install.sh" >/dev/null
echo "Instalado en $DEST ($(git -C "$T/MoreWaita" log -1 --format=%cs))"

gsettings set org.gnome.desktop.interface icon-theme MoreWaita
echo "Tema de iconos activado: MoreWaita"

# Las apps Flatpak no ven ~/.local/share/icons sin permiso
if command -v flatpak >/dev/null; then
    flatpak override --user --filesystem=xdg-data/icons:ro
    echo "Permiso Flatpak concedido (las apps Flatpak también usarán los iconos)."
fi
