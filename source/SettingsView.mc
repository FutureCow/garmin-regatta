// SettingsView.mc — In-app settings op het horloge
//
// Via MENU → Instellingen bereikbaar. Alle instellingen worden
// direct op het horloge beheerd — geen telefoon nodig.
//
// Settings:
//   Server URL  → picklist met veelgebruikte URLs
//   Auth token  → toon status + wissen
//   Race code   → tekstinvoer (max 10 chars)
//   Auto sync   → toggle

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
    hidden var _editChars = "";
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
            _editField = _editField.substring(0, _editPos) +
                         _charSet.substring(_editCharIdx, _editCharIdx + 1) +
                         (_editPos + 1 < _editField.length() ? _editField.substring(_editPos + 1, _editField.length()) : "");
        } else {
            _selectedIndex = (_selectedIndex + 1) % 4;
        }
        WatchUi.requestUpdate();
    }

    function prevItem() {
        if (_editMode) {
            _editCharIdx = (_editCharIdx - 1 + _charSet.length()) % _charSet.length();
            _editField = _editField.substring(0, _editPos) +
                         _charSet.substring(_editCharIdx, _editCharIdx + 1) +
                         (_editPos + 1 < _editField.length() ? _editField.substring(_editPos + 1, _editField.length()) : "");
        } else {
            _selectedIndex = (_selectedIndex - 1 + 4) % 4;
        }
        WatchUi.requestUpdate();
    }

    function selectItem() {
        if (_editMode) {
            // Volgende karakter
            _editPos++;
            if (_editPos >= _editField.length()) {
                // Klaar met invoeren
                _finishEdit();
            } else {
                _editCharIdx = _charSet.find(_editField.substring(_editPos, _editPos + 1));
                if (_editCharIdx == null) { _editCharIdx = 0; }
            }
            WatchUi.requestUpdate();
            return;
        }

        if (_selectedIndex == 0) {
            // Server URL — cycle through presets
            _cycleServerUrl();
        } else if (_selectedIndex == 1) {
            // Auth token — toggle wissen
            if (_authToken == null || _authToken.length() == 0) {
                // Kan niet instellen via watch, toon melding
            } else {
                _authToken = null;
                _saveAll();
            }
        } else if (_selectedIndex == 2) {
            // Race code — start edit
            _startRaceCodeEdit();
        } else if (_selectedIndex == 3) {
            // Auto sync — toggle
            _autoSync = !_autoSync;
            _saveAll();
        }
        WatchUi.requestUpdate();
    }

    function backItem() {
        if (_editMode) {
            if (_editPos > 0) {
                _editPos--;
                _editCharIdx = _charSet.find(_editField.substring(_editPos, _editPos + 1));
                if (_editCharIdx == null) { _editCharIdx = 0; }
            } else {
                _finishEdit();
            }
            WatchUi.requestUpdate();
            return true;
        }
        return false; // Pop view
    }

    // ─── Server URL cycler ────────────────────────────────────────

    hidden var _urlPresets = [
        "https://regatta.fhettinga.nl",
        "http://192.168.1.89:3000",
        null  // "Geen" / wissen
    ];

    function _cycleServerUrl() {
        var currentIdx = -1;
        for (var i = 0; i < _urlPresets.size(); i++) {
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

    function _startRaceCodeEdit() {
        _editMode = true;
        if (_raceCode == null || _raceCode.length() == 0) {
            _editField = "        "; // 8 spaties
            _editPos = 0;
            _editCharIdx = 0;
        } else {
            _editField = _raceCode;
            _editPos = 0;
            _editCharIdx = _charSet.find(_editField.substring(0, 1));
            if (_editCharIdx == null) { _editCharIdx = 0; }
        }
    }

    function _finishEdit() {
        _editMode = false;
        // Trim en opslaan
        var result = "";
        for (var i = 0; i < _editField.length(); i++) {
            var c = _editField.substring(i, i + 1);
            if (!c.equals(" ")) {
                result += c;
            }
        }
        _raceCode = result.length() > 0 ? result : null;
        _saveAll();
    }

    // ─── Render ───────────────────────────────────────────────────

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;

        var colorPrimary = 0x55FFFF;
        var colorWhite = Graphics.COLOR_WHITE;
        var colorGrey = 0x888888;
        var colorRed = 0xFF3333;

        if (_editMode) {
            _drawRaceCodeEditor(dc, width, height, cx, colorPrimary, colorWhite);
            return;
        }

        // Titel
        dc.setColor(colorPrimary, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height * 0.08, Graphics.FONT_XTINY, "INSTELLINGEN", Graphics.TEXT_JUSTIFY_CENTER);

        var startY = height * 0.18;
        var rowH = height * 0.16;

        // Server URL
        _drawRow(dc, 0, "Server", _formatUrl(_serverUrl), startY, rowH, cx, width, colorPrimary, colorWhite, colorGrey);

        // Auth token
        var tokenLabel = (_authToken != null && _authToken.length() > 0) ? "Ingesteld" : "Niet ingesteld";
        _drawRow(dc, 1, "Token", tokenLabel, startY + rowH, rowH, cx, width, colorPrimary, colorWhite, colorGrey);

        // Race code
        var codeLabel = (_raceCode != null && _raceCode.length() > 0) ? _raceCode : "—";
        _drawRow(dc, 2, "Race code", codeLabel, startY + rowH * 2, rowH, cx, width, colorPrimary, colorWhite, colorGrey);

        // Auto sync
        var syncLabel = _autoSync ? "Aan" : "Uit";
        _drawRow(dc, 3, "Auto sync", syncLabel, startY + rowH * 3, rowH, cx, width, colorPrimary, colorWhite, colorGrey);

        // Hints onderaan
        dc.setColor(colorGrey, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height - 25, Graphics.FONT_XTINY, "UP/DOWN: kies", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, height - 10, Graphics.FONT_XTINY, "START: wijzig  BACK: terug", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function _drawRow(dc, index, label, value, y, h, cx, width, primary, white, grey) {
        var isSelected = (_selectedIndex == index);

        if (isSelected) {
            dc.setColor(primary, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(cx - width * 0.42, y - 2, width * 0.84, h - 4);
        }

        dc.setColor(white, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - width * 0.38, y + h * 0.3, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_LEFT);

        dc.setColor(isSelected ? primary : grey, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + width * 0.38, y + h * 0.3, Graphics.FONT_XTINY, value, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    function _formatUrl(url) {
        if (url == null || url.length() == 0) { return "—"; }
        // Toon alleen het domein
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

    function _drawRaceCodeEditor(dc, width, height, cx, primary, white) {
        // Titel
        dc.setColor(primary, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height * 0.08, Graphics.FONT_XTINY, "RACE CODE", Graphics.TEXT_JUSTIFY_CENTER);

        // Huidige invoer
        dc.setColor(white, Graphics.COLOR_TRANSPARENT);
        var display = "";
        for (var i = 0; i < _editField.length(); i++) {
            if (i == _editPos) {
                display += "[";
            }
            display += _editField.substring(i, i + 1);
            if (i == _editPos) {
                display += "]";
            }
        }
        dc.drawText(cx, height * 0.22, Graphics.FONT_MEDIUM, display, Graphics.TEXT_JUSTIFY_CENTER);

        // Karakter strip (toon ±7 chars rond huidige)
        var charY = height * 0.5;
        var charW = width / 9;
        var startIdx = _editCharIdx - 3;
        if (startIdx < 0) { startIdx += _charSet.length(); }
        for (var i = 0; i < 7; i++) {
            var idx = (startIdx + i) % _charSet.length();
            var ch = _charSet.substring(idx, idx + 1);
            var x = cx + (i - 3) * charW;
            if (idx == _editCharIdx) {
                dc.setColor(Graphics.COLOR_BLACK, primary);
                dc.fillRectangle(x - charW/2 + 2, charY - 14, charW - 4, 28);
                dc.setColor(primary, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(white, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(x, charY, Graphics.FONT_MEDIUM, ch, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Hints
        var colorGrey = 0x888888;
        dc.setColor(colorGrey, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, height - 25, Graphics.FONT_XTINY, "UP/DOWN: kies letter", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, height - 10, Graphics.FONT_XTINY, "START: volgende  BACK: vorige", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
