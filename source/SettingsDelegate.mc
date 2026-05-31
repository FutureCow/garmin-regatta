// SettingsDelegate.mc — Input handling voor SettingsView
//
// UP/DOWN: navigeren door instellingen
// START/ENTER: selecteren/wijzigen
// BACK: terug (of karakter terug in edit mode)

using Toybox.WatchUi;
using Toybox.System;

class SettingsDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        _view.selectItem();
        return true;
    }

    function onNextPage() {
        _view.nextItem();
        return true;
    }

    function onPreviousPage() {
        _view.prevItem();
        return true;
    }

    function onBack() {
        if (_view.backItem()) {
            return true; // Handled by view (edit mode)
        }
        // Pop settings view
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
