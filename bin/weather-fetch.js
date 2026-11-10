#!/usr/bin/gjs -m
// Busca o tempo com a libgweather e imprime JSON no stdout.
// Uso: weather-fetch.js '<location serializada (GVariant em texto)>'
// O proxy vem do ambiente (https_proxy), que o widget define só para este processo.
import GLib from 'gi://GLib';
import GWeather from 'gi://GWeather?version=4.0';
import System from 'system';

const C = GWeather.TemperatureUnit.CENTIGRADE;
const loop = new GLib.MainLoop(null, false);
let exitCode = 0;

function item(info) {
    const [, ts] = info.get_value_update();
    const [, c] = info.get_value_temp(C);
    return {ts, c, icon: info.get_icon_name(), sym: info.get_symbolic_icon_name()};
}

try {
    const world = GWeather.Location.get_world();
    const location = world.deserialize(GLib.Variant.parse(null, ARGV[0], null, null));
    const info = new GWeather.Info({
        application_id: 'org.gnome.Shell',
        contact_info: 'https://gitlab.gnome.org/GNOME/gnome-shell/-/raw/HEAD/gnome-shell.doap',
        enabled_providers: GWeather.Provider.METAR | GWeather.Provider.MET_NO | GWeather.Provider.OWM,
        location,
    });
    info.connect('updated', () => {
        const valid = info.is_valid();
        const out = {valid, neterr: info.network_error()};
        if (valid) {
            const [, c] = info.get_value_temp(C);
            const [, ac] = info.get_value_apparent(C);
            Object.assign(out, {
                c, ac,
                icon: info.get_icon_name(),
                sym: info.get_symbolic_icon_name(),
                summary: info.get_weather_summary(),
                humidity: info.get_humidity(),
                locationName: info.get_location_name(),
                forecasts: info.get_forecast_list().map(item),
            });
        }
        print(JSON.stringify(out));
        loop.quit();
    });
    info.update();
    GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 50, () => {
        exitCode = 2;
        loop.quit();
        return GLib.SOURCE_REMOVE;
    });
    loop.run();
} catch (e) {
    printerr(e);
    exitCode = 1;
}
System.exit(exitCode);
