// RegattaApp.mc — Garmin IQ Regatta Timer + GPS Recorder
//
// Entry point for the Regatta watch app. Handles app lifecycle,
// settings storage, and delegates UI to RegattaView.
//
// Architecture:
//   RegattaApp (Application)
//       ├── RegattaView (WatchUi.View)         — main timer/GPS UI
//       ├── RegattaDelegate (WatchUi.BehaviorDelegate) — button/input handling
//       ├── TimerModel                          — countdown + elapsed timer logic
//       ├── GpsRecorder                         — FIT file GPS recording
//       └── SyncManager                         — BLE phone-relayed sync to regatta server

using Toybox.Application;
using Toybox.System;
using Toybox.WatchUi;
using Toybox.Background;
using Toybox.Timer;
using Toybox.Attention;

class RegattaApp extends Application.AppBase {

    hidden var _view;
    hidden var _timerModel;
    hidden var _gpsRecorder;
    hidden var _syncManager;
    hidden var _uiTimer;

    function initialize() {
        AppBase.initialize();
        _timerModel = new TimerModel();
        _gpsRecorder = new GpsRecorder(method(:onGpsUpdate));
        _syncManager = new SyncManager();
    }

    function getTimerModel() { return _timerModel; }
    function getGpsRecorder() { return _gpsRecorder; }
    function getSyncManager() { return _syncManager; }

    // ─── App Lifecycle ────────────────────────────────────────────────

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        _view = new RegattaView();
        var delegate = new RegattaDelegate(method(:onMenu), method(:onSelect));

        // Start 1-second UI refresh timer
        _uiTimer = new Timer.Timer();
        _uiTimer.start(method(:onUiTick), 1000, true);

        return [_view, delegate];
    }

    function onStart(state) {
    }

    function onStop(state) {
        if (_uiTimer != null) {
            _uiTimer.stop();
            _uiTimer = null;
        }
        if (_gpsRecorder != null && _gpsRecorder.isRecording()) {
            // GPS stays active — don't stop it here, app may be backgrounded
        }
    }

    function onUiTick() as Void {
        _timerModel.tick();
        // Keep backlight on while timer is running
        if (_timerModel.isRunning()) {
            Attention.backlight(true);
        }
        WatchUi.requestUpdate();
    }

    // ─── Settings Access ──────────────────────────────────────────────

    static function getServerUrl() {
        var val = Application.Properties.getValue("ServerUrl");
        if (val == null || val.length() == 0) {
            return null;
        }
        return val;
    }

    static function getAuthToken() {
        var val = Application.Properties.getValue("AuthToken");
        if (val == null || val.length() == 0) {
            return null;
        }
        return val;
    }

    static function getRaceCode() {
        var val = Application.Properties.getValue("RaceCode");
        if (val == null || val.length() == 0) {
            return null;
        }
        return val;
    }

    static function getAutoSync() {
        var val = Application.Properties.getValue("AutoSync");
        if (val == null) {
            return true;
        }
        return val;
    }

    // ─── GPS Callback ──────────────────────────────────────────────────

    function onGpsUpdate(pointCount) {
        // Called by GpsRecorder when new points arrive
        // Update the view if it's visible
        if (_view != null && _view has :updateGps) {
            _view.updateGps(pointCount);
        }
    }

    // ─── Menu ──────────────────────────────────────────────────────────
    // Sync uses BLE → Garmin Connect IQ app on phone → server.
    // No WiFi required.

    function onMenu() {
        var menu = new WatchUi.Menu2({:title=>WatchUi.loadResource(Rez.Strings.MenuSettings)});

        // Menu items
        if (_gpsRecorder.hasSavedFile()) {
            menu.addItem(
                new WatchUi.MenuItem(
                    WatchUi.loadResource(Rez.Strings.MenuUpload),
                    null,
                    1,
                    {}
                )
            );
        }

        menu.addItem(
            new WatchUi.MenuItem(
                WatchUi.loadResource(Rez.Strings.MenuSync),
                null,
                2,
                {}
            )
        );

        menu.addItem(
            new WatchUi.MenuItem(
                WatchUi.loadResource(Rez.Strings.MenuSettings),
                null,
                3,
                {}
            )
        );

        WatchUi.pushView(
            menu,
            new RegattaMenuDelegate(method(:onMenuItem)),
            WatchUi.SLIDE_IMMEDIATE
        );
    }

    function onMenuItem(item) {
        if (item == :upload) {
            _syncManager.syncLatest(method(:onSyncComplete));
        } else if (item == :syncAll) {
            _syncManager.syncAllPending(method(:onSyncComplete));
        } else if (item == :settings) {
            // Open Garmin Connect IQ settings — user configures there
            System.println("Open settings via Garmin Connect IQ app");
        }
    }

    function onSyncComplete(success, message) {
        if (_view != null && _view has :showMessage) {
            _view.showMessage(message);
        }
    }

    // ─── Select (start button pressed) ─────────────────────────────────

    function onSelect() {
        var app = Application.getApp();
        var timer = app.getTimerModel();

        if (timer.isRunning()) {
            // Stop timer and GPS recording
            timer.stop();
            app.getGpsRecorder().stop();

            // Auto-sync if enabled
            if (RegattaApp.getAutoSync()) {
                app.getSyncManager().syncLatest(method(:onSyncComplete));
            }
        } else {
            // Start timer and GPS recording
            timer.start();
            app.getGpsRecorder().start();
        }

        WatchUi.requestUpdate();
    }
}

// ─── Menu Delegate ────────────────────────────────────────────────────

class RegattaMenuDelegate extends WatchUi.Menu2InputDelegate {
    hidden var _callback;

    function initialize(callback) {
        Menu2InputDelegate.initialize();
        _callback = callback;
    }

    function onSelect(item) {
        var id = item.getId();
        if (id == 1) {
            _callback.invoke(:upload);
        } else if (id == 2) {
            _callback.invoke(:syncAll);
        } else if (id == 3) {
            _callback.invoke(:settings);
        }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}