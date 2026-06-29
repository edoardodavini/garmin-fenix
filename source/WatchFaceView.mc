import Toybox.Graphics;
import Toybox.WatchUi;

class WatchFaceView extends WatchUi.WatchFace {

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onShow() as Void {
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
    }

    function onHide() as Void {
    }
}
