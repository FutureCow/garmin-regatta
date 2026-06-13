// TouchBlockerView.mc — Blokkeert alle touch input op de FR965
//
// Op de FR965 genereert een tap op het scherm onSelect (niet onTap),
// en een swipe genereert onNextPage/onPreviousPage. Het enige dat
// werkt is een view pushen die ALLE events consumeert.
//
// Deze view blokkeert alle input EN tekent de timer door de
// RegattaView's rendering aan te roepen.

using Toybox.WatchUi;

class TouchBlockerView extends WatchUi.View {
    hidden var _regattaView;

    function initialize(regattaView) {
        View.initialize();
        _regattaView = regattaView;
    }

    function onUpdate(dc) {
        // Laat de RegattaView de timer tekenen
        if (_regattaView != null) {
            (_regattaView as RegattaView).onUpdate(dc);
        }
    }
}

class TouchBlockerDelegate extends WatchUi.InputDelegate {
    function initialize() {
        InputDelegate.initialize();
    }

    // Blokkeer ALLE touch/button events behalve back
    function onSelect()       { return true; }
    function onNextPage()     { return true; }
    function onPreviousPage() { return true; }
    function onTap(e)         { return true; }
    function onSwipe(e)       { return true; }
    function onHold(e)        { return true; }
    function onBack()         { return false; }  // back moet nog werken
}
