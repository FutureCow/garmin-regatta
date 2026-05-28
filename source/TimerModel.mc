// TimerModel.mc — Countdown/elapsed race timer
//
// Manages a regatta countdown timer with preset durations.
// Flow: countdown → elapsed race time after countdown reaches zero.

class TimerModel {

    // Presets in seconds
    static const PRESET_5  = 300;   // 5 minutes
    static const PRESET_10 = 600;   // 10 minutes
    static const PRESET_15 = 900;   // 15 minutes

    enum Status {
        STATUS_IDLE,
        STATUS_RUNNING,
        STATUS_PAUSED
    }

    hidden var _status = STATUS_IDLE;
    hidden var _presetSeconds = PRESET_5;    // countdown duration
    hidden var _remainingSeconds = PRESET_5; // current countdown remaining
    hidden var _elapsedSeconds = 0;          // seconds since countdown hit 0
    hidden var _startMoment;                 // when timer was started (moment)

    function initialize() {
        _status = STATUS_IDLE;
    }

    // ─── Controls ──────────────────────────────────────────────────────

    function start() {
        if (_status == STATUS_RUNNING) { return; }

        if (_status == STATUS_IDLE) {
            // Fresh start
            _remainingSeconds = _presetSeconds;
            _elapsedSeconds = 0;
        }
        // If paused, resume where we left off

        _startMoment = System.getTimer();
        _status = STATUS_RUNNING;
    }

    function stop() {
        // Save current state before stopping (for pause/resume)
        _captureState();
        _status = STATUS_PAUSED;
    }

    function reset() {
        _status = STATUS_IDLE;
        _remainingSeconds = _presetSeconds;
        _elapsedSeconds = 0;
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

    function getPresetSeconds() { return _presetSeconds; }

    // ─── Display ───────────────────────────────────────────────────────

    function isRunning()    { return _status == STATUS_RUNNING; }
    function isPaused()     { return _status == STATUS_PAUSED; }
    function isIdle()       { return _status == STATUS_IDLE; }
    function isCountingDown() { return isRunning() && _remainingSeconds > 0; }

    // Returns formatted time string like "05:00" or "+00:15"
    function getDisplayString() {
        _captureState();

        if (isCountingDown()) {
            return formatTime(_remainingSeconds, true);
        } else if (isRunning()) {
            // Race elapsed
            return "+" + formatTime(_elapsedSeconds, false);
        } else if (isPaused()) {
            if (_remainingSeconds > 0) {
                return formatTime(_remainingSeconds, true);
            } else {
                return "+" + formatTime(_elapsedSeconds, false);
            }
        } else {
            // Idle — show preset
            return formatTime(_presetSeconds, false);
        }
    }

    // Returns "AFTELLEN" or "RACE" label
    function getLabel() {
        if (isCountingDown()) {
            return "AFTELLEN";
        } else if (isRunning() && _remainingSeconds <= 0) {
            return "RACE";
        }
        return "AFTELLEN";
    }

    function getRemainingSeconds() { _captureState(); return _remainingSeconds; }
    function getElapsedSeconds()   { _captureState(); return _elapsedSeconds; }

    // ─── Internal ──────────────────────────────────────────────────────

    hidden function _captureState() {
        if (_status != STATUS_RUNNING) { return; }

        var now = System.getTimer();
        var elapsedMs = now - _startMoment;
        var elapsedSecs = elapsedMs / 1000;

        if (_remainingSeconds > 0) {
            // Still counting down
            if (elapsedSecs >= _remainingSeconds) {
                // Countdown finished — overflow into race time
                _elapsedSeconds += (elapsedSecs - _remainingSeconds);
                _remainingSeconds = 0;
            } else {
                _remainingSeconds -= elapsedSecs;
            }
        } else {
            // Already in race time
            _elapsedSeconds += elapsedSecs;
        }

        _startMoment = now;
    }

    // ─── Utility ───────────────────────────────────────────────────────

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