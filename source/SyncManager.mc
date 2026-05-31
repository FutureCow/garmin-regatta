// SyncManager.mc — Direct WiFi upload to regatta server
//
// Uses Communications.makeWebRequest() for direct HTTP from the watch
// via WiFi — no phone/BLE needed. Requires the watch to be WiFi-connected.
//
// Flow:
//   watch → makeWebRequest(WiFi) → HTTP → regatta server
//
// Server accepts: POST /api/tracks  with JSON body { "gpx": "<xml>" }
//                 POST /api/join    with JSON body { "code": "...", "trackId": N }

using Toybox.Communications;
using Toybox.System;
using Toybox.Application;

class SyncManager {

    hidden var _callback;

    function initialize() {
    }

    // ─── Public API ────────────────────────────────────────────────────

    function syncLatest(callback) {
        _callback = callback;
        var app = Application.getApp();
        var recorder = app.getGpsRecorder();

        var gpx = recorder.exportGpx();
        if (gpx == null || gpx.length() == 0) {
            _notify(false, "Geen GPS data");
            return;
        }

        _uploadGpx(gpx);
    }

    function syncAllPending(callback) {
        _callback = callback;
        var app = Application.getApp();
        var recorder = app.getGpsRecorder();
        var gpx = recorder.exportGpx();

        if (gpx != null && gpx.length() > 0) {
            _uploadGpx(gpx);
        } else {
            _notify(false, "Geen tracks om te syncen");
        }
    }

    // ─── Upload via WiFi (makeWebRequest → direct HTTP) ────────────────

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

    function onUploadResponse(responseCode as Number, data) as Void {
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
            // -1 = generic error, -104 = BLE_CONNECTION_UNAVAILABLE (no WiFi)
            _notify(false, "Geen WiFi");
            _saveForRetry();
        } else {
            _notify(false, "Fout " + responseCode);
            _saveForRetry();
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

    function onJoinResponse(responseCode as Number, data) as Void {
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

    // ─── Retry Storage ─────────────────────────────────────────────────

    hidden function _saveForRetry() {
        var app = Application.getApp();
        app.getGpsRecorder().saveTrackPoints();
    }

    // ─── Notification ──────────────────────────────────────────────────

    hidden function _notify(success, message) {
        if (_callback != null) {
            _callback.invoke(success, message);
        }
        _callback = null;
    }
}
