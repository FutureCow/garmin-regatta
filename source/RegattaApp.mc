// RegattaApp.mc — Garmin IQ Regatta Timer + GPS Recorder
//
// Entry point for the Regatta watch app. Records timer + GPS position
// to a FIT file with SPORT_SAILING. The FIT file auto-syncs to Garmin
// Connect via the phone — no WiFi, Bluetooth, or server config needed.
// The regatta-server pulls sailing activities from Garmin Connect.
//
// When stopping, the timer pauses and GPS pauses. Press BACK to show
// a confirm dialog letting the user choose:
//   Opslaan        → save FIT, sync to Garmin Connect
//   Verder opnemen → resume timer + GPS
//   Verwijderen    → discard recording
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
    hidden var _lastAlertSec = -1;   // voorkomt dubbele alerts
    hidden var _touchBlocked = false;

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
        // Fire alerts BEFORE tick (display matches remaining value)
        if (_timerModel.isCountingDown()) {
            var remaining = _timerModel.getRemainingSeconds();
            _fireCountdownAlert(remaining);
        }

        _timerModel.tick();

        // Reset alert tracking when countdown ends
        if (!_timerModel.isCountingDown()) {
            _lastAlertSec = -1;
        }

        WatchUi.requestUpdate();
    }

    // ─── Countdown alerts (piep + tril) ────────────────────────────────

    hidden function _fireCountdownAlert(remaining) {
        if (remaining == _lastAlertSec) { return; }

        var shouldAlert = false;

        if (remaining <= 5 && remaining > 0) {
            // Laatste 5 seconden: elke seconde
            shouldAlert = true;
        } else if (remaining <= 60 && remaining > 0 && remaining % 10 == 0) {
            // Laatste minuut: elke 10 seconden
            shouldAlert = true;
        } else if (remaining <= 300 && remaining % 60 == 0) {
            // Vanaf 5:00: elke minuut (5:00, 4:00, 3:00, 2:00, 1:00)
            shouldAlert = true;
        }

        if (shouldAlert) {
            _lastAlertSec = remaining;

            // Korte piep
            Attention.playTone(Attention.TONE_START);

            // Korte vibratie
            if (Attention has :vibrate) {
                var vibe = [new Attention.VibeProfile(50, 150)];
                Attention.vibrate(vibe);
            }
        }
    }

    // ─── GPS Callback ────────────────────────────────────────────────────

    function onGpsUpdate(pointCount) as Void {
        if (_view != null && _view has :updateGps) {
            _view.updateGps(pointCount);
        }
    }

    // ─── Select (START button) ──────────────────────────────────────────

    function onSelect() {
        var timer = _timerModel;
        var gps = _gpsRecorder;

        if (timer.isRunning()) {
            // Stop → pause timer + GPS, session blijft draaien, geen menu
            timer.stop();
            gps.pause();
            _unblockTouch();
            WatchUi.requestUpdate();
        } else if (timer.isPaused()) {
            // Resume from paused state
            timer.start();
            gps.start();
            _blockTouch();
            WatchUi.requestUpdate();
        } else {
            // Idle → start
            timer.start();
            gps.start();
            _blockTouch();
            WatchUi.requestUpdate();
        }
    }

    // ─── Touch blokkering via view stack ─────────────────────────────────

    hidden function _blockTouch() {
        if (!_touchBlocked && _view != null) {
            _touchBlocked = true;
            WatchUi.pushView(
                new TouchBlockerView(_view),
                new TouchBlockerDelegate(),
                WatchUi.SLIDE_BLANK
            );
        }
    }

    hidden function _unblockTouch() {
        if (_touchBlocked) {
            _touchBlocked = false;
            WatchUi.popView(WatchUi.SLIDE_BLANK);
        }
    }

    // ─── Confirm menu (na stoppen) ─────────────────────────────────────

    hidden function _showConfirmMenu() {
        var menu = new WatchUi.Menu2({:title=>"Opname stoppen"});

        menu.addItem(
            new WatchUi.MenuItem("Opslaan", "Bewaar track voor Garmin Connect", 1, {})
        );
        menu.addItem(
            new WatchUi.MenuItem("Verder opnemen", "Hervat timer + GPS", 2, {})
        );
        menu.addItem(
            new WatchUi.MenuItem("Verwijderen", "Gooi opname weg", 3, {})
        );

        WatchUi.pushView(
            menu,
            new ConfirmMenuDelegate(method(:onConfirmChoice)),
            WatchUi.SLIDE_IMMEDIATE
        );
    }

    function onConfirmChoice(choice) {
        var timer = _timerModel;
        var gps = _gpsRecorder;

        if (choice == 1) {
            // Opslaan
            gps.saveAndStop();
            _unblockTouch();
            if (_view != null && _view has :showMessage) {
                _view.showMessage("Opgeslagen");
            }
            WatchUi.requestUpdate();
        } else if (choice == 2) {
            // Verder opnemen
            timer.start();
            gps.start();
            _blockTouch();
            if (_view != null && _view has :showMessage) {
                _view.showMessage("");
            }
            WatchUi.requestUpdate();
        } else if (choice == 3) {
            // Verwijderen
            gps.discardAndStop();
            timer.reset();
            _unblockTouch();
            if (_view != null && _view has :showMessage) {
                _view.showMessage("Verwijderd");
            }
            WatchUi.requestUpdate();
        }
    }

    // ─── BACK button ─────────────────────────────────────────────────────

    function onBackPressed() {
        var timer = _timerModel;
        var gps = _gpsRecorder;

        if (timer.isRunning()) {
            return false; // Block back during race
        }

        if (timer.isPaused()) {
            // Stopped/paused — show confirm menu (Opslaan/Verder/Verwijderen)
            _showConfirmMenu();
            return true;
        }

        return false; // Idle — exit app
    }
}

// ─── Confirm Menu Delegate ────────────────────────────────────────────

class ConfirmMenuDelegate extends WatchUi.Menu2InputDelegate {
    hidden var _callback;

    function initialize(callback) {
        Menu2InputDelegate.initialize();
        _callback = callback;
    }

    function onSelect(item) {
        var id = item.getId();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        _callback.invoke(id);
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}
