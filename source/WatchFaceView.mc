import Toybox.Application;
import Toybox.Graphics;
import Toybox.Position;
import Toybox.Sensor;
import Toybox.Weather;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class WatchFaceView extends WatchUi.WatchFace {

    var _isAwake as Lang.Boolean = true;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onShow() as Void {
    }

    function onEnterSleep() as Void {
        _isAwake = false;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _isAwake = true;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var cx = dc.getWidth()  / 2;
        var cy = dc.getHeight() / 2;
        var r  = cx;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var t = System.getClockTime();

        // Digital time drawn first — sits behind everything as background element
        drawDigitalBar(dc, cx, cy, r, t.hour, t.min);

        try { drawInsights(dc, cx, cy, r); }     catch (e instanceof Lang.Exception) {}
        try { drawDayProgress(dc, cx, cy, r); }  catch (e instanceof Lang.Exception) {}
        drawTicks(dc, cx, cy, r);

        var numberStyle = Application.getApp().getProperty("NumberStyle") as Lang.Number;
        if (numberStyle == null) { numberStyle = 0; }
        drawNumbers(dc, cx, cy, r, numberStyle);

        drawHourHand(dc, cx, cy, r, t.hour, t.min);
        drawMinuteHand(dc, cx, cy, r, t.min, t.sec);
        if (_isAwake) {
            drawSecondHand(dc, cx, cy, r, t.sec);
        }

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

    hidden function drawDayProgress(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number) as Void {
        // Default sunrise/sunset if weather data unavailable
        var riseH = 6.0;
        var setH  = 20.0;

        var conditions = Weather.getCurrentConditions();
        if (conditions != null) {
            var loc = conditions.observationLocationPosition;
            if (loc != null) {
                var now     = Time.now();
                var sunrise = Weather.getSunrise(loc, now);
                var sunset  = Weather.getSunset(loc, now);
                if (sunrise != null) {
                    var ri = Gregorian.info(sunrise, Time.FORMAT_SHORT);
                    riseH = ri.hour + ri.min / 60.0;
                }
                if (sunset != null) {
                    var si = Gregorian.info(sunset, Time.FORMAT_SHORT);
                    setH = si.hour + si.min / 60.0;
                }
            }
        }

        var t    = System.getClockTime();
        var nowH = t.hour + t.min / 60.0;

        // Map 0-24h to arc angle: midnight=150°, noon=90°, next midnight=30°
        // 5° per hour across a 120° arc in the upper face
        var arcR    = (r * 0.55).toNumber();
        var riseAng = (150.0 - riseH * 5.0).toNumber();
        var setAng  = (150.0 - setH  * 5.0).toNumber();
        var nowAng  = (150.0 - nowH  * 5.0).toNumber();

        // Dim full-day background arc
        dc.setColor(0x282828, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawArc(cx, cy, arcR, Graphics.ARC_CLOCKWISE, 150, 30);

        // Yellow daylight arc (sunrise to sunset)
        dc.setColor(0xFFCC00, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawArc(cx, cy, arcR, Graphics.ARC_CLOCKWISE, riseAng, setAng);

        // White dot at current time
        var dotRad = nowAng * Math.PI / 180.0;
        var dotX   = cx + (arcR * Math.cos(dotRad)).toNumber();
        var dotY   = cy - (arcR * Math.sin(dotRad)).toNumber();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(dotX, dotY, 3);
    }

    hidden function drawNumbers(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number, style as Lang.Number) as Void {
        if (style == 0) { return; }
        var roman   = ["XII", "III", "VI", "IX"] as Lang.Array<Lang.String>;
        var arabic  = ["12",  "3",   "6",  "9"]  as Lang.Array<Lang.String>;
        var labels  = (style == 1) ? roman : arabic;
        var numR    = (r * 0.70).toNumber();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 4; i++) {
            var angleRad = (i * 90 - 90) * Math.PI / 180.0;
            var x = cx + (numR * Math.cos(angleRad)).toNumber();
            var y = cy + (numR * Math.sin(angleRad)).toNumber();
            dc.drawText(x, y, Graphics.FONT_XTINY, labels[i],
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    hidden function drawInsights(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number) as Void {
        dc.setColor(0x505050, Graphics.COLOR_TRANSPARENT);

        // Temperature
        var tempStr = "--°C";
        var conditions = Weather.getCurrentConditions();
        if (conditions != null && conditions.temperature != null) {
            tempStr = conditions.temperature.toNumber().format("%d") + "°C";
        }
        dc.drawText(cx, cy + (r * 0.72).toNumber(),
            Graphics.FONT_XTINY, tempStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Altitude
        var altStr = "--m";
        var sensorInfo = Sensor.getInfo();
        if (sensorInfo != null && sensorInfo.altitude != null) {
            altStr = sensorInfo.altitude.toNumber().format("%d") + "m";
        }
        dc.drawText(cx, cy + (r * 0.83).toNumber(),
            Graphics.FONT_XTINY, altStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    hidden function drawDigitalBar(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number, hours as Lang.Number, minutes as Lang.Number) as Void {
        // Large grey time — drawn before ticks/hands so it sits as a background element
        var timeStr = hours.format("%02d") + ":" + minutes.format("%02d");
        dc.setColor(0x3A3A3A, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy,
            Graphics.FONT_NUMBER_HOT, timeStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Date — smaller, same grey, just below center
        var dayNames = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"] as Lang.Array<Lang.String>;
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dateStr = dayNames[info.day_of_week - 1] + " " + info.day.format("%d");
        dc.setColor(0x303030, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + (r * 0.62).toNumber(),
            Graphics.FONT_XTINY, dateStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
