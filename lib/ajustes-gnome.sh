#!/usr/bin/env bash
# Ajustes generales de GNOME del tema (aspecto oscuro, ventanas, escritorio,
# Nautilus y gThumb). Se ejecuta al final, después de los scripts del tema.
# Requiere lib/comun.sh cargado.

poner_fondo() {
    local destino="$HOME/.local/share/backgrounds/evilnagi-gnome-team.svg"
    local origen="$RAIZ/tema/fondos/fondo.svg"
    [[ -f $origen ]] || { aviso "no encuentro el fondo del tema"; return 0; }
    mkdir -p "$(dirname "$destino")"
    cp -f "$origen" "$destino"
    local uri
    uri="file://$(python3 -c 'import os,sys,urllib.parse; print(urllib.parse.quote(os.path.abspath(sys.argv[1])))' "$destino")"
    gs org.gnome.desktop.background picture-uri "$uri"
    gs org.gnome.desktop.background picture-uri-dark "$uri"
    gs org.gnome.desktop.background picture-options 'zoom'
    gs org.gnome.desktop.background color-shading-type 'solid'
    gs org.gnome.desktop.background primary-color '#121117'
    gs org.gnome.desktop.background secondary-color '#121117'
    gs org.gnome.desktop.screensaver picture-uri "$uri"
    gs org.gnome.desktop.screensaver color-shading-type 'solid'
    ok "Fondo de escritorio del tema"
}

aplicar_ajustes_gnome() {
    paso "Ajustes generales de GNOME"

    # Aspecto
    gs org.gnome.desktop.interface color-scheme 'prefer-dark'
    gs org.gnome.desktop.interface gtk-theme 'Adwaita'
    gs org.gnome.desktop.interface icon-theme 'Papelera-Tela'
    gs org.gnome.desktop.interface font-antialiasing 'grayscale'
    gs org.gnome.desktop.interface font-hinting 'medium'
    gs org.gnome.desktop.interface enable-hot-corners false
    gs org.gnome.desktop.interface show-battery-percentage true

    # Ventanas: botones a la izquierda (cerrar), 2 escritorios fijos
    gs org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
    gs org.gnome.desktop.wm.preferences num-workspaces 2
    gs org.gnome.mutter dynamic-workspaces false
    gs org.gnome.desktop.wm.keybindings switch-to-workspace-left "['<Control>Left']"
    gs org.gnome.desktop.wm.keybindings switch-to-workspace-right "['<Control>Right']"

    # Nautilus: vista compacta, columnas y preferencias del tema
    gs org.gnome.nautilus.icon-view default-zoom-level 'small-plus'
    gs org.gnome.nautilus.icon-view captions "['size', 'none', 'none']"
    gs org.gnome.nautilus.list-view default-zoom-level 'small'
    gs org.gnome.nautilus.list-view use-tree-view true
    gs org.gnome.nautilus.list-view default-visible-columns \
        "['name', 'size', 'date_modified', 'date_created', 'detailed_type']"
    gs org.gnome.nautilus.preferences date-time-format 'detailed'
    gs org.gnome.nautilus.preferences default-folder-viewer 'icon-view'
    gs org.gnome.nautilus.preferences show-create-link true
    gs org.gnome.nautilus.preferences show-delete-permanently true
    gs org.gnome.nautilus.preferences show-image-thumbnails 'local-only'

    # gThumb: miniaturas de 256 px
    gs org.gnome.gthumb.browser thumbnail-size 256
    gs org.gnome.gthumb.browser sort-type 'file::mtime'

    poner_fondo
    ok "Aspecto oscuro, botones de ventana, Nautilus y gThumb"
}
