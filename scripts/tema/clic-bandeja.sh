#!/usr/bin/env bash
# Hace que un clic izquierdo en el icono de una app en la bandeja (barra superior, extensión
# AppIndicator) abra la app en vez de mostrar su menú. El clic derecho sigue mostrando el menú.
# Por defecto: 1Password.
#
# AppIndicator no tiene ajuste para esto (clic = menú, doble clic = activar), así que lo hace una
# mini-extensión propia (clic-bandeja@pandi.local). En GNOME 50 el menú de un icono de la barra lo
# abren el gesto de clic de GNOME (ClickGesture del botón del panel) y el manejador de AppIndicator.
# La extensión se engancha a captured-event del icono, la primera fase por la que pasa un evento
# (antes que los gestos y que AppIndicator): con el botón izquierdo abre la app y corta el evento;
# el derecho y el central siguen igual. Deja mensajes "clic-bandeja:" en el registro de GNOME.
#
# Uso:  clic-bandeja.sh                     clic en 1Password = abrir 1Password
#       clic-bandeja.sh <id> <app.desktop>  otra app (el id es la propiedad Id de su icono de
#                                           bandeja, p. ej. "1Password_status_icon_1")
#       clic-bandeja.sh --quitar            la desinstala
#
# Independiente: todo va dentro de este script (Fedora y Ubuntu, GNOME 46–50). La primera vez hay
# que cerrar sesión para que GNOME cargue la extensión.

set -euo pipefail

UUID="clic-bandeja@pandi.local"
DIR="$HOME/.local/share/gnome-shell/extensions/$UUID"
ID="1Password_status_icon_1"
APP="1password.desktop"

activar() { # activar <uuid> true|false  (en enabled-extensions; vale aunque la shell aún no la conozca)
    python3 - "$1" "$2" <<'PY'
import ast, subprocess, sys
uuid, on = sys.argv[1], sys.argv[2] == "true"
k = ["org.gnome.shell", "enabled-extensions"]
l = ast.literal_eval(subprocess.check_output(["gsettings", "get", *k], text=True).replace("@as ", ""))
n = (l + [uuid] if uuid not in l else l) if on else [u for u in l if u != uuid]  # sin reordenar
if n != l:
    subprocess.check_call(["gsettings", "set", *k, str(n)])
PY
}

case "${1:-}" in
    --quitar)
        activar "$UUID" false
        rm -rf "$DIR"
        echo "Clic de bandeja normal otra vez (del todo al cerrar sesión)."
        exit 0 ;;
    "") ;;
    *)
        [[ $# -eq 2 ]] || { echo "Uso: $(basename "$0") [<id> <app.desktop> | --quitar]" >&2; exit 1; }
        ID="$1"; APP="$2" ;;
esac

mkdir -p "$DIR"
cat > "$DIR/metadata.json" <<'EOF'
{
  "uuid": "clic-bandeja@pandi.local",
  "name": "Clic de bandeja abre la app",
  "description": "Clic izquierdo en el icono de 1Password de la bandeja: abre 1Password en vez del menú (el clic derecho sigue mostrando el menú). La crea clic-bandeja.sh.",
  "shell-version": ["46", "47", "48", "49", "50"]
}
EOF
cat > "$DIR/extension.js" <<EOF
// Clic izquierdo en un icono de la bandeja (AppIndicator) = abrir su app. Generado por clic-bandeja.sh.
// Se engancha a captured-event del icono: es la fase de captura, la primera por la que pasa un
// evento, antes que los gestos (ClickGesture del botón del panel, que abre el menú) y que el
// manejador de AppIndicator. Cortando ahí la pulsación y la suelta del botón izquierdo, el menú
// no llega a abrirse. El clic derecho y el central no se tocan.
import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

// Id de la app en la bandeja (propiedad Id de StatusNotifierItem) -> lanzador que abre
const ICONOS = {
    '$ID': '$APP',
};

// Abre la app de un lanzador .desktop. Si el lanzador está marcado como oculto (Hidden=true, como
// el de 1Password), Gio no lo carga: entonces se lee su Exec y se ejecuta tal cual.
function abrir(app) {
    const info = Gio.DesktopAppInfo.new(app);
    if (info) {
        info.launch([], global.create_app_launch_context(0, -1));
        return;
    }
    for (const dir of [GLib.get_user_data_dir(), ...GLib.get_system_data_dirs()]) {
        const ruta = GLib.build_filenamev([dir, 'applications', app]);
        if (!GLib.file_test(ruta, GLib.FileTest.EXISTS))
            continue;
        const kf = new GLib.KeyFile();
        kf.load_from_file(ruta, GLib.KeyFileFlags.NONE);
        const exec = kf.get_string('Desktop Entry', 'Exec').replace(/ ?%[a-zA-Z]/g, '');
        GLib.spawn_command_line_async(exec);
        return;
    }
    console.warn(\`clic-bandeja: no encuentro \${app}\`);
}

export default class ClicBandeja extends Extension {
    enable() {
        this._enganchados = new Map();   // icono -> id de señal
        // El icono puede entrar en cualquiera de las tres cajas de la barra (AppIndicator lo pone
        // donde diga su ajuste tray-pos y otras extensiones lo mueven)
        this._cajas = [Main.panel._leftBox, Main.panel._centerBox, Main.panel._rightBox]
            .map(caja => [caja, caja.connect('child-added', () => this._buscar())]);
        this._buscar();
    }

    _buscar() {
        // AppIndicator registra cada icono como "appindicator-<bus>@<ruta>", que cambia cada vez
        // que se abre la app: se busca por el Id de la app, que es fijo
        for (const [clave, icono] of Object.entries(Main.panel.statusArea)) {
            if (!clave.startsWith('appindicator-') || !icono || this._enganchados.has(icono))
                continue;
            let nombre;
            try {
                nombre = icono._indicator?.id;
            } catch {}
            const app = ICONOS[nombre];
            if (!app)
                continue;
            console.log(\`clic-bandeja: enganchado a \${nombre} (abre \${app})\`);
            const id = icono.connect('captured-event', (_actor, evento) => {
                const tipo = evento.type();
                if (tipo !== Clutter.EventType.BUTTON_PRESS && tipo !== Clutter.EventType.BUTTON_RELEASE)
                    return Clutter.EVENT_PROPAGATE;
                if (evento.get_button() !== Clutter.BUTTON_PRIMARY)
                    return Clutter.EVENT_PROPAGATE;   // clic derecho / central: lo de siempre
                if (tipo === Clutter.EventType.BUTTON_PRESS) {
                    console.log(\`clic-bandeja: clic en \${nombre}, abriendo \${app}\`);
                    try {
                        abrir(app);
                    } catch (e) {
                        console.warn(\`clic-bandeja: no se pudo abrir \${app}: \${e.message}\`);
                    }
                }
                return Clutter.EVENT_STOP;
            });
            this._enganchados.set(icono, id);
            icono.connect('destroy', () => this._enganchados.delete(icono));
        }
    }

    disable() {
        this._cajas?.forEach(([caja, id]) => caja.disconnect(id));
        this._cajas = null;
        this._enganchados?.forEach((id, icono) => {
            try {
                icono.disconnect(id);
            } catch {}
        });
        this._enganchados = null;
    }
}
EOF

activar "$UUID" true
echo "Clic izquierdo en el icono de bandeja '$ID' = abrir $APP. Cierra sesión y vuelve a entrar para cargarlo."
