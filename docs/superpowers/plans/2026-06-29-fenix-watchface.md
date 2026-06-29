# Fenix 8 Watchface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Garmin Fenix 8 watchface in Monkey C showing a full analog clock with a small digital time + date bar at the bottom of the face.

**Architecture:** Single-file view (`WatchFaceView.mc`) draws everything programmatically in `onUpdate(dc)`. Five `hidden` helper methods handle tick marks, each hand, center dot, and digital bar. No XML layouts.

**Tech Stack:** Monkey C, Connect IQ SDK 7.x, target device `fenix8` (416×416 AMOLED round display).

---

## File Map

| File | Role |
|------|------|
| `manifest.xml` | App metadata, target device, min SDK |
| `monkey.jungle` | Build config, source/resource paths |
| `resources/strings/strings.xml` | App name string |
| `source/WatchFaceApp.mc` | App entry point, returns initial view |
| `source/WatchFaceView.mc` | All drawing logic |
| `developer_key.der` | Local signing key (not committed) |
| `.gitignore` | Excludes key, build output |

---

## Task 1: Development Environment Setup

**Files:** system-level only (no project files)

- [ ] **Step 1: Install VS Code Monkey C extension**

  Open VS Code → Extensions (⇧⌘X) → search `garmin.monkey-c` → Install.

- [ ] **Step 2: Download Connect IQ SDK via extension**

  VS Code Command Palette (⇧⌘P) → `Monkey C: Select SDK` → download latest (7.x).

- [ ] **Step 3: Add SDK bin to PATH**

```bash
ls ~/Library/Application\ Support/Garmin/ConnectIQ/Sdks/
```

Copy the latest version directory name (e.g. `connectiq-sdk-mac-7.4.3-2024-10-17`), then add to `~/.zshrc`:

```bash
export CIQ_SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-7.4.3-2024-10-17"
export PATH="$CIQ_SDK/bin:$PATH"
```

Replace the version string with what `ls` showed.

- [ ] **Step 4: Reload shell and verify**

```bash
source ~/.zshrc
monkeyc --version
```

Expected output (version numbers will vary):
```
monkeyc version 7.4.3.202...
```

- [ ] **Step 5: Generate developer signing key** (one-time; never commit this file)

```bash
cd /Users/edoardo.davini/edoardodavini/garmin-fenix
openssl req -x509 -newkey rsa:4096 \
  -keyout developer_key.pem \
  -out developer_key.crt \
  -days 3650 -nodes \
  -subj "/CN=developer"
openssl pkcs8 -topk8 -inform PEM -outform DER \
  -in developer_key.pem \
  -out developer_key.der \
  -nocrypt
rm developer_key.pem developer_key.crt
```

Expected: `developer_key.der` exists (binary file, ~2.4 KB).

---

## Task 2: Project Scaffold

**Files:**
- Create: `manifest.xml`
- Create: `monkey.jungle`
- Create: `resources/strings/strings.xml`
- Create: `source/WatchFaceApp.mc`
- Create: `source/WatchFaceView.mc` (black-screen placeholder)
- Create: `.gitignore`

- [ ] **Step 1: Generate a UUID for the app ID**

```bash
uuidgen | tr '[:upper:]' '[:lower:]'
```

Copy the output (e.g. `a3f7c2d1-8b4e-4f9a-b6c3-7d2e1f0a9b8c`). You will paste it into `manifest.xml` next.

- [ ] **Step 2: Create `manifest.xml`** (replace `YOUR-UUID-HERE` with the UUID from Step 1)

```xml
<iq:manifest xmlns:iq="http://www.garmin.com/xml/connectiq" version="3">
    <iq:application
        entry="WatchFaceApp"
        id="YOUR-UUID-HERE"
        minSdkVersion="4.2.0"
        name="@Strings.AppName"
        type="watchFace"
        version="1.0.0">
        <iq:products>
            <iq:product id="fenix8"/>
        </iq:products>
        <iq:permissions/>
        <iq:languages/>
    </iq:application>
</iq:manifest>
```

- [ ] **Step 3: Create `monkey.jungle`**

```
project.manifest = manifest.xml

base.sourcePath = source
base.resourcePath = resources
```

- [ ] **Step 4: Create `resources/strings/strings.xml`**

```bash
mkdir -p resources/strings
```

```xml
<strings>
    <string id="AppName">Fenix Watchface</string>
</strings>
```

- [ ] **Step 5: Create `source/WatchFaceApp.mc`**

```bash
mkdir -p source bin
```

```monkey-c
import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class WatchFaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Lang.Dictionary?) as Void {
    }

    function onStop(state as Lang.Dictionary?) as Void {
    }

    function getInitialView() as Lang.Array<WatchUi.Views>? {
        return [new WatchFaceView()] as Lang.Array<WatchUi.Views>;
    }
}

function getApp() as WatchFaceApp {
    return Application.getApp() as WatchFaceApp;
}
```

- [ ] **Step 6: Create `source/WatchFaceView.mc`** (black screen placeholder — just enough to compile)

```monkey-c
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
```

- [ ] **Step 7: Create `.gitignore`**

```
developer_key.der
bin/
.superpowers/
```

- [ ] **Step 8: Compile**

```bash
monkeyc -f monkey.jungle -o bin/watchface.prg -d fenix8 -y developer_key.der
```

Expected: exits with code 0, `bin/watchface.prg` created, no errors printed.

If you see `error: cannot find symbol 'WatchFaceView'` — the file wasn't saved. If you see `error: cannot open file 'monkey.jungle'` — run the command from the repo root.

- [ ] **Step 9: Load in simulator**

```bash
connectiq &
sleep 3
monkeydo bin/watchface.prg fenix8
```

Expected: simulator opens showing an all-black round watchface.

- [ ] **Step 10: Commit**

```bash
git add manifest.xml monkey.jungle resources/ source/ .gitignore
git commit -m "feat: scaffold Fenix 8 watchface project"
```

---

## Task 3: Analog Face — Tick Marks

**Files:**
- Modify: `source/WatchFaceView.mc`

- [ ] **Step 1: Replace `source/WatchFaceView.mc`** with the version below, which adds `drawTicks`

```monkey-c
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
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
}
```

- [ ] **Step 2: Compile**

```bash
monkeyc -f monkey.jungle -o bin/watchface.prg -d fenix8 -y developer_key.der
```

Expected: exit code 0, no errors.

- [ ] **Step 3: Load in simulator**

```bash
monkeydo bin/watchface.prg fenix8
```

Expected: 12 grey tick marks on black background — 4 longer ones at 12/3/6/9, 8 shorter ones between them.

- [ ] **Step 4: Commit**

```bash
git add source/WatchFaceView.mc
git commit -m "feat: draw analog tick marks"
```

---

## Task 4: Analog Face — Clock Hands + Center Dot

**Files:**
- Modify: `source/WatchFaceView.mc`

- [ ] **Step 1: Replace `source/WatchFaceView.mc`** with the full version below

```monkey-c
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
```

- [ ] **Step 2: Compile**

```bash
monkeyc -f monkey.jungle -o bin/watchface.prg -d fenix8 -y developer_key.der
```

Expected: exit code 0, no errors.

- [ ] **Step 3: Load in simulator**

```bash
monkeydo bin/watchface.prg fenix8
```

Expected: analog clock showing current time. White hour hand (short, thick), white minute hand (medium), red second hand (thin, with counterbalance tail), white center dot. Hands update each second.

- [ ] **Step 4: Verify hand positions**

Check that the hands point in plausible directions for the current time shown in the simulator's title bar or status. The hour hand should be between two hour markers, the minute hand near the correct minute mark.

- [ ] **Step 5: Commit**

```bash
git add source/WatchFaceView.mc
git commit -m "feat: draw analog clock hands and center dot"
```

---

## Task 5: Digital Bar

**Files:**
- Modify: `source/WatchFaceView.mc`

- [ ] **Step 1: Replace `source/WatchFaceView.mc`** with the final version below

```monkey-c
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
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

        drawDigitalBar(dc, cx, cy, r, t.hour, t.min);
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

    hidden function drawDigitalBar(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, r as Lang.Number, hours as Lang.Number, minutes as Lang.Number) as Void {
        var barW = (r * 0.90).toNumber();
        var barH = (r * 0.22).toNumber();
        var barX = cx - barW / 2;
        var barY = (cy + r * 0.55).toNumber();

        // Background fill + border
        dc.setColor(0x1A1A1A, 0x1A1A1A);
        dc.fillRoundedRectangle(barX, barY, barW, barH, 6);
        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRoundedRectangle(barX, barY, barW, barH, 6);

        // HH:MM — centered, white
        var timeStr = hours.format("%02d") + ":" + minutes.format("%02d");
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, barY + (barH * 0.08).toNumber(),
            Graphics.FONT_SMALL, timeStr, Graphics.TEXT_JUSTIFY_CENTER);

        // EEE DD — centered, grey, smaller
        var dayNames = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"] as Lang.Array<Lang.String>;
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var dateStr = dayNames[info.day_of_week - 1] + " " + info.day.format("%d");
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, barY + (barH * 0.58).toNumber(),
            Graphics.FONT_XTINY, dateStr, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
```

- [ ] **Step 2: Compile**

```bash
monkeyc -f monkey.jungle -o bin/watchface.prg -d fenix8 -y developer_key.der
```

Expected: exit code 0, no errors.

- [ ] **Step 3: Load in simulator**

```bash
monkeydo bin/watchface.prg fenix8
```

Expected: full analog face with working hands, plus a dark rounded rect in the lower third of the face showing `HH:MM` in white and `EEE DD` (e.g. `SUN 29`) in grey below it.

- [ ] **Step 4: Verify digital bar content**

Check the time shown in the digital bar matches the simulator clock. Check that the day abbreviation and date are correct for today.

- [ ] **Step 5: Commit**

```bash
git add source/WatchFaceView.mc
git commit -m "feat: add digital time and date bar"
```

---

## Task 6: Finish Up

**Files:**
- No code changes — just housekeeping

- [ ] **Step 1: Verify .gitignore is correct**

```bash
git status
```

Expected: only tracked files shown. `bin/` and `developer_key.der` should NOT appear.

- [ ] **Step 2: Final compile + simulator check**

```bash
monkeyc -f monkey.jungle -o bin/watchface.prg -d fenix8 -y developer_key.der
monkeydo bin/watchface.prg fenix8
```

Verify visually:
- Black background ✓
- 12 tick marks (4 long, 8 short) ✓
- White hour hand (thick, short) ✓
- White minute hand (medium) ✓
- Red second hand (thin, with tail) ✓
- White center dot ✓
- Dark bar at bottom with correct `HH:MM` ✓
- Correct `EEE DD` date below time ✓

- [ ] **Step 3: Save memory**

```bash
cat /Users/edoardo.davini/.claude/projects/-Users-edoardo-davini-edoardodavini-garmin-fenix/memory/MEMORY.md 2>/dev/null || echo "no memory yet"
```

- [ ] **Step 4: Final commit**

```bash
git add -A
git status   # confirm nothing unexpected is staged
git commit -m "chore: finalize watchface v1.0.0"
```

---

## Troubleshooting

| Error | Fix |
|-------|-----|
| `monkeyc: command not found` | Add SDK bin to PATH (Task 1 Step 3) |
| `error: cannot find product 'fenix8'` | Check SDK includes Fenix 8 device; re-run `monkeyc --version` to confirm SDK version |
| `error: cannot open input file 'developer_key.der'` | Re-run key generation (Task 1 Step 5) |
| `error: symbol 'Gregorian' not found` | Confirm `import Toybox.Time.Gregorian;` is present |
| Simulator shows blank / white screen | Check `dc.clear()` is called before any drawing |
| Hands not moving | Simulator may need to be running in "normal" mode not paused |
