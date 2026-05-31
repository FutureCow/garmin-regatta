// SettingsDelegate.mc — Input handling voor SettingsView

using Toybox.WatchUi;
using Toybox.System;
using Toybox.Lang;

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
            return true;
        }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
