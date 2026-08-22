// TimerModel.mc — Countdown/elapsed race timer
//
// Uses tick() instead of System.getTimer() to avoid 32-bit float
// precision loss with large millisecond values.

class TimerModel {

    static const PRESET_5  = 300;
    static const PRESET_10 = 600;
    static const PRESET_15 = 900;

    // Geen PAUSED-toestand: de timer loopt van START tot Opslaan of
    // Verwijderen onafgebroken door. Zie de kop van RegattaApp.mc waarom.
    enum Status {
        STATUS_IDLE,
        STATUS_RUNNING
    }

    hidden var _status = STATUS_IDLE;
    hidden var _presetSeconds = PRESET_5;
    hidden var _remainingSeconds = PRESET_5;
    hidden var _elapsedSeconds = 0;

    function initialize() {
        _status = STATUS_IDLE;
    }

    // ─── Controls ──────────────────────────────────────────────────────

    function start() {
        if (_status == STATUS_RUNNING) { return; }

        _remainingSeconds = _presetSeconds;
        _elapsedSeconds = 0;
        _status = STATUS_RUNNING;
    }

    function reset() {
        _status = STATUS_IDLE;
        _remainingSeconds = _presetSeconds;
        _elapsedSeconds = 0;
    }

    // ─── Tick (called every second by UI timer) ─────────────────────────

    function tick() {
        if (_status != STATUS_RUNNING) { return; }

        if (_remainingSeconds > 0) {
            _remainingSeconds = _remainingSeconds - 1;
        } else {
            _elapsedSeconds = _elapsedSeconds + 1;
        }
    }

    // ─── Presets ───────────────────────────────────────────────────────

    function setPreset(seconds) {
        if (_status != STATUS_IDLE) { return; }
        _presetSeconds = seconds;
        _remainingSeconds = seconds;
    }

    function nextPreset() {
        if (_status != STATUS_IDLE) { return; }
        if (_presetSeconds == PRESET_5) {
            _presetSeconds = PRESET_10;
        } else if (_presetSeconds == PRESET_10) {
            _presetSeconds = PRESET_15;
        } else {
            _presetSeconds = PRESET_5;
        }
        _remainingSeconds = _presetSeconds;
    }

    function prevPreset() {
        if (_status != STATUS_IDLE) { return; }
        if (_presetSeconds == PRESET_15) {
            _presetSeconds = PRESET_10;
        } else if (_presetSeconds == PRESET_10) {
            _presetSeconds = PRESET_5;
        } else {
            _presetSeconds = PRESET_15;
        }
        _remainingSeconds = _presetSeconds;
    }

    // ─── Timer adjustment (±1 min during countdown) ────────────────────
    // +1 min → round UP to next whole minute (4:35 → 5:00)
    // -1 min → round DOWN to previous whole minute (4:35 → 4:00)

    function adjustUp() {
        if (_status == STATUS_RUNNING && isCountingDown()) {
            var secs = _remainingSeconds % 60;
            if (secs > 0) {
                _remainingSeconds += (60 - secs);  // round up to next minute
            } else {
                _remainingSeconds += 60;  // already on minute boundary
            }
        }
    }

    function adjustDown() {
        if (_status == STATUS_RUNNING && isCountingDown()) {
            var secs = _remainingSeconds % 60;
            if (secs > 0) {
                _remainingSeconds -= secs;  // round down to current minute
            } else {
                _remainingSeconds -= 60;  // already on minute boundary
            }
            if (_remainingSeconds < 0) {
                _remainingSeconds = 0;
            }
        }
    }

    function getPresetSeconds() { return _presetSeconds; }

    // ─── Display ───────────────────────────────────────────────────────

    function isRunning()    { return _status == STATUS_RUNNING; }
    function isIdle()       { return _status == STATUS_IDLE; }
    function isCountingDown() { return isRunning() && _remainingSeconds > 0; }

    function getRemainingSeconds() { return _remainingSeconds; }
    function getElapsedSeconds()   { return _elapsedSeconds; }

    function getDisplayString() {
        if (isCountingDown()) {
            return formatTime(_remainingSeconds, true);
        } else if (isRunning()) {
            return formatTime(_elapsedSeconds, false);
        }
        return formatTime(_presetSeconds, false);
    }

    function getLabel() {
        if (isRunning() && _remainingSeconds <= 0) {
            return "RACE";
        }
        return "AFTELLEN";
    }

    static function formatTime(totalSeconds, showNegative) {
        var absSecs = totalSeconds;
        var prefix = "";
        if (showNegative && totalSeconds < 0) {
            prefix = "-";
            absSecs = -totalSeconds;
        }

        var hours = absSecs / 3600;
        var mins = (absSecs % 3600) / 60;
        var secs = absSecs % 60;

        if (hours > 0) {
            return prefix + hours.format("%d") + ":" +
                   mins.format("%02d") + ":" +
                   secs.format("%02d");
        } else {
            return prefix + mins.format("%02d") + ":" + secs.format("%02d");
        }
    }
}
