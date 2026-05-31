// SyncManager.mc — Direct WiFi upload to regatta server
//
// Uses Communications.makeWebRequest() for direct HTTP from the watch
// via WiFi — no phone/BLE needed. Requires the watch to be WiFi-connected.
//
// Flow:
//   Stop timer → save to watch storage → later: menu → Upload → WiFi → server
//
// Server accepts: POST /api/tracks  with JSON body { "gpx": "<xml>" }
//                 POST /api/join    with JSON body { "code": "...", "trackId": N }

using Toybox.Communications;
using Toybox.System;
using Toybox.Application;
using Toybox.Lang;
using Toybox.Time;

class SyncManager {

    hidden var _callback;

    function initialize() {
    }

    // ─── Public API ────────────────────────────────────────────────────

    function syncStored(callback) {
        _callback = callback;

        // Load track points from persistent storage
        var data = Application.Storage.getValue("gps_track");
        if (data == null) {
            _notify(false, "Geen opgeslagen track");
            return;
        }

        var gpx = _storageToGpx(data.toString());
        if (gpx == null || gpx.length() == 0) {
            _notify(false, "Geen GPS data");
            return;
        }

        _uploadGpx(gpx);
    }

    // ─── Upload via WiFi (makeWebRequest → direct HTTP) ────────────────
    //
    // makeWebRequest() op FR965 gebruikt uitsluitend WiFi — er is GEEN
    // BLE-fallback. Dus geen "IQ!" dialoog zoals bij transmit().
    // Als WiFi niet beschikbaar is, komt de fout via de callback.

    hidden function _uploadGpx(gpxData) {
        var serverUrl = RegattaApp.getServerUrl();
        var authToken = RegattaApp.getAuthToken();

        if (serverUrl == null) {
            _notify(false, "Server niet ingesteld");
            return;
        }

        var url = serverUrl + "/api/tracks";
        var filename = "track_" + Time.now().value().format("%d") + ".gpx";

        // JSON body: {"gpx": "<xml>", "filename": "track_01.gpx"}
        var params = {
            "gpx" => gpxData,
            "filename" => filename
        };

        var headers = {
            "Content-Type" => "application/json"
        };
        if (authToken != null) {
            headers["Authorization"] = "Bearer " + authToken;
        }

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => headers,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        System.println("WiFi upload GPX to: " + url + " (" + gpxData.length() + " bytes)");

        Communications.makeWebRequest(
            url,
            params,
            options,
            method(:onUploadResponse)
        );
    }

    function onUploadResponse(responseCode as Lang.Number, data as Lang.Dictionary or Lang.String or Null) as Void {
        System.println("Upload response: " + responseCode);

        if (responseCode == 200 || responseCode == 201) {
            var trackId = null;
            try {
                if (data != null && data has :id) {
                    trackId = data[:id];
                }
            } catch (e) {
                System.println("Parse error: " + e.getErrorMessage());
            }

            var raceCode = RegattaApp.getRaceCode();
            if (raceCode != null && trackId != null) {
                _joinRace(raceCode, trackId);
                return;
            }

            var app = Application.getApp();
            app.getGpsRecorder().clearTrackPoints();
            Application.Storage.deleteValue("gps_track");

            _notify(true, "Geupload");
        } else if (responseCode == 401) {
            _notify(false, "Auth fout");
        } else if (responseCode == 409) {
            // Duplicate — still success from user's perspective
            var app = Application.getApp();
            app.getGpsRecorder().clearTrackPoints();
            Application.Storage.deleteValue("gps_track");
            _notify(true, "Al bekend");
        } else if (responseCode == -1 || responseCode == -104) {
            _notify(false, "Geen WiFi");
            // Data is already in storage from timer-stop, no need to re-save
        } else {
            _notify(false, "Fout " + responseCode);
            // Data stays in storage for retry
        }
    }

    // ─── Join Race ─────────────────────────────────────────────────────

    hidden function _joinRace(raceCode, trackId) {
        var serverUrl = RegattaApp.getServerUrl();
        var authToken = RegattaApp.getAuthToken();

        var url = serverUrl + "/api/join";

        var params = {
            "code" => raceCode,
            "trackId" => trackId
        };

        var headers = {
            "Content-Type" => "application/json"
        };
        if (authToken != null) {
            headers["Authorization"] = "Bearer " + authToken;
        }

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => headers,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        Communications.makeWebRequest(
            url,
            params,
            options,
            method(:onJoinResponse)
        );
    }

    function onJoinResponse(responseCode as Lang.Number, data as Lang.Dictionary or Lang.String or Null) as Void {
        System.println("Join response: " + responseCode);

        if (responseCode == 200 || responseCode == 201) {
            var raceName = "";
            if (data != null && data has :name) {
                raceName = data[:name];
            }
            _notify(true, "Gekoppeld: " + raceName);
        } else {
            _notify(true, "Geupload (niet gekoppeld)");
        }

        var app = Application.getApp();
        app.getGpsRecorder().clearTrackPoints();
        Application.Storage.deleteValue("gps_track");
    }

    // ─── Storage → GPX conversion ──────────────────────────────────────
    // Format: lat,lon,ele,time,speed|lat,lon,ele,time,speed|...

    hidden function _storageToGpx(storedData) {
        var points = _split(storedData, "|");
        if (points.size() == 0) { return null; }

        var gpx = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
        gpx += "<gpx version=\"1.1\" creator=\"Regatta Garmin\"";
        gpx += " xmlns=\"http://www.topografix.com/GPX/1/1\">\n";
        gpx += "  <trk>\n";
        gpx += "    <name>Regatta Race</name>\n";
        gpx += "    <trkseg>\n";

        for (var i = 0; i < points.size(); i++) {
            var fields = _split(points[i], ",");
            if (fields.size() < 5) { continue; }

            var lat = fields[0].toFloat();
            var lon = fields[1].toFloat();
            var ele = fields[2].toFloat();
            var timeVal = fields[3].toNumber();
            var speed = fields[4].toFloat();

            var timeStr = _formatGpxTime(timeVal);

            gpx += "      <trkpt lat=\"" + lat.format("%.6f") +
                   "\" lon=\"" + lon.format("%.6f") + "\">\n";
            gpx += "        <ele>" + ele.format("%.1f") + "</ele>\n";
            gpx += "        <time>" + timeStr + "</time>\n";
            if (speed > 0) {
                gpx += "        <speed>" + speed.format("%.2f") + "</speed>\n";
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

    // ─── Notification ──────────────────────────────────────────────────

    hidden function _notify(success, message) {
        if (_callback != null) {
            _callback.invoke(success, message);
        }
        _callback = null;
    }
}
