// RegattaDelegate.mc — Input handling for Regatta watch app
//
// Handles button presses:
//   START/ENTER → Start/Stop timer + GPS (via onKey, NOT onSelect)
//   UP          → Next preset (when idle)
//   DOWN        → Previous preset (when idle)
//   BACK        → Reset timer (when stopped)
//
// Touch is blocked during recording (water droplets trigger false taps).
// onSelect() is REMOVED — on FR965 it fires on BOTH button AND touch,
// which causes tap=pause. Instead we use onKey(KEY_ENTER) for the button.

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

    // Physical ENTER button — Start/Stop
    // We use onKey instead of onSelect because onSelect fires on BOTH
    // button press AND touch on FR965, causing tap=pause during recording.
    function onKey(keyEvent) {
        if (keyEvent.getKey() == WatchUi.KEY_ENTER) {
            _selectCallback.invoke();
            return true;
        }
        return false;
    }

    // UP button — Cycle presets forward (when idle)
    function onNextPage() {
        var app = Application.getApp();
        var timer = app.getTimerModel();

        if (!timer.isIdle()) {
            return true;  // Block swipe during recording
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
            return true;  // Block swipe during recording
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
    function onTap(clickEvent) {
        var app = Application.getApp();
        var timer = app.getTimerModel();

        // Block ALL touch during recording
        if (!timer.isIdle()) {
            return true;
        }

        // Allow touch when idle
        return false;
    }

    // Block swipe during recording
    function onSwipe(swipeEvent) {
        var app = Application.getApp();
        var timer = app.getTimerModel();

        if (!timer.isIdle()) {
            return true;
        }

        return false;
    }

    // Block hold during recording
    function onHold(holdEvent) {
        var app = Application.getApp();
        var timer = app.getTimerModel();

        if (!timer.isIdle()) {
            return true;
        }

        return false;
    }
}