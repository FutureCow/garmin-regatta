// SettingsView.mc — Minimal settings op het horloge

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Lang;
using Toybox.Application;

class SettingsView extends WatchUi.View {

    hidden var _selected = 0;
    hidden var _serverUrl;
    hidden var _authToken;
    hidden var _raceCode;
    hidden var _autoSync;

    function initialize() {
        View.initialize();
    }

    function onShow() {
        _serverUrl = Application.Properties.getValue("ServerUrl");
        _authToken = Application.Properties.getValue("AuthToken");
        _raceCode = Application.Properties.getValue("RaceCode");
        var s = Application.Properties.getValue("AutoSync");
        _autoSync = (s == null) ? true : s;
    }

    function nextItem() {
        _selected = (_selected + 1) % 4;
        WatchUi.requestUpdate();
    }

    function prevItem() {
        _selected = (_selected - 1 + 4) % 4;
        WatchUi.requestUpdate();
    }

    function selectItem() {
        if (_selected == 0) {
            // Cycle server URL
            if (_serverUrl == null || _serverUrl.length() == 0) {
                _serverUrl = "https://regatta.fhettinga.nl";
            } else if (_serverUrl.find("regatta.fhettinga.nl") != null) {
                _serverUrl = "http://192.168.1.89:3000";
            } else {
                _serverUrl = null;
            }
        } else if (_selected == 1) {
            // Clear token
            _authToken = null;
        } else if (_selected == 2) {
            // Clear race code
            _raceCode = null;
        } else if (_selected == 3) {
            // Toggle auto sync
            _autoSync = !_autoSync;
        }
        _save();
        WatchUi.requestUpdate();
    }

    function backItem() {
        return false; // pop view
    }

    hidden function _save() {
        Application.Properties.setValue("ServerUrl", _serverUrl);
        Application.Properties.setValue("AuthToken", _authToken);
        Application.Properties.setValue("RaceCode", _raceCode);
        Application.Properties.setValue("AutoSync", _autoSync);
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cp = 0x55FFFF;
        var cw = Graphics.COLOR_WHITE;
        var cg = 0x888888;
        var fs = Graphics.FONT_XTINY;

        // Title
        dc.setColor(cp, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, 20, fs, "INSTELLINGEN", Graphics.TEXT_JUSTIFY_CENTER);

        // Rows
        var rowH = 60;
        var y0 = 75;
        var lx = cx - 150;
        var rx = cx + 150;

        _row(dc, 0, "Server", _urlLabel(), y0, rowH, lx, rx, cx, cp, cw, cg, fs);
        _row(dc, 1, "Token", _tokenLabel(), y0 + rowH, rowH, lx, rx, cx, cp, cw, cg, fs);
        _row(dc, 2, "Race code", _codeLabel(), y0 + rowH * 2, rowH, lx, rx, cx, cp, cw, cg, fs);
        _row(dc, 3, "Auto sync", _syncLabel(), y0 + rowH * 3, rowH, lx, rx, cx, cp, cw, cg, fs);

        // Hints
        dc.setColor(cg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h - 30, fs, "UP/DOWN: kies  START: wijzig", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h - 15, fs, "BACK: terug", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _row(dc, idx, label, value, y, h, lx, rx, cx, cp, cw, cg, fs) {
        if (_selected == idx) {
            dc.setColor(cp, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(lx, y, rx - lx, h);
        }
        dc.setColor(cw, Graphics.COLOR_TRANSPARENT);
        dc.drawText(lx + 5, y + h / 3, fs, label, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor((_selected == idx) ? cp : cg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rx - 5, y + h / 3, fs, value, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    hidden function _urlLabel() {
        if (_serverUrl == null || _serverUrl.length() == 0) { return "Uit"; }
        var s = _serverUrl.toString();
        var i = s.find("://");
        if (i != null) { s = s.substring(i + 3, s.length()); }
        if (s.length() > 20) { s = s.substring(0, 19) + "…"; }
        return s;
    }

    hidden function _tokenLabel() {
        if (_authToken != null && _authToken.length() > 0) { return "Ingesteld"; }
        return "Niet ingesteld";
    }

    hidden function _codeLabel() {
        if (_raceCode != null && _raceCode.length() > 0) { return _raceCode; }
        return "—";
    }

    hidden function _syncLabel() {
        if (_autoSync) { return "Aan"; }
        return "Uit";
    }
}
