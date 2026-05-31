// RegattaView.mc — Main watch face UI
//
// Renders the timer, GPS status, and preset selector on a round watch screen.
// Layout (round 454×454 screen, with margins for round bezel):
//
//   ┌─────────────────┐
//   │    AFTELLEN     │  ← label (y=60)
//   │     05:00       │  ← timer (large, y=185)
//   │                  │
//   │  5m  10m  15m   │  ← presets (y=275, idle only)
//   │  ● GPS 32 pts   │  ← GPS status (y=365)
//   │  START / STOP   │  ← button hint (y=400)
//   └─────────────────┘

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Lang;
using Toybox.Application;

class RegattaView extends WatchUi.View {

    hidden var _timerModel;
    hidden var _gpsRecorder;
    hidden var _gpsCount = 0;
    hidden var _statusMessage = "";

    function initialize() {
        View.initialize();
    }

    function onLayout(dc) {
    }

    function onShow() {
        var app = Application.getApp();
        _timerModel = app.getTimerModel();
        _gpsRecorder = app.getGpsRecorder();
    }

    function updateGps(count) {
        _gpsCount = count;
        WatchUi.requestUpdate();
    }

    function showMessage(msg) {
        _statusMessage = msg;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        // Colors
        var cp = 0x55FFFF;  // teal
        var cr = 0xFF3333;  // red
        var cw = Graphics.COLOR_WHITE;
        var cg = 0x888888;  // grey
        var cb = Graphics.COLOR_BLACK;

        dc.setColor(cb, cb);
        dc.clear();

        var timer = _timerModel;
        if (timer == null) {
            dc.setColor(cw, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2, Graphics.FONT_MEDIUM, "Regatta Timer", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var displayStr = timer.getDisplayString();
        var labelStr = timer.getLabel();
        var isIdle = timer.isIdle();
        var isRunning = timer.isRunning();

        // ─── Label (top) ────────────────────────────────────────
        dc.setColor(cg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 65, Graphics.FONT_XTINY, labelStr, Graphics.TEXT_JUSTIFY_CENTER);

        // ─── Timer (main, large) ─────────────────────────────────
        var tc = cw;
        if (timer.isCountingDown() && timer.getRemainingSeconds() <= 10) {
            tc = cr;
        } else if (!timer.isCountingDown() && isRunning) {
            tc = cp;
        }

        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        var font = Graphics.FONT_NUMBER_THAI_HOT;
        if (displayStr.length() > 5) {
            font = Graphics.FONT_NUMBER_MEDIUM;
        }
        dc.drawText(cx, 185, font, displayStr, Graphics.TEXT_JUSTIFY_CENTER);

        // ─── Presets (idle only) ─────────────────────────────────
        if (isIdle) {
            var presetY = 280;
            var colW = w / 3;

            // Labels
            dc.setColor(cg, Graphics.COLOR_TRANSPARENT);
            dc.drawText(colW / 2, presetY, Graphics.FONT_XTINY, "5m", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(colW * 3 / 2, presetY, Graphics.FONT_XTINY, "10m", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(colW * 5 / 2, presetY, Graphics.FONT_XTINY, "15m", Graphics.TEXT_JUSTIFY_CENTER);

            // Highlight selected
            var sel = timer.getPresetSeconds();
            var selX = colW / 2;
            if (sel == 600) { selX = colW * 3 / 2; }
            else if (sel == 900) { selX = colW * 5 / 2; }

            dc.setColor(cp, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(selX - 22, presetY - 8, 44, 22);
            dc.setColor(cb, Graphics.COLOR_TRANSPARENT);
            var selLabel = "5m";
            if (sel == 600) { selLabel = "10m"; }
            else if (sel == 900) { selLabel = "15m"; }
            dc.drawText(selX, presetY, Graphics.FONT_XTINY, selLabel, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ─── GPS Status ──────────────────────────────────────────
        var gpsY = 365;
        if (_gpsRecorder != null && _gpsRecorder.isRecording()) {
            dc.setColor(cr, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - 25, gpsY, 4);
            dc.setColor(cw, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + 5, gpsY, Graphics.FONT_XTINY,
                        _gpsCount.format("%d") + " pts", Graphics.TEXT_JUSTIFY_LEFT);
        }

        // ─── Action hint ─────────────────────────────────────────
        var hintY = 400;
        dc.setColor(cg, Graphics.COLOR_TRANSPARENT);
        if (isRunning) {
            dc.drawText(cx, hintY, Graphics.FONT_XTINY, "STOP", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (isIdle) {
            dc.drawText(cx, hintY, Graphics.FONT_XTINY, "START", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(cx, hintY, Graphics.FONT_XTINY, "HERVAT", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ─── Status message overlay ──────────────────────────────
        if (_statusMessage.length() > 0) {
            dc.setColor(cb, cb);
            dc.fillRectangle(0, h / 2 - 15, w, 30);
            dc.setColor(cp, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2, Graphics.FONT_XTINY, _statusMessage, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
