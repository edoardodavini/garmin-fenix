import Toybox.Lang;
import Toybox.WatchUi;

class WatchFaceInputDelegate extends WatchUi.WatchFaceDelegate {

    var _view as WatchFaceView;

    function initialize(view as WatchFaceView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Lang.Boolean {
        _view.setAwake(true);
        WatchUi.requestUpdate();
        return true;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Lang.Boolean {
        if (keyEvent.getKey() == WatchUi.KEY_LIGHT) {
            _view.setAwake(true);
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }
}
