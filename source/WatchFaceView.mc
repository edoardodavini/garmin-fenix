import Toybox.Graphics;
import Toybox.Activity;
import Toybox.Weather;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.ActivityMonitor;
import Toybox.SensorHistory;
import Toybox.WatchUi;

// MIP display: 64-colour palette, so stick to exact palette greys
const COL_SILVER = 0xAAAAAA;
const COL_DIM    = 0x555555;
const COL_DIGITS = 0x3A3A3A;

class WatchFaceView extends WatchUi.WatchFace {

    var _isAwake as Lang.Boolean = true;
    var _lastSec as Lang.Number  = -1;

    // Offscreen copy of everything except the second hand, so onPartialUpdate
    // can erase the old second hand by repainting only its bounding box
    var _buf as Graphics.BufferedBitmapReference? = null;

    // Cached per-minute data — refreshed in onUpdate (~every minute)
    var _bodyBattery  as Lang.Number? = null;
    var _watchBattery as Lang.Number  = 100;
    var _steps        as Lang.Number? = null;
    var _stepGoal     as Lang.Number? = null;
    var _riseH        as Lang.Float   = 6.0;
    var _setH         as Lang.Float   = 20.0;
    var _riseStr      as Lang.String  = "--:--";
    var _setStr       as Lang.String  = "--:--";
    var _tempStr      as Lang.String  = "--°C";
    var _altStr       as Lang.String  = "--m";

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        if (Graphics has :createBufferedBitmap) {
            _buf = Graphics.createBufferedBitmap({
                :width  => dc.getWidth(),
                :height => dc.getHeight()
            });
        }
    }

    function onShow() as Void {
    }

    function setAwake(awake as Lang.Boolean) as Void {
        _isAwake = awake;
    }

    function onEnterSleep() as Void {
        _isAwake = false;
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
                if (sample != null && sample.data != null) { _bodyBattery = (sample.data as Lang.Numeric).toNumber(); }
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
                    _riseH   = ri.hour + ri.min / 60.0;
                    _riseStr = ri.hour.format("%02d") + ":" + ri.min.format("%02d");
                }
                if (sunset != null) {
                    var si = Gregorian.info(sunset, Time.FORMAT_SHORT);
                    _setH   = si.hour + si.min / 60.0;
                    _setStr = si.hour.format("%02d") + ":" + si.min.format("%02d");
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

        var buf = _buf;
        if (buf != null) {
            var bmp = buf.get() as Graphics.BufferedBitmap?;
            if (bmp != null) {
                drawDial(bmp.getDc(), cx, cy, r, t);
                dc.drawBitmap(0, 0, buf);
            } else {
                drawDial(dc, cx, cy, r, t);
            }
        } else {
            drawDial(dc, cx, cy, r, t);
        }

        dc.setAntiAlias(true);
        drawSecondHand(dc, cx, cy, r, t.sec);
        _lastSec = t.sec;
    }

    // Called every second in low power — repaint only where the second hand was and is
    function onPartialUpdate(dc as Graphics.Dc) as Void {
        var buf = _buf;
        if (buf == null) { return; }

        var cx = dc.getWidth()  / 2;
        var cy = dc.getHeight() / 2;
        var r  = cx;
        var t  = System.getClockTime();

        if (_lastSec >= 0) {
            var old = secondHandBounds(cx, cy, r, _lastSec);
            dc.setClip(old[0], old[1], old[2], old[3]);
            dc.drawBitmap(0, 0, buf);
        }

        var cur = secondHandBounds(cx, cy, r, t.sec);
        dc.setClip(cur[0], cur[1], cur[2], cur[3]);
        dc.drawBitmap(0, 0, buf);
        dc.setAntiAlias(true);
        drawSecondHand(dc, cx, cy, r, t.sec);
        dc.clearClip();
        _lastSec = t.sec;
    }

    function onHide() as Void {
    }

    // Everything except the second hand
    hidden function drawDial(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number, t as System.ClockTime) as Void {
        dc.setAntiAlias(true);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        drawDigits(dc, cx, cy, t.hour, t.min);

        try { drawSunRing(dc, cx, cy, r, t.hour, t.min); } catch (e instanceof Lang.Exception) {}
        drawMinuteTrack(dc, cx, cy, r);
        drawIndices(dc, cx, cy, r);

        var subR = (r * 0.19).toNumber();
        var subY = (r * 0.44).toNumber();
        try { drawBatterySubdial(dc, cx, cy - subY, subR); }        catch (e instanceof Lang.Exception) {}
        try { drawSunTimes(dc, cx, cy - subY, subR); }              catch (e instanceof Lang.Exception) {}
        try { drawStepsSubdial(dc, cx, cy + subY, subR, r); }       catch (e instanceof Lang.Exception) {}
        try { drawInsights(dc, cx, cy + subY, r); }                 catch (e instanceof Lang.Exception) {}
        try { drawDateWindow(dc, cx, cy, r); }                      catch (e instanceof Lang.Exception) {}

        drawHourHand(dc, cx, cy, r, t.hour, t.min);
        drawMinuteHand(dc, cx, cy, r, t.min, t.sec);
    }

    // Point at `len` from (x, y) along clock angle `deg` (0 = 12 o'clock, clockwise)
    hidden function polar(x as Lang.Number, y as Lang.Number, len as Lang.Numeric, deg as Lang.Numeric) as [Lang.Number, Lang.Number] {
        var a = (deg - 90) * Math.PI / 180.0;
        return [x + (len * Math.cos(a)).toNumber(), y + (len * Math.sin(a)).toNumber()];
    }

    hidden function radialLine(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, r1 as Lang.Numeric, r2 as Lang.Numeric, deg as Lang.Numeric) as Void {
        var p1 = polar(x, y, r1, deg);
        var p2 = polar(x, y, r2, deg);
        dc.drawLine(p1[0], p1[1], p2[0], p2[1]);
    }

    hidden function drawDigits(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, hours as Lang.Number, minutes as Lang.Number) as Void {
        var timeStr = hours.format("%02d") + " " + minutes.format("%02d");
        dc.setColor(COL_DIGITS, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy,
            Graphics.FONT_NUMBER_THAI_HOT, timeStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    hidden function drawSunRing(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number, hours as Lang.Number, minutes as Lang.Number) as Void {
        // 24h mapped to full 360°: midnight at bottom, noon at top, 15°/h clockwise
        var arcR    = r - 4;
        var nowH    = hours + minutes / 60.0;
        var riseAng = (270.0 - _riseH * 15.0).toNumber();
        var setAng  = (270.0 - _setH  * 15.0).toNumber();

        dc.setColor(COL_DIM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawArc(cx, cy, arcR, Graphics.ARC_CLOCKWISE, setAng, riseAng);

        dc.setColor(COL_SILVER, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawArc(cx, cy, arcR, Graphics.ARC_CLOCKWISE, riseAng, setAng);

        // Hour ticks, brighter every 6h
        for (var h = 0; h < 24; h++) {
            var major = (h % 6 == 0);
            dc.setColor(major ? COL_SILVER : COL_DIM, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(major ? 2 : 1);
            radialLine(dc, cx, cy, r * 0.92, r * 0.94, h * 15 + 180);
        }

        var dot = polar(cx, cy, arcR, nowH * 15.0 + 180.0);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(dot[0], dot[1], 4);
    }

    hidden function drawMinuteTrack(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number) as Void {
        for (var i = 0; i < 60; i++) {
            var five = (i % 5 == 0);
            dc.setColor(five ? COL_SILVER : COL_DIM, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(1);
            radialLine(dc, cx, cy, five ? r * 0.845 : r * 0.86, r * 0.88, i * 6);
        }
    }

    hidden function drawIndices(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number) as Void {
        // Baton indices with a lume dot; 12 and 6 make room for sub-dials, 3 for the date window
        for (var h = 1; h < 12; h++) {
            if (h == 3 || h == 6) { continue; }
            dc.setColor(COL_SILVER, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(4);
            radialLine(dc, cx, cy, r * 0.72, r * 0.83, h * 30);
            var p = polar(cx, cy, r * 0.69, h * 30);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(p[0], p[1], 2);
        }
    }

    hidden function drawSubdialBase(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, sr as Lang.Number) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, sr);
        dc.setColor(COL_SILVER, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(x, y, sr);
    }

    hidden function drawSmallHand(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, len as Lang.Number, deg as Lang.Numeric) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        radialLine(dc, x, y, -4, len, deg);
    }

    hidden function drawBatterySubdial(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, sr as Lang.Number) as Void {
        // Two 180° gauges sharing one pivot: 0 at bottom, 100 at top.
        // Left half = body battery, right half = watch battery.
        drawSubdialBase(dc, x, y, sr);
        var pr = sr - 4;

        // Progress tracks (Garmin arc degrees: 0 = 3 o'clock, counter-clockwise)
        dc.setColor(COL_DIM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawArc(x, y, pr, Graphics.ARC_CLOCKWISE, 267, 93);
        dc.drawArc(x, y, pr, Graphics.ARC_COUNTER_CLOCKWISE, 273, 87);

        // Scale ticks every 25%
        dc.setColor(COL_SILVER, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        for (var i = 0; i <= 4; i++) {
            radialLine(dc, x, y, sr - 10, sr - 7, 180 + i * 45);
            radialLine(dc, x, y, sr - 10, sr - 7, 180 - i * 45);
        }

        // Tiny bolt (left) and battery (right) icons in the lower half
        var s = (sr * 0.22).toNumber();
        drawBoltIcon(dc, x - sr / 3, y + sr / 2, s);
        drawBatteryIcon(dc, x + sr / 3, y + sr / 2, s);

        var bb  = _bodyBattery;
        var bat = clampPct(_watchBattery);

        dc.setColor(COL_SILVER, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        if (bb != null && clampPct(bb) >= 2) {
            dc.drawArc(x, y, pr, Graphics.ARC_CLOCKWISE, 267, (267 - clampPct(bb) * 1.74).toNumber());
        }
        if (bat >= 2) {
            dc.drawArc(x, y, pr, Graphics.ARC_COUNTER_CLOCKWISE, 273, ((273 + bat * 1.74).toNumber()) % 360);
        }

        drawSmallHand(dc, x, y, sr - 8, 180 + (bb != null ? clampPct(bb) : 0) * 1.8);
        drawSmallHand(dc, x, y, sr - 8, 180 - bat * 1.8);
        dc.fillCircle(x, y, 3);
    }

    hidden function clampPct(v as Lang.Number) as Lang.Number {
        return (v < 0) ? 0 : ((v > 100) ? 100 : v);
    }

    hidden function drawBoltIcon(dc as Graphics.Dc, bx as Lang.Number, by as Lang.Number, s as Lang.Number) as Void {
        dc.setColor(COL_SILVER, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [bx + s/3, by - s],
            [bx - s/3, by    ],
            [bx + s/6, by    ],
            [bx - s/3, by + s],
            [bx + s/3, by    ],
            [bx - s/6, by    ]
        ]);
    }

    hidden function drawBatteryIcon(dc as Graphics.Dc, bx as Lang.Number, by as Lang.Number, s as Lang.Number) as Void {
        var bw2 = s * 2 / 5 + 1;
        var h2  = s * 7 / 10;
        var nw2 = s / 5;
        var nh  = s / 5 + 1;
        dc.setColor(COL_SILVER, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bx - nw2, by - h2 - nh, nw2 * 2 + 1, nh);
        dc.fillRectangle(bx - bw2, by - h2, bw2 * 2 + 1, h2 * 2 + 1);
    }

    hidden function drawSunTimes(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, sr as Lang.Number) as Void {
        // Sunrise left of the battery sub-dial, sunset right, each with a small up/down arrow above
        var font = Graphics.FONT_XTINY;
        var gap  = 6;
        var fh   = dc.getFontHeight(font);
        var a    = 3;
        var ay   = y - fh / 2 - 1;

        dc.setColor(COL_SILVER, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x - sr - gap, y, font, _riseStr,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(x + sr + gap, y, font, _setStr,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var lx = x - sr - gap - dc.getTextWidthInPixels(_riseStr, font) / 2;
        var rx = x + sr + gap + dc.getTextWidthInPixels(_setStr,  font) / 2;
        dc.fillPolygon([[lx, ay - a], [lx - a, ay + a - 1], [lx + a, ay + a - 1]]);
        dc.fillPolygon([[rx - a, ay - a], [rx + a, ay - a], [rx, ay + a - 1]]);
    }

    hidden function drawStepsSubdial(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, sr as Lang.Number, r as Lang.Number) as Void {
        // Small hand: one full turn = step goal (stops at the top once reached)
        drawSubdialBase(dc, x, y, sr);
        for (var i = 0; i < 10; i++) {
            var major = (i % 5 == 0);
            dc.setColor(major ? COL_SILVER : COL_DIM, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(major ? 2 : 1);
            radialLine(dc, x, y, sr - 6, sr - 2, i * 36);
        }

        var steps    = _steps;
        var stepGoal = _stepGoal;
        var frac     = 0.0;
        if (steps != null && stepGoal != null && stepGoal > 0) {
            frac = steps.toFloat() / stepGoal.toFloat();
            if (frac > 1.0) { frac = 1.0; }
        }
        drawSmallHand(dc, x, y, sr - 4, frac * 360.0);
        dc.fillCircle(x, y, 3);

        if (steps != null) {
            var label = (steps < 1000) ? steps.format("%d") : (steps / 1000.0).format("%.1f") + "k";
            dc.setColor(COL_DIM, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y + sr + (r * 0.02).toNumber(), Graphics.FONT_XTINY, label,
                Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    hidden function drawInsights(dc as Graphics.Dc, cx as Lang.Number, y as Lang.Number, r as Lang.Number) as Void {
        dc.setColor(COL_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - (r * 0.42).toNumber(), y, Graphics.FONT_XTINY, _tempStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(cx + (r * 0.42).toNumber(), y, Graphics.FONT_XTINY, _altStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    hidden function drawDateWindow(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number) as Void {
        var dayNames = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"] as Lang.Array<Lang.String>;
        var info     = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dateStr  = dayNames[info.day_of_week - 1] + " " + info.day.format("%d");

        var font  = Graphics.FONT_XTINY;
        var padX  = 4;
        var w     = dc.getTextWidthInPixels(dateStr, font) + padX * 2;
        var h     = dc.getFontHeight(font);
        var right = cx + (r * 0.82).toNumber();
        var left  = right - w;
        var top   = cy - h / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(left, top, w, h);
        dc.setColor(COL_SILVER, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRectangle(left, top, w, h);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left + w / 2, cy, font, dateStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Silver baton with a white insert on the outer part and a short tail past the pivot
    hidden function drawBaton(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, len as Lang.Number, tail as Lang.Number, width as Lang.Number, deg as Lang.Float) as Void {
        dc.setColor(COL_SILVER, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(width);
        radialLine(dc, cx, cy, -tail, len, deg);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(width - 2);
        radialLine(dc, cx, cy, len * 0.45, len - 3, deg);
    }

    hidden function drawHourHand(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number, hours as Lang.Number, minutes as Lang.Number) as Void {
        var deg = ((hours % 12) + minutes / 60.0) * 30.0;
        drawBaton(dc, cx, cy, (r * 0.48).toNumber(), (r * 0.08).toNumber(), 6, deg);
    }

    hidden function drawMinuteHand(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number, minutes as Lang.Number, seconds as Lang.Number) as Void {
        var deg = (minutes + seconds / 60.0) * 6.0;
        drawBaton(dc, cx, cy, (r * 0.72).toNumber(), (r * 0.08).toNumber(), 5, deg);
    }

    hidden function drawSecondHand(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number, seconds as Lang.Number) as Void {
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        radialLine(dc, cx, cy, -r * 0.20, r * 0.85, seconds * 6);
        dc.setColor(COL_SILVER, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 5);
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 2);
    }

    // [x, y, w, h] clip box covering the second hand (incl. pivot cap) at `seconds`
    hidden function secondHandBounds(cx as Lang.Number, cy as Lang.Number, r as Lang.Number, seconds as Lang.Number) as [Lang.Number, Lang.Number, Lang.Number, Lang.Number] {
        var tip  = polar(cx, cy, r * 0.85, seconds * 6);
        var tail = polar(cx, cy, -r * 0.20, seconds * 6);
        var pad  = 6;
        var x1 = ((tip[0] < tail[0]) ? tip[0] : tail[0]) - pad;
        var y1 = ((tip[1] < tail[1]) ? tip[1] : tail[1]) - pad;
        var x2 = ((tip[0] > tail[0]) ? tip[0] : tail[0]) + pad;
        var y2 = ((tip[1] > tail[1]) ? tip[1] : tail[1]) + pad;
        return [x1, y1, x2 - x1, y2 - y1];
    }
}
