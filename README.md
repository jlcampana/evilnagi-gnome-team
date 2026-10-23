# Evilnagi GNOME Team

Tema completo de escritorio **GNOME** para **Fedora** y **Ubuntu**, instalable en un solo paso y sin clonar el repositorio. Deja el escritorio con la misma pinta que el equipo original: barra y dock grises, ventanas compactas estilo macOS, botones de cerrar y de confirmar en rojo, transparencias, reborde de ventanas, iconos MoreWaita con la papelera de Tela-circle, terminal MSX, extensiones de GNOME y scripts propios.

## Instalación

### Requisitos

- **Fedora** (41 o posterior) o **Ubuntu/Debian** (24.04 o posterior) con escritorio **GNOME 46–50**.
- `curl` y conexión a internet.
- `sudo` (o `pkexec`): el instalador pide permisos solo para instalar paquetes.
- No lo ejecutes entero con `sudo`; instalaría las cosas en `/root`.

Probado en **Fedora 44** con **GNOME 50**. En **Ubuntu 24.04+** se instalan los equivalentes de `apt` y las mismas extensiones; **Dash to Dock no se instala**: chocaría con Ubuntu Dock, que usa los mismos ajustes, así que el dock queda igual.

### Instalación rápida (recomendada)

Abre una terminal en el equipo donde quieras poner el tema y pega:

```bash
curl -fsSL https://raw.githubusercontent.com/jlcampana/evilnagi-gnome-team/main/install.sh | bash
```

Ese único comando:

1. Descarga el repositorio a una carpeta temporal (no hace falta tener `git` ni clonar nada).
2. Instala con `dnf` o `apt` los paquetes que falten (iconos, fuentes, Ptyxis, gThumb, `openmpt123`…).
3. Aplica el tema de GNOME: GTK, Nautilus, botones, dock, barra, transparencias, rebordes, iconos y fondo.
4. Instala las extensiones de GNOME y sus ajustes.
5. Instala los scripts de descarga (`ydl`, `yda`, `xdl`, `twitter`, `r34dl`, `allr34dl`) y el reproductor **tracker**.
6. Guarda una copia de lo que sobrescribe en `~/backups/evilnagi-gnome-team-<fecha>/`.

El instalador pregunta si el equipo es portátil o sobremesa y pide confirmación antes de empezar. Las preguntas se leen por `/dev/tty`, así que funcionan aunque el script venga por una tubería (`curl | bash`).

**Al terminar, cierra sesión y vuelve a entrar** para que GNOME cargue las extensiones y el tema.

### Instalación sin preguntas

Para que no pregunte nada (usa los valores por defecto):

```bash
curl -fsSL https://raw.githubusercontent.com/jlcampana/evilnagi-gnome-team/main/install.sh | bash -s -- --si
```

En un portátil (no instala Soft Brightness Plus, que choca con el brillo del portátil):

```bash
curl -fsSL https://raw.githubusercontent.com/jlcampana/evilnagi-gnome-team/main/install.sh | bash -s -- --si --portatil
```

### Instalación desde un clon

Si prefieres tener el repositorio en local:

```bash
git clone https://github.com/jlcampana/evilnagi-gnome-team.git
cd evilnagi-gnome-team
./install.sh            # o ./bin/instalar.sh
```

### Opciones

| Opción | Qué hace |
|---|---|
| `--si` | No pregunta nada (usa los valores por defecto) |
| `--portatil` | Equipo portátil: no instala Soft Brightness Plus |
| `--sobremesa` | Equipo de sobremesa (por defecto si hay batería se detecta solo) |
| `--sin-paquetes` | No instala paquetes del sistema |
| `--sin-extensiones` | No toca las extensiones de GNOME |
| `--sin-descargas` | No instala scripts de descarga ni tracker |
| `--solo-tema` | Solo el tema (equivale a `--sin-descargas`) |
| `--solo-descargas` | Solo descargas y tracker (implica `--sin-paquetes` y `--sin-tema`) |
| `-h`, `--ayuda` | Ayuda |

El instalador es idempotente: se puede volver a ejecutar para actualizar. Todo lo que sobrescribe (GTK CSS, scripts, `.bashrc`…) se guarda antes en `~/backups/evilnagi-gnome-team-<fecha>/`.

## Contenido

| Bloque | Qué hace |
|---|---|
| **GTK / Nautilus** | Barras de título de 30 px y botones pequeños (estilo macOS), botón de cerrar rojo en GTK 4, pestañas compactas, Nautilus sin el título «Archivos» y con el panel lateral estrecho, diálogos de confirmación con los botones en fila y el botón destructivo en rojo |
| **Barra y dock** | Barra superior y dock del gris `#2e2e32` al 95 % (mini-extensión `barra-nautilus`), dock fijo a la izquierda, iconos de 32 px y botón «Mostrar aplicaciones» con imagen propia |
| **Ventanas** | Reborde de 2 px con P7 Borders (color de acento en la ventana activa), transparencias con blur en Nautilus y Ptyxis |
| **Botones del sistema** | Apagar/Reiniciar/Cerrar sesión y confirmaciones de GNOME Shell en rojo (mini-extensión `botones-sesion`) |
| **Iconos** | [MoreWaita](https://github.com/somepaulo/MoreWaita) + papelera de [Tela-circle](https://github.com/vinceliuice/Tela-circle-icon-theme) en verde (mini-tema `Papelera-Tela`), icono de Retoques de Reversal y de 1Password en la bandeja |
| **Terminal** | Ptyxis con el perfil **MSX** (fondo azul del V9938, paleta del TMS9918, fuente Hack 11, opacidad 85 % y carpetas en amarillo en `ls`) |
| **Extensiones** | Las mismas de GNOME del equipo original, con sus ajustes: Dash to Dock, Just Perfection, DING, Top Bar Organizer, Vitals, Clipboard Indicator, P7 Borders, AppIndicator, Transparencias… |
| **Escritorio** | Modo oscuro, fondo del tema, 2 escritorios, botones de ventana a la izquierda, Ctrl+←/→ para cambiar de escritorio y ajustes de Nautilus/gThumb |
| **Descargas** | `ydl`, `yda`, `xdl`, `twitter`, `r34dl` y `allr34dl`, con `gallery-dl`, `yt-dlp`, `ffmpeg`, Deno y cookies del navegador |
| **Tracker** | Reproductor de música tracker (`tracker`): explora modarchive.org y reproduce MOD/XM/S3M/IT con `openmpt123` |

No se incluyen datos personales (fondos, avatares, memorias, credenciales, scripts de emulación, etc.). Tampoco se instalan apps de escritorio: solo sus dependencias.

## Descargas

Los scripts quedan en `~/scripts` y se añaden al `PATH` desde `~/.bashrc`:

```bash
ydl  https://youtu.be/...          # vídeo de YouTube (detecta vídeo, playlist o canal)
yda  https://youtu.be/...          # solo audio (mp3; -f ogg para ogg)
xdl  https://x.com/usuario/media   # imágenes de X (con -v, también vídeos)
twitter                            # procesa las URLs de listas.md
r34dl  "etiqueta1 etiqueta2"       # rule34.xxx
allr34dl                           # aplica r34dl a todas las URLs de una lista
tracker                            # explorador y reproductor de módulos
```

La configuración está en **`~/.config/evilnagi-gnome-team/descargas.conf`**:

- `DESCARGAS_DIR`: carpeta base (por defecto `~/Descargas`).
- `NAVEGADOR`: de dónde se leen las cookies (`brave`, `chrome`, `chromium`, `firefox`…).
- `TWITTER_LISTA` y `ALLR34_LISTA`: ficheros de listas de URLs.
- `R34_API_KEY` / `R34_USER_ID`: credenciales opcionales del API de rule34.
- `TRACKER_DIR`: biblioteca local de módulos (por defecto `Música/Tracker`).

Dependencias que instala: `python3`, `python3-venv`, `ffmpeg`, `openmpt123`, `unzip` y los entornos de Python `~/.local/share/gallery-dl-venv` (gallery-dl, yt-dlp, yt-dlp-ejs, secretstorage, curl_cffi) y `~/.local/share/trackerplay-venv` (Textual). **Deno** se baja de su web oficial a `~/.local/bin/deno`.

> Para descargar con cookies, el navegador debe haberse abierto al menos una vez con la sesión iniciada y el llavero de GNOME desbloqueado.

## Estructura

```
install.sh                 Bootstrap para curl | bash (descarga el tarball y llama a bin/instalar.sh)
bin/instalar.sh            Instalador principal
bin/desinstalar.sh         Desinstalador
lib/comun.sh               Utilidades, detección de distro/GNOME, copias de seguridad
lib/paquetes.sh            Paquetes dnf/apt y repos (RPM Fusion, universe)
lib/tema.sh                Orquesta el tema y las extensiones
lib/ajustes-gnome.sh       Ajustes generales (dconf/gsettings), fondo y Nautilus
lib/descargas.sh           Scripts de descarga, venvs, Deno y tracker
scripts/tema/              Scripts del tema (cada uno se puede ejecutar suelto con --quitar)
scripts/descargas/         ydl, yda, xdl, twitter, r34dl, allr34dl, r34html.py
tema/dconf/                Ajustes de las extensiones
tema/extensiones.txt       Lista de extensiones y estado (activa/inactiva, usuario/sistema)
tema/extensiones-locales/  Extensión propia Transparencias
tema/nautilus-python/      Extensiones de Nautilus (gThumb, panel estrecho, opacidad)
tema/iconos/apps-propias/  Iconos propios (botón del dock, bandeja de 1Password)
tema/fondos/fondo.svg      Fondo del tema
extras/trackerplay/        Reproductor de música tracker
```

## Desinstalar

```bash
./bin/desinstalar.sh          # pregunta antes de quitar
./bin/desinstalar.sh --si     # sin preguntar
./bin/desinstalar.sh --todo   # además borra venvs y configuración
```

Los ajustes de dconf (dock, extensiones, fondo…) no se revierten solos; el desinstalador deja las extensiones desactivadas y explica cómo volver al aspecto por defecto.

## Problemas frecuentes

- **No aparecen las extensiones o la barra gris**: cierra sesión y vuelve a entrar. En Wayland no se puede reiniciar GNOME Shell sin cerrar sesión.
- **La barra superior sigue transparente**: comprueba que `barra-nautilus@pandi.local` está activa (`gnome-extensions list --enabled`) y que Blur my Shell no tiene activado el blur del panel.
- **El dock no cambia en Ubuntu**: Ubuntu Dock usa el mismo esquema de ajustes que Dash to Dock. Si no se aplica al momento, `Alt+F2` → `r` (X11) o cierra sesión.
- **Ptyxis no está**: en Ubuntu puede no venir en los repos; el perfil MSX se omite y el resto del tema funciona igual.
- **No hay 1Password**: se omiten su icono de bandeja y el clic para abrirlo.
- **gThumb**: si no está instalado, la extensión «Abrir con gThumb» no hace nada.
- **La terminal no lee las cookies**: abre Brave/Chrome una vez con tu cuenta, desbloquea el llavero y revisa `NAVEGADOR` en la configuración.
- **`tracker` no suena**: falta `openmpt123` (`sudo dnf install openmpt123` / `sudo apt install openmpt123`).

## Créditos

- [MoreWaita](https://github.com/somepaulo/MoreWaita) y [Tela-circle](https://github.com/vinceliuice/Tela-circle-icon-theme) (iconos).
- [P7 Borders](https://extensions.gnome.org/extension/9064/p7-window-borders/), [Just Perfection](https://extensions.gnome.org/extension/3843/just-perfection/), [Dash to Dock](https://extensions.gnome.org/extension/307/dash-to-dock/) y el resto de extensiones de [extensions.gnome.org](https://extensions.gnome.org).
- [The Mod Archive](https://modarchive.org) y [libopenmpt](https://lib.openmpt.org/) (tracker).
- [Reversal](https://github.com/yeyushengfan258/Reversal-icon-theme) (icono de Retoques).

## Licencia

MIT. Ver [LICENSE](LICENSE).
