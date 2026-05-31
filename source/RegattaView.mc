// RegattaView.mc — Main watch face UI
//
// Round 454×454 AMOLED screen. Physical buttons:
//   LIGHT (top-left)     START/STOP (top-right)
//   UP    (mid-left)     
//   DOWN  (bot-left)     BACK       (bot-right)
//
// Screen layout:
//         ┌─────────┐
//   MENU  │AFTELLEN │ START
//    ⇣    │  05:00  │
//         │5m 10m15m│
//         │ GPS 32  │
//   RESET │         │ STOP
//         └─────────┘

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
        var w = dc.getWidth();   // 454
        var h = dc.getHeight();  // 454
        var cx = w / 2;          // 227
        var cy = h / 2;          // 227

        // Colors
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
        var fs = Graphics.FONT_XTINY;

        // ─── Button labels (at screen edges) ─────────────────────

        // TOP-RIGHT → START/STOP button (x≈390, y≈60)
        var brX = 385;
        var blX = 65;
        if (isRunning) {
            dc.setColor(cr, Graphics.COLOR_TRANSPARENT);
            dc.drawText(brX, 60, fs, "STOP", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (isIdle) {
            dc.setColor(cp, Graphics.COLOR_TRANSPARENT);
            dc.drawText(brX, 60, fs, "START", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.setColor(cp, Graphics.COLOR_TRANSPARENT);
            dc.drawText(brX, 60, fs, "HERVAT", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // MID-LEFT → UP button — cycle presets (when idle)
        if (isIdle) {
            var preset = timer.getPresetSeconds();
            var pLabel = "5m";
            if (preset == 600) { pLabel = "10m"; }
            else if (preset == 900) { pLabel = "15m"; }
            dc.setColor(cp, Graphics.COLOR_TRANSPARENT);
            dc.drawText(blX, 170, fs, pLabel, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(blX, 190, fs, "▲", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // BOT-LEFT → DOWN button — menu
        dc.setColor(cg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(blX, 330, fs, "▼", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(blX, 350, fs, "MENU", Graphics.TEXT_JUSTIFY_CENTER);

        // BOT-RIGHT → BACK button — reset (when stopped)
        if (!isRunning) {
            dc.setColor(cg, Graphics.COLOR_TRANSPARENT);
            dc.drawText(brX, 350, fs, "RESET", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ─── Center content ──────────────────────────────────────

        // Label
        dc.setColor(cg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 50, fs, labelStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Timer (centered in screen)
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
        dc.drawText(cx, cy + 5, font, displayStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Preset selector (below timer, idle only)
        if (isIdle) {
            var pY = 310;
            var colW = w / 3;

            dc.setColor(cg, Graphics.COLOR_TRANSPARENT);
            dc.drawText(colW / 2, pY, fs, "5m", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(colW * 3 / 2, pY, fs, "10m", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(colW * 5 / 2, pY, fs, "15m", Graphics.TEXT_JUSTIFY_CENTER);

            var sel = timer.getPresetSeconds();
            var selX = colW / 2;
            if (sel == 600) { selX = colW * 3 / 2; }
            else if (sel == 900) { selX = colW * 5 / 2; }

            dc.setColor(cp, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(selX - 22, pY - 8, 44, 22);
            dc.setColor(cb, Graphics.COLOR_TRANSPARENT);
            var sl = "5m";
            if (sel == 600) { sl = "10m"; }
            else if (sel == 900) { sl = "15m"; }
            dc.drawText(selX, pY, fs, sl, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // GPS status (above hint, if recording)
        if (_gpsRecorder != null && _gpsRecorder.isRecording()) {
            var gY = 375;
            dc.setColor(cr, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - 20, gY, 4);
            dc.setColor(cw, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx + 5, gY, fs, _gpsCount.format("%d") + " pts", Graphics.TEXT_JUSTIFY_LEFT);
        }

        // ─── Overlay ─────────────────────────────────────────────
        if (_statusMessage.length() > 0) {
            dc.setColor(cb, cb);
            dc.fillRectangle(0, cy - 15, w, 30);
            dc.setColor(cp, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, fs, _statusMessage, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
