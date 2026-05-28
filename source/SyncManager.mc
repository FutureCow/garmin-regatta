// SyncManager.mc — Phone-relayed HTTP sync to regatta server
//
// Uses Communications.transmit() which routes all data through the
// Garmin Connect IQ phone app — no companion app needed.
// The phone forwards HTTP requests to the regatta server.
//
// Flow:
//   watch → transmit(BLE) → Garmin IQ app → HTTP → regatta server

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

        var body = "--" + boundary + "\r\n";
        body += "Content-Disposition: form-data; name=\"gpx\"; filename=\"" + filename + "\"\r\n";
        body += "Content-Type: application/gpx+xml\r\n\r\n";
        body += gpxData + "\r\n";
        body += "--" + boundary + "--\r\n";

        // transmit() options: URL + headers → phone doet HTTP request
        var options = {
            :url => url,
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Content-Type" => "multipart/form-data; boundary=" + boundary,
                "Authorization" => "Bearer " + (authToken != null ? authToken : "")
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        // Content is the body string directly
        var content = body;

        System.println("Transmit GPX to: " + url + " (" + gpxData.length() + " bytes)");

        Communications.transmit(
            content,
            options,
            new _TransmitDelegate(method(:onUploadResponse), method(:onUploadError))
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
        } else {
            _notify(false, "Fout " + responseCode);
            _saveForRetry();
        }
    }

    function onUploadError(code) {
        System.println("Upload error: " + code);
        _notify(false, "Sync fout");
        _saveForRetry();
    }

    // ─── Join Race ─────────────────────────────────────────────────────

    hidden function _joinRace(raceCode, trackId) {
        var serverUrl = RegattaApp.getServerUrl();
        var authToken = RegattaApp.getAuthToken();

        var url = serverUrl + "/api/join";
        var body = "{\"code\":\"" + raceCode + "\",\"trackId\":" + trackId + "}";

        var options = {
            :url => url,
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Content-Type" => "application/json",
                "Authorization" => "Bearer " + (authToken != null ? authToken : "")
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        var content = body;

        Communications.transmit(
            content,
            options,
            new _TransmitDelegate(method(:onJoinResponse), method(:onJoinError))
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

    function onJoinError(code) {
        _notify(true, "Geupload (niet gekoppeld)");
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

// ─── Transmit Delegate ────────────────────────────────────────────────

// Communications.ConnectionListener voor transmit() callbacks.
// SDK 6+ pattern: onComplete() voor succes, onError() voor falen.
class _TransmitDelegate extends Communications.ConnectionListener {

    hidden var _onSuccess;
    hidden var _onError;

    function initialize(onSuccess, onError) {
        ConnectionListener.initialize();
        _onSuccess = onSuccess;
        _onError = onError;
    }

    function onComplete() {
        // Helaas geeft ConnectionListener geen responseCode/data terug.
        // We moeten hopen dat de transmit geslaagd is.
        if (_onSuccess != null) {
            _onSuccess.invoke(200, null);
        }
    }

    function onError() {
        if (_onError != null) {
            _onError.invoke(-1);
        }
    }
}
