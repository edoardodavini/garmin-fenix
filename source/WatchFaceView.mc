import Toybox.Application;
import Toybox.Graphics;
import Toybox.Activity;
import Toybox.Position;
import Toybox.Weather;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.ActivityMonitor;
import Toybox.SensorHistory;
import Toybox.WatchUi;

class WatchFaceView extends WatchUi.WatchFace {

    var _isAwake as Lang.Boolean = true;
    var _lastSec as Lang.Number  = -1;

    // Cached per-minute data — refreshed in onUpdate (~every minute)
    var _bodyBattery  as Lang.Number? = null;
    var _watchBattery as Lang.Number  = 100;
    var _steps        as Lang.Number? = null;
    var _stepGoal     as Lang.Number? = null;
    var _riseH        as Lang.Float   = 6.0;
    var _setH         as Lang.Float   = 20.0;
    var _tempStr      as Lang.String  = "--°C";
    var _altStr       as Lang.String  = "--m";

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onShow() as Void {
    }

    function setAwake(awake as Lang.Boolean) as Void {
        _isAwake = awake;
    }

    function onEnterSleep() as Void {
        _isAwake = false;
        _lastSec = -1;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _isAwake = true;
        WatchUi.requestUpdate();
    }

    hidden function refreshData() as Void {
        // Body battery
        _bodyBattery = null;
        if ((Toybox has :SensorHistory) && (SensorHistory has :getBodyBatteryHistory)) {
            var iter = SensorHistory.getBodyBatteryHistory({:period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST});
            if (iter != null) {
                var sample = iter.next();
                if (sample != null) { _bodyBattery = sample.data as Lang.Number?; }
            }
        }

        // Watch battery
        _watchBattery = System.getSystemStats().battery.toNumber();

        // Steps
        var amInfo = ActivityMonitor.getInfo();
        _steps     = amInfo.steps;
        _stepGoal  = amInfo.stepGoal;

        // Weather: sunrise/sunset + temperature
        var conditions = Weather.getCurrentConditions();
        if (conditions != null) {
            if (conditions.temperature != null) {
                _tempStr = (conditions.temperature as Lang.Number).toNumber().format("%d") + "°C";
            }
            var loc = conditions.observationLocationPosition;
            if (loc != null) {
                var now     = Time.now();
                var sunrise = Weather.getSunrise(loc, now);
                var sunset  = Weather.getSunset(loc, now);
                if (sunrise != null) {
                    var ri = Gregorian.info(sunrise, Time.FORMAT_SHORT);
                    _riseH = ri.hour + ri.min / 60.0;
                }
                if (sunset != null) {
                    var si = Gregorian.info(sunset, Time.FORMAT_SHORT);
                    _setH = si.hour + si.min / 60.0;
                }
            }
        }

        // Altitude
        var actInfo = Activity.getActivityInfo();
        if (actInfo != null && actInfo.altitude != null) {
            _altStr = (actInfo.altitude as Lang.Float).toNumber().format("%d") + "m";
        }
    }

    // Full redraw — called ~every minute by system when onPartialUpdate is implemented
    function onUpdate(dc as Graphics.Dc) as Void {
        var cx = dc.getWidth()  / 2;
        var cy = dc.getHeight() / 2;
        var r  = cx;
        var t  = System.getClockTime();

        try { refreshData(); } catch (e instanceof Lang.Exception) {}

        dc.setAntiAlias(true);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        drawDigitalBar(dc, cx, cy, r, t.hour, t.min);

        try { drawInsights(dc, cx, cy, r); }                          catch (e instanceof Lang.Exception) {}
        try { drawDayProgressFull(dc, cx, cy, r, t.hour, t.min); }   catch (e instanceof Lang.Exception) {}
        try { drawBodyBattery(dc, cx, cy, r); }                       catch (e instanceof Lang.Exception) {}
        try { drawWatchBattery(dc, cx, cy, r); }                      catch (e instanceof Lang.Exception) {}
        try { drawSteps(dc, cx, cy, r); }                             catch (e instanceof Lang.Exception) {}
        drawTicks(dc, cx, cy, r);

        var numberStyle = Application.Storage.getValue("NumberStyle") as Lang.Number?;
        if (numberStyle == null) { numberStyle = 0; }
        drawNumbers(dc, cx, cy, r, numberStyle);

        drawHourHand(dc, cx, cy, r, t.hour, t.min);
        drawMinuteHand(dc, cx, cy, r, t.min, t.sec);

        drawSecondHand(dc, cx, cy, r, t.sec);
        _lastSec = t.sec;
    }

    // Called every second — only updates second hand
    function onPartialUpdate(dc as Graphics.Dc) as Void {
        var cx = dc.getWidth()  / 2;
        var cy = dc.getHeight() / 2;
        var r  = cx;
        var t  = System.getClockTime();

        // Erase previous second hand
        if (_lastSec >= 0) {
            eraseSecondHand(dc, cx, cy, r, _lastSec);
        }

        _lastSec = t.sec;
        drawSecondHand(dc, cx, cy, r, t.sec);
    }

    function onHide() as Void {
    }

    hidden function eraseSecondHand(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number, seconds as Lang.Number) as Void {
        var angleRad = seconds * 6.0 * Math.PI / 180.0 - Math.PI / 2.0;
        var len     = (r * 0.99).toNumber();
        var tailLen = (r * -0.55).toNumber();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4); // wider than draw pen to cover antialiasing
        dc.drawLine(
            cx - (tailLen * Math.cos(angleRad)).toNumber(),
            cy - (tailLen * Math.sin(angleRad)).toNumber(),
            cx + (len * Math.cos(angleRad)).toNumber(),
            cy + (len * Math.sin(angleRad)).toNumber());
    }

    hidden function drawTicks(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number) as Void {
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 60; i++) {
            var angleRad = (i * 6 - 90) * Math.PI / 180.0;
            var isMajor  = (i % 15 == 0);
            var isMiddle = (i % 5 == 0);
            var innerR   = isMajor ? (r * 0.88).toNumber() : isMiddle ? (r * 0.92).toNumber() : (r * 0.96).toNumber();
            var outerR   = (r * 1).toNumber();
            var x1 = cx + (innerR * Math.cos(angleRad)).toNumber();
            var y1 = cy + (innerR * Math.sin(angleRad)).toNumber();
            var x2 = cx + (outerR * Math.cos(angleRad)).toNumber();
            var y2 = cy + (outerR * Math.sin(angleRad)).toNumber();
            dc.setPenWidth(isMajor ? 5 : isMiddle ? 3 : 1);
            dc.drawLine(x1, y1, x2, y2);
        }
    }

    hidden function drawHourHand(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number, hours as Lang.Number, minutes as Lang.Number) as Void {
        var a    = ((hours % 12) + minutes / 60.0) * 30.0 * Math.PI / 180.0 - Math.PI / 2.0;
        var cosA = Math.cos(a);
        var sinA = Math.sin(a);
        var len  = (r * 0.60).toNumber();
        var shld = (r * 0.42).toNumber(); // shoulder: point where hand widens; tip→shld = white, shld→tail = black
        var tail = (r * 0).toNumber(); // counterbalance stub past center
        var hw   = 10;                     // half-width at shoulder (pixels)
        var tipX  = cx + (len  * cosA).toNumber();
        var tipY  = cy + (len  * sinA).toNumber();
        var shldX = cx + (shld * cosA).toNumber();
        var shldY = cy + (shld * sinA).toNumber();
        var tailX = cx - (tail * cosA).toNumber();
        var tailY = cy - (tail * sinA).toNumber();
        var pxN   = (hw * (-sinA)).toNumber();
        var pyN   = (hw * cosA).toNumber();
        dc.setPenWidth(5);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(tipX, tipY, shldX + pxN, shldY + pyN);
        dc.drawLine(shldX - pxN, shldY - pyN, tipX, tipY);
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(shldX + pxN, shldY + pyN, tailX, tailY);
        dc.drawLine(tailX, tailY, shldX - pxN, shldY - pyN);
    }

    hidden function drawMinuteHand(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number, minutes as Lang.Number, seconds as Lang.Number) as Void {
        var a    = (minutes + seconds / 60.0) * 6.0 * Math.PI / 180.0 - Math.PI / 2.0;
        var cosA = Math.cos(a);
        var sinA = Math.sin(a);
        var len  = (r * 0.80).toNumber();
        var shld = (r * 0.45).toNumber(); // shoulder: point where hand widens; tip→shld = white, shld→tail = black
        var tail = (r * 0).toNumber(); // counterbalance stub past center
        var hw   = 8;                     // half-width at shoulder (pixels)
        var tipX  = cx + (len  * cosA).toNumber();
        var tipY  = cy + (len  * sinA).toNumber();
        var shldX = cx + (shld * cosA).toNumber();
        var shldY = cy + (shld * sinA).toNumber();
        var tailX = cx - (tail * cosA).toNumber();
        var tailY = cy - (tail * sinA).toNumber();
        var pxN   = (hw * (-sinA)).toNumber();
        var pyN   = (hw * cosA).toNumber();
        dc.setPenWidth(3);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(tipX, tipY, shldX + pxN, shldY + pyN);
        dc.drawLine(shldX - pxN, shldY - pyN, tipX, tipY);
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(shldX + pxN, shldY + pyN, tailX, tailY);
        dc.drawLine(tailX, tailY, shldX - pxN, shldY - pyN);
    }

    hidden function drawSecondHand(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number, seconds as Lang.Number) as Void {
        var angleRad = seconds * 6.0 * Math.PI / 180.0 - Math.PI / 2.0;
        var len     = (r * 0.99).toNumber();
        var tailLen = (r * -0.55).toNumber();
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(
            cx - (tailLen * Math.cos(angleRad)).toNumber(),
            cy - (tailLen * Math.sin(angleRad)).toNumber(),
            cx + (len * Math.cos(angleRad)).toNumber(),
            cy + (len * Math.sin(angleRad)).toNumber());
    }

    hidden function drawDayProgressFull(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number, hours as Lang.Number, minutes as Lang.Number) as Void {
        // 24h mapped to full 360°: midnight at bottom (270°), noon at top (90°), 15°/h clockwise
        var nowH    = hours + minutes / 60.0;
        var arcR    = (r).toNumber();
        var riseAng = (270.0 - _riseH * 15.0).toNumber();
        var setAng  = (270.0 - _setH  * 15.0).toNumber();
        var nowAng  = (270.0 - nowH   * 15.0).toNumber();

        dc.setColor(0x000055, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawArc(cx, cy, arcR, Graphics.ARC_CLOCKWISE, setAng, riseAng);

        dc.setColor(0xFFCC00, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);
        dc.drawArc(cx, cy, arcR, Graphics.ARC_CLOCKWISE, riseAng, setAng);

        var dotRad = nowAng * Math.PI / 180.0;
        var dotX   = cx + (arcR * Math.cos(dotRad)).toNumber();
        var dotY   = cy - (arcR * Math.sin(dotRad)).toNumber();
        dc.setColor(0xFFCC00, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(dotX, dotY, 8);
    }

    hidden function drawBodyBattery(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number) as Void {
        var arcR = (r * 0.07).toNumber();
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(cx, cy - (r * 0.09), arcR);

        var battery = _bodyBattery;
        if (battery == null) { return; }

        var color = (battery > 60) ? 0x00AA55 : ((battery > 30) ? 0xFFAA00 : 0xAA2200);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (battery >= 100) {
            dc.drawCircle(cx, cy - (r * 0.09), arcR);
        } else {
            var endAng = (90 - battery * 360 / 100).toNumber();
            dc.drawArc(cx, cy - (r * 0.09), arcR, Graphics.ARC_CLOCKWISE, 90, endAng);
        }

        // Lightning bolt icon centered in circle
        var bx = cx;
        var by = cy - (r * 0.09).toNumber();
        var s  = (r * 0.048).toNumber();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [bx + s/3, by - s],
            [bx - s/3, by    ],
            [bx + s/6, by    ],
            [bx - s/3, by + s],
            [bx + s/3, by    ],
            [bx - s/6, by    ]
        ]);
    }

    hidden function drawWatchBattery(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number) as Void {
        var arcR  = (r * 0.07).toNumber();
        var dotCy = cy + (r * 0.09).toNumber();
        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(cx, dotCy, arcR);

        var battery = _watchBattery;
        var color = (battery > 60) ? 0x00AA55 : ((battery > 30) ? 0xFFAA00 : 0xAA2200);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (battery >= 100) {
            dc.drawCircle(cx, dotCy, arcR);
        } else {
            var endAng = (90 - battery * 360 / 100).toNumber();
            dc.drawArc(cx, dotCy, arcR, Graphics.ARC_CLOCKWISE, 90, endAng);
        }

        // Battery icon (nub on top)
        var s   = (r * 0.048).toNumber();
        var bw2 = s * 2 / 5;
        var h2  = s * 7 / 10;
        var nw2 = s / 5;
        var nh  = s / 5;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [cx - nw2, dotCy - h2 - nh],
            [cx + nw2, dotCy - h2 - nh],
            [cx + nw2, dotCy - h2     ],
            [cx + bw2, dotCy - h2     ],
            [cx + bw2, dotCy + h2     ],
            [cx - bw2, dotCy + h2     ],
            [cx - bw2, dotCy - h2     ],
            [cx - nw2, dotCy - h2     ]
        ]);
    }

    hidden function drawSteps(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number) as Void {
        // Smile arc: 90° centered at bottom (270°), from 315° to 225° clockwise
        // Goal marker at 75% of arc (247.5°); full arc = goal * 4/3
        var arcR = (r * 0.70).toNumber();

        dc.setColor(0x444444, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawArc(cx, cy, arcR, Graphics.ARC_CLOCKWISE, 315, 225);

        var steps    = _steps;
        var stepGoal = _stepGoal;
        if (steps == null || stepGoal == null || stepGoal == 0) { return; }

        // Goal marker tick at 292.5° (75% of arc from 225°)
        var markerRad = 292.5 * Math.PI / 180.0;
        var inner = arcR - 5;
        var outer = arcR + 5;
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(
            cx + (inner * Math.cos(markerRad)).toNumber(),
            cy - (inner * Math.sin(markerRad)).toNumber(),
            cx + (outer * Math.cos(markerRad)).toNumber(),
            cy - (outer * Math.sin(markerRad)).toNumber()
        );

        if (steps == 0) { return; }
        var arcFraction = steps.toFloat() * 0.75 / stepGoal.toFloat();
        if (arcFraction > 1.0) { arcFraction = 1.0; }
        var fillDeg  = arcFraction * 90.0;
        var startAng = (225.0 + fillDeg).toNumber(); // fills left→right through bottom
        var color    = (arcFraction >= 0.75) ? 0x00AA55 : ((arcFraction >= 0.375) ? 0xFFAA00 : 0xAA2200);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawArc(cx, cy, arcR, Graphics.ARC_CLOCKWISE, startAng, 225);
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
        dc.drawText(cx - (r * 0.40), cy + (r * 0.36).toNumber(),
            Graphics.FONT_XTINY, _tempStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(cx + (r * 0.40), cy + (r * 0.36).toNumber(),
            Graphics.FONT_XTINY, _altStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    hidden function drawDigitalBar(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number, hours as Lang.Number, minutes as Lang.Number) as Void {
        var timeStr = hours.format("%02d") + " " + minutes.format("%02d");
        dc.setColor(0x3A3A3A, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy,
            Graphics.FONT_NUMBER_THAI_HOT, timeStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var dayNames = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"] as Lang.Array<Lang.String>;
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dateStr = dayNames[info.day_of_week - 1] + " " + info.day.format("%d");
        dc.setColor(0x303030, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - (r * 0.38).toNumber(),
            Graphics.FONT_XTINY, dateStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
