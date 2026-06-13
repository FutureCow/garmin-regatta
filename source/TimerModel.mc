// TimerModel.mc — Countdown/elapsed race timer
//
// Uses tick() instead of System.getTimer() to avoid 32-bit float
// precision loss with large millisecond values.

class TimerModel {

    static const PRESET_5  = 300;
    static const PRESET_10 = 600;
    static const PRESET_15 = 900;

    enum Status {
        STATUS_IDLE,
        STATUS_RUNNING,
        STATUS_PAUSED
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

        if (_status == STATUS_IDLE) {
            _remainingSeconds = _presetSeconds;
            _elapsedSeconds = 0;
        }
        _status = STATUS_RUNNING;
    }

    function stop() {
        _status = STATUS_PAUSED;
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

    // +1 min (naar boven afronden) — werkt tijdens countdown
    function adjustUp() {
        if (_status != STATUS_RUNNING) { return; }
        if (_remainingSeconds > 0) {
            var secs = _remainingSeconds % 60;
            _remainingSeconds = (secs != 0)
                ? (_remainingSeconds / 60 + 1) * 60
                : _remainingSeconds + 60;
        }
    }

    // -1 min (naar beneden afronden) — werkt tijdens countdown
    function adjustDown() {
        if (_status != STATUS_RUNNING) { return; }
        if (_remainingSeconds > 0) {
            var secs = _remainingSeconds % 60;
            _remainingSeconds = (secs != 0)
                ? (_remainingSeconds / 60) * 60
                : _remainingSeconds - 60;
            if (_remainingSeconds < 0) { _remainingSeconds = 0; }
        }
    }

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

    function getPresetSeconds() { return _presetSeconds; }

    // ─── Display ───────────────────────────────────────────────────────

    function isRunning()    { return _status == STATUS_RUNNING; }
    function isPaused()     { return _status == STATUS_PAUSED; }
    function isIdle()       { return _status == STATUS_IDLE; }
    function isCountingDown() { return isRunning() && _remainingSeconds > 0; }

    function getRemainingSeconds() { return _remainingSeconds; }
    function getElapsedSeconds()   { return _elapsedSeconds; }

    function getDisplayString() {
        if (isCountingDown()) {
            return formatTime(_remainingSeconds, true);
        } else if (isRunning()) {
            return "+" + formatTime(_elapsedSeconds, false);
        } else if (isPaused()) {
            if (_remainingSeconds > 0) {
                return formatTime(_remainingSeconds, true);
            } else {
                return "+" + formatTime(_elapsedSeconds, false);
            }
        } else {
            return formatTime(_presetSeconds, false);
        }
    }

    function getLabel() {
        if (isCountingDown()) {
            return "AFTELLEN";
        }
        // Race phase: running OR paused — zolang countdown voorbij is
        if (_remainingSeconds <= 0 && (isRunning() || isPaused())) {
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
