// GpsRecorder.mc — GPS recording to FIT file with Session
//
// Records position, speed, heading at 1 Hz into a FIT file
// using Toybox.ActivityRecording.Session and FitContributor.
// On stop, saves the FIT file for later sync to regatta server.

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
    hidden var _lastFitFile = null;     // path to last saved FIT file
    hidden var _positionCallback;
    hidden var _updateTimer;

    // FitContributor fields for extra data
    hidden var _speedField = null;

    function initialize(callback) {
        _positionCallback = callback;
    }

    // ─── Start / Stop ──────────────────────────────────────────────────

    function start() {
        if (_recording) { return; }

        // Create a recording session
        _session = ActivityRecording.createSession({
            :name=>"Regatta Race",
            :sport=>ActivityRecording.SPORT_SAILING,
            :subSport=>ActivityRecording.SUB_SPORT_GENERIC
        });

        // Add speed as a custom field
        _speedField = _session.createField(
            "speed_ms",
            0,
            FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"m/s"}
        );

        // Start the session
        _session.start();
        _recording = true;
        _pointCount = 0;

        // Enable GPS positioning at 1-second intervals
        Position.enableLocationEvents(Position.LOCATION_ONE_SECOND, method(:onPosition));

        // Periodic UI update (every 5 seconds)
        _updateTimer = new Timer.Timer();
        _updateTimer.start(method(:onUpdateTimer), 5000, true);

        System.println("GPS recording started");
    }

    function stop() {
        if (!_recording) { return; }

        // Stop location events
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));

        // Stop update timer
        if (_updateTimer != null) {
            _updateTimer.stop();
            _updateTimer = null;
        }

        // Save and close the session
        if (_session != null) {
            _session.stop();
            _session.save();
            _session = null;
        }

        _recording = false;

        // Find the saved FIT file
        // Garmin stores FIT files in /GARMIN/ACTIVITY/
        // We need to locate the most recent one
        _findLastFitFile();

        System.println("GPS recording stopped: " + _pointCount + " points");
    }

    // ─── GPS Position Callback ─────────────────────────────────────────

    function onPosition(info) {
        if (!_recording) { return; }

        if (info has :lat && info has :lon) {
            // Check accuracy — skip poor quality positions
            var accuracy = info has :accuracy ? info.accuracy : null;
            if (accuracy != null && accuracy > Position.QUALITY_USABLE) {
                return;
            }

            // Store trackpoint for GPX export
            _addTrackPoint(info);

            _pointCount++;

            // Set speed field if available
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

    function isRecording()           { return _recording; }
    function getPointCount()         { return _pointCount; }
    function hasSavedFile()          { return _lastFitFile != null; }
    function getLastFitFile()        { return _lastFitFile; }

    function clearSavedFile() {
        _lastFitFile = null;
    }

    // ─── Internal ──────────────────────────────────────────────────────

    hidden function _findLastFitFile() {
        // On Garmin watches, the saved activity is stored in /GARMIN/ACTIVITY/
        // with a numbered filename like 1234567890.FIT
        // We scan the directory for the most recent .FIT file
        try {
            var iter = Application.Storage.listFiles("/GARMIN/ACTIVITY/");
            var latest = null;
            var latestNum = 0;

            while (iter.hasNext()) {
                var name = iter.next();
                if (name != null && name.length() > 4 &&
                    name.substring(name.length() - 4, name.length()).toUpper().equals(".FIT")) {
                    // Extract number from filename
                    var numStr = name.substring(0, name.length() - 4);
                    var num = numStr.toNumber();
                    if (num != null && num > latestNum) {
                        latestNum = num;
                        latest = name;
                    }
                }
            }
            iter.close();

            if (latest != null) {
                _lastFitFile = "/GARMIN/ACTIVITY/" + latest;
                System.println("Found FIT file: " + _lastFitFile);
            }
        } catch (e) {
            System.println("Error scanning FIT files: " + e.getErrorMessage());
        }
    }

    // ─── GPX Export ────────────────────────────────────────────────────

    // Convert the saved FIT file to a simplified GPX string for upload.
    // Garmin IQ does not have a native FIT parser, so we store our own
    // trackpoints and write GPX directly.
    //
    // For simplicity, we also store raw positions in a lightweight format
    // during recording and export to GPX independently of the FIT file.
    hidden var _trackPoints = [];  // Array of {lat, lon, ele, time, speed}

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

    // Returns GPX XML string or null
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
        // Convert Moment to ISO 8601 string
        var info = Time.Gregorian.info(new Time.Moment(moment), Time.FORMAT_SHORT);
        return info.year.format("%04d") + "-" +
               info.month.format("%02d") + "-" +
               info.day.format("%02d") + "T" +
               info.hour.format("%02d") + ":" +
               info.min.format("%02d") + ":" +
               info.sec.format("%02d") + "Z";
    }

    // Clear trackpoints after successful sync
    function clearTrackPoints() {
        _trackPoints = [];
        _pointCount = 0;
    }

    // Store track data to Application.Storage (survives app close)
    function saveTrackPoints() {
        if (_trackPoints.size() == 0) { return; }
        // Serialize trackpoints to JSON-like string for storage
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

    function loadTrackPoints() {
        var data = Application.Storage.getValue("gps_track");
        if (data == null) { return; }
        _trackPoints = [];
        var parts = data.toString().split("|");
        for (var i = 0; i < parts.size(); i++) {
            var fields = parts[i].split(",");
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