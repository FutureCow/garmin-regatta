// GpsRecorder.mc — GPS recording to FIT file with SPORT_SAILING
//
// Records position, speed, heading at 1 Hz into a FIT file
// using Toybox.ActivityRecording.Session. The FIT file is
// automatically synced to Garmin Connect via the phone.
//
// Lifecycle:
//   start() → ... recording ... → saveAndStop()     (opslaan)
//                               → discardAndStop()  (verwijderen)
//
// Er is geen pauze: de sessie loopt onafgebroken door tot je opslaat of
// weggooit. Het menu openen onderbreekt de opname dus niet.

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

    // ─── Start ─────────────────────────────────────────────────────────

    function start() {
        if (_recording) { return; }

        _pointCount = 0;

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

        Position.enableLocationEvents({:acquisitionType=>Position.LOCATION_CONTINUOUS}, method(:onPosition));

        _updateTimer = new Timer.Timer();
        _updateTimer.start(method(:onUpdateTimer), 5000, true);

        System.println("GPS recording started (SPORT_SAILING FIT)");
    }

    // ─── GPS en update-timer uitzetten ──────────────────────────────────

    hidden function _stopSensors() {
        Position.enableLocationEvents({:acquisitionType=>Position.LOCATION_DISABLE}, method(:onPosition));

        if (_updateTimer != null) {
            _updateTimer.stop();
            _updateTimer = null;
        }

        _recording = false;
    }

    // ─── Save ──────────────────────────────────────────────────────────

    function saveAndStop() {
        if (!_recording) { return; }

        _stopSensors();

        if (_session != null) {
            _session.stop();
            _session.save();
            _session = null;
        }
        _speedField = null;

        System.println("GPS saved: " + _pointCount + " points → FIT auto-syncs");
    }

    // ─── Discard ───────────────────────────────────────────────────────

    function discardAndStop() {
        if (!_recording) {
            _pointCount = 0;
            return;
        }

        _stopSensors();

        if (_session != null) {
            _session.stop();
            _session.discard();
            _session = null;
        }
        _speedField = null;
        _pointCount = 0;

        System.println("GPS discarded: recording thrown away");
    }

    // ─── GPS Position Callback ─────────────────────────────────────────

    // Position.Info heeft GEEN lat/lon members — alleen accuracy, altitude,
    // heading, position, speed en when. De oude check (info has :lat) was
    // daarom altijd false, waardoor _pointCount op 0 bleef staan en het
    // speed_ms-veld nooit gevuld werd.
    function onPosition(info as Position.Info) as Void {
        if (!_recording) { return; }
        if (info == null || info.position == null) { return; }

        // QUALITY_NOT_AVAILABLE=0, LAST_KNOWN=1, POOR=2, USABLE=3, GOOD=4
        var accuracy = info.accuracy;
        if (accuracy != null && accuracy < Position.QUALITY_USABLE) {
            return;
        }

        _pointCount++;

        if (_speedField != null && info.speed != null) {
            _speedField.setData(info.speed);
        }
    }

    function onUpdateTimer() as Void {
        if (_positionCallback != null) {
            _positionCallback.invoke(_pointCount);
        }
    }

    // ─── State ─────────────────────────────────────────────────────────

    function isRecording()   { return _recording; }
    function getPointCount() { return _pointCount; }
}
