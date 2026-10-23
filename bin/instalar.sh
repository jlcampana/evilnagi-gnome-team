#!/usr/bin/env bash
# Instalador de Evilnagi GNOME Team.
#
#   curl -fsSL https://raw.githubusercontent.com/jlcampana/evilnagi-gnome-team/main/install.sh | bash
#
# Este archivo es el que se ejecuta dentro del repo (install.sh solo lo descarga
# y lo llama). También se puede lanzar desde un clon: ./bin/instalar.sh
set -euo pipefail

RAIZ="$(cd "$(dirname "$(realpath "$0")")/.." && pwd)"
# shellcheck source=../lib/comun.sh
. "$RAIZ/lib/comun.sh"
# shellcheck source=../lib/paquetes.sh
. "$RAIZ/lib/paquetes.sh"
# shellcheck source=../lib/tema.sh
. "$RAIZ/lib/tema.sh"
# shellcheck source=../lib/ajustes-gnome.sh
. "$RAIZ/lib/ajustes-gnome.sh"
# shellcheck source=../lib/descargas.sh
. "$RAIZ/lib/descargas.sh"

CON_PAQUETES=1
CON_TEMA=1
CON_EXTENSIONES=1
CON_DESCARGAS=1

uso() {
    cat <<EOF
Evilnagi GNOME Team — tema de GNOME para Fedora y Ubuntu

Uso:
  curl -fsSL $RAW/install.sh | bash

Opciones (con curl: ... | bash -s -- <opciones>):
  --si                no hacer preguntas (todo por defecto)
  --portatil          equipo portátil (no instala Soft Brightness Plus)
  --sobremesa         equipo de sobremesa
  --sin-paquetes      no instalar paquetes del sistema
  --sin-extensiones   no tocar las extensiones de GNOME
  --sin-descargas     no instalar scripts de descarga ni tracker
  --solo-tema         solo tema de GNOME (implica --sin-descargas)
  --solo-descargas    solo scripts de descarga y tracker (implica --sin-paquetes --sin-tema)
  -h, --ayuda         esta ayuda

Qué instala:
  · Tema visual: GTK/Nautilus compactos, botones rojos, dock y barra grises,
    transparencias, reborde de ventanas, iconos MoreWaita + papelera Tela.
  · Extensiones de GNOME y sus ajustes (Dash to Dock se omite en Ubuntu).
  · Scripts del tema en ~/scripts, y ~/scripts y ~/.local/bin en el PATH.
  · Descargas: ydl, yda, xdl, twitter, r34dl, allr34dl (con gallery-dl,
    yt-dlp, ffmpeg, Deno…) y el reproductor de música tracker.
  · Configuración de descargas en ~/.config/evilnagi-gnome-team/descargas.conf

Todo lo que se sobrescribe se guarda en ~/backups/evilnagi-gnome-team-<fecha>/
EOF
}

while (( $# )); do
    case "$1" in
        --si|-y)          ASUMIR=1 ;;
        --portatil)       EQUIPO=portatil ;;
        --sobremesa)      EQUIPO=sobremesa ;;
        --sin-paquetes)   CON_PAQUETES=0 ;;
        --sin-extensiones) CON_EXTENSIONES=0 ;;
        --sin-descargas)  CON_DESCARGAS=0 ;;
        --solo-tema)      CON_DESCARGAS=0 ;;
        --solo-descargas) CON_DESCARGAS=1; CON_PAQUETES=0; CON_TEMA=0; CON_EXTENSIONES=0 ;;
        -h|--ayuda|--help) uso; exit 0 ;;
        *) morir "opción desconocida: $1 (usa --ayuda)" ;;
    esac
    shift
done

(( EUID == 0 )) && [[ ${HOME:-} == /root ]] &&
    morir "no ejecutes el instalador entero con sudo: pide permisos solo cuando hace falta"

export PATH="$HOME/.local/bin:$HOME/scripts:$PATH"

paso "Evilnagi GNOME Team"
detectar_sistema
elegir_equipo

if (( ASUMIR == 0 )); then
    echo
    info "Se va a instalar el tema en $PRETTY (GNOME $VER_GNOME, equipo $EQUIPO)."
    info "Se guardará copia de lo que se sobrescriba en ~/backups/"
    preguntar_si "¿Continuar? [S/n]" s || { echo "Cancelado."; exit 0; }
fi

(( CON_PAQUETES )) && instalar_paquetes

if (( CON_TEMA )); then
    aplicar_tema
    aplicar_ajustes_gnome
    (( CON_EXTENSIONES )) && instalar_extensiones_gnome
fi

(( CON_DESCARGAS )) && instalar_descargas

paso "Listo"
if [[ -d $BACKUP ]]; then
    info "Copia de lo anterior: $BACKUP"
fi
info "Cierra sesión y vuelve a entrar para que GNOME cargue las extensiones y el tema."
if command -v tracker >/dev/null 2>&1; then
    info "Prueba el reproductor con: tracker"
fi
if command -v ydl >/dev/null 2>&1; then
    info "Descargas: ydl <url> · yda <url> · xdl <url> · r34dl <tags>"
fi
