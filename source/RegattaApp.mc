// RegattaApp.mc — Garmin IQ Regatta Timer + GPS Recorder
//
// Entry point for the Regatta watch app. Records timer + GPS position
// to a FIT file with SPORT_SAILING. The FIT file auto-syncs to Garmin
// Connect via the phone — no WiFi, Bluetooth, or server config needed.
// The regatta-server pulls sailing activities from Garmin Connect.
//
// Architecture:
//   RegattaApp (Application)
//       ├── RegattaView (WatchUi.View)               — timer/GPS UI
//       ├── RegattaDelegate (WatchUi.BehaviorDelegate) — button input
//       ├── TimerModel                                — countdown + elapsed
//       └── GpsRecorder                               — FIT file GPS recording

using Toybox.Application;
using Toybox.System;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.Attention;

class RegattaApp extends Application.AppBase {

    hidden var _view;
    hidden var _timerModel;
    hidden var _gpsRecorder;
    hidden var _uiTimer;

    function initialize() {
        AppBase.initialize();
        _timerModel = new TimerModel();
        _gpsRecorder = new GpsRecorder(method(:onGpsUpdate));
    }

    function getTimerModel()  { return _timerModel; }
    function getGpsRecorder() { return _gpsRecorder; }

    // ─── App Lifecycle ────────────────────────────────────────────────

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        _view = new RegattaView();
        var delegate = new RegattaDelegate(method(:onBackPressed), method(:onSelect));

        // Start 1-second UI refresh timer
        _uiTimer = new Timer.Timer();
        _uiTimer.start(method(:onUiTick), 1000, true);

        return [_view, delegate];
    }

    function onStart(state) {}

    function onStop(state) {
        if (_uiTimer != null) {
            _uiTimer.stop();
            _uiTimer = null;
        }
    }

    function onUiTick() as Void {
        _timerModel.tick();
        if (_timerModel.isRunning()) {
            Attention.backlight(true);
        }
        WatchUi.requestUpdate();
    }

    // ─── GPS Callback ────────────────────────────────────────────────────

    function onGpsUpdate(pointCount) {
        if (_view != null && _view has :updateGps) {
            _view.updateGps(pointCount);
        }
    }

    // ─── Select (START button) — Start / Stop timer + GPS ────────────────

    function onSelect() {
        var timer = _timerModel;
        var gps = _gpsRecorder;

        if (timer.isRunning()) {
            // Stop: timer + GPS. FIT file is auto-saved by GpsRecorder.
            // Garmin Connect will sync it automatically via phone.
            timer.stop();
            gps.stop();
            if (_view != null && _view has :showMessage) {
                _view.showMessage("Opgeslagen");
            }
        } else {
            // Start: timer + GPS
            timer.start();
            gps.start();
        }

        WatchUi.requestUpdate();
    }

    // ─── BACK button — Reset when stopped, block when running ────────────

    function onBackPressed() {
        var timer = _timerModel;
        var gps = _gpsRecorder;

        if (timer.isRunning()) {
            // Running — block back to prevent accidental exit
            return false;
        }

        if (timer.isPaused()) {
            // Stopped — reset timer and GPS
            timer.reset();
            gps.stop();
            WatchUi.requestUpdate();
            return true;
        }

        // Idle — let system handle (exit app)
        return true; // true = we handled it, but system exits for idle
    }
}
