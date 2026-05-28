// SyncManager.mc — Phone-relayed HTTP sync to regatta server
//
// Uploads GPX track data to the regatta-server API via the phone.
// Uses Communications.makeWebRequest() with CONNECTION_TYPE_BLE,
// which routes HTTP through the Garmin Connect IQ app on the phone.
//
// Flow:
//   1. Build GPX XML from recorded trackpoints
//   2. makeWebRequest() over BLE → phone → server
//   3. Optionally join race via deelnamecode
//   4. Clear local track data on success

using Toybox.Communications;
using Toybox.System;
using Toybox.Application;

class SyncManager {

    hidden var _callback;
    hidden var _pendingTracks;

    function initialize() {
        _pendingTracks = [];
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

    // ─── Upload via Phone (BLE → Garmin IQ → Server) ──────────────────

    hidden function _uploadGpx(gpxData) {
        var serverUrl = RegattaApp.getServerUrl();
        var authToken = RegattaApp.getAuthToken();

        if (serverUrl == null) {
            _notify(false, "Server niet ingesteld");
            return;
        }

        var url = serverUrl + "/api/tracks";
        var boundary = "----RegattaGarminBoundary";
        var filename = "track_" + Time.now().value().format("%d") + ".gpx";

        // Build multipart form data
        var body = "--" + boundary + "\r\n";
        body += "Content-Disposition: form-data; name=\"gpx\"; filename=\"" + filename + "\"\r\n";
        body += "Content-Type: application/gpx+xml\r\n\r\n";
        body += gpxData + "\r\n";
        body += "--" + boundary + "--\r\n";

        var headers = {
            "Content-Type" => "multipart/form-data; boundary=" + boundary,
            "Authorization" => "Bearer " + (authToken != null ? authToken : "")
        };

        // Parameters for makeWebRequest: URL params (empty dict) + options
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => headers,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            :connectionType => Communications.CONNECTION_TYPE_BLE
        };

        System.println("Uploading GPX to: " + url + " (" + gpxData.length() + " bytes)");

        Communications.makeWebRequest(
            url,
            { "body" => body },
            options,
            method(:onUploadResponse)
        );
    }

    function onUploadResponse(responseCode, data) {
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
        } else if (responseCode == Communications.BLE_CONNECTION_UNAVAILABLE) {
            _notify(false, "Geen telefoon");
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
        var body = "{\"code\":\"" + raceCode + "\",\"trackId\":" + trackId + "}";

        var headers = {
            "Content-Type" => "application/json",
            "Authorization" => "Bearer " + (authToken != null ? authToken : "")
        };

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => headers,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            :connectionType => Communications.CONNECTION_TYPE_BLE
        };

        Communications.makeWebRequest(
            url,
            { "body" => body },
            options,
            method(:onJoinResponse)
        );
    }

    function onJoinResponse(responseCode, data) {
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
