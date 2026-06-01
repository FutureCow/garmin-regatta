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

    // BACK button — delegate to RegattaApp.onBackPressed()
    function onBack() {
        return _backCallback.invoke();
    }

    // Touch screen tap (for touch-enabled watches)
    // Disabled during recording — water droplets trigger false taps.
    // Use physical buttons to START/STOP during a race.
    function onTap(clickEvent) {
        var app = Application.getApp();
        var timer = app.getTimerModel();

        // Block all touch during recording — water-druppels ≠ STOP
        if (!timer.isIdle()) {
            return true;
        }

        var coords = clickEvent.getCoordinates();
        var height = System.getDeviceSettings().screenHeight;
        var width = System.getDeviceSettings().screenWidth;
        var cx = width / 2;

        // Tap bottom half → start
        if (coords[1] > height * 0.6) {
            _selectCallback.invoke();
            return true;
        }

        // Tap top area → cycle presets
        if (coords[1] < height * 0.4) {
            timer.nextPreset();
            WatchUi.requestUpdate();
            return true;
        }

        return false;
    }
}
