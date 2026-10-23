// Ventana de ajustes de Transparencias (app Extensiones → Transparencias → Ajustes).
// Los mismos controles que el botón de Ajustes rápidos, sobre los mismos ajustes:
// los cambios se ven a la vez en los dos sitios.
import Adw from 'gi://Adw';
import Gio from 'gi://Gio';
import Gtk from 'gi://Gtk';

import {ExtensionPreferences} from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js';


// ¿Está Ptyxis instalado?
function hayPtyxis() {
    return !!Gio.SettingsSchemaSource.get_default().lookup('org.gnome.Ptyxis', true);
}

// Fila con deslizador de opacidad (50–100 %)
function filaOpacidad(titulo, subtitulo, leer, escribir, conectar) {
    const fila = new Adw.ActionRow({title: titulo, subtitle: subtitulo});
    const escala = new Gtk.Scale({
        adjustment: new Gtk.Adjustment({lower: 50, upper: 100, step_increment: 1, page_increment: 5}),
        digits: 0, draw_value: true, value_pos: Gtk.PositionType.RIGHT,
        hexpand: true, valign: Gtk.Align.CENTER, width_request: 220,
    });
    escala.set_format_value_func((_e, v) => `${Math.round(v)} %`);
    let actualizando = false;
    const refrescar = () => {
        actualizando = true;
        escala.set_value(Math.round(leer() * 100));
        actualizando = false;
    };
    escala.connect('value-changed', () => {
        if (!actualizando)
            escribir(escala.get_value() / 100);
    });
    conectar(refrescar);
    refrescar();
    fila.add_suffix(escala);
    return fila;
}

export default class TransparenciasPrefs extends ExtensionPreferences {
    fillPreferencesWindow(ventana) {
        const ajustes = this.getSettings();
        // Que el objeto Gio.Settings viva lo que la ventana (si no, se pierden las señales)
        ventana._ajustes = ajustes;

        const pagina = new Adw.PreferencesPage({title: 'Transparencias', icon_name: 'weather-fog-symbolic'});
        ventana.add(pagina);

        const filaBlur = (clave, subtitulo = 'Desenfoque detrás de la ventana') => {
            const fila = new Adw.SwitchRow({title: 'Blur', subtitle: subtitulo});
            ajustes.bind(clave, fila, 'active', Gio.SettingsBindFlags.DEFAULT);
            return fila;
        };

        // Nivel de blur (común a todas las ventanas con blur; solo aquí, no en el menú)
        const gBlur = new Adw.PreferencesGroup({
            title: 'Blur',
            description: 'Intensidad del desenfoque detrás de todas las ventanas con blur. ' +
                         'Más alto = más desenfocado y algo más de trabajo para la tarjeta gráfica.',
        });
        const filaNivel = new Adw.ActionRow({title: 'Nivel', subtitle: 'Por defecto: 21'});
        const escalaNivel = new Gtk.Scale({
            adjustment: new Gtk.Adjustment({lower: 0, upper: 100, step_increment: 1, page_increment: 5}),
            digits: 0, draw_value: true, value_pos: Gtk.PositionType.RIGHT,
            hexpand: true, valign: Gtk.Align.CENTER, width_request: 220,
        });
        for (const marca of [10, 21, 40])
            escalaNivel.add_mark(marca, Gtk.PositionType.BOTTOM, null);
        ajustes.bind('blur-nivel', escalaNivel.adjustment, 'value', Gio.SettingsBindFlags.DEFAULT);
        filaNivel.add_suffix(escalaNivel);
        gBlur.add(filaNivel);
        pagina.add(gBlur);

        // Nautilus
        const gNautilus = new Adw.PreferencesGroup({
            title: 'Nautilus',
            description: 'La opacidad la aplica la extensión de nautilus-python opacidad-nautilus.py',
        });
        gNautilus.add(filaOpacidad('Opacidad', null,
            () => ajustes.get_double('nautilus-opacity'),
            v => ajustes.set_double('nautilus-opacity', v),
            cb => ajustes.connect('changed::nautilus-opacity', cb)));
        gNautilus.add(filaBlur('nautilus-blur'));
        pagina.add(gNautilus);

        // Terminal
        const gPtyxis = new Adw.PreferencesGroup({
            title: 'Terminal (Ptyxis)',
            description: hayPtyxis() ? 'La opacidad se pone en todos los perfiles de Ptyxis, también en los nuevos'
                                     : 'Ptyxis no está instalado',
        });
        gPtyxis.add(filaOpacidad('Opacidad', null,
            () => ajustes.get_double('ptyxis-opacity'),
            v => ajustes.set_double('ptyxis-opacity', v),
            cb => ajustes.connect('changed::ptyxis-opacity', cb)));
        gPtyxis.add(filaBlur('ptyxis-blur'));
        pagina.add(gPtyxis);

    }
}
