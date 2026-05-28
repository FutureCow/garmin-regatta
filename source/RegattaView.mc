// RegattaView.mc — Main watch face UI
//
// Renders the timer, GPS status, and preset selector on a round watch screen.
// Layout (round screen, top-to-bottom):
//   ┌─────────────────┐
//   │    AFTELLEN     │  ← label
//   │     05:00       │  ← timer (large, centered)
//   │                  │
//   │  5m  10m  15m   │  ← preset buttons
//   │  GPS ● 32 pts   │  ← GPS status
//   │  START / STOP   │  ← button hint
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
    hidden var _statusTimer = null;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc) {
        // Nothing to pre-compute
    }

    function onShow() {
        var app = Application.getApp();
        _timerModel = app.getTimerModel();
        _gpsRecorder = app.getGpsRecorder();
    }

    // Called by RegattaApp when GPS count updates
    function updateGps(count) {
        _gpsCount = count;
        WatchUi.requestUpdate();
    }

    // Called by RegattaApp when sync completes
    function showMessage(msg) {
        _statusMessage = msg;
        // Clear after 3 seconds
        if (_statusTimer != null) {
            _statusTimer.stop();
        }
        _statusTimer = new Timer.Timer();
        _statusTimer.start(method(:clearMessage), 3000, false);
        WatchUi.requestUpdate();
    }

    function clearMessage() as Void {
        _statusMessage = "";
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;
        var cy = height / 2;

        // Clear screen
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var timer = _timerModel != null ? _timerModel : null;

        if (timer == null) {
            // Loading state
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Graphics.FONT_MEDIUM, "Regatta", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var displayStr = timer.getDisplayString();
        var labelStr = timer.getLabel();
        var isIdle = timer.isIdle();
        var isRunning = timer.isRunning();

        // ─── Colors ────────────────────────────────────────────────
        var colorPrimary = 0x55FFFF;  // Teal/cyan
        var colorRed = 0xFF3333;      // Red for recording
        var colorWhite = Graphics.COLOR_WHITE;
        var colorGrey = 0x888888;

        // ─── Label (top) ──────────────────────────────────────────
        dc.setColor(colorGrey, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height * 0.15, Graphics.FONT_XTINY, labelStr, Graphics.TEXT_JUSTIFY_CENTER);

        // ─── Timer (large, centered) ──────────────────────────────
        var timerColor = colorWhite;
        if (timer.isCountingDown() && timer.getRemainingSeconds() <= 10) {
            timerColor = colorRed;
        } else if (!timer.isCountingDown() && isRunning) {
            timerColor = colorPrimary;
        }

        dc.setColor(timerColor, Graphics.COLOR_TRANSPARENT);

        // Font selection based on string length
        var font = Graphics.FONT_NUMBER_THAI_HOT;  // Largest built-in
        if (displayStr.length() > 5) {
            font = Graphics.FONT_NUMBER_MEDIUM;
        }

        dc.drawText(cx, cy - 10, font, displayStr, Graphics.TEXT_JUSTIFY_CENTER);

        // ─── Preset selector (idle state) ────────────────────────
        if (isIdle) {
            dc.setColor(colorGrey, Graphics.COLOR_TRANSPARENT);
            var presetY = cy + 40;
            var presetSpacing = width / 3;

            dc.drawText(presetSpacing * 0.5, presetY, Graphics.FONT_XTINY, "5m", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(presetSpacing * 1.5, presetY, Graphics.FONT_XTINY, "10m", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(presetSpacing * 2.5, presetY, Graphics.FONT_XTINY, "15m", Graphics.TEXT_JUSTIFY_CENTER);

            // Highlight selected preset
            var selectedPreset = timer.getPresetSeconds();
            var selectedX;
            if (selectedPreset == TimerModel.PRESET_5) {
                selectedX = presetSpacing * 0.5;
            } else if (selectedPreset == TimerModel.PRESET_10) {
                selectedX = presetSpacing * 1.5;
            } else {
                selectedX = presetSpacing * 2.5;
            }

            dc.setColor(colorPrimary, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(selectedX - 18, presetY - 6, 36, 18);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            if (selectedPreset == TimerModel.PRESET_5) {
                dc.drawText(selectedX, presetY, Graphics.FONT_XTINY, "5m", Graphics.TEXT_JUSTIFY_CENTER);
            } else if (selectedPreset == TimerModel.PRESET_10) {
                dc.drawText(selectedX, presetY, Graphics.FONT_XTINY, "10m", Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.drawText(selectedX, presetY, Graphics.FONT_XTINY, "15m", Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        // ─── GPS Status (bottom area) ────────────────────────────
        var gpsY = height - 50;
        if (_gpsRecorder != null && _gpsRecorder.isRecording()) {
            // Recording indicator
            dc.setColor(colorRed, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - 30, gpsY, 4);
            dc.setColor(colorWhite, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, gpsY, Graphics.FONT_XTINY,
                        _gpsCount.format("%d") + " pts",
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ─── Action hint (bottom) ────────────────────────────────
        var hintY = height - 20;
        dc.setColor(colorGrey, Graphics.COLOR_TRANSPARENT);
        if (isRunning) {
            dc.drawText(cx, hintY, Graphics.FONT_XTINY, "STOP", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (isIdle) {
            dc.drawText(cx, hintY, Graphics.FONT_XTINY, "START", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(cx, hintY, Graphics.FONT_XTINY, "HERVAT", Graphics.TEXT_JUSTIFY_CENTER);
        }

        // ─── Status message overlay ──────────────────────────────
        if (_statusMessage.length() > 0) {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.fillRectangle(0, height / 2 - 15, width, 30);
            dc.setColor(colorPrimary, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, height / 2, Graphics.FONT_XTINY,
                        _statusMessage,
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}