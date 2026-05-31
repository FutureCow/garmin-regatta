// RegattaView.mc — Main watch face UI, round 454×454 AMOLED
//
// Simple centered layout:
//         AFTELLEN        (top area)
//          05:00          (absolute center)
//      5m   10m   15m     (below timer, idle only)
//     ● GPS 32 pts        (GPS recording indicator)
//      START / STOP       (bottom hint)
//
// Button hints are inline (bottom) — physical buttons on FR965:
//   START/STOP = start/stop, UP = presets, DOWN = menu, BACK = reset

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
        var cy = h / 2;
        var fs = Graphics.FONT_XTINY;

        var cp = 0x55FFFF;
        var cr = 0xFF3333;
        var cw = Graphics.COLOR_WHITE;
        var cg = 0x888888;
        var cb = Graphics.COLOR_BLACK;

        dc.setColor(cb, cb);
        dc.clear();

        var timer = _timerModel;
        if (timer == null) {
            dc.setColor(cw, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Graphics.FONT_MEDIUM, "Regatta Timer", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var displayStr = timer.getDisplayString();
        var labelStr = timer.getLabel();
        var isIdle = timer.isIdle();
        var isRunning = timer.isRunning();

        // ─── Label ───────────────────────────────────────────────
        dc.setColor(cg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 50, fs, labelStr, Graphics.TEXT_JUSTIFY_CENTER);

        // ─── Timer (visually centered — drawText uses Y as baseline) ──
        var tc = cw;
        if (timer.isCountingDown() && timer.getRemainingSeconds() <= 10 && isRunning) {
            tc = cr;
        } else if (!timer.isCountingDown() && isRunning) {
            tc = cp;
        }
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);

        var font = Graphics.FONT_NUMBER_THAI_HOT;
        var baselineY = cy + 20;  // baseline offset: large digits extend ~60px above baseline
        if (displayStr.length() > 5) {
            font = Graphics.FONT_NUMBER_MEDIUM;
            baselineY = cy + 10;
        }
        dc.drawText(cx, baselineY, font, displayStr, Graphics.TEXT_JUSTIFY_CENTER);

        // ─── Presets ─────────────────────────────────────────────
        if (isIdle) {
            var pY = cy + 70;
            var col = w / 3;
            dc.setColor(cg, Graphics.COLOR_TRANSPARENT);
            dc.drawText(col / 2, pY, fs, "5m", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(col * 3 / 2, pY, fs, "10m", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(col * 5 / 2, pY, fs, "15m", Graphics.TEXT_JUSTIFY_CENTER);

            var sel = timer.getPresetSeconds();
            var sx = col / 2;
            if (sel == 600) { sx = col * 3 / 2; }
            else if (sel == 900) { sx = col * 5 / 2; }

            dc.setColor(cp, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(sx - 22, pY - 8, 44, 22);
            dc.setColor(cb, Graphics.COLOR_TRANSPARENT);
            var sl = "5m";
            if (sel == 600) { sl = "10m"; }
            else if (sel == 900) { sl = "15m"; }
            dc.drawText(sx, pY, fs, sl, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ─── GPS recording indicator ──────────────────────────────
        var gpsY = h - 65;
        if (_gpsRecorder != null && _gpsRecorder.isRecording()) {
            dc.setColor(cr, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - 20, gpsY, 4);
            dc.setColor(cw, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + 5, gpsY, fs,
                        _gpsCount.format("%d") + " pts", Graphics.TEXT_JUSTIFY_LEFT);
        }

        // ─── Bottom hints ─────────────────────────────────────────
        var hintY = h - 30;
        dc.setColor(cg, Graphics.COLOR_TRANSPARENT);
        var hint = "START";
        if (isRunning) { hint = "STOP"; }
        else if (!isIdle) { hint = "HERVAT"; }
        dc.drawText(cx, hintY, fs, hint, Graphics.TEXT_JUSTIFY_CENTER);

        // ─── Overlay ─────────────────────────────────────────────
        if (_statusMessage.length() > 0) {
            dc.setColor(cb, cb);
            dc.fillRectangle(0, cy - 15, w, 30);
            dc.setColor(cp, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, fs, _statusMessage, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ─── Always-On Display (low-power mode) ──────────────────────
    // Called ~1/sec when screen dims. 1-bit monochrome only
    // (COLOR_WHITE / COLOR_BLACK). Keeps timer visible.

    function onPartialUpdate(dc) {
        var timer = _timerModel;
        if (timer == null || !timer.isRunning()) { return; }

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var fs = Graphics.FONT_XTINY;

        // Black background
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Label
        var labelStr = timer.getLabel();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 50, fs, labelStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Timer (large, centered)
        var displayStr = timer.getDisplayString();
        var font = Graphics.FONT_NUMBER_MEDIUM;  // smaller font saves power
        dc.drawText(cx, h / 2 + 10, font, displayStr, Graphics.TEXT_JUSTIFY_CENTER);

        // GPS dot (if recording)
        if (_gpsRecorder != null && _gpsRecorder.isRecording()) {
            dc.fillCircle(cx, h - 50, 3);
        }
    }
}
