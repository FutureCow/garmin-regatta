// SettingsView.mc — In-app settings op het horloge
//
// Via MENU → Instellingen bereikbaar. Alle instellingen worden
// direct op het horloge beheerd — geen telefoon nodig.

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Lang;
using Toybox.Application;

class SettingsView extends WatchUi.View {

    hidden var _serverUrl;
    hidden var _authToken;
    hidden var _raceCode;
    hidden var _autoSync;
    hidden var _selectedIndex = 0;
    hidden var _editMode = false;
    hidden var _editField = "";
    hidden var _editPos = 0;
    hidden var _editCharIdx = 0;

    // Karakterset voor race code invoer
    hidden var _charSet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

    function initialize() {
        View.initialize();
    }

    function onShow() {
        _loadSettings();
    }

    function _loadSettings() {
        _serverUrl = Application.Properties.getValue("ServerUrl");
        _authToken = Application.Properties.getValue("AuthToken");
        _raceCode = Application.Properties.getValue("RaceCode");
        var syncVal = Application.Properties.getValue("AutoSync");
        _autoSync = (syncVal == null) ? true : syncVal;
    }

    function _saveAll() {
        Application.Properties.setValue("ServerUrl", _serverUrl);
        Application.Properties.setValue("AuthToken", _authToken);
        Application.Properties.setValue("RaceCode", _raceCode);
        Application.Properties.setValue("AutoSync", _autoSync);
    }

    // ─── Navigatie ────────────────────────────────────────────────

    function nextItem() {
        if (_editMode) {
            _editCharIdx = (_editCharIdx + 1) % _charSet.length();
            _applyEditChar();
        } else {
            _selectedIndex = (_selectedIndex + 1) % 4;
        }
        WatchUi.requestUpdate();
    }

    function prevItem() {
        if (_editMode) {
            _editCharIdx = (_editCharIdx - 1 + _charSet.length()) % _charSet.length();
            _applyEditChar();
        } else {
            _selectedIndex = (_selectedIndex - 1 + 4) % 4;
        }
        WatchUi.requestUpdate();
    }

    hidden function _applyEditChar() {
        // Vervang karakter op _editPos door _charSet[_editCharIdx]
        var before = "";
        var after = "";
        if (_editPos > 0) {
            before = _editField.substring(0, _editPos);
        }
        if (_editPos + 1 < _editField.length()) {
            after = _editField.substring(_editPos + 1, _editField.length());
        }
        _editField = before + _charSet.substring(_editCharIdx, _editCharIdx + 1) + after;
    }

    function selectItem() {
        if (_editMode) {
            _editPos = _editPos + 1;
            if (_editPos >= _editField.length()) {
                _finishEdit();
            } else {
                _syncEditCharFromField();
            }
            WatchUi.requestUpdate();
            return;
        }

        if (_selectedIndex == 0) {
            _cycleServerUrl();
        } else if (_selectedIndex == 1) {
            // Auth token — wissen indien ingesteld
            if (_authToken != null && _authToken.length() > 0) {
                _authToken = null;
                _saveAll();
            }
        } else if (_selectedIndex == 2) {
            _startRaceCodeEdit();
        } else if (_selectedIndex == 3) {
            _autoSync = !_autoSync;
            _saveAll();
        }
        WatchUi.requestUpdate();
    }

    function backItem() {
        if (_editMode) {
            if (_editPos > 0) {
                _editPos = _editPos - 1;
                _syncEditCharFromField();
            } else {
                _finishEdit();
            }
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    hidden function _syncEditCharFromField() {
        var ch = _editField.substring(_editPos, _editPos + 1);
        var found = _charSet.find(ch);
        if (found == null) {
            _editCharIdx = 0;
        } else {
            _editCharIdx = found;
        }
    }

    // ─── Server URL cycler ────────────────────────────────────────

    hidden var _urlPresets = [
        "https://regatta.fhettinga.nl",
        "http://192.168.1.89:3000",
        null
    ];

    hidden function _cycleServerUrl() {
        var currentIdx = -1;
        for (var i = 0; i < _urlPresets.size(); i = i + 1) {
            if (_serverUrl == _urlPresets[i]) {
                currentIdx = i;
                break;
            }
        }
        currentIdx = (currentIdx + 1) % _urlPresets.size();
        _serverUrl = _urlPresets[currentIdx];
        _saveAll();
    }

    // ─── Race code editor ─────────────────────────────────────────

    hidden function _startRaceCodeEdit() {
        _editMode = true;
        if (_raceCode == null || _raceCode.length() == 0) {
            _editField = "        ";
            _editPos = 0;
            _editCharIdx = 0;
        } else {
            _editField = _raceCode;
            _editPos = 0;
            _syncEditCharFromField();
        }
    }

    hidden function _finishEdit() {
        _editMode = false;
        var result = "";
        for (var i = 0; i < _editField.length(); i = i + 1) {
            var c = _editField.substring(i, i + 1);
            if (!c.equals(" ")) {
                result = result + c;
            }
        }
        if (result.length() > 0) {
            _raceCode = result;
        } else {
            _raceCode = null;
        }
        _saveAll();
    }

    // ─── Render ───────────────────────────────────────────────────

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        var cp = 0x55FFFF;  // teal primary
        var cw = Graphics.COLOR_WHITE;
        var cg = 0x888888;  // grey

        if (_editMode) {
            _drawRaceCodeEditor(dc, w, h, cx, cp, cw);
            return;
        }

        // Titel
        dc.setColor(cp, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 10, Graphics.FONT_XTINY, "INSTELLINGEN", Graphics.TEXT_JUSTIFY_CENTER);

        var rowH = h / 6;
        var startY = h / 5;

        // Server
        var urlLabel = _formatUrl(_serverUrl);
        _drawRow(dc, 0, "Server", urlLabel, startY, rowH, cx, w, cp, cw, cg);

        // Token
        var tok = "Niet ingesteld";
        if (_authToken != null && _authToken.length() > 0) {
            tok = "Ingesteld";
        }
        _drawRow(dc, 1, "Token", tok, startY + rowH, rowH, cx, w, cp, cw, cg);

        // Race code
        var rc = "—";
        if (_raceCode != null && _raceCode.length() > 0) {
            rc = _raceCode;
        }
        _drawRow(dc, 2, "Race code", rc, startY + rowH * 2, rowH, cx, w, cp, cw, cg);

        // Auto sync
        var syn = "Uit";
        if (_autoSync) {
            syn = "Aan";
        }
        _drawRow(dc, 3, "Auto sync", syn, startY + rowH * 3, rowH, cx, w, cp, cw, cg);

        // Hints
        dc.setColor(cg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h - 30, Graphics.FONT_XTINY, "UP/DOWN: kies", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h - 15, Graphics.FONT_XTINY, "START: wijzig  BACK: terug", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawRow(dc, idx, label, value, y, h, cx, w, cp, cw, cg) {
        var sel = (_selectedIndex == idx);
        var left = cx - (w * 4 / 10);
        var boxW = w * 8 / 10;

        if (sel) {
            dc.setColor(cp, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(left, y - 2, boxW, h - 4);
        }

        var labelX = left + 8;
        var valX = left + boxW - 8;
        var textY = y + h / 3;

        dc.setColor(cw, Graphics.COLOR_TRANSPARENT);
        dc.drawText(labelX, textY, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_LEFT);

        var vc = cg;
        if (sel) { vc = cp; }
        dc.setColor(vc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(valX, textY, Graphics.FONT_XTINY, value, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    hidden function _formatUrl(url) {
        if (url == null || url.length() == 0) { return "—"; }
        var s = url.toString();
        var idx = s.find("://");
        if (idx != null) {
            s = s.substring(idx + 3, s.length());
        }
        if (s.length() > 18) {
            s = s.substring(0, 17) + "…";
        }
        return s;
    }

    // ─── Race Code Editor UI ───────────────────────────────────────

    hidden function _drawRaceCodeEditor(dc, w, h, cx, cp, cw) {
        dc.setColor(cp, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 10, Graphics.FONT_XTINY, "RACE CODE", Graphics.TEXT_JUSTIFY_CENTER);

        // Bouw display string met [cursor]
        var disp = "";
        for (var i = 0; i < _editField.length(); i = i + 1) {
            if (i == _editPos) { disp = disp + "["; }
            disp = disp + _editField.substring(i, i + 1);
            if (i == _editPos) { disp = disp + "]"; }
        }
        dc.setColor(cw, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 5, Graphics.FONT_MEDIUM, disp, Graphics.TEXT_JUSTIFY_CENTER);

        // Karakter strip
        var charY = h / 2;
        var charW = w / 9;
        var charLen = _charSet.length();

        for (var i = 0; i < 7; i = i + 1) {
            var ci = (_editCharIdx - 3 + i + charLen) % charLen;
            var ch = _charSet.substring(ci, ci + 1);
            var charX = cx + (i - 3) * charW;

            if (ci == _editCharIdx) {
                dc.setColor(Graphics.COLOR_BLACK, cp);
                dc.fillRectangle(charX - charW/2 + 2, charY - 14, charW - 4, 28);
                dc.setColor(cp, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(cw, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(charX, charY, Graphics.FONT_MEDIUM, ch, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Hints
        var cg = 0x888888;
        dc.setColor(cg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h - 30, Graphics.FONT_XTINY, "UP/DOWN: letter", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, h - 15, Graphics.FONT_XTINY, "START: volgende  BACK: vorige", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
