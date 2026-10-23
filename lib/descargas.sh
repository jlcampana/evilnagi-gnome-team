#!/usr/bin/env bash
# Scripts de descarga (YouTube, X/Twitter, rule34), sus dependencias de Python,
# Deno y el reproductor de música tracker.
# Requiere lib/comun.sh cargado.

VENV_DESCARGAS="$HOME/.local/share/gallery-dl-venv"
VENV_TRACKER="$HOME/.local/share/trackerplay-venv"
APP_TRACKER="$HOME/.local/share/trackerplay-app"

bloque_path() {
    local bashrc="$HOME/.bashrc"
    grep -q '# >>> evilnagi-gnome-team >>>' "$bashrc" 2>/dev/null && return 0
    respaldar "$bashrc"
    {
        echo
        echo '# >>> evilnagi-gnome-team >>>'
        echo '# Scripts propios y binarios locales (lo añade el instalador del tema)'
        echo 'case ":$PATH:" in *":$HOME/scripts:"*) ;; *) export PATH="$HOME/scripts:$PATH" ;; esac'
        echo 'case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac'
        echo '# <<< evilnagi-gnome-team <<<'
    } >> "$bashrc"
    ok "~/scripts y ~/.local/bin añadidos al PATH en ~/.bashrc"
}

preparar_venv_descargas() {
    if [[ ! -x "$VENV_DESCARGAS/bin/python" ]]; then
        info "Creando entorno de Python para las descargas…"
        python3 -m venv "$VENV_DESCARGAS" || { aviso "no se pudo crear $VENV_DESCARGAS"; return 1; }
    fi
    "$VENV_DESCARGAS/bin/pip" install -q -U pip >/dev/null 2>&1 || true
    info "Instalando/actualizando gallery-dl, yt-dlp, yt-dlp-ejs, secretstorage y curl_cffi…"
    if "$VENV_DESCARGAS/bin/pip" install -q -U gallery-dl yt-dlp yt-dlp-ejs secretstorage curl_cffi requests; then
        ok "Entorno de descargas listo ($VENV_DESCARGAS)"
    else
        aviso "no se pudieron instalar todas las dependencias de descargas; los scripts las reintentarán solos"
    fi
}

instalar_deno() {
    command -v deno >/dev/null 2>&1 && { ok "Deno ya está instalado"; return 0; }
    [[ -x "$HOME/.local/bin/deno" ]] && { ok "Deno ya está en ~/.local/bin"; return 0; }

    local arq zip tmp
    case "$(uname -m)" in
        x86_64|amd64)  arq=x86_64-unknown-linux-gnu ;;
        aarch64|arm64) arq=aarch64-unknown-linux-gnu ;;
        *) aviso "arquitectura $(uname -m) sin binario de Deno; se omite"; return 0 ;;
    esac
    zip="https://github.com/denoland/deno/releases/latest/download/deno-$arq.zip"
    tmp="$(mktemp -d)"
    if curl -fsSL --retry 3 "$zip" -o "$tmp/deno.zip" &&
       python3 -m zipfile -e "$tmp/deno.zip" "$tmp" 2>/dev/null &&
       [[ -f "$tmp/deno" ]]; then
        mkdir -p "$HOME/.local/bin"
        install -m755 "$tmp/deno" "$HOME/.local/bin/deno"
        ok "Deno instalado en ~/.local/bin/deno (para el reto JS de YouTube)"
    else
        aviso "no se pudo instalar Deno; yt-dlp solo obtendrá storyboards de YouTube"
    fi
    rm -rf "$tmp"
}

instalar_tracker() {
    local origen="$RAIZ/extras/trackerplay"
    [[ -d $origen ]] || { aviso "no encuentro extras/trackerplay"; return 0; }

    mkdir -p "$APP_TRACKER"
    cp -a "$origen"/. "$APP_TRACKER"/
    chmod +x "$APP_TRACKER/tracker.sh" "$APP_TRACKER/tracker.py"
    info "Preparando el reproductor tracker (Textual)…"
    if [[ ! -x "$VENV_TRACKER/bin/python" ]]; then
        python3 -m venv "$VENV_TRACKER" || { aviso "no se pudo crear $VENV_TRACKER"; return 1; }
    fi
    "$VENV_TRACKER/bin/pip" install -q -U pip >/dev/null 2>&1 || true
    if "$VENV_TRACKER/bin/pip" install -q -r "$APP_TRACKER/requirements.txt"; then
        ok "Tracker instalado en $APP_TRACKER"
    else
        aviso "no se pudieron instalar las dependencias del tracker (Textual)"
    fi
    mkdir -p "$HOME/.local/bin"
    ln -sf "$APP_TRACKER/tracker.sh" "$HOME/.local/bin/tracker"
    ok "Comando 'tracker' disponible en ~/.local/bin/tracker"
}

instalar_descargas() {
    paso "Scripts de descarga y reproductor tracker"

    mkdir -p "$HOME/scripts" "$HOME/.local/bin" "$CONFIG_DIR"

    # Scripts: se copian tal cual, sin borrar otros que tenga el usuario
    local f
    for f in "$RAIZ"/scripts/descargas/{ydl,yda,xdl,twitter,r34dl,allr34dl,r34html.py}; do
        [[ -f $f ]] && poner "$f" "$HOME/scripts/$(basename "$f")"
    done
    chmod +x "$HOME"/scripts/{ydl,yda,xdl,twitter,r34dl,allr34dl,r34html.py} 2>/dev/null || true
    ok "Scripts instalados en ~/scripts (ydl, yda, xdl, twitter, r34dl, allr34dl)"

    # Configuración común (no se pisa la que ya exista)
    if [[ ! -f "$CONFIG_DIR/descargas.conf" ]]; then
        cp "$RAIZ/scripts/descargas/descargas.conf.ejemplo" "$CONFIG_DIR/descargas.conf"
        ok "Configuración creada en $CONFIG_DIR/descargas.conf"
    else
        ok "Se conserva la configuración existente: $CONFIG_DIR/descargas.conf"
    fi

    bloque_path
    preparar_venv_descargas
    instalar_deno
    instalar_tracker

    command -v ffmpeg >/dev/null 2>&1 && ok "ffmpeg disponible" ||
        aviso "ffmpeg no está instalado: ydl no podrá unir vídeo+audio ni convertir a mp3"
    command -v openmpt123 >/dev/null 2>&1 ||
        aviso "openmpt123 no está instalado: tracker no podrá reproducir módulos"
}
