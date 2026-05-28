// SyncManager.mc — Phone-relayed sync to regatta server
//
// Uploads GPX track data to the regatta-server API via the Garmin
// Connect IQ phone app. The watch communicates over BLE to the phone,
// and the phone makes the actual HTTP request.
//
// Flow:
//   1. Build GPX XML from recorded trackpoints
//   2. Communications.transmit() over BLE → phone → server
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

        // Options voor transmit: URL, headers, method, response type
        var options = {
            :url => url,
            :headers => headers,
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        // Data als Dictionary — transmit() verpakt dit via BLE naar de telefoon
        var content = {
            :data => body
        };

        System.println("Transmit GPX to: " + url + " (" + gpxData.length() + " bytes)");

        Communications.transmit(
            content,
            options,
            new TransmitDelegate(method(:onUploadResponse))
        );
    }

    function onUploadResponse(responseCode, data) {
        System.println("Transmit response: " + responseCode);

        if (responseCode == 200 || responseCode == 201) {
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
        } else if (responseCode == Communications.BLE_CONNECTION_UNAVAILABLE) {
            _notify(false, "Geen verbinding met telefoon");
        } else if (responseCode == Communications.BLE_QUEUE_FULL) {
            _notify(false, "Wachtrij vol — probeer later");
        } else if (responseCode == Communications.BLE_REQUEST_TOO_LARGE) {
            _notify(false, "Track te groot voor BLE");
            _saveForRetry();
        } else {
            var msg = "Fout " + responseCode;
            if (data != null && data.hasKey(:error)) {
                msg = data[:error];
            }
            _notify(false, msg);
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
            :url => url,
            :headers => headers,
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        var content = {
            :data => body
        };

        Communications.transmit(
            content,
            options,
            new TransmitDelegate(method(:onJoinResponse))
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

// ─── Transmit Delegate (Phone BLE → HTTP relay) ─────────────────────

// Communications.transmit() requires a Communications.TransmitListener
// delegate. This wraps the callback for async phone-relayed HTTP requests.
class TransmitDelegate extends Communications.TransmitListener {

    hidden var _callback;

    function initialize(callback) {
        TransmitListener.initialize();
        _callback = callback;
    }

    // Called when the phone completes the HTTP request
    function onTransmitComplete(responseCode, data) {
        if (_callback != null) {
            _callback.invoke(responseCode, data);
        }
    }

    // Called when the transmission fails (no phone, timeout, etc.)
    function onError(code) {
        System.println("Transmit error: " + code);
        if (_callback != null) {
            _callback.invoke(code, null);
        }
    }
}
