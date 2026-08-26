// RegattaView.mc — Twee pagina's op een rond 454×454 AMOLED-scherm
//
// De ronde rand snijdt boven en onder ~45px weg, dus alles blijft ruim
// binnen de verticale randen.
//
// Beide pagina's delen dezelfde kop (fase-label + grote cijfers) en
// dezelfde voet (hint). Daartussen tekent elke pagina zijn eigen inhoud:
//
//   pagina 0   fase-label, presets (idle) of ±1-knoplabels (aftellen),
//              GPS-stip en de hint onderin
//   pagina 1   klok bovenaan, daaronder snelheid in knopen en koers over
//              grond, zo groot als er past
//
// Pagina 1 heeft bewust geen fase-label en geen hint: die pagina bestaat
// alleen tijdens de race, dus "RACE" zei niets, en de ruimte is beter
// besteed aan leesbare cijfers.
//
// Pagina 1 bestaat alleen tijdens de race. Tijdens het aftellen zijn
// UP/DOWN nodig voor ±1 minuut, dus dan valt er niets te bladeren en
// staat de weergave vast op pagina 0. Zie RegattaDelegate.

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Lang;
using Toybox.Application;

class RegattaView extends WatchUi.View {

    static const C_ACCENT = 0x55FFFF;   // cyaan — race en selectie
    static const C_ALERT  = 0xFF3333;   // rood — laatste 10 seconden
    static const C_DIM    = 0x888888;   // grijs — labels
    static const C_FIX    = 0x00FF44;   // groen — GPS-punten binnen

    hidden var _app;
    hidden var _timerModel;
    hidden var _gpsRecorder;
    hidden var _telemetry;
    hidden var _gpsCount = 0;
    hidden var _statusMessage = "";

    function initialize() { View.initialize(); }
    function onLayout(dc) {}

    function onShow() {
        _app = Application.getApp();
        _timerModel = _app.getTimerModel();
        _gpsRecorder = _app.getGpsRecorder();
        _telemetry = _app.getTelemetry();
    }

    function updateGps(count) {
        _gpsCount = count;
        WatchUi.requestUpdate();
    }

    function showMessage(msg) {
        _statusMessage = msg;
        WatchUi.requestUpdate();
    }

    // ─── Hoofdtekening ──────────────────────────────────────────────────

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var fs = Graphics.FONT_XTINY;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var timer = _timerModel;
        if (timer == null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Graphics.FONT_MEDIUM, "Regatta Timer", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var isIdle   = timer.isIdle();
        var counting = timer.isCountingDown();
        var inRace   = timer.isRunning() && !counting;
        var page     = (inRace && _app != null) ? _app.getPage() : 0;

        // ─── Kop ─────────────────────────────────────────────────────────
        // Pagina 1 zet hier de klok neer in plaats van het fase-label.
        if (page == 1) {
            _drawClockLine(dc, cx, 62);
        } else {
            dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 40, fs, timer.getLabel(), Graphics.TEXT_JUSTIFY_CENTER);
        }

        var displayStr = timer.getDisplayString();
        var tc = Graphics.COLOR_WHITE;
        if (counting && timer.getRemainingSeconds() <= 10) {
            tc = C_ALERT;
        } else if (inRace) {
            tc = C_ACCENT;
        }
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);

        var font = Graphics.FONT_NUMBER_THAI_HOT;
        var baselineY = cy - 80;
        if (displayStr.length() > 5) {
            font = Graphics.FONT_NUMBER_MEDIUM;
            baselineY = cy - 55;
        }
        dc.drawText(cx, baselineY, font, displayStr, Graphics.TEXT_JUSTIFY_CENTER);

        // ─── Pagina-inhoud ───────────────────────────────────────────────
        if (page == 1) {
            _drawInfoPage(dc, w, h);
        } else {
            _drawTimerPage(dc, w, h, isIdle, counting, timer);
        }

        // ─── Voet ────────────────────────────────────────────────────────
        // Geen hint op pagina 1: die ruimte is voor de cijfers.
        if (page != 1) {
            dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h - 55, fs, isIdle ? "START" : "BACK = MENU", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Paginastippen alleen als er echt te bladeren valt
        if (inRace) {
            _drawPageDots(dc, cx, h - 28, page);
        }

        if (_statusMessage.length() > 0) {
            dc.setColor(C_ACCENT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 80, fs, _statusMessage, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ─── Pagina 0: timer ────────────────────────────────────────────────

    hidden function _drawTimerPage(dc, w, h, isIdle, counting, timer) {
        var cx = w / 2;
        var cy = h / 2;
        var fs = Graphics.FONT_XTINY;

        // Knoplabels naast de UP/DOWN-knoppen tijdens het aftellen
        if (counting) {
            dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx - w / 2 + 5,  cy - 20,  fs, "+1", Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(cx - w / 2 + 40, cy + 100, fs, "-1", Graphics.TEXT_JUSTIFY_LEFT);
        }

        // Presets alleen op het startscherm
        if (isIdle) {
            var pY = h - 115;
            var sp = 60;

            dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx - sp, pY, fs, "5m",  Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx,      pY, fs, "10m", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(cx + sp, pY, fs, "15m", Graphics.TEXT_JUSTIFY_CENTER);

            var sel = timer.getPresetSeconds();
            var sx = cx;
            var sl = "10m";
            if (sel == 300) {
                sx = cx - sp;
                sl = "5m";
            } else if (sel == 900) {
                sx = cx + sp;
                sl = "15m";
            }

            dc.setColor(C_ACCENT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(sx, pY, fs, sl, Graphics.TEXT_JUSTIFY_CENTER);
        }

        _drawGpsDot(dc, cx - 5, h - 85);
    }

    // ─── Pagina 1: snelheid, koers, klok ────────────────────────────────

    // Posities komen uit de gemeten fonthoogte, niet uit vaste offsets.
    // Met vaste offsets liep het label door de waarde heen zodra het font
    // hoger uitviel dan aangenomen.
    // Het blok hangt vanaf ONDEREN: het label staat een vaste afstand boven
    // de paginastippen en de waarde daar weer boven. Van bovenaf uitrekenen
    // werkte niet, want dc.getFontHeight() geeft de regelhoogte van het font
    // terug en niet hoe ver de cijfers zichtbaar doorlopen — bij een
    // FONT_NUMBER_* zit daar zoveel loze ruimte onder dat de band veel te
    // krap uitviel en het waardefont onnodig degradeerde.
    hidden function _drawInfoPage(dc, w, h) {
        var cx = w / 2;
        var fs = Graphics.FONT_XTINY;
        var col = 88;                   // horizontale afstand tot het midden
        var gap = 6;                    // tussen waarde en label
        var bottom = h - 45;            // onderkant van het label

        var knots  = (_telemetry != null) ? _telemetry.getSpeedKnots()    : null;
        var course = (_telemetry != null) ? _telemetry.getCourseDegrees() : null;

        // Geen ° achter de koers: de FONT_NUMBER_*-familie is "number only"
        // en kan het teken niet tekenen. Het label KOERS zegt genoeg.
        var speedStr  = (knots  != null) ? knots.format("%.1f") : "--";
        var courseStr = (course != null) ? course.toNumber().format("%03d") : "---";

        var lH = dc.getFontHeight(fs);
        var valueFont = _fitValueFont(dc, speedStr, courseStr, col);
        var vH = dc.getFontHeight(valueFont);
        var labelY = bottom - lH / 2;
        var valueY = bottom - lH - gap - vH / 2;
        var mid = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - col, valueY, valueFont, speedStr,  mid);
        dc.drawText(cx + col, valueY, valueFont, courseStr, mid);

        dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - col, labelY, fs, "KNOPEN", mid);
        dc.drawText(cx + col, labelY, fs, "KOERS",  mid);
    }

    // Selecteert op BREEDTE alleen. getTextWidthInPixels() meet de echte
    // glyphs en is betrouwbaar; getFontHeight() geeft de regelhoogte van het
    // font en valt bij een FONT_NUMBER_* veel hoger uit dan de cijfers zelf.
    // Een hoogtecheck op dat getal degradeerde het font onnodig — dat was de
    // bug in v1.12.2 en v1.12.3. Nodig is die check ook niet: het blok hangt
    // vanaf onderen en kan dus niet over de paginastippen zakken.
    //
    // FONT_NUMBER_HOT ontbreekt bewust: op de FR965 botst die met de racetijd.
    hidden function _fitValueFont(dc, a, b, col) {
        var fonts = [
            Graphics.FONT_NUMBER_MEDIUM,
            Graphics.FONT_NUMBER_MILD,
            Graphics.FONT_MEDIUM
        ];
        var maxWidth = 2 * (col - 8);

        for (var i = 0; i < fonts.size(); i++) {
            var wa = dc.getTextWidthInPixels(a, fonts[i]);
            var wb = dc.getTextWidthInPixels(b, fonts[i]);
            var widest = (wa > wb) ? wa : wb;
            if (widest <= maxWidth) { return fonts[i]; }
        }
        return fonts[fonts.size() - 1];
    }

    // Klok met de GPS-stip ervoor, gecentreerd rond het midden.
    hidden function _drawClockLine(dc, cx, y) {
        var fs = Graphics.FONT_XTINY;
        var clock = _clockString();
        var textWidth = dc.getTextWidthInPixels(clock, fs);
        var mid = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 10, y, fs, clock, mid);
        _drawGpsDot(dc, cx + 10 - textWidth / 2 - 14, y);
    }

    // ─── Gedeelde onderdelen ────────────────────────────────────────────

    // Grijs = timer loopt, opname begint pas op 5:00
    // Rood  = opname loopt, nog geen bruikbare fix
    // Groen = punten binnen
    hidden function _drawGpsDot(dc, x, y) {
        if (_gpsRecorder == null) { return; }

        var color;
        if (_gpsRecorder.isRecording()) {
            color = (_gpsCount > 0) ? C_FIX : C_ALERT;
        } else if (_timerModel != null && _timerModel.isRunning()) {
            color = C_DIM;
        } else {
            return;   // startscherm: geen stip
        }

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, 5);
    }

    hidden function _drawPageDots(dc, cx, y, page) {
        for (var i = 0; i < 2; i++) {
            dc.setColor((i == page) ? C_ACCENT : C_DIM, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - 8 + i * 16, y, 3);
        }
    }

    hidden function _clockString() {
        var t = System.getClockTime();
        var hour = t.hour;

        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }

        return hour.format("%02d") + ":" + t.min.format("%02d");
    }
}
