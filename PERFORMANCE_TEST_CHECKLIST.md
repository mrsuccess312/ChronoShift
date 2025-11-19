# Performance Testing Checklist

**Purpose:** Compare performance between old (main.tscn) and refactored (main_refactored.tscn) architectures

**Tester:** ______________________
**Date:** ______________________
**Godot Version:** ______________________

---

## 🎯 Test Setup

### Prerequisites
- [ ] Godot 4.x is running
- [ ] ChronoShift project loaded
- [ ] No other heavy applications running (for accurate FPS measurement)
- [ ] Project Settings configured:
  - Go to: Project → Project Settings → Debug → Settings
  - Enable: "Print FPS" or install FPS counter addon

### Alternative FPS Counter Setup
If "Print FPS" not available, add this to both scenes:

1. Add Label node to UI
2. Attach this script:
```gdscript
extends Label

func _process(_delta):
    text = "FPS: %d" % Engine.get_frames_per_second()
```

---

## 📊 TEST 1: OLD ARCHITECTURE (main.tscn)

### Load Time Test

1. **Preparation:**
   - [ ] Close Godot completely
   - [ ] Reopen Godot
   - [ ] Open `scenes/main.tscn`
   - [ ] Clear Output panel (Right-click → Clear Output)

2. **Execute:**
   - [ ] Note current time: **______:______:______** (HH:MM:SS)
   - [ ] Press F6 to run scene
   - [ ] Watch Output panel for "GameManager ready!" message
   - [ ] Note time when message appears: **______:______:______**

3. **Calculate:**
   - Load time = (End time - Start time)
   - **OLD Load Time: ________ seconds**

### FPS Test - Idle

4. **Idle FPS:**
   - [ ] Game is running, but no actions taken
   - [ ] Let game sit for 10 seconds
   - [ ] Observe FPS counter
   - **OLD Idle FPS: ________ fps** (average)
   - **OLD Idle FPS (min): ________ fps** (lowest observed)

### FPS Test - Combat

5. **Combat FPS:**
   - [ ] Click PLAY button to execute turn
   - [ ] Watch FPS during combat animations
   - [ ] Note FPS during carousel slide
   - **OLD Combat FPS (during attacks): ________ fps**
   - **OLD Combat FPS (during carousel): ________ fps**
   - **OLD Combat FPS (min during turn): ________ fps**

### Memory Usage (Optional)

6. **Memory Tracking:**
   - [ ] Open Debugger panel (bottom of Godot)
   - [ ] Click "Monitors" tab
   - [ ] Watch "Memory/Static" value
   - **OLD Initial Memory: ________ MB**
   - **OLD After 1 turn: ________ MB**
   - **OLD After 5 turns: ________ MB**

### Turn Execution Time

7. **Turn Duration:**
   - [ ] Start timer when clicking PLAY button
   - [ ] Stop timer when PLAY button re-enables
   - **OLD Turn Duration (Turn 1): ________ seconds**
   - **OLD Turn Duration (Turn 2): ________ seconds**
   - **OLD Turn Duration (Turn 3): ________ seconds**
   - **OLD Average Turn Duration: ________ seconds**

### Notes on OLD Architecture
```
Observations (lag, stutters, visual issues):




Console errors/warnings:



```

---

## 📊 TEST 2: REFACTORED ARCHITECTURE (main_refactored.tscn)

### Load Time Test

1. **Preparation:**
   - [ ] Close current game window (keep Godot open)
   - [ ] Open `scenes/main_refactored.tscn`
   - [ ] Clear Output panel (Right-click → Clear Output)

2. **Execute:**
   - [ ] Note current time: **______:______:______** (HH:MM:SS)
   - [ ] Press F6 to run scene
   - [ ] Watch Output panel for "GameController ready!" message
   - [ ] Note time when message appears: **______:______:______**

3. **Calculate:**
   - Load time = (End time - Start time)
   - **NEW Load Time: ________ seconds**

### FPS Test - Idle

4. **Idle FPS:**
   - [ ] Game is running, but no actions taken
   - [ ] Let game sit for 10 seconds
   - [ ] Observe FPS counter
   - **NEW Idle FPS: ________ fps** (average)
   - **NEW Idle FPS (min): ________ fps** (lowest observed)

### FPS Test - Combat

5. **Combat FPS:**
   - [ ] Click PLAY button to execute turn
   - [ ] Watch FPS during combat animations
   - [ ] Note FPS during carousel slide
   - **NEW Combat FPS (during attacks): ________ fps**
   - **NEW Combat FPS (during carousel): ________ fps**
   - **NEW Combat FPS (min during turn): ________ fps**

### Memory Usage (Optional)

6. **Memory Tracking:**
   - [ ] Open Debugger panel (bottom of Godot)
   - [ ] Click "Monitors" tab
   - [ ] Watch "Memory/Static" value
   - **NEW Initial Memory: ________ MB**
   - **NEW After 1 turn: ________ MB**
   - **NEW After 5 turns: ________ MB**

### Turn Execution Time

7. **Turn Duration:**
   - [ ] Start timer when clicking PLAY button
   - [ ] Stop timer when PLAY button re-enables
   - **NEW Turn Duration (Turn 1): ________ seconds**
   - **NEW Turn Duration (Turn 2): ________ seconds**
   - **NEW Turn Duration (Turn 3): ________ seconds**
   - **NEW Average Turn Duration: ________ seconds**

### Notes on REFACTORED Architecture
```
Observations (lag, stutters, visual issues):




Console errors/warnings:



```

---

## 📈 PERFORMANCE COMPARISON

### Load Time Comparison

| Metric | OLD (main.tscn) | NEW (main_refactored.tscn) | Difference | Status |
|--------|-----------------|----------------------------|------------|--------|
| Load Time | _______ sec | _______ sec | _______ sec | [ ] ✅ [ ] ⚠️ [ ] ❌ |

**Criteria:**
- ✅ NEW is faster or within 0.5s of OLD
- ⚠️ NEW is 0.5-1.0s slower than OLD (acceptable)
- ❌ NEW is > 1.0s slower than OLD (investigate)

### FPS Comparison

| Metric | OLD | NEW | Difference | Status |
|--------|-----|-----|------------|--------|
| Idle FPS (avg) | _______ | _______ | _______ | [ ] ✅ [ ] ⚠️ [ ] ❌ |
| Idle FPS (min) | _______ | _______ | _______ | [ ] ✅ [ ] ⚠️ [ ] ❌ |
| Combat FPS (attacks) | _______ | _______ | _______ | [ ] ✅ [ ] ⚠️ [ ] ❌ |
| Combat FPS (carousel) | _______ | _______ | _______ | [ ] ✅ [ ] ⚠️ [ ] ❌ |
| Combat FPS (min) | _______ | _______ | _______ | [ ] ✅ [ ] ⚠️ [ ] ❌ |

**Criteria:**
- ✅ NEW FPS >= OLD FPS (equal or better)
- ⚠️ NEW FPS is 5-10 fps lower than OLD (acceptable if still > 30)
- ❌ NEW FPS is > 10 fps lower than OLD or drops below 30 fps

### Memory Comparison

| Metric | OLD | NEW | Difference | Status |
|--------|-----|-----|------------|--------|
| Initial Memory | _____ MB | _____ MB | _____ MB | [ ] ✅ [ ] ⚠️ [ ] ❌ |
| After 1 turn | _____ MB | _____ MB | _____ MB | [ ] ✅ [ ] ⚠️ [ ] ❌ |
| After 5 turns | _____ MB | _____ MB | _____ MB | [ ] ✅ [ ] ⚠️ [ ] ❌ |
| Memory Growth | _____ MB | _____ MB | _____ MB | [ ] ✅ [ ] ⚠️ [ ] ❌ |

**Criteria:**
- ✅ NEW memory <= OLD memory (no regression)
- ⚠️ NEW memory is 10-50 MB higher (investigate but acceptable)
- ❌ NEW memory is > 50 MB higher or grows continuously (memory leak)

### Turn Execution Time Comparison

| Metric | OLD | NEW | Difference | Status |
|--------|-----|-----|------------|--------|
| Turn 1 Duration | _____ sec | _____ sec | _____ sec | [ ] ✅ [ ] ⚠️ [ ] ❌ |
| Turn 2 Duration | _____ sec | _____ sec | _____ sec | [ ] ✅ [ ] ⚠️ [ ] ❌ |
| Turn 3 Duration | _____ sec | _____ sec | _____ sec | [ ] ✅ [ ] ⚠️ [ ] ❌ |
| Average Duration | _____ sec | _____ sec | _____ sec | [ ] ✅ [ ] ⚠️ [ ] ❌ |

**Criteria:**
- ✅ NEW duration <= OLD duration (faster or equal)
- ⚠️ NEW duration is 0.5-1.0s slower (acceptable)
- ❌ NEW duration is > 1.0s slower (investigate)

---

## 🎯 OVERALL PERFORMANCE ASSESSMENT

### Summary

**Total Metrics Tested:** 13

**Results:**
- ✅ **Pass:** _______ metrics (better or equal performance)
- ⚠️ **Acceptable:** _______ metrics (minor regression, still acceptable)
- ❌ **Fail:** _______ metrics (significant regression, needs investigation)

### Pass/Fail Criteria

- **PASS:** ≥ 10/13 metrics are ✅ or ⚠️, no ❌ metrics
- **CONDITIONAL PASS:** 8-9/13 metrics are ✅ or ⚠️, 1-2 ❌ metrics (minor)
- **FAIL:** < 8/13 metrics passing, or any ❌ metric is critical (e.g., < 30 FPS, memory leak)

### Overall Status: [ ] PASS [ ] CONDITIONAL PASS [ ] FAIL

---

## 💡 Performance Notes

### What to Look For

**Good Signs:**
- ✅ NEW load time within 0.5s of OLD
- ✅ NEW FPS is 60 and stable
- ✅ No frame drops during combat
- ✅ Memory usage stable across multiple turns
- ✅ Turn execution feels smooth and responsive

**Warning Signs:**
- ⚠️ FPS occasionally dips to 45-55 (acceptable, but monitor)
- ⚠️ Load time slightly slower (< 1s difference)
- ⚠️ Memory usage slightly higher but stable

**Red Flags:**
- ❌ FPS drops below 30 during combat
- ❌ Visible stuttering or lag
- ❌ Memory grows continuously (memory leak)
- ❌ Load time > 5 seconds
- ❌ Turn execution > 8 seconds

### Common Performance Issues

**If NEW is significantly slower:**

1. **Check Debug Mode:**
   - Ensure both scenes tested in same mode (Debug vs Release)
   - Try: Project → Export → Export Project (Release build)

2. **Check Script Errors:**
   - Review console for errors/warnings
   - Errors can cause performance degradation

3. **Check System Count:**
   - More systems = more overhead
   - But should be negligible with only 3 systems (Combat, Card, Targeting)

4. **Check Event Emissions:**
   - Excessive event emissions can slow down game
   - Use `print()` to count event fires per frame

**If Memory Leak Detected:**

1. **Check Entity Cleanup:**
   - Verify `clear_entities()` called before creating new ones
   - Check `queue_free()` called on old entities

2. **Check Arrow Cleanup:**
   - Verify `clear_arrows()` called before creating new ones

3. **Check Tween Cleanup:**
   - Ensure tweens are properly finished and cleaned up

---

## 📝 Test Execution Log

**Test Start Time:** ______________________
**Test End Time:** ______________________
**Total Test Duration:** ______________________

**Environment:**
- OS: ______________________
- CPU: ______________________
- RAM: ______________________
- GPU: ______________________
- Godot Version: ______________________

**Tester Notes:**
```




```

---

## ✅ Sign-Off

**Tester Signature:** ______________________
**Date:** ______________________

**Performance Assessment:** [ ] APPROVED [ ] APPROVED WITH NOTES [ ] REJECTED

**Recommendation:**
- [ ] ✅ Proceed with cutover - performance is acceptable
- [ ] ⚠️ Proceed with caution - minor performance issues noted
- [ ] ❌ Do NOT proceed - significant performance regression

**Next Steps:**
```



```

---

**Save this completed checklist as:** `PERFORMANCE_TEST_RESULTS.md`
