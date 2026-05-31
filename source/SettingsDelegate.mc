// SettingsDelegate.mc — Input handling voor SettingsView

using Toybox.WatchUi;
using Toybox.System;

class SettingsDelegate extends WatchUi.BehaviorDelegate {

    hidden var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        _view.selectItem();
        return true;
    }

    function onNextPage() as Boolean {
        _view.nextItem();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.prevItem();
        return true;
    }

    function onBack() as Boolean {
        if (_view.backItem()) {
            return true;
        }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
