# ChronoShift - Integration Testing Guide

**Version:** 1.0
**Last Updated:** 2025-11-19
**Purpose:** Instructions for running integration tests on refactored game

---

## 🎯 Quick Start

### Option 1: Automated Testing (Recommended for Developers)

**Not yet implemented** - Automated test script exists but needs to be attached to test scene.

### Option 2: Manual Testing (Recommended for QA)

1. Open Godot 4.x
2. Open project: `ChronoShift`
3. Open scene: `scenes/main_refactored.tscn`
4. Press **F6** to run the scene
5. Follow checklist in `MANUAL_TEST_CHECKLIST.md`

---

## 📋 Testing Options

### Manual Testing
- **File:** `MANUAL_TEST_CHECKLIST.md`
- **Duration:** ~20-30 minutes for full suite
- **Best For:** QA, comprehensive validation, user acceptance testing
- **Requires:** Human tester, Godot Editor

### Automated Testing (Future)
- **File:** `scripts/integration_test.gd`
- **Duration:** ~5-10 minutes for full suite
- **Best For:** CI/CD, regression testing, rapid iteration
- **Requires:** Godot command line or test runner scene

---

## 🧪 Manual Testing Procedure

### Step 1: Prepare Environment

```bash
# Ensure you're on the correct branch
git branch --show-current
# Should output: claude/final-integration-testing-01Q5Jj4RZMGAQH11gQHQ5MEu

# Pull latest changes
git pull origin claude/final-integration-testing-01Q5Jj4RZMGAQH11gQHQ5MEu

# Open Godot project
# (Use Godot 4.x)
```

### Step 2: Run Tests

1. **Open Godot Project Manager**
2. **Import or Select:** `ChronoShift` project
3. **Open Scene:** `scenes/main_refactored.tscn`
4. **Clear Console:** Right-click Output panel → Clear Output
5. **Run Scene:** Press **F6** (or click "Play Scene" button)

### Step 3: Execute Test Scenarios

Open `MANUAL_TEST_CHECKLIST.md` and follow each test:

- ✅ **Test 1:** Full Game Loop (~5 min)
- ✅ **Test 2:** Targeting Card System (~3 min)
- ✅ **Test 3:** Multiple Turns (~10 min)
- ✅ **Test 4:** Game Over Condition (~3 min)
- ✅ **Test 5:** Event Flow Verification (~5 min)

### Step 4: Document Results

Fill out the **Test Summary Report** at the bottom of `MANUAL_TEST_CHECKLIST.md`

### Step 5: Report Issues

If critical issues found:
1. Check `ROLLBACK_PLAN.md` for severity assessment
2. Create GitHub issue with:
   - Test scenario that failed
   - Expected vs actual behavior
   - Console output (errors/warnings)
   - Steps to reproduce
   - Screenshots/video if applicable

---

## 🤖 Automated Testing Procedure (Future Implementation)

### Setup (One-Time)

1. **Create Test Scene:**
   ```
   scenes/integration_test.tscn
   ```

2. **Attach Script:**
   - Root Node: `Node2D` or `Node`
   - Add Child: `GameController` (from `main_refactored.tscn`)
   - Attach Script: `scripts/integration_test.gd` to root node

3. **Configure:**
   ```gdscript
   # In integration_test.gd:
   # Ensure game_controller reference is correct
   ```

### Run Automated Tests

**Option A: Via Godot Editor**
```
1. Open scenes/integration_test.tscn
2. Press F6
3. Watch console output
4. Tests run automatically
5. Results printed to console
```

**Option B: Via Command Line**
```bash
# Run headless test
godot --headless --path /path/to/ChronoShift scenes/integration_test.tscn --quit-after 60

# Parse output for PASS/FAIL
grep "TEST RESULTS SUMMARY" output.log
```

**Option C: CI/CD Integration**
```yaml
# Example GitHub Actions workflow
name: Integration Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: abarichello/godot-ci@v3
        with:
          godot_version: 4.2
      - name: Run Integration Tests
        run: |
          godot --headless --path . scenes/integration_test.tscn --quit-after 60
      - name: Check Results
        run: |
          grep -q "FINAL SCORE: [5-5]/5" output.log || exit 1
```

---

## 📊 Interpreting Results

### Manual Test Results

**PASS Criteria:**
- ✅ All checklist items marked as complete
- ✅ No critical errors in console
- ✅ Game playable for 5+ minutes without crashes
- ✅ Core features work as expected

**FAIL Criteria:**
- ❌ Any critical feature broken (combat, carousel, cards)
- ❌ Game crashes or hangs
- ❌ Console shows null reference or critical errors
- ❌ Data corruption (HP/stats don't persist correctly)

### Automated Test Results

**Test Report Format:**
```
==================================================
  TEST RESULTS SUMMARY
==================================================

✅ Test 1: Full Game Loop
✅ Test 2: Targeting Card
✅ Test 3: Multiple Turns
❌ Test 4: Game Over
✅ Test 5: Event Flow

==================================================
  FINAL SCORE: 4/5 TESTS PASSED (80.0%)
==================================================
```

**Severity Levels:**

| Score | Status | Action |
|-------|--------|--------|
| 5/5 (100%) | ✅ Perfect | Approve for merge |
| 4/5 (80%) | ⚠️ Good | Review failed test, fix if critical |
| 3/5 (60%) | ⚠️ Acceptable | Fix issues before merge |
| 2/5 (40%) | ❌ Poor | Significant rework needed |
| 0-1/5 (0-20%) | ❌ Critical | Consider rollback |

---

## 🐛 Common Test Failures

### Test 1 Failure: Full Game Loop

**Symptoms:**
- Turn doesn't complete
- Carousel doesn't slide
- Cards don't recycle

**Debug Steps:**
1. Check console for errors during `_execute_complete_turn()`
2. Verify `timeline_panels.size() == 6`
3. Check `GameState.current_turn` increments
4. Verify `card_manager` is initialized

**Possible Fixes:**
- Ensure all systems initialized in `_ready()`
- Check tween animations complete
- Verify scene structure matches expected

---

### Test 2 Failure: Targeting Card

**Symptoms:**
- Targeting mode doesn't activate
- Clicking enemy does nothing
- Card doesn't execute

**Debug Steps:**
1. Check `targeting_system` is initialized
2. Verify `Events.card_targeting_started` fires
3. Check entity `mouse_filter` is set to STOP
4. Verify `GameState.time_remaining >= card_cost`

**Possible Fixes:**
- Ensure `TargetingSystem.initialize()` called
- Check entity `Sprite` node has `mouse_filter = STOP`
- Verify card cost <= available time

---

### Test 3 Failure: Multiple Turns

**Symptoms:**
- Turns don't increment
- Timelines don't update
- Cards don't recycle

**Debug Steps:**
1. Check `GameState.current_turn` after each turn
2. Verify `_recalculate_future_timelines()` called
3. Check `card_manager.recycle_cards()` or equivalent
4. Monitor memory for leaks (entity duplication)

**Possible Fixes:**
- Ensure `GameState.increment_turn()` called
- Verify carousel properly rotates `timeline_panels` array
- Check `clear_entities()` called before creating new ones

---

### Test 4 Failure: Game Over

**Symptoms:**
- Game doesn't detect player death
- PLAY button still enabled
- Can still interact after game over

**Debug Steps:**
1. Check `GameState.game_over` value after player HP = 0
2. Verify `Events.game_over` fires
3. Check `_on_game_over()` callback connected

**Possible Fixes:**
- Ensure game over check in `_execute_complete_turn()`
- Verify `GameState.set_game_over()` called
- Check UI updates on game over event

---

### Test 5 Failure: Event Flow

**Symptoms:**
- Events fire in wrong order
- Expected events never fire
- Extra/duplicate events

**Debug Steps:**
1. Review `event_log` array in automated test
2. Check manual console output for event sequence
3. Verify event connections in `_connect_events()`

**Possible Fixes:**
- Ensure events emit at correct points in code
- Check `await` statements don't block event flow
- Verify event handlers don't have errors

---

## 📈 Performance Testing

### Metrics to Monitor

During testing, watch for:

1. **Frame Rate:**
   - Target: 60 FPS stable
   - Acceptable: 30-60 FPS
   - Poor: < 30 FPS or frequent drops

2. **Memory Usage:**
   - Initial: ~100-200 MB
   - After 10 turns: < 300 MB
   - Memory leak if > 500 MB or continuously growing

3. **Turn Execution Time:**
   - Target: 2-4 seconds per turn
   - Acceptable: 4-6 seconds
   - Poor: > 6 seconds

### How to Monitor

**In Godot Editor:**
1. Open Debugger panel (bottom of editor)
2. Click "Monitors" tab
3. Watch during gameplay:
   - FPS
   - Memory (Static/Dynamic)
   - Objects (nodes in scene tree)

**Console Commands:**
```gdscript
# Add to game_controller.gd for profiling:

func _process(delta):
    if Input.is_action_just_pressed("ui_page_down"):
        print("=== PERFORMANCE METRICS ===")
        print("FPS: ", Engine.get_frames_per_second())
        print("Memory: ", OS.get_static_memory_usage() / 1024.0 / 1024.0, " MB")
        print("Nodes: ", get_tree().get_node_count())
        print("Turn: ", GameState.current_turn)
```

---

## 🔄 Regression Testing

### When to Run Tests

- ✅ Before every merge to main branch
- ✅ After any refactoring
- ✅ After fixing a critical bug
- ✅ Before releasing a new version
- ✅ When adding new features that interact with core systems

### Regression Test Suite

**Baseline:** Establish baseline metrics on first successful test run

**Subsequent Runs:** Compare to baseline

```
Baseline (Turn 1):
  - Player HP: 100
  - Enemy A HP: 45
  - Enemy B HP: 30
  - Turn Execution: 3.2s
  - FPS: 60

Test Run (Turn 1):
  - Player HP: 100 ✅
  - Enemy A HP: 45 ✅
  - Enemy B HP: 30 ✅
  - Turn Execution: 3.5s ✅ (within acceptable range)
  - FPS: 58 ✅ (within acceptable range)
```

---

## 📝 Test Logging

### Enable Debug Logging

```gdscript
# In game_controller.gd, _ready():
func _ready():
    GameState.debug_mode = true  # Enable verbose logging
    GameState.log_events = true  # Log all events
```

### Log Files

**Godot Console Output:**
- Copy from Output panel
- Save as `test_log_<date>.txt`

**Example Log:**
```
[2025-11-19 14:32:10] Game initialized
[2025-11-19 14:32:12] Test 1: Full Game Loop - STARTED
[2025-11-19 14:32:15] Card played: Meal Time
[2025-11-19 14:32:16] Player HP: 100 → 115
[2025-11-19 14:32:18] Turn executed
[2025-11-19 14:32:22] Test 1: Full Game Loop - PASSED
```

---

## 🎓 Best Practices

### For Testers

1. **Fresh Start:** Always test from a clean game launch
2. **Document Everything:** Note even minor visual glitches
3. **Reproduce:** If issue found, try to reproduce 2-3 times
4. **Console Output:** Always save console output for failed tests
5. **Screenshots:** Capture screenshots of any visual issues

### For Developers

1. **Test Locally:** Run manual tests before pushing
2. **Automated Tests:** Use automated tests for quick checks
3. **Fix Fast:** Fix critical issues immediately (< 4 hours)
4. **Commit Often:** Small commits easier to revert if needed
5. **Document Changes:** Update test docs when adding features

---

## 🚨 Critical Path Testing

**Minimum tests to run before any release:**

1. ✅ Game launches without errors
2. ✅ One full turn completes successfully
3. ✅ One instant card works
4. ✅ One targeting card works
5. ✅ Game over triggers correctly

**Time:** ~10 minutes

If any of these fail, **DO NOT RELEASE**.

---

## 📞 Support & Questions

### Troubleshooting

1. Check `MANUAL_TEST_CHECKLIST.md` → Common Issues section
2. Check Godot console for error messages
3. Review `ROLLBACK_PLAN.md` if considering rollback
4. Search GitHub issues for similar problems

### Reporting Issues

**GitHub Issue Template:**
```markdown
## Test Failure Report

**Test:** Test 1 - Full Game Loop
**Status:** FAILED
**Branch:** claude/final-integration-testing-01Q5Jj4RZMGAQH11gQHQ5MEu
**Godot Version:** 4.2.x

### Expected Behavior
Carousel should slide after combat completes

### Actual Behavior
Carousel does not slide, turn hangs

### Steps to Reproduce
1. Launch scenes/main_refactored.tscn
2. Click PLAY button
3. Combat completes
4. Carousel does not slide

### Console Output
```
[Paste console errors here]
```

### Screenshots
[Attach if applicable]

### Severity
- [ ] Critical (blocks all testing)
- [x] High (blocks this test)
- [ ] Medium (workaround exists)
- [ ] Low (cosmetic issue)
```

---

## 📅 Test Schedule

### Development Phase
- Run automated tests after each feature commit
- Run manual tests daily

### Pre-Release Phase
- Run full manual test suite
- Run automated tests in CI/CD
- Performance testing
- Regression testing vs previous version

### Post-Release
- Smoke tests (critical path only)
- Monitor for user-reported issues

---

**Happy Testing! 🧪**

If you find any issues with this testing guide itself, please update it and commit the changes.

**Last Updated:** 2025-11-19
**Maintained By:** Development Team
