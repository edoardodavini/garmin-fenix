# Garmin Fenix 8 Watchface — Design Spec

**Date:** 2026-06-29

## Summary

A Garmin Fenix 8 watchface written in Monkey C (Connect IQ SDK) that displays a full-screen analog clock with a small digital time + date bar at the bottom of the face.

---

## Visual Design

**Layout:** Full-circle analog face filling the 416×416 round display. A small rounded-rectangle bar sits at approximately 75% from center (lower third of face), overlaid on the analog face, showing digital time and date.

**Color palette:**
- Background: `0x000000` (black)
- Hour hand: `0xFFFFFF` (white), thick
- Minute hand: `0xFFFFFF` (white), medium
- Second hand: `0xFF0000` (red), thin
- Hour tick marks: `0x888888` (grey)
- Digital bar background: `0x1A1A1A` with `0x333333` border
- Digital time text: `0xFFFFFF` (white)
- Digital date text: `0x888888` (grey)
- Center hub dot: `0xFFFFFF` (white)

**Analog face elements:**
- 12 tick marks at hour positions (longer at 12/3/6/9, shorter at others)
- Hour hand: length ~40% of radius, width 4px
- Minute hand: length ~60% of radius, width 2.5px
- Second hand: length ~65% of radius, width 1.5px, with short counterbalance tail
- Center dot: radius 4px

**Digital bar:**
- Position: centered horizontally, top edge at ~75% of radius from center
- Size: ~50% of diameter wide, ~15% of radius tall
- Content: `HH:MM` centered, with `EEE DD` (e.g., `SUN 29`) in smaller grey text below it
- Font: system monospace/numeric font

---

## Technical Stack

| Item | Choice |
|------|--------|
| Language | Monkey C |
| SDK | Connect IQ 7.x |
| Target device | `fenix8` |
| Display | Round, 416×416 px |
| Entry point | `WatchFace.WatchFaceApp` |

---

## File Structure

```
garmin-fenix/
├── manifest.xml          # app ID, permissions, min SDK version
├── monkey.jungle         # build config, device targets
├── resources/
│   ├── strings/
│   │   └── strings.xml   # app name string
│   └── layouts/          # empty — drawing is fully programmatic
└── source/
    ├── WatchFaceApp.mc   # app entry point, extends WatchFace.WatchFaceApp
    └── WatchFaceView.mc  # all drawing logic, extends WatchFace.WatchFaceView
```

---

## Implementation

### `WatchFaceApp.mc`

Minimal app class. Returns a new `WatchFaceView` from `getInitialView()`.

### `WatchFaceView.mc`

Implements `WatchFace.WatchFaceView`. All drawing happens in `onUpdate(dc)`.

**`onUpdate(dc)` sequence:**

1. Clear screen to black.
2. Compute center point (`cx = dc.getWidth() / 2`, `cy = dc.getHeight() / 2`), radius (`r = cx`).
3. Draw 12 tick marks — iterate `i` 0..11, compute angle `i * 30°`, draw line from `r * 0.88` to `r * 0.96` (minor) or `r * 0.82` to `r * 0.96` (major at 12/3/6/9).
4. Get current time via `Toybox.System.getClockTime()` → `hours`, `minutes`, `seconds`.
5. Compute hand angles (0° = 12 o'clock, clockwise):
   - Hour: `(hours % 12 + minutes / 60.0) * 30°`
   - Minute: `(minutes + seconds / 60.0) * 6°`
   - Second: `seconds * 6°`
6. Draw hands using `Math.sin` / `Math.cos`, converting degrees to radians.
7. Draw center dot.
8. Draw digital bar rect at `(cx - barW/2, cy + r*0.55)`.
9. Draw time string `HH:MM` centered in upper portion of bar, then `EEE DD` (e.g., `SUN 29`) in smaller grey text centered below it, using `dc.drawText`.

**`onExitSleep` / `onEnterSleep`:** No-op for initial version — full-power mode only.

---

## Out of Scope (v1)

- Complications (heart rate, battery, steps)
- AOD (always-on display) mode
- Settings / color customization via GCM
- Fonts other than system built-ins
- Anti-aliasing on hands

---

## Success Criteria

- Watchface installs on Fenix 8 simulator without errors
- Analog hands show correct time and update each second
- Digital bar shows correct `HH:MM` and `EEE DD`
- All elements visible against black background
