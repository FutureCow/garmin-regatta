// GpsRecorder.mc — GPS recording to FIT file with SPORT_SAILING
//
// Records position, speed, heading at 1 Hz into a FIT file
// using Toybox.ActivityRecording.Session. The FIT file is
// automatically synced to Garmin Connect via the phone —
// no WiFi, Bluetooth, or manual upload needed.
//
// The regatta-server pulls sailing activities from Garmin Connect
// via garmin_sync.py using the garminconnect library.

using Toybox.Position;
using Toybox.ActivityRecording;
using Toybox.FitContributor;
using Toybox.System;
using Toybox.Timer;

class GpsRecorder {

    hidden var _session = null;
    hidden var _recording = false;
    hidden var _pointCount = 0;
    hidden var _positionCallback;
    hidden var _updateTimer;
    hidden var _speedField = null;

    function initialize(callback) {
        _positionCallback = callback;
    }

    // ─── Start / Stop ──────────────────────────────────────────────────

    function start() {
        if (_recording) { return; }

        _session = ActivityRecording.createSession({
            :name=>"Regatta Race",
            :sport=>ActivityRecording.SPORT_SAILING,
            :subSport=>ActivityRecording.SUB_SPORT_GENERIC
        });

        _speedField = _session.createField(
            "speed_ms",
            0,
            FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"m/s"}
        );

        _session.start();
        _recording = true;
        _pointCount = 0;

        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));

        _updateTimer = new Timer.Timer();
        _updateTimer.start(method(:onUpdateTimer), 5000, true);

        System.println("GPS recording started (SPORT_SAILING FIT)");
    }

    function stop() {
        if (!_recording) { return; }

        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));

        if (_updateTimer != null) {
            _updateTimer.stop();
            _updateTimer = null;
        }

        if (_session != null) {
            _session.stop();
            _session.save();   // ← FIT file saved, auto-syncs via Garmin Connect
            _session = null;
        }

        _recording = false;

        System.println("GPS recording stopped: " + _pointCount + " points → FIT saved");
    }

    // ─── GPS Position Callback ─────────────────────────────────────────

    function onPosition(info) {
        if (!_recording) { return; }

        if (info has :lat && info has :lon) {
            var accuracy = info has :accuracy ? info.accuracy : null;
            if (accuracy != null && accuracy > Position.QUALITY_USABLE) {
                return;
            }

            _pointCount++;

            if (_speedField != null && info has :speed && info.speed != null) {
                _speedField.setData(info.speed);
            }
        }
    }

    function onUpdateTimer() {
        if (_positionCallback != null) {
            _positionCallback.invoke(_pointCount);
        }
    }

    // ─── State ─────────────────────────────────────────────────────────

    function isRecording()   { return _recording; }
    function getPointCount() { return _pointCount; }
}
