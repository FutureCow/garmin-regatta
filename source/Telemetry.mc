// Telemetry.mc — GPS-telemetrie voor het infoscherm
//
// Wordt één keer per seconde aangetikt vanuit RegattaApp.onUiTick(), en
// bewust niet vanuit de view: onUpdate() draait ook op losse
// requestUpdate()-aanroepen, en dan zou het gemiddelde over een
// onregelmatige tijdbasis lopen in plaats van over echte seconden.
//
// Snelheid is het gemiddelde over de laatste SAMPLES metingen. Rauwe
// GPS-snelheid springt op het water makkelijk een halve knoop per
// seconde heen en weer; gedempt is hij pas leesbaar.
//
// Koers komt uit Activity.Info.track — de uit GPS-beweging afgeleide
// verplaatsingsrichting, dus koers over grond. Niet currentHeading:
// dat is de kompaskoers.

using Toybox.Activity;
using Toybox.Math;

class Telemetry {

    static const SAMPLES = 5;                   // venster in seconden
    static const MPS_TO_KNOTS = 1.943844;
    static const MIN_KNOTS_FOR_COURSE = 0.5;

    hidden var _speeds;             // ringbuffer met m/s
    hidden var _count = 0;          // aantal geldige metingen (max SAMPLES)
    hidden var _next = 0;           // schrijfpositie in de ringbuffer
    hidden var _course = null;      // graden, of null zolang er niets binnen is

    function initialize() {
        _speeds = new [SAMPLES];
        reset();
    }

    function reset() {
        for (var i = 0; i < SAMPLES; i++) {
            _speeds[i] = 0.0;
        }
        _count = 0;
        _next = 0;
        _course = null;
    }

    // Eén keer per seconde aanroepen.
    function tick() {
        var info = Activity.getActivityInfo();
        if (info == null) { return; }

        if (info.currentSpeed != null) {
            _speeds[_next] = info.currentSpeed;
            _next = (_next + 1) % SAMPLES;
            if (_count < SAMPLES) { _count++; }
        }

        if (info.track != null) {
            var deg = info.track * 180.0 / Math.PI;
            while (deg < 0.0)    { deg += 360.0; }
            while (deg >= 360.0) { deg -= 360.0; }
            _course = deg;
        }
    }

    function hasFix() { return _count > 0; }

    // Gemiddelde snelheid in knopen, of null zolang er niets gemeten is.
    function getSpeedKnots() {
        if (_count == 0) { return null; }

        var sum = 0.0;
        for (var i = 0; i < _count; i++) {
            sum += _speeds[i];
        }
        return (sum / _count) * MPS_TO_KNOTS;
    }

    // Koers over grond in graden, of null als je te langzaam gaat: onder
    // de drempel is track pure ruis en tolt het getal alle kanten op.
    function getCourseDegrees() {
        var knots = getSpeedKnots();
        if (knots == null || knots < MIN_KNOTS_FOR_COURSE) { return null; }
        return _course;
    }
}
