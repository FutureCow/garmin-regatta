// RegattaDelegate.mc — Input handling for Regatta watch app
//
// Handles button presses:
//   START/ENTER → Start/Stop timer + GPS (via onKey, NOT onSelect)
//   UP          → Vorige preset (idle) / +1 min (aftellen) / blader (race)
//   DOWN        → Volgende preset (idle) / -1 min (aftellen) / blader (race)
//   BACK        → Bevestigingsmenu (Opslaan / Verder opnemen / Verwijderen)
//
// Let op: Garmin mapt de UP-knop op onPreviousPage() en de DOWN-knop op
// onNextPage() — dus niet zoals de functienamen doen vermoeden.
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

    // DOWN-knop (onNextPage) — Volgende preset (idle) / -1 min (aftellen)
    function onNextPage() {
        var app = Application.getApp();
        var timer = app.getTimerModel();

        if (timer.isIdle()) {
            timer.nextPreset();
        } else if (timer.isCountingDown()) {
            timer.adjustDown();
            app.resetUiTimer();
        } else {
            app.togglePage();   // race: blader naar het andere scherm
            return true;
        }

        WatchUi.requestUpdate();
        return true;
    }

    // UP-knop (onPreviousPage) — Vorige preset (idle) / +1 min (aftellen)
    function onPreviousPage() {
        var app = Application.getApp();
        var timer = app.getTimerModel();

        if (timer.isIdle()) {
            timer.prevPreset();
        } else if (timer.isCountingDown()) {
            timer.adjustUp();
            app.resetUiTimer();
        } else {
            app.togglePage();   // race: blader naar het andere scherm
            return true;
        }

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
