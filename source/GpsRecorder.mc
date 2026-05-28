// GpsRecorder.mc — GPS recording to FIT file with Session
//
// Records position, speed, heading at 1 Hz into a FIT file
// using Toybox.ActivityRecording.Session and FitContributor.
// Stores trackpoints in memory for GPX export — no file scanning needed.

using Toybox.Position;
using Toybox.ActivityRecording;
using Toybox.FitContributor;
using Toybox.System;
using Toybox.Timer;
using Toybox.Application;

class GpsRecorder {

    hidden var _session = null;
    hidden var _recording = false;
    hidden var _pointCount = 0;
    hidden var _lastFitFile = null;
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

        // LOCATION_CONTINUOUS = ~1 Hz updates (vervangt LOCATION_ONE_SECOND in SDK 7+)
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));

        _updateTimer = new Timer.Timer();
        _updateTimer.start(method(:onUpdateTimer), 5000, true);

        System.println("GPS recording started");
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
            _session.save();
            _session = null;
        }

        _recording = false;

        System.println("GPS recording stopped: " + _pointCount + " points");
    }

    // ─── GPS Position Callback ─────────────────────────────────────────

    function onPosition(info as Position.Info) {
        if (!_recording) { return; }

        if (info has :lat && info has :lon) {
            var accuracy = info has :accuracy ? info.accuracy : null;
            if (accuracy != null && accuracy > Position.QUALITY_USABLE) {
                return;
            }

            _addTrackPoint(info);
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

    function isRecording()           { return _recording; }
    function getPointCount()         { return _pointCount; }
    function hasSavedFile()          { return _lastFitFile != null; }
    function getLastFitFile()        { return _lastFitFile; }
    function clearSavedFile()        { _lastFitFile = null; }

    // ─── GPX Export ────────────────────────────────────────────────────

    hidden var _trackPoints = [];

    function _addTrackPoint(info) {
        if (!(info has :lat && info has :lon)) { return; }
        _trackPoints.add({
            :lat=>info.lat.toDouble(),
            :lon=>info.lon.toDouble(),
            :ele=>info has :altitude ? info.altitude : 0,
            :time=>Time.now().value(),
            :speed=>info has :speed ? info.speed : 0
        });
    }

    function exportGpx() {
        if (_trackPoints.size() == 0) { return null; }

        var gpx = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
        gpx += "<gpx version=\"1.1\" creator=\"Regatta Garmin\"";
        gpx += " xmlns=\"http://www.topografix.com/GPX/1/1\">\n";
        gpx += "  <trk>\n";
        gpx += "    <name>Regatta Race</name>\n";
        gpx += "    <trkseg>\n";

        for (var i = 0; i < _trackPoints.size(); i++) {
            var pt = _trackPoints[i];
            var timeStr = _formatGpxTime(pt[:time]);
            gpx += "      <trkpt lat=\"" + pt[:lat].format("%.6f") +
                   "\" lon=\"" + pt[:lon].format("%.6f") + "\">\n";
            gpx += "        <ele>" + pt[:ele].format("%.1f") + "</ele>\n";
            gpx += "        <time>" + timeStr + "</time>\n";
            if (pt[:speed] > 0) {
                gpx += "        <speed>" + pt[:speed].format("%.2f") + "</speed>\n";
            }
            gpx += "      </trkpt>\n";
        }

        gpx += "    </trkseg>\n";
        gpx += "  </trk>\n";
        gpx += "</gpx>";

        return gpx;
    }

    hidden function _formatGpxTime(moment) {
        var info = Time.Gregorian.info(new Time.Moment(moment), Time.FORMAT_SHORT);
        return info.year.format("%04d") + "-" +
               info.month.format("%02d") + "-" +
               info.day.format("%02d") + "T" +
               info.hour.format("%02d") + ":" +
               info.min.format("%02d") + ":" +
               info.sec.format("%02d") + "Z";
    }

    function clearTrackPoints() {
        _trackPoints = [];
        _pointCount = 0;
    }

    // ─── Persistence (Application.Storage) ─────────────────────────────

    function saveTrackPoints() {
        if (_trackPoints.size() == 0) { return; }
        var data = "";
        for (var i = 0; i < _trackPoints.size(); i++) {
            var pt = _trackPoints[i];
            if (i > 0) { data += "|"; }
            data += pt[:lat].format("%.6f") + "," +
                    pt[:lon].format("%.6f") + "," +
                    pt[:ele].format("%.1f") + "," +
                    pt[:time].format("%d") + "," +
                    pt[:speed].format("%.2f");
        }
        Application.Storage.setValue("gps_track", data);
    }

    // Handmatige split() — Monkey C heeft geen String.split()
    hidden function _split(str, delim) {
        var result = [];
        var remaining = str;
        while (true) {
            var pos = remaining.find(delim);
            if (pos == null) {
                result.add(remaining);
                break;
            }
            result.add(remaining.substring(0, pos));
            remaining = remaining.substring(pos + delim.length(), remaining.length());
        }
        return result;
    }

    function loadTrackPoints() {
        var data = Application.Storage.getValue("gps_track");
        if (data == null) { return; }
        _trackPoints = [];
        var parts = _split(data.toString(), "|");
        for (var i = 0; i < parts.size(); i++) {
            var fields = _split(parts[i], ",");
            if (fields.size() >= 5) {
                _trackPoints.add({
                    :lat=>fields[0].toFloat(),
                    :lon=>fields[1].toFloat(),
                    :ele=>fields[2].toFloat(),
                    :time=>fields[3].toNumber(),
                    :speed=>fields[4].toFloat()
                });
            }
        }
        _pointCount = _trackPoints.size();
    }

    function hasStoredTrack() {
        return Application.Storage.getValue("gps_track") != null;
    }
}
