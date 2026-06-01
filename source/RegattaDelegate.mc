// RegattaDelegate.mc — Input handling for Regatta watch app
//
// Handles button presses:
//   START/ENTER → Start/Stop timer + GPS
//   UP          → Next preset (when idle)
//   DOWN        → Previous preset (when idle)
//   BACK        → Reset timer (when stopped)

using Toybox.WatchUi;
using Toybox.System;
using Toybox.Application;

class RegattaDelegate extends WatchUi.BehaviorDelegate {

    hidden var _backCallback;
    hidden var _selectCallback;

    function initialize(backCallback, selectCallback) {
        BehaviorDelegate.initialize();
        _backCallback = backCallback;
        _selectCallback = selectCallback;
    }

    // START/ENTER button — Start/Stop
    function onSelect() {
        _selectCallback.invoke();
        return true;
    }

    // UP button — Cycle presets forward (when idle)
    function onNextPage() {
        var app = Application.getApp();
        var timer = app.getTimerModel();

        if (!timer.isIdle()) {
            return false;
        }

        timer.nextPreset();
        WatchUi.requestUpdate();
        return true;
    }

    // DOWN button — Cycle presets backward (when idle)
    function onPreviousPage() {
        var app = Application.getApp();
        var timer = app.getTimerModel();

        if (!timer.isIdle()) {
            return false;
        }

        timer.prevPreset();
        WatchUi.requestUpdate();
        return true;
    }

    // BACK button — Reset (paused), Block (running), Exit (idle)
    function onBack() {
        var app = Application.getApp();
        var timer = app.getTimerModel();

        if (timer.isRunning()) {
            return true; // Block back during race
        }

        if (timer.isPaused()) {
            timer.reset();
            app.getGpsRecorder().stop();
            WatchUi.requestUpdate();
            return true;
        }

        return false; // Idle — exit app
    }

    // Touch screen tap (for touch-enabled watches)
    function onTap(clickEvent) {
        var coords = clickEvent.getCoordinates();
        var height = System.getDeviceSettings().screenHeight;
        var width = System.getDeviceSettings().screenWidth;
        var cx = width / 2;

        // Tap bottom half → start/stop
        if (coords[1] > height * 0.6) {
            _selectCallback.invoke();
            return true;
        }

        // Tap top area → cycle presets (when idle)
        var app = Application.getApp();
        var timer = app.getTimerModel();
        if (timer.isIdle() && coords[1] < height * 0.4) {
            timer.nextPreset();
            WatchUi.requestUpdate();
            return true;
        }

        return false;
    }
}
