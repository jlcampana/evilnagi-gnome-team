#!/usr/bin/env bash
# Pone en Ptyxis (la terminal de GNOME) el perfil "MSX" como perfil por defecto:
#   - paleta de colores MSX (fondo azul del V9938 de MSX2 y colores ANSI del TMS9918)
#   - fuente Hack 11 (la instala si falta: source-foundry-hack-fonts en Fedora, fonts-hack en Ubuntu)
#   - opacidad 85 % (el blur detrás lo pone blur-ventanas.sh o la extensión Transparencias)
#   - carpetas de ls en amarillo (LS_COLORS en ~/.bashrc): el azul de las carpetas no se lee sobre el fondo azul
#
# Si ya existe un perfil llamado "MSX" lo reutiliza; si no, lo crea.
#
# Uso:  terminal-msx.sh             crea/actualiza el perfil MSX y lo deja por defecto
#       terminal-msx.sh --quitar    borra el perfil MSX y la paleta (vuelve el perfil anterior)
#
# Independiente: todo va dentro de este script (Fedora y Ubuntu con Ptyxis). Las ventanas de
# Ptyxis ya abiertas cogen el cambio al abrir una pestaña o ventana nueva.

set -euo pipefail

PALETAS="$HOME/.local/share/org.gnome.Ptyxis/palettes"
BASE=/org/gnome/Ptyxis
OPACIDAD=0.85

gsettings list-schemas | grep -x org.gnome.Ptyxis >/dev/null ||
    { echo "Ptyxis no está instalado (Fedora: sudo dnf install ptyxis · Ubuntu: sudo apt install ptyxis)." >&2; exit 1; }

uuids() { gsettings get org.gnome.Ptyxis profile-uuids | grep -oE '[0-9a-f]{32}' || true; }
uuid_msx() { for u in $(uuids); do [[ "$(dconf read "$BASE/Profiles/$u/label")" == "'MSX'" ]] && { echo "$u"; return; }; done; true; }
BASHRC_ALT='# Carpetas en amarillo en ls (terminal-msx)'

lista() { python3 -c "import sys; print(str(sys.argv[1:]))" "$@"; }

if [[ "${1:-}" == "--quitar" ]]; then
    U="$(uuid_msx)"
    if [[ -n "$U" ]]; then
        RESTO=($(uuids | grep -vx "$U" || true))
        gsettings set org.gnome.Ptyxis profile-uuids "$(lista "${RESTO[@]}")"
        [[ "$(gsettings get org.gnome.Ptyxis default-profile-uuid)" == "'$U'" && ${#RESTO[@]} -gt 0 ]] &&
            gsettings set org.gnome.Ptyxis default-profile-uuid "${RESTO[0]}"
        dconf reset -f "$BASE/Profiles/$U/"
    fi
    rm -f "$PALETAS/MSX.palette"
    [[ -f "$HOME/.bashrc" ]] && sed -i "/^$BASHRC_ALT\$/,+1d" "$HOME/.bashrc"
    echo "Perfil y paleta MSX quitados."
    exit 0
fi

# --- Paleta
mkdir -p "$PALETAS"
cat > "$PALETAS/MSX.palette" <<'EOF'
[Palette]
Name=MSX
Primary=true
Background=#2424DB
Foreground=#FFFFFF
Cursor=#FFFFFF
Color0=#000000
Color1=#D4524D
Color2=#21C842
Color3=#D4C154
Color4=#2D2B9E
Color5=#C95BBA
Color6=#42EBF5
Color7=#CCCCCC
Color8=#9A9A9A
Color9=#FF7978
Color10=#5EDC78
Color11=#E6CE80
Color12=#B5B0FF
Color13=#E08CD6
Color14=#8CF4FA
Color15=#FFFFFF

# Paleta inspirada en el MSX: fondo azul del V9938 (MSX2), colores ANSI del TMS9918
EOF

# --- Fuente Hack
if ! fc-list : family | grep -ix hack >/dev/null; then
    . /etc/os-release
    como_root() { if command -v sudo >/dev/null 2>&1; then sudo "$@"; else pkexec "$@"; fi; }
    case " $ID ${ID_LIKE:-} " in
        *" fedora "*) como_root dnf install -y source-foundry-hack-fonts ;;
        *" ubuntu "*|*" debian "*) como_root sh -c "apt-get update -q && apt-get install -y fonts-hack" ;;
    esac || echo "AVISO: no se pudo instalar la fuente Hack; Ptyxis usará otra monoespaciada."
fi

# --- Perfil MSX (reutiliza el que exista con ese nombre)
U="$(uuid_msx)"
if [[ -z "$U" ]]; then
    U="$(python3 -c 'import uuid; print(uuid.uuid4().hex)')"
    ACTUALES=($(uuids))
    gsettings set org.gnome.Ptyxis profile-uuids "$(lista "${ACTUALES[@]}" "$U")"
    echo "Perfil MSX creado ($U)"
fi
dconf write "$BASE/Profiles/$U/label" "'MSX'"
dconf write "$BASE/Profiles/$U/palette" "'MSX'"
dconf write "$BASE/Profiles/$U/opacity" "$OPACIDAD"
gsettings set org.gnome.Ptyxis default-profile-uuid "$U"
gsettings set org.gnome.Ptyxis use-system-font false
gsettings set org.gnome.Ptyxis font-name 'Hack 11'
gsettings set org.gnome.Ptyxis interface-style 'dark'
# --- Carpetas en amarillo (si el .bashrc no lo hace ya, p. ej. el de albedo)
if ! grep -q 'di=01;33' "$HOME/.bashrc" 2>/dev/null; then
    printf '\n%s\nexport LS_COLORS="${LS_COLORS}:di=01;33"\n' "$BASHRC_ALT" >> "$HOME/.bashrc"
    echo "Carpetas en amarillo en ~/.bashrc (terminales nuevas)."
fi
echo "Ptyxis: perfil MSX por defecto (paleta MSX, Hack 11, opacidad $(python3 -c "print(round($OPACIDAD*100))") %)."
