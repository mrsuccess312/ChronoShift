# Cutover Verification Checklist

**Purpose:** Quick reference checklist for cutover verification
**Use:** After completing CUTOVER_INSTRUCTIONS.md

---

## ✅ PRE-CUTOVER VERIFICATION

**Before starting cutover, verify:**

- [ ] **Manual tests completed**
  - File: `MANUAL_TEST_CHECKLIST.md`
  - Result: [ ] All passed [ ] Some failed (acceptable)

- [ ] **Performance tests completed** (or skipped)
  - File: `PERFORMANCE_TEST_CHECKLIST.md`
  - Result: [ ] Completed [ ] Skipped

- [ ] **No critical blockers**
  - Check: `KNOWN_ISSUES.md`
  - Critical issues: 0 (or acceptable)

- [ ] **Rollback plan ready**
  - File exists: `ROLLBACK_INSTRUCTIONS.md`
  - You've read it: [ ] Yes

- [ ] **Git backup created**
  ```bash
  git branch backup/pre-cutover-$(date +%Y%m%d)
  ```

- [ ] **You have time**
  - 30-45 minutes uninterrupted

**If ALL checked:** ✅ Proceed with cutover

**If ANY unchecked:** ❌ STOP, complete first

---

## 🔄 CUTOVER STEPS VERIFICATION

**As you complete each step, check it off:**

### Step 1: Create Git Backup
- [ ] Backup branch created
- [ ] Verified with `git branch --list backup/*`

### Step 2: Verify Current State
- [ ] Godot open
- [ ] Files exist:
  - [ ] `scenes/main.tscn`
  - [ ] `scenes/main_refactored.tscn`
  - [ ] `scripts/game_manager.gd`
  - [ ] `scripts/controllers/game_controller.gd`

### Step 3: Rename Files
- [ ] `main.tscn` → `main_legacy.tscn`
- [ ] `main_refactored.tscn` → `main.tscn`
- [ ] `game_manager.gd` → `game_manager_legacy.gd`

**Verify FileSystem shows:**
- [ ] `scenes/main.tscn` (refactored)
- [ ] `scenes/main_legacy.tscn` (old)
- [ ] `scripts/game_manager_legacy.gd` (old)

### Step 4: Update Project Settings
- [ ] Project Settings → Application → Run → Main Scene
- [ ] Changed to: `res://scenes/main.tscn`
- [ ] Settings saved (clicked "Close")

### Step 5: Restart Godot
- [ ] Saved all scenes
- [ ] Quit Godot (File → Quit)
- [ ] Reopened Godot
- [ ] Project loaded without errors

### Step 6: Verify Cutover
- [ ] Pressed F5 (Run Project)
- [ ] Console shows: "GameController Initializing..."
- [ ] Console shows: "GameController ready!"
- [ ] No red errors in Output panel
- [ ] Game displays correctly

**Visual Check:**
- [ ] Player entity visible
- [ ] Enemy entities visible
- [ ] Cards visible (3 decks)
- [ ] PLAY button visible
- [ ] Timer visible
- [ ] Wave counter visible

**Interaction Check:**
- [ ] Cards respond to clicks
- [ ] PLAY button works
- [ ] Combat executes
- [ ] Carousel slides
- [ ] No crashes

### Step 7: Quick Regression Tests
- [ ] Played 1 full turn
- [ ] Tested instant card
- [ ] Tested targeting card
- [ ] Tested ESC cancel
- [ ] Played 3 turns
- [ ] No critical issues

### Step 8: Commit Changes
- [ ] Changes committed to Git
- [ ] Changes pushed to remote

### Step 9: Test Rollback (Optional)
- [ ] Switched to `main_legacy.tscn`
- [ ] Old code works
- [ ] Switched back to `main.tscn`
- [ ] New code works

---

## ✅ POST-CUTOVER VERIFICATION

**Final checks after cutover:**

### File Structure
- [ ] `scenes/main.tscn` exists (refactored, primary)
- [ ] `scenes/main_legacy.tscn` exists (old, backup)
- [ ] `scripts/game_manager_legacy.gd` exists (old, backup)
- [ ] `scripts/controllers/game_controller.gd` exists (refactored, primary)

### Project Settings
- [ ] Main Scene = `res://scenes/main.tscn` (refactored)

### Functionality
- [ ] F5 launches refactored version
- [ ] Game initializes without errors
- [ ] All core features work:
  - [ ] Combat
  - [ ] Carousel
  - [ ] Cards (instant + targeting)
  - [ ] Timer
  - [ ] Game over
- [ ] No critical regressions
- [ ] Performance acceptable (FPS > 30)

### Git
- [ ] Backup branch exists
- [ ] Cutover changes committed
- [ ] Changes pushed to remote

### Documentation
- [ ] `SUCCESS_METRICS.md` exists
- [ ] `KNOWN_ISSUES.md` updated (if issues found)
- [ ] `POST_CUTOVER_MONITORING.md` ready to use

---

## 📊 CUTOVER STATUS

**Check one:**

- [ ] ✅ **CUTOVER SUCCESSFUL**
  - All verification checks passed
  - Game is playable
  - No critical errors
  - Ready for monitoring

- [ ] ⚠️ **CUTOVER PARTIAL**
  - Most checks passed
  - Minor issues found (documented in KNOWN_ISSUES.md)
  - Acceptable to continue with monitoring

- [ ] ❌ **CUTOVER FAILED**
  - Critical checks failed
  - Game unplayable or broken
  - Rollback required

---

## 🎯 NEXT STEPS

### If Cutover Successful (✅):

1. **Update** `SUCCESS_METRICS.md`:
   - Fill in performance data (if measured)
   - Add any observations

2. **Begin Monitoring:**
   - Use `POST_CUTOVER_MONITORING.md`
   - Daily checks for 1 week
   - Document any issues

3. **Notify Team:**
   - Cutover complete
   - Monitoring in progress
   - Report any issues found

---

### If Cutover Partial (⚠️):

1. **Document Issues:**
   - Add to `KNOWN_ISSUES.md`
   - Classify severity
   - Plan fixes

2. **Continue with Caution:**
   - Begin monitoring
   - Watch for more issues
   - Fix issues as needed

3. **Reassess in 1 Week:**
   - If stable → Continue
   - If unstable → Consider rollback

---

### If Cutover Failed (❌):

1. **Rollback Immediately:**
   - Follow `ROLLBACK_INSTRUCTIONS.md`
   - Use Quick Rollback (5 minutes)

2. **Document Failure:**
   - What went wrong?
   - Error messages?
   - Steps to reproduce?

3. **Plan Fix:**
   - Identify root cause
   - Fix in separate branch
   - Test thoroughly
   - Re-attempt cutover when ready

---

## 📝 CUTOVER COMPLETION REPORT

**Fill this out after cutover:**

**Cutover Date:** ________________

**Cutover Time:** ________ to ________

**Duration:** ________ minutes

**Performed By:** ______________________

**Result:** [ ] ✅ Success [ ] ⚠️ Partial [ ] ❌ Failed

**Issues Encountered:**
```




```

**Rollback Required:** [ ] Yes [ ] No

**Current Status:**
- [ ] Running refactored code
- [ ] Rolled back to legacy code

**Performance Notes:**
- **FPS:** ________
- **Memory:** ________ MB
- **Load Time:** ________ seconds
- **Turn Time:** ________ seconds

**Observations:**
```




```

**Next Actions:**
```




```

---

## 🎉 SUCCESS!

**If cutover successful, congratulations!** 🎊

You've successfully migrated ChronoShift to a modern, modular architecture!

**Benefits Achieved:**
- ✅ 57% reduction in main file size
- ✅ Modular, testable code
- ✅ Event-driven architecture
- ✅ Better maintainability
- ✅ Easier feature development

**What's Next:**
1. Monitor daily for 1 week
2. Fix any issues found
3. After 1 week stability, delete legacy files
4. Enjoy your improved codebase!

---

**Last Updated:** 2025-11-19
**Version:** 1.0
