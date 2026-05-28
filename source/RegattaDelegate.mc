// RegattaDelegate.mc — Input handling for Regatta watch app
//
// Handles button presses:
//   START/ENTER → Start/Stop timer + GPS
//   UP          → Next preset (only when idle)
//   DOWN        → Open menu (sync, settings, upload)
//   BACK        → Reset timer (when stopped)

using Toybox.WatchUi;
using Toybox.System;
using Toybox.Application;

class RegattaDelegate extends WatchUi.BehaviorDelegate {

    hidden var _menuCallback;
    hidden var _selectCallback;

    function initialize(menuCallback, selectCallback) {
        BehaviorDelegate.initialize();
        _menuCallback = menuCallback;
        _selectCallback = selectCallback;
    }

    // START/ENTER button — Start/Stop
    function onSelect() {
        _selectCallback.invoke();
        return true;
    }

    // UP button — Cycle presets (when idle)
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

    // DOWN button — Open menu
    function onPreviousPage() {
        _menuCallback.invoke();
        return true;
    }

    // BACK button — Reset (when stopped) or exit (when running)
    function onBack() {
        var app = Application.getApp();
        var timer = app.getTimerModel();

        if (timer.isRunning()) {
            // Running — ignore back (prevent accidental exit)
            // Show confirmation? For now, do nothing.
            return true;
        }

        // When stopped, back resets the timer
        timer.reset();
        app.getGpsRecorder().stop();
        WatchUi.requestUpdate();
        return true; // Consume the event
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