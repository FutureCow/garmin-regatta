// RegattaView.mc — Main watch face UI, round 454×454 AMOLED
//
// Round bezel cuts off ~45px on top/bottom. All Y coords
// shifted up by ~30px vs previous version.

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

    function initialize() { View.initialize(); }
    function onLayout(dc) {}

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

        // Label
        dc.setColor(cg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 40, fs, labelStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Timer — baseline above center (digits extend upward)
        var tc = cw;
        if (timer.isCountingDown() && timer.getRemainingSeconds() <= 10 && isRunning) {
            tc = cr;
        } else if (!timer.isCountingDown() && isRunning) {
            tc = cp;
        }
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);

        var font = Graphics.FONT_NUMBER_THAI_HOT;
        var baselineY = cy - 60;
        if (displayStr.length() > 5) {
            font = Graphics.FONT_NUMBER_MEDIUM;
            baselineY = cy - 35;
        }
        dc.drawText(cx, baselineY, font, displayStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Presets (idle only) — well below timer
        if (isIdle) {
            var pY = h - 100;
            var col = w / 3;
            dc.setColor(cg, Graphics.COLOR_TRANSPARENT);
            dc.drawText(col / 2, pY, fs, "5m", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(col * 3 / 2, pY, fs, "10m", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(col * 5 / 2, pY, fs, "15m", Graphics.TEXT_JUSTIFY_CENTER);

            // Highlight selected preset with color (no rectangle)
            var sel = timer.getPresetSeconds();
            var sx = col / 2;
            if (sel == 600) { sx = col * 3 / 2; }
            else if (sel == 900) { sx = col * 5 / 2; }

            dc.setColor(cp, Graphics.COLOR_TRANSPARENT);
            var sl = "5m";
            if (sel == 600) { sl = "10m"; }
            else if (sel == 900) { sl = "15m"; }
            dc.drawText(sx, pY, fs, sl, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // GPS indicator
        var gpsY = h - 85;
        if (_gpsRecorder != null && _gpsRecorder.isRecording()) {
            dc.setColor(cr, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - 20, gpsY, 4);
            dc.setColor(cw, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + 5, gpsY, fs,
                        _gpsCount.format("%d") + " pts", Graphics.TEXT_JUSTIFY_LEFT);
        }

        // Bottom hint
        var hintY = h - 55;
        dc.setColor(cg, Graphics.COLOR_TRANSPARENT);
        var hint = "START";
        if (isRunning) { hint = "STOP"; }
        else if (!isIdle) { hint = "HERVAT"; }
        dc.drawText(cx, hintY, fs, hint, Graphics.TEXT_JUSTIFY_CENTER);

        // Overlay
        if (_statusMessage.length() > 0) {
            dc.setColor(cb, cb);
            dc.fillRectangle(0, cy - 15, w, 30);
            dc.setColor(cp, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, fs, _statusMessage, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ─── Always-On Display ─────────────────────────────────────
    function onPartialUpdate(dc) {
        var timer = _timerModel;
        if (timer == null || !timer.isRunning()) { return; }

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var fs = Graphics.FONT_XTINY;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var labelStr = timer.getLabel();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 40, fs, labelStr, Graphics.TEXT_JUSTIFY_CENTER);

        var displayStr = timer.getDisplayString();
        var font = Graphics.FONT_NUMBER_MEDIUM;
        dc.drawText(cx, h / 2 - 45, font, displayStr, Graphics.TEXT_JUSTIFY_CENTER);

        if (_gpsRecorder != null && _gpsRecorder.isRecording()) {
            dc.fillCircle(cx, h - 65, 3);
        }
    }
}
