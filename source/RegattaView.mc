// RegattaView.mc — Twee pagina's op een rond 454×454 AMOLED-scherm
//
// De ronde rand snijdt boven en onder ~45px weg, dus alles blijft ruim
// binnen de verticale randen.
//
// Beide pagina's delen dezelfde kop (fase-label + grote cijfers) en
// dezelfde voet (hint). Daartussen tekent elke pagina zijn eigen inhoud:
//
//   pagina 0   presets (idle) of de ±1-knoplabels (aftellen), GPS-stip
//   pagina 1   snelheid in knopen, koers over grond, klok
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

        // ─── Gedeelde kop: fase-label + grote cijfers ────────────────────
        dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 40, fs, timer.getLabel(), Graphics.TEXT_JUSTIFY_CENTER);

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

        // ─── Gedeelde voet ───────────────────────────────────────────────
        dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h - 55, fs, isIdle ? "START" : "BACK = MENU", Graphics.TEXT_JUSTIFY_CENTER);

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

    hidden function _drawInfoPage(dc, w, h) {
        var cx = w / 2;
        var fs = Graphics.FONT_XTINY;
        var col = 85;                   // horizontale afstand tot het midden

        var knots  = (_telemetry != null) ? _telemetry.getSpeedKnots()    : null;
        var course = (_telemetry != null) ? _telemetry.getCourseDegrees() : null;

        var speedStr  = (knots  != null) ? knots.format("%.1f") : "--";
        var courseStr = (course != null) ? course.toNumber().format("%03d") + "°" : "---";

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - col, h - 166, Graphics.FONT_MEDIUM, speedStr,  Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx + col, h - 166, Graphics.FONT_MEDIUM, courseStr, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(C_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - col, h - 132, fs, "KNOPEN", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx + col, h - 132, fs, "KOERS",  Graphics.TEXT_JUSTIFY_CENTER);

        // Klok met de GPS-stip ervoor
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + 10, h - 100, fs, _clockString(), Graphics.TEXT_JUSTIFY_CENTER);
        _drawGpsDot(dc, cx - 30, h - 88);
    }

    // ─── Gedeelde onderdelen ────────────────────────────────────────────

    hidden function _drawGpsDot(dc, x, y) {
        if (_gpsRecorder == null || !_gpsRecorder.isRecording()) { return; }

        dc.setColor((_gpsCount > 0) ? C_FIX : C_ALERT, Graphics.COLOR_TRANSPARENT);
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
