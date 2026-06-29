import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
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
        var cx = dc.getWidth()  / 2;
        var cy = dc.getHeight() / 2;
        var r  = cx;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        drawTicks(dc, cx, cy, r);

        var t = System.getClockTime();
        drawHourHand(dc, cx, cy, r, t.hour, t.min);
        drawMinuteHand(dc, cx, cy, r, t.min, t.sec);
        drawSecondHand(dc, cx, cy, r, t.sec);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 4);
    }

    function onHide() as Void {
    }

    hidden function drawTicks(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number) as Void {
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 12; i++) {
            var angleRad = (i * 30 - 90) * Math.PI / 180.0;
            var isMajor  = (i % 3 == 0);
            var innerR   = isMajor ? (r * 0.82).toNumber() : (r * 0.88).toNumber();
            var outerR   = (r * 0.96).toNumber();
            var x1 = cx + (innerR * Math.cos(angleRad)).toNumber();
            var y1 = cy + (innerR * Math.sin(angleRad)).toNumber();
            var x2 = cx + (outerR * Math.cos(angleRad)).toNumber();
            var y2 = cy + (outerR * Math.sin(angleRad)).toNumber();
            dc.setPenWidth(isMajor ? 3 : 2);
            dc.drawLine(x1, y1, x2, y2);
        }
    }

    hidden function drawHourHand(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number, hours as Lang.Number, minutes as Lang.Number) as Void {
        var angleRad = ((hours % 12) + minutes / 60.0) * 30.0 * Math.PI / 180.0 - Math.PI / 2.0;
        var len = (r * 0.40).toNumber();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);
        dc.drawLine(cx, cy,
            cx + (len * Math.cos(angleRad)).toNumber(),
            cy + (len * Math.sin(angleRad)).toNumber());
    }

    hidden function drawMinuteHand(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number, minutes as Lang.Number, seconds as Lang.Number) as Void {
        var angleRad = (minutes + seconds / 60.0) * 6.0 * Math.PI / 180.0 - Math.PI / 2.0;
        var len = (r * 0.60).toNumber();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawLine(cx, cy,
            cx + (len * Math.cos(angleRad)).toNumber(),
            cy + (len * Math.sin(angleRad)).toNumber());
    }

    hidden function drawSecondHand(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number, seconds as Lang.Number) as Void {
        var angleRad = seconds * 6.0 * Math.PI / 180.0 - Math.PI / 2.0;
        var len     = (r * 0.65).toNumber();
        var tailLen = (r * 0.15).toNumber();
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(
            cx - (tailLen * Math.cos(angleRad)).toNumber(),
            cy - (tailLen * Math.sin(angleRad)).toNumber(),
            cx + (len * Math.cos(angleRad)).toNumber(),
            cy + (len * Math.sin(angleRad)).toNumber());
    }
}
