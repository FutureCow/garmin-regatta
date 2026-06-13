// GpsRecorder.mc — GPS recording to FIT file with SPORT_SAILING
//
// Records position, speed, heading at 1 Hz into a FIT file
// using Toybox.ActivityRecording.Session. The FIT file is
// automatically synced to Garmin Connect via the phone.
//
// Lifecycle:
//   start() → ... recording ... → pause() → saveAndStop()    (opslaan)
//                                          resume()          (verder opnemen)
//                                          discardAndStop()  (verwijderen)
//
// Session blijft draaien tijdens pause — punten gaan niet verloren.

using Toybox.Position;
using Toybox.ActivityRecording;
using Toybox.FitContributor;
using Toybox.System;
using Toybox.Timer;

class GpsRecorder {

    hidden var _session = null;
    hidden var _recording = false;
    hidden var _paused = false;      // paused awaiting save/discard/resume
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

        if (_paused) {
            // Resume — session is still alive, just re-enable position
            _paused = false;
            _recording = true;
            Position.enableLocationEvents({:acquisitionType=>Position.LOCATION_CONTINUOUS}, method(:onPosition));
            _updateTimer = new Timer.Timer();
            _updateTimer.start(method(:onUpdateTimer), 5000, true);
            System.println("GPS resumed: " + _pointCount + " pts so far");
            return;
        }

        // Fresh recording
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
        _paused = false;

        Position.enableLocationEvents({:acquisitionType=>Position.LOCATION_CONTINUOUS}, method(:onPosition));

        _updateTimer = new Timer.Timer();
        _updateTimer.start(method(:onUpdateTimer), 5000, true);

        System.println("GPS recording started (SPORT_SAILING FIT)");
    }

    // ─── Pause (session blijft draaien) ─────────────────────────────────

    function pause() {
        if (!_recording) { return; }

        Position.enableLocationEvents({:acquisitionType=>Position.LOCATION_DISABLE}, method(:onPosition));

        if (_updateTimer != null) {
            _updateTimer.stop();
            _updateTimer = null;
        }

        _recording = false;
        _paused = true;

        System.println("GPS paused: " + _pointCount + " pts — session still alive");
    }

    // ─── Save ──────────────────────────────────────────────────────────

    function saveAndStop() {
        if (!_paused) { return; }

        if (_session != null) {
            _session.stop();
            _session.save();
            _session = null;
        }

        _paused = false;

        System.println("GPS saved: " + _pointCount + " points → FIT auto-syncs");
    }

    // ─── Discard ───────────────────────────────────────────────────────

    function discardAndStop() {
        if (!_paused && !_recording) {
            // Not paused and not recording — nothing to discard
            _pointCount = 0;
            return;
        }

        // Stop session first if still recording
        if (_recording) {
            Position.enableLocationEvents({:acquisitionType=>Position.LOCATION_DISABLE}, method(:onPosition));
            if (_updateTimer != null) { _updateTimer.stop(); _updateTimer = null; }
            _recording = false;
        }

        if (_session != null) {
            _session.stop();
            _session.discard();
            _session = null;
        }

        _paused = false;
        _pointCount = 0;

        System.println("GPS discarded: recording thrown away");
    }

    // ─── GPS Position Callback ─────────────────────────────────────────

    function onPosition(info as Position.Info) as Void {
        if (!_recording) { return; }

        if (info has :lat && info has :lon) {
            var accuracy = info has :accuracy ? info.accuracy : null;
            if (accuracy != null && accuracy < Position.QUALITY_USABLE) {
                return;
            }

            _pointCount++;

            if (_speedField != null && info has :speed && info.speed != null) {
                _speedField.setData(info.speed);
            }
        }
    }

    function onUpdateTimer() as Void {
        if (_positionCallback != null) {
            _positionCallback.invoke(_pointCount);
        }
    }

    // ─── State ─────────────────────────────────────────────────────────

    function isRecording()   { return _recording; }
    function isPaused()      { return _paused; }
    function getPointCount() { return _pointCount; }
}
