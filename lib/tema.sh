#!/usr/bin/env bash
# Aplicación del tema GNOME (iconos, GTK, Nautilus, extensiones y ajustes).
# Requiere lib/comun.sh cargado.

ejecutar() { # ejecutar <script> [argumentos...]
    local script="$1"; shift
    local ruta="$RAIZ/scripts/tema/$script"
    [[ -f $ruta ]] || { aviso "falta $ruta"; return 0; }
    if bash "$ruta" "$@"; then
        return 0
    fi
    aviso "$script terminó con errores (se continúa)"
    return 0
}

hay_1password() {
    [[ -f /usr/share/applications/1password.desktop ]] ||
    [[ -f "$HOME/.local/share/applications/1password.desktop" ]] ||
    command -v 1password >/dev/null 2>&1
}

hay_gtk_tweaks() {
    [[ -f /usr/share/applications/org.gnome.tweaks.desktop ]] ||
    [[ -f /var/lib/flatpak/exports/share/applications/org.gnome.tweaks.desktop ]] ||
    [[ -f "$HOME/.local/share/flatpak/exports/share/applications/org.gnome.tweaks.desktop" ]]
}

hay_dock() {
    extension_instalada dash-to-dock@micxgx.gmail.com ||
    extension_instalada ubuntu-dock@ubuntu.com ||
    gsettings list-schemas 2>/dev/null | grep -qx org.gnome.shell.extensions.dash-to-dock
}

instalar_extensiones_locales() {
    # Transparencias trae su propio instalador (extensión + nautilus-python)
    ejecutar instalar-transparencias.sh

    # Extensiones de Nautilus que no van con Transparencias
    mkdir -p "$NPY_DIR"
    local f
    for f in abrir-con-gthumb.py panel-lateral-estrecho.py; do
        [[ -f "$RAIZ/tema/nautilus-python/$f" ]] && poner "$RAIZ/tema/nautilus-python/$f" "$NPY_DIR/$f"
    done
    ok "Extensiones de Nautilus: Abrir con gThumb y panel lateral estrecho"
}

copiar_scripts_tema() {
    local f
    mkdir -p "$HOME/scripts"
    for f in "$RAIZ"/scripts/tema/*.sh; do
        poner "$f" "$HOME/scripts/$(basename "$f")"
    done
    chmod +x "$HOME"/scripts/*.sh 2>/dev/null || true
    ok "Scripts del tema instalados en ~/scripts"
}

aplicar_tema() {
    paso "Tema de GNOME"

    info "GTK y Nautilus compactos, diálogos de confirmación…"
    ejecutar gtk-compacto.sh
    ejecutar dialogos-confirmacion.sh
    ejecutar nautilus-compacto.sh

    info "Iconos MoreWaita y papelera de Tela-circle…"
    ejecutar instalar-morewaita.sh
    ejecutar papelera-tela.sh

    if hay_gtk_tweaks; then
        ejecutar icono-app.sh --retoques
    else
        info "Retoques no está instalado; se omite su icono"
    fi
    hay_1password && ejecutar icono-app.sh --1password-bandeja

    info "Extensiones locales y de Nautilus…"
    instalar_extensiones_locales

    info "Transparencias y blur en Nautilus y Ptyxis…"
    ejecutar blur-ventanas.sh

    info "Reborde de ventanas (P7 Borders)…"
    ejecutar reborde-ventanas.sh

    info "Barra superior y dock grises…"
    ejecutar barra-dock-gris.sh

    info "Botones de sesión y confirmación en rojo…"
    ejecutar botones-sesion-rojos.sh

    if hay_dock; then
        info "Botón de aplicaciones con imagen en el dock…"
        ejecutar boton-aplicaciones.sh
    else
        info "No hay Dash to Dock/Ubuntu Dock; se omite el botón de aplicaciones"
    fi

    if hay_1password; then
        info "Clic en el icono de 1Password de la bandeja…"
        ejecutar clic-bandeja.sh
    fi

    info "Terminal con el perfil MSX…"
    ejecutar terminal-msx.sh

    copiar_scripts_tema
    ok "Tema aplicado (cierra sesión para cargar las extensiones nuevas)"
}

instalar_extensiones_gnome() {
    paso "Extensiones de GNOME"
    ejecutar extensiones.sh "--$EQUIPO"
}
