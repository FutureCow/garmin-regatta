// RegattaApp.mc — Garmin IQ Regatta Timer + GPS Recorder
//
// Entry point for the Regatta watch app. Records timer + GPS position
// to a FIT file with SPORT_SAILING. The FIT file auto-syncs to Garmin
// Connect via the phone — no WiFi, Bluetooth, or server config needed.
// The regatta-server pulls sailing activities from Garmin Connect.
//
// Er is geen pauze. START werkt alleen vanuit het startscherm; zodra de
// timer loopt doet de knop niets meer, want op het water druk je hem te
// makkelijk per ongeluk in. BACK opent een menu terwijl timer en GPS
// gewoon doorlopen:
//   Verder opnemen → sluit het menu, er verandert niets (bovenaan, dus
//                    BACK-BACK en BACK-START zijn allebei onschadelijk)
//   Opslaan        → FIT bewaren, sync naar Garmin Connect, terug naar start
//   Verwijderen    → opname weggooien, terug naar start
//
// Architecture:
//   RegattaApp (Application)
//       ├── RegattaView (WatchUi.View)               — timer/GPS UI
//       ├── RegattaDelegate (WatchUi.BehaviorDelegate) — button input
//       ├── TimerModel                                — countdown + elapsed
//       ├── GpsRecorder                               — FIT file GPS recording
//       └── Telemetry                                 — snelheid/koers voor pagina 1

using Toybox.Application;
using Toybox.System;
using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.Attention;

class RegattaApp extends Application.AppBase {

    // De opname begint pas in de laatste 5 minuten voor de start. Eerder
    // levert alleen aanlooprommel op, en 5 minuten is ruim genoeg voor een
    // GPS-fix (die heeft doorgaans onder de minuut nodig).
    static const GPS_START_SECONDS = 300;

    hidden var _view;
    hidden var _timerModel;
    hidden var _gpsRecorder;
    hidden var _telemetry;
    hidden var _uiTimer;
    hidden var _lastAlertSec = -1;   // voorkomt dubbele alerts
    hidden var _lapMarked = false;   // precies één lapmarker per race
    hidden var _page = 0;            // 0 = timer, 1 = info (alleen in de race)

    function initialize() {
        AppBase.initialize();
        _timerModel = new TimerModel();
        _gpsRecorder = new GpsRecorder(method(:onGpsUpdate));
        _telemetry = new Telemetry();
    }

    function getTimerModel()  { return _timerModel; }
    function getGpsRecorder() { return _gpsRecorder; }
    function getTelemetry()   { return _telemetry; }

    // ─── Paginastand ──────────────────────────────────────────────────
    // Bladeren kan alleen tijdens de race; RegattaView negeert de stand
    // in elke andere fase, dus hier hoeft niets afgeschermd te worden.

    function getPage() { return _page; }

    function togglePage() {
        _page = (_page == 0) ? 1 : 0;
        WatchUi.requestUpdate();
    }

    // Reset UI timer — called after adjustUp/adjustDown so the next
    // tick always fires exactly 1 second later (consistent timing).
    function resetUiTimer() {
        if (_uiTimer != null) {
            _uiTimer.stop();
            _uiTimer.start(method(:onUiTick), 1000, true);
        }
    }

    // ─── App Lifecycle ────────────────────────────────────────────────

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        _view = new RegattaView();
        var delegate = new RegattaDelegate(method(:onBackPressed), method(:onSelect));

        _uiTimer = new Timer.Timer();
        _uiTimer.start(method(:onUiTick), 1000, true);

        return [_view, delegate];
    }

    function onStart(state) {}

    function onStop(state) {
        if (_uiTimer != null) {
            _uiTimer.stop();
            _uiTimer = null;
        }
    }

    function onUiTick() as Void {
        // Fire alerts BEFORE tick (display matches remaining value)
        if (_timerModel.isCountingDown()) {
            var remaining = _timerModel.getRemainingSeconds();
            _fireCountdownAlert(remaining);
        }

        _timerModel.tick();

        _maybeStartRecording();
        _maybeMarkStartLap();

        // Zonder sessie levert Activity.getActivityInfo() niets zinnigs op,
        // dus pas meten zodra er ook echt opgenomen wordt.
        if (_gpsRecorder.isRecording()) {
            _telemetry.tick();
        }

        // Reset alert tracking when countdown ends
        if (!_timerModel.isCountingDown()) {
            _lastAlertSec = -1;
        }

        WatchUi.requestUpdate();
    }

    // ─── Countdown alerts (piep + tril) ────────────────────────────────

    hidden function _fireCountdownAlert(remaining) {
        if (remaining == _lastAlertSec) { return; }

        var shouldAlert = false;

        if (remaining <= 5 && remaining > 0) {
            // Laatste 5 seconden: elke seconde
            shouldAlert = true;
        } else if (remaining <= 60 && remaining > 0 && remaining % 10 == 0) {
            // Laatste minuut: elke 10 seconden
            shouldAlert = true;
        } else if (remaining <= 300 && remaining % 60 == 0) {
            // Vanaf 5:00: elke minuut (5:00, 4:00, 3:00, 2:00, 1:00)
            shouldAlert = true;
        }

        if (shouldAlert) {
            _lastAlertSec = remaining;

            // Korte piep
            Attention.playTone(Attention.TONE_START);

            // Korte vibratie
            if (Attention has :vibrate) {
                var vibe = [new Attention.VibeProfile(50, 150)];
                Attention.vibrate(vibe);
            }
        }
    }

    // ─── Opnamevenster en lapmarker ──────────────────────────────────────

    // Start de opname zodra de resttijd onder de drempel zakt. Idempotent,
    // dus veilig om elke tik aan te roepen. Eenmaal begonnen stoppen we
    // niet meer: ga je met +1 weer boven 5:00, dan loopt de opname door,
    // anders knip je een gat in je eigen track.
    hidden function _maybeStartRecording() {
        if (!_timerModel.isRunning()) { return; }
        if (_gpsRecorder.isRecording()) { return; }
        if (_timerModel.getRemainingSeconds() > GPS_START_SECONDS) { return; }

        _gpsRecorder.start();
    }

    // Zet één lapmarker op het startschot, zodat in het FIT-bestand te zien
    // is waar de aanloop ophoudt en de race begint.
    hidden function _maybeMarkStartLap() {
        if (_lapMarked) { return; }
        if (!_timerModel.isRunning()) { return; }
        if (_timerModel.getRemainingSeconds() > 0) { return; }

        _gpsRecorder.markLap();
        _lapMarked = true;   // ook na een mislukking niet elke seconde opnieuw
    }

    // ─── GPS Callback ────────────────────────────────────────────────────

    function onGpsUpdate(pointCount) as Void {
        if (_view != null && _view has :updateGps) {
            _view.updateGps(pointCount);
        }
    }

    // ─── Select (START button) ──────────────────────────────────────────

    function onSelect() {
        // Alleen vanuit het startscherm. Tijdens aftellen of race doet
        // START bewust niets — stoppen gaat via BACK → menu.
        if (!_timerModel.isIdle()) { return; }

        if (_view != null && _view has :showMessage) {
            _view.showMessage("");   // melding van de vorige opname wissen
        }
        _page = 0;
        _lapMarked = false;
        _telemetry.reset();
        _timerModel.start();
        _maybeStartRecording();   // begint meteen als de preset al 5:00 is
        WatchUi.requestUpdate();
    }

    // ─── Confirm menu (na stoppen) ─────────────────────────────────────

    // "Verder opnemen" staat bewust bovenaan: dat is de gemarkeerde keuze,
    // zodat een per ongeluk ingedrukte BACK gevolgd door START niets doet.
    hidden function _showConfirmMenu() {
        var menu = new WatchUi.Menu2({:title=>"Race"});

        menu.addItem(
            new WatchUi.MenuItem("Verder opnemen", "Sluit dit menu", 1, {})
        );
        menu.addItem(
            new WatchUi.MenuItem("Opslaan", "Bewaar track voor Garmin Connect", 2, {})
        );
        menu.addItem(
            new WatchUi.MenuItem("Verwijderen", "Gooi opname weg", 3, {})
        );

        WatchUi.pushView(
            menu,
            new ConfirmMenuDelegate(method(:onConfirmChoice)),
            WatchUi.SLIDE_IMMEDIATE
        );
    }

    function onConfirmChoice(choice) {
        if (choice == 1) {
            // Verder opnemen — er is niets gepauzeerd, dus alleen sluiten
            WatchUi.requestUpdate();
        } else if (choice == 2) {
            // Opslaan — terug naar IDLE, anders erft de volgende race de
            // klok van deze race terwijl de recorder wel opnieuw begint.
            // Vóór 5:00 is er nog geen sessie. Dan valt er niets te bewaren
            // en zou "Opgeslagen" suggereren dat er een track op het horloge
            // staat die er niet is.
            var recorded = _gpsRecorder.isRecording();
            _gpsRecorder.saveAndStop();
            _timerModel.reset();
            _page = 0;
            if (_view != null && _view has :showMessage) {
                _view.showMessage(recorded ? "Opgeslagen" : "Niets opgenomen");
            }
            WatchUi.requestUpdate();
        } else if (choice == 3) {
            // Verwijderen
            _gpsRecorder.discardAndStop();
            _timerModel.reset();
            _page = 0;
            if (_view != null && _view has :showMessage) {
                _view.showMessage("Verwijderd");
            }
            WatchUi.requestUpdate();
        }
    }

    // ─── BACK button ─────────────────────────────────────────────────────

    function onBackPressed() {
        if (_timerModel.isIdle()) {
            return false;   // startscherm — laat het systeem de app sluiten
        }

        // Timer en GPS lopen door terwijl het menu open staat: BACK stopt
        // of pauzeert niets, het opent alleen een keuze.
        _showConfirmMenu();
        return true;
    }
}


// ─── Confirm Menu Delegate ────────────────────────────────────────────

class ConfirmMenuDelegate extends WatchUi.Menu2InputDelegate {
    hidden var _callback;

    function initialize(callback) {
        Menu2InputDelegate.initialize();
        _callback = callback;
    }

    function onSelect(item) {
        var id = item.getId();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        _callback.invoke(id);
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}
