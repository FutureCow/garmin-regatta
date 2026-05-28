// SyncManager.mc — WiFi sync to regatta server
//
// Uploads GPX track data to the regatta-server API via WiFi.
// Handles authentication via JWT token (set in Garmin IQ settings).
//
// Flow:
//   1. Check WiFi connectivity
//   2. Convert trackpoints → GPX XML
//   3. POST to /api/tracks/upload (multipart form data)
//   4. Optionally POST to /api/join with race code

using Toybox.Communications;
using Toybox.System;
using Toybox.Application;

class SyncManager {

    hidden var _callback;
    hidden var _pendingTracks;  // tracks waiting to be synced

    function initialize() {
        _pendingTracks = [];
    }

    // ─── Public API ────────────────────────────────────────────────────

    // Sync the most recent track (after recording stops)
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

    // Sync all locally stored pending tracks
    function syncAllPending(callback) {
        _callback = callback;

        // First try unsaved track points in memory
        var app = Application.getApp();
        var recorder = app.getGpsRecorder();
        var gpx = recorder.exportGpx();

        if (gpx != null && gpx.length() > 0) {
            _uploadGpx(gpx);
        } else {
            _notify(false, "Geen tracks om te syncen");
        }
    }

    // ─── Network Check ─────────────────────────────────────────────────

    hidden function _checkNetwork() {
        var deviceSettings = System.getDeviceSettings();
        if (deviceSettings has :connectionAvailable &&
            deviceSettings.connectionAvailable) {
            return true;
        }

        // Check WiFi specifically
        if (deviceSettings has :phoneConnected && deviceSettings.phoneConnected) {
            return true; // Can use phone connection
        }

        return false;
    }

    // ─── Upload ────────────────────────────────────────────────────────

    hidden function _uploadGpx(gpxData) {
        var serverUrl = RegattaApp.getServerUrl();
        var authToken = RegattaApp.getAuthToken();

        if (serverUrl == null) {
            _notify(false, "Server niet ingesteld");
            return;
        }

        if (!_checkNetwork()) {
            _notify(false, "Geen netwerk");
            return;
        }

        var url = serverUrl + "/api/tracks";
        var boundary = "----RegattaGarminBoundary";

        // Build multipart form data manually
        var filename = "track_" + Time.now().value().format("%d") + ".gpx";
        var body = "--" + boundary + "\r\n";
        body += "Content-Disposition: form-data; name=\"gpx\"; filename=\"" + filename + "\"\r\n";
        body += "Content-Type: application/gpx+xml\r\n\r\n";
        body += gpxData + "\r\n";
        body += "--" + boundary + "--\r\n";

        var headers = {
            "Content-Type" => "multipart/form-data; boundary=" + boundary,
            "Authorization" => "Bearer " + (authToken != null ? authToken : "")
        };

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => headers,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
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
            // Parse response for track ID
            var trackId = null;
            try {
                if (data != null && data has :id) {
                    trackId = data[:id];
                }
            } catch (e) {
                System.println("Parse error: " + e.getErrorMessage());
            }

            // If we have a race code, try to join
            var raceCode = RegattaApp.getRaceCode();
            if (raceCode != null && trackId != null) {
                _joinRace(raceCode, trackId);
                return;
            }

            // Success — clear stored track data
            var app = Application.getApp();
            app.getGpsRecorder().clearTrackPoints();
            Application.Storage.deleteValue("gps_track");

            _notify(true, "Geupload ✓");
        } else if (responseCode == 401) {
            _notify(false, "Auth fout — check token");
        } else {
            var msg = "Fout " + responseCode;
            if (data != null && data.hasKey(:error)) {
                msg = data[:error];
            }
            _notify(false, msg);
            // Save track for later retry
            _saveForRetry();
        }
    }

    // ─── Join Race ─────────────────────────────────────────────────────

    hidden function _joinRace(raceCode, trackId) {
        var serverUrl = RegattaApp.getServerUrl();
        var authToken = RegattaApp.getAuthToken();

        var url = serverUrl + "/api/join";
        var body = {
            "code" => raceCode,
            "trackId" => trackId
        };

        var headers = {
            "Content-Type" => "application/json",
            "Authorization" => "Bearer " + (authToken != null ? authToken : "")
        };

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => headers,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        Communications.makeWebRequest(
            url,
            body,
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
            // Upload succeeded, join failed — still count as success for upload
            _notify(true, "Geupload (niet gekoppeld)");
        }

        // Clean up
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