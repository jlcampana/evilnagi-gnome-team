// Transparencias: botón en Ajustes rápidos para la opacidad y el blur de Nautilus y Ptyxis.
//  - Blur: lo hace la propia extensión (GestorVentanas, abajo); no necesita Blur my Shell.
//  - Opacidad de Ptyxis: clave propia ptyxis-opacity, que se copia a la clave "opacity" de
//    todos los perfiles de Ptyxis (se aplica en directo).
//  - Opacidad de Nautilus: clave propia nautilus-opacity, que aplica la extensión de
//    nautilus-python opacidad-nautilus.py dentro de Nautilus.
import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';
import St from 'gi://St';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import {Slider} from 'resource:///org/gnome/shell/ui/slider.js';
import {QuickMenuToggle, SystemIndicator} from 'resource:///org/gnome/shell/ui/quickSettings.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const OPACIDAD_MIN = 0.5;
const CLAVES_BLUR = ['nautilus-blur', 'ptyxis-blur'];
const ICONO = 'weather-fog-symbolic';

const APPS = {
    nautilus: {nombre: 'Nautilus', wmClass: 'org.gnome.Nautilus', icono: 'org.gnome.Nautilus-symbolic'},
    ptyxis: {nombre: 'Terminal', wmClass: 'org.gnome.Ptyxis', icono: 'utilities-terminal-symbolic'},
};

// Blur de las ventanas de Nautilus y Ptyxis (su opacidad la ponen ellas mismas): un actor "transparencias-blur" dentro del actor
//    de la ventana, por debajo de la superficie y del tamaño del marco, con Shell.BlurEffect en
//    modo BACKGROUND (desenfoca lo que hay detrás). Es la técnica de Blur my Shell, sin depender
//    de ella. Un efecto de pintado le pide repintar cada pocos fotogramas, para que el desenfoque
//    siga lo que se mueve detrás.
const TIPOS = [Meta.WindowType.NORMAL, Meta.WindowType.DIALOG, Meta.WindowType.MODAL_DIALOG];
const NOMBRE_BLUR = 'transparencias-blur';
const RADIO_ESQUINAS = 15;   // px de las esquinas redondeadas de las ventanas de libadwaita
const PINTADOS_ENTRE_REPINTADOS = 2;
const CON_ESQUINAS = Shell.BlurEffect.list_properties().some(p => p.name === 'corner-radius');

const EfectoPintado = GObject.registerClass({GTypeName: 'TransparenciasEfectoPintado'},
class EfectoPintado extends Clutter.Effect {
    setCallback(cb) {
        this._cb = cb;
    }

    vfunc_paint(nodo, contexto, flags) {
        this._cb?.();
        super.vfunc_paint(nodo, contexto, flags);
    }
});

class GestorVentanas {
    constructor(ajustes) {
        this._ajustes = ajustes;
        this._ventanas = new Map();  // Meta.Window -> [[objeto, id]…] (señales de esa ventana)
        this._blurs = new Map();     // Meta.Window -> {actor, efecto, pintado}
        this._aplicando = new Set(); // ventanas en medio de _aplicar
        this._tema = St.ThemeContext.get_for_stage(global.stage);
        this._globales = [];
        for (const k of CLAVES_BLUR)
            this._globales.push([ajustes, ajustes.connect(`changed::${k}`, () => this._aplicarTodas())]);
        this._globales.push([ajustes, ajustes.connect('changed::blur-nivel', () => this._radioTodos())]);
        this._globales.push([this._tema, this._tema.connect('notify::scale-factor', () => this._radioTodos())]);
        this._globales.push([global.display, global.display.connect('window-created', (_d, w) => this._nueva(w))]);
        global.get_window_actors().forEach(a => this._nueva(a.meta_window));
    }

    // 'nautilus', 'ptyxis' o null (no se toca)
    _categoria(w) {
        if (!TIPOS.includes(w.get_window_type()) || w.is_skip_taskbar())
            return null;
        const clase = w.get_wm_class();
        if (clase === APPS.nautilus.wmClass)
            return 'nautilus';
        if (clase === APPS.ptyxis.wmClass)
            return 'ptyxis';
        return null;
    }

    _quiereBlur(w, cat) {
        if (!cat || w.is_fullscreen())
            return false;
        return this._ajustes.get_boolean(`${cat}-blur`);
    }

    _nueva(w) {
        if (!w || this._ventanas.has(w))
            return;
        const senales = [];
        this._ventanas.set(w, senales);
        for (const senal of ['notify::wm-class', 'notify::fullscreen',
            'notify::maximized-horizontally', 'notify::maximized-vertically'])
            senales.push([w, w.connect(senal, () => this._aplicar(w))]);
        senales.push([w, w.connect('size-changed', () => this._geometria(w))]);
        senales.push([w, w.connect('position-changed', () => this._geometria(w))]);
        senales.push([w, w.connect('unmanaged', () => this._olvidar(w, true))]);
        // El actor y su superficie aparecen después de crear la ventana
        GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
            const actor = w.get_compositor_private();
            if (actor && this._ventanas.has(w)) {
                senales.push([actor, actor.connect('child-added', (_a, hijo) => {
                    if (hijo.name === NOMBRE_BLUR)   // la capa de blur propia: nada que hacer
                        return;
                    const b = this._blurs.get(w);
                    if (b)   // el blur siempre por debajo de la superficie
                        actor.set_child_below_sibling(b.actor, null);
                    this._aplicar(w);
                })]);
                senales.push([actor, actor.connect('first-frame', () => this._aplicar(w))]);
                this._aplicar(w);
            }
            return GLib.SOURCE_REMOVE;
        });
    }

    // cerrada = la ventana se ha cerrado: sus actores ya se destruyen con sus señales, así que
    // solo se desconectan las de la propia ventana (si no, GLib avisa en el registro)
    _olvidar(w, cerrada = false) {
        this._ventanas.get(w)?.forEach(([obj, id]) => {
            if (cerrada && obj !== w)
                return;
            try {
                obj.disconnect(id);
            } catch {}
        });
        if (!cerrada)
            this._quitarBlur(w);
        this._blurs.delete(w);
        this._ventanas.delete(w);
    }

    // --- Blur

    // Escala que Mutter aplica a los hijos del actor de la ventana. Solo existe en el modo de
    // disposición "physical" con ventanas Wayland; en el "logical" (escalado fraccionario, el que
    // viene por defecto en GNOME 50, sin la clave scale-monitor-framebuffer) es 1. Se lee del propio
    // actor en vez de adivinarla por la escala del monitor: así vale en cualquier pantalla.
    _escala(w) {
        try {
            const m = w.get_compositor_private()?.get_child_transform();
            return m && !m.is_identity() ? m.get_x_scale() || 1 : 1;
        } catch {
            return 1;
        }
    }

    _radio() {
        return Math.max(0, this._ajustes.get_int('blur-nivel') * 2 * this._tema.scale_factor);
    }

    _ponerBlur(w) {
        const ventana = w.get_compositor_private();
        if (!ventana || this._blurs.has(w))
            return;
        const actor = new Clutter.Actor({name: NOMBRE_BLUR});
        const efecto = new Shell.BlurEffect({mode: Shell.BlurMode.BACKGROUND, brightness: 1.0, radius: this._radio()});
        actor.add_effect(efecto);
        let saltar = 0;
        const pintado = new EfectoPintado();
        pintado.setCallback(() => {
            if (saltar-- > 0)
                return;
            saltar = PINTADOS_ENTRE_REPINTADOS;
            efecto.queue_repaint();
        });
        actor.add_effect(pintado);
        // Apuntarla ANTES de añadirla: añadirla emite child-added, que vuelve a llamar a _aplicar
        this._blurs.set(w, {actor, efecto, pintado});
        ventana.insert_child_at_index(actor, 0);
        this._geometria(w);
    }

    _quitarBlur(w) {
        const b = this._blurs.get(w);
        if (!b)
            return;
        b.pintado.setCallback(null);
        b.actor.destroy();
        this._blurs.delete(w);
    }

    _geometria(w) {
        const b = this._blurs.get(w);
        if (!b)
            return;
        const escala = this._escala(w);
        const marco = w.get_frame_rect();
        const buffer = w.get_buffer_rect();
        b.actor.set_position((marco.x - buffer.x) / escala, (marco.y - buffer.y) / escala);
        b.actor.set_size(marco.width / escala, marco.height / escala);
        if (CON_ESQUINAS) {
            const maximizada = w.maximized_horizontally && w.maximized_vertically;
            b.efecto.corner_radius = maximizada ? 0 : RADIO_ESQUINAS * this._tema.scale_factor;
        }
    }

    _radioTodos() {
        const radio = this._radio();
        this._blurs.forEach(b => {
            b.efecto.radius = radio;
        });
    }

    _aplicar(w) {
        if (!this._ventanas.has(w) || this._aplicando.has(w))
            return;
        this._aplicando.add(w);   // evita volver a entrar por las señales que emite lo que hace
        try {
            this._aplicarVentana(w);
        } finally {
            this._aplicando.delete(w);
        }
    }

    _aplicarVentana(w) {
        if (this._quiereBlur(w, this._categoria(w)))
            this._ponerBlur(w);
        else
            this._quitarBlur(w);
        this._geometria(w);
    }

    _aplicarTodas() {
        global.get_window_actors().forEach(a => this._aplicar(a.meta_window));
    }

    destroy() {
        [...this._ventanas.keys()].forEach(w => this._olvidar(w));
        this._globales.forEach(([obj, id]) => obj.disconnect(id));
    }
}

// Opacidad de Ptyxis: la clave propia ptyxis-opacity (85 % por defecto) manda y se pone en
// todos sus perfiles, también en los nuevos. Si se cambia en un perfil desde las preferencias de
// Ptyxis, se copia a la clave (y de ahí al resto de perfiles).
class PerfilesPtyxis {
    constructor(ajustes) {
        this._ajustes = ajustes;
        const fuente = Gio.SettingsSchemaSource.get_default();
        this.disponible = !!fuente.lookup('org.gnome.Ptyxis', true) &&
                          !!fuente.lookup('org.gnome.Ptyxis.Profile', true);
        this._perfiles = [];
        if (!this.disponible)
            return;
        this._general = new Gio.Settings({schema_id: 'org.gnome.Ptyxis'});
        this._idUuids = this._general.connect('changed::profile-uuids', () => this._cargar());
        this._idClave = ajustes.connect('changed::ptyxis-opacity', () => this._aplicar());
        this._cargar();
    }

    _cargar() {
        this._perfiles.forEach(([p, id]) => p.disconnect(id));
        this._perfiles = this._general.get_strv('profile-uuids').map(uuid => {
            const p = new Gio.Settings({schema_id: 'org.gnome.Ptyxis.Profile', path: `/org/gnome/Ptyxis/Profiles/${uuid}/`});
            return [p, p.connect('changed::opacity', () => {
                if (this._aplicando)
                    return;
                const v = p.get_double('opacity');
                if (v >= 0.5 && Math.abs(v - this.opacidad) > 0.001)
                    this._ajustes.set_double('ptyxis-opacity', v);
            })];
        });
        this._aplicar();
    }

    _aplicar() {
        const v = this.opacidad;
        this._aplicando = true;
        for (const [p] of this._perfiles) {
            if (Math.abs(p.get_double('opacity') - v) > 0.001)
                p.set_double('opacity', v);
        }
        this._aplicando = false;
    }

    get opacidad() {
        return this._ajustes.get_double('ptyxis-opacity');
    }

    set opacidad(valor) {
        this._ajustes.set_double('ptyxis-opacity', valor);
    }

    destroy() {
        this._perfiles.forEach(([p, id]) => p.disconnect(id));
        if (this._idUuids)
            this._general.disconnect(this._idUuids);
        if (this._idClave)
            this._ajustes.disconnect(this._idClave);
    }
}

// Fila de deslizador con icono y porcentaje
const FilaOpacidad = GObject.registerClass(
class FilaOpacidad extends PopupMenu.PopupBaseMenuItem {
    _init(icono, alCambiar) {
        super._init({activate: false});
        this._alCambiar = alCambiar;
        this.add_child(new St.Icon({icon_name: icono, style_class: 'popup-menu-icon'}));
        this._slider = new Slider(0);
        this._slider.x_expand = true;
        this.add_child(this._slider);
        this._etiqueta = new St.Label({y_align: 2 /* CENTER */, style: 'min-width: 3.5em; text-align: right;'});
        this.add_child(this._etiqueta);
        this._slider.connect('notify::value', () => {
            const valor = this.opacidad;
            this._etiqueta.text = `${Math.round(valor * 100)} %`;
            if (!this._actualizando)
                this._alCambiar(valor);
        });
    }

    get opacidad() {
        return OPACIDAD_MIN + this._slider.value * (1 - OPACIDAD_MIN);
    }

    set opacidad(valor) {
        this._actualizando = true;
        this._slider.value = Math.min(1, Math.max(0, (valor - OPACIDAD_MIN) / (1 - OPACIDAD_MIN)));
        this._etiqueta.text = `${Math.round(valor * 100)} %`;
        this._actualizando = false;
    }
});

const BotonTransparencias = GObject.registerClass(
class BotonTransparencias extends QuickMenuToggle {
    _init(ext) {
        super._init({title: 'Transparencias', iconName: ICONO, toggleMode: true});
        this._ajustes = ext.getSettings();
        this._ptyxis = new PerfilesPtyxis(this._ajustes);
        this._conexiones = [];
        this._switches = {};

        this.menu.setHeader(ICONO, 'Transparencias', 'Opacidad y blur de las ventanas');

        // Nautilus
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem(APPS.nautilus.nombre));
        this._opNautilus = new FilaOpacidad(APPS.nautilus.icono,
            v => this._ajustes.set_double('nautilus-opacity', v));
        this.menu.addMenuItem(this._opNautilus);
        this._crearSwitchBlur('nautilus-blur');

        // Terminal (Ptyxis)
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem(APPS.ptyxis.nombre));
        this._opPtyxis = new FilaOpacidad(APPS.ptyxis.icono, v => {
            this._ptyxis.opacidad = v;
        });
        this.menu.addMenuItem(this._opPtyxis);
        this._opPtyxis.visible = this._ptyxis.disponible;
        this._crearSwitchBlur('ptyxis-blur');

        // El botón principal activa o quita el blur de todo a la vez
        this.connect('clicked', () => {
            const activar = !this.checked;
            for (const k of CLAVES_BLUR)
                this._ajustes.set_boolean(k, activar);
        });

        // Mantener el menú al día si los ajustes cambian por fuera (scripts, preferencias…)
        for (const k of ['nautilus-opacity', 'ptyxis-opacity', ...CLAVES_BLUR])
            this._conexiones.push([this._ajustes, this._ajustes.connect(`changed::${k}`, () => this._actualizar())]);

        this._actualizar();
    }

    _crearSwitchBlur(clave) {
        const item = new PopupMenu.PopupSwitchMenuItem('Blur', false);
        item.connect('toggled', (_item, estado) => {
            if (!this._actualizando)
                this._ajustes.set_boolean(clave, estado);
        });
        this.menu.addMenuItem(item);
        this._switches[clave] = item;
    }

    _actualizar() {
        this._actualizando = true;
        const nautilus = this._ajustes.get_double('nautilus-opacity');
        this._opNautilus.opacidad = nautilus;
        let resumen = `Nautilus ${Math.round(nautilus * 100)} %`;
        if (this._ptyxis.disponible) {
            const ptyxis = this._ptyxis.opacidad;
            this._opPtyxis.opacidad = ptyxis;
            resumen += ` · Terminal ${Math.round(ptyxis * 100)} %`;
        }
        this.subtitle = resumen;
        for (const k of CLAVES_BLUR)
            this._switches[k].setToggleState(this._ajustes.get_boolean(k));
        this.checked = CLAVES_BLUR.some(k => this._ajustes.get_boolean(k));
        this._actualizando = false;
    }

    destroy() {
        this._conexiones.forEach(([obj, id]) => obj.disconnect(id));
        this._ptyxis.destroy();
        super.destroy();
    }
});

const Indicador = GObject.registerClass(
class Indicador extends SystemIndicator {
    _init(ext) {
        super._init();
        this.quickSettingsItems.push(new BotonTransparencias(ext));
    }

    destroy() {
        this.quickSettingsItems.forEach(item => item.destroy());
        super.destroy();
    }
});

export default class Transparencias extends Extension {
    enable() {
        this._gestor = new GestorVentanas(this.getSettings());
        this._indicador = new Indicador(this);
        Main.panel.statusArea.quickSettings.addExternalIndicator(this._indicador);
    }

    disable() {
        this._indicador?.destroy();
        this._indicador = null;
        this._gestor?.destroy();
        this._gestor = null;
    }
}
