#!/usr/bin/env bash
# Instalación de paquetes del sistema (Fedora con dnf / Ubuntu con apt).
# Requiere lib/comun.sh cargado.

paquetes_fedora() {
    cat <<'EOF'
ca-certificates
curl
dconf
desktop-file-utils
ffmpeg
git
glib2
gnome-tweaks
gthumb
gtk-update-icon-cache
nautilus-python
openmpt123
python3
python3-pip
source-foundry-hack-fonts
unzip
xdg-utils
EOF
}

paquetes_ubuntu() {
    cat <<'EOF'
ca-certificates
curl
dconf-cli
desktop-file-utils
ffmpeg
fonts-hack
git
gnome-shell-extensions
gnome-tweaks
gthumb
gtk-update-icon-cache
libglib2.0-bin
openmpt123
python3
python3-nautilus
python3-pip
python3-venv
unzip
xdg-utils
EOF
}

paquetes_extra_fedora() {
    # Fedora 44 ya no trae el metapaquete gnome-shell-extensions: las de sistema
    # van en paquetes sueltos. --skip-unavailable ignora las que no existan.
    cat <<'EOF'
ptyxis
gnome-shell-extension-appindicator
gnome-shell-extension-drive-menu
gnome-shell-extension-launch-new-instance
gnome-shell-extension-places-menu
gnome-shell-extension-user-theme
gnome-shell-extension-window-list
EOF
}

paquetes_extra_ubuntu() { echo "ptyxis"; }

preparar_repos_fedora() {
    local fv
    fv="$(rpm -E %fedora 2>/dev/null || echo 0)"
    if ! rpm -q rpmfusion-free-release >/dev/null 2>&1 &&
       [[ ! -f /etc/yum.repos.d/rpmfusion-free.repo ]]; then
        info "Añadiendo RPM Fusion (para ffmpeg)…"
        como_root dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$fv.noarch.rpm" \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$fv.noarch.rpm" \
            >/dev/null 2>&1 || aviso "no se pudo añadir RPM Fusion; ffmpeg podría no estar disponible"
    fi
}

preparar_repos_ubuntu() {
    # openmpt123 y algunos paquetes están en universe
    if ! grep -rqs 'universe' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
        info "Activando el repositorio universe…"
        if command -v add-apt-repository >/dev/null 2>&1; then
            como_root add-apt-repository -y universe >/dev/null 2>&1 || true
        else
            como_root apt-get install -y software-properties-common >/dev/null 2>&1 || true
            como_root add-apt-repository -y universe >/dev/null 2>&1 || true
        fi
    fi
    como_root apt-get update -q
}

instalar_paquetes() {
    paso "Paquetes del sistema"
    local lista paquete

    if [[ $DISTRO == fedora ]]; then
        preparar_repos_fedora
        mapfile -t lista < <(paquetes_fedora)
        info "Instalando ${#lista[@]} paquetes con dnf…"
        como_root dnf install -y --skip-unavailable --skip-broken "${lista[@]}" ||
            aviso "algunos paquetes no se pudieron instalar; el tema seguirá sin ellos"
        for paquete in $(paquetes_extra_fedora); do
            como_root dnf install -y --skip-unavailable --skip-broken "$paquete" >/dev/null 2>&1 || true
        done
    else
        preparar_repos_ubuntu
        mapfile -t lista < <(paquetes_ubuntu)
        info "Instalando ${#lista[@]} paquetes con apt…"
        if ! como_root apt-get install -y "${lista[@]}"; then
            aviso "instalación conjunta fallida; probando paquete a paquete"
            for paquete in "${lista[@]}"; do
                como_root apt-get install -y "$paquete" || aviso "no se pudo instalar $paquete"
            done
        fi
        for paquete in $(paquetes_extra_ubuntu); do
            como_root apt-get install -y "$paquete" >/dev/null 2>&1 || true
        done
    fi

    command -v gthumb >/dev/null 2>&1       || aviso "gThumb no está instalado (Abrir con gThumb no funcionará)"
    command -v openmpt123 >/dev/null 2>&1   || aviso "openmpt123 no está instalado (tracker no podrá reproducir)"
    gsettings list-schemas 2>/dev/null | grep -qx org.gnome.Ptyxis ||
        aviso "Ptyxis no está instalado; el perfil MSX de la terminal se saltará"
    ok "Paquetes listos"
}
