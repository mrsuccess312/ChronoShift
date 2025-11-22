# Cutover Instructions - Refactored Architecture

**Purpose:** Switch ChronoShift to use refactored code as primary architecture
**Date:** 2025-11-19
**Estimated Time:** 30-45 minutes
**Risk Level:** Low (rollback plan ready)

---

## ⚠️ IMPORTANT: READ BEFORE STARTING

**This is a MANUAL procedure** - You must perform these steps in Godot Editor.

**Prerequisites:**
- ✅ All integration tests passed (or documented in KNOWN_ISSUES.md)
- ✅ Performance tests completed (or acceptable to skip for now)
- ✅ `ROLLBACK_INSTRUCTIONS.md` exists
- ✅ You have 30-45 minutes uninterrupted time
- ✅ No uncommitted changes in Git

**If any prerequisite is NOT met, STOP and complete it first.**

---

## 📋 PRE-CUTOVER CHECKLIST

### Step 0: Verify Preconditions

Before proceeding, manually verify:

- [ ] ✅ **Manual tests completed**
  - File: `MANUAL_TEST_CHECKLIST.md`
  - Status: [ ] All passed [ ] Some failed (documented)

- [ ] ✅ **Performance tests completed** (or acceptable to skip)
  - File: `PERFORMANCE_TEST_CHECKLIST.md`
  - Status: [ ] Completed [ ] Skipped (acceptable)

- [ ] ✅ **No critical blockers**
  - Check `KNOWN_ISSUES.md`
  - Critical issues: 0 (or acceptable risk)

- [ ] ✅ **Rollback plan exists**
  - File exists: `ROLLBACK_INSTRUCTIONS.md`
  - You've read it: [ ] Yes

- [ ] ✅ **Git is clean**
  ```bash
  git status
  # Should show: "nothing to commit, working tree clean"
  ```

- [ ] ✅ **You have time**
  - Uninterrupted: 30-45 minutes
  - No pressure: Not rushing before meeting/deadline

**If ALL boxes checked:** ✅ Proceed to Step 1

**If ANY box unchecked:** ❌ STOP, complete prerequisites first

---

## 🔄 CUTOVER PROCEDURE

### Step 1: Create Git Backup (Safety First!)

**Why:** Create a snapshot before any changes, easy to revert if needed.

**Commands:**
```bash
cd /path/to/ChronoShift

# Create backup branch
git branch backup/pre-cutover-$(date +%Y%m%d-%H%M%S)

# Verify backup created
git branch --list backup/*

# Should show your new backup branch
```

**Verification:**
- [ ] Backup branch created and listed

**If verification fails:** STOP, troubleshoot Git

---

### Step 2: Verify Current State in Godot

**Why:** Confirm we're starting from expected state.

**Actions:**
1. **Open Godot Editor**
2. **Load ChronoShift project**
3. **Check FileSystem panel:**
   - [ ] `scenes/main.tscn` exists
   - [ ] `scenes/main_refactored.tscn` exists
   - [ ] `scripts/game_manager.gd` exists
   - [ ] `scripts/controllers/game_controller.gd` exists

4. **Test Current Setup:**
   - Press F5 (Run Project)
   - Note which scene launches: ________________
   - Close game window

**Expected:** Either `main.tscn` or `main_refactored.tscn` launches

**If files missing:** STOP, verify you're on correct branch

---

### Step 3: Rename Old Files (Archive Legacy Code)

**Why:** Preserve old code with clear "legacy" naming, but make room for new code.

**IMPORTANT:** Do these renames in Godot FileSystem panel, NOT in file explorer.

#### Rename 3.1: Archive Old Main Scene

**In Godot FileSystem panel:**
1. Navigate to: `res://scenes/`
2. **Right-click** `main.tscn`
3. Select: **"Rename..."**
4. New name: `main_legacy.tscn`
5. Click: **"Rename"** button
6. **Verify:** `main_legacy.tscn` now exists in FileSystem

**Checkpoint:**
- [ ] `main_legacy.tscn` exists
- [ ] `main.tscn` NO LONGER exists (now renamed)

---

#### Rename 3.2: Promote Refactored Scene

**In Godot FileSystem panel:**
1. Navigate to: `res://scenes/`
2. **Right-click** `main_refactored.tscn`
3. Select: **"Rename..."**
4. New name: `main.tscn`
5. Click: **"Rename"** button
6. **Verify:** `main.tscn` now exists in FileSystem

**Checkpoint:**
- [ ] `main.tscn` exists (this is the refactored version!)
- [ ] `main_refactored.tscn` NO LONGER exists (now renamed)

---

#### Rename 3.3: Archive Old Game Manager

**In Godot FileSystem panel:**
1. Navigate to: `res://scripts/`
2. **Right-click** `game_manager.gd`
3. Select: **"Rename..."**
4. New name: `game_manager_legacy.gd`
5. Click: **"Rename"** button
6. **Verify:** `game_manager_legacy.gd` now exists in FileSystem

**Checkpoint:**
- [ ] `game_manager_legacy.gd` exists
- [ ] `game_manager.gd` NO LONGER exists (now renamed)

---

**Step 3 Complete Verification:**

After all renames, your FileSystem should show:

**Scenes:**
- ✅ `scenes/main.tscn` (refactored - primary)
- ✅ `scenes/main_legacy.tscn` (old - backup)

**Scripts:**
- ✅ `scripts/game_manager_legacy.gd` (old - backup)
- ✅ `scripts/controllers/game_controller.gd` (refactored - primary)

**Checkpoint:**
- [ ] All 3 renames completed successfully
- [ ] FileSystem shows expected files

**If any rename failed:** Use Ctrl+Z to undo, try again

---

### Step 4: Update Project Settings (Critical!)

**Why:** Tell Godot to launch refactored scene when pressing F5.

**Actions:**

1. **Open Project Settings:**
   - Menu: **Project → Project Settings**

2. **Navigate to Main Scene Setting:**
   - In left panel, click: **Application**
   - Click: **Run**
   - Find setting: **"Main Scene"**

3. **Update Main Scene:**
   - Current value might be: `res://scenes/main_legacy.tscn` or empty
   - Click the folder icon next to Main Scene
   - Browse to: `res://scenes/main.tscn` (this is the refactored one!)
   - Click: **"Open"**

4. **Verify:**
   - Main Scene now shows: `res://scenes/main.tscn`

5. **Save Settings:**
   - Click: **"Close"** button (auto-saves)

**Checkpoint:**
- [ ] Project Settings → Application → Run → Main Scene = `res://scenes/main.tscn`

---

### Step 5: Restart Godot (Ensure Clean State)

**Why:** Clear any cached state, ensure fresh start with new settings.

**Actions:**

1. **Save Everything:**
   - Menu: **Scene → Save All Scenes** (or Ctrl+Shift+S)
   - Verify: No unsaved changes (no * in tab names)

2. **Quit Godot:**
   - Menu: **File → Quit** (or Ctrl+Q)
   - Wait for Godot to fully close

3. **Reopen Project:**
   - Launch Godot
   - Select: **ChronoShift** project
   - Click: **"Edit"** (or double-click project)
   - Wait for project to fully load

**Checkpoint:**
- [ ] Godot restarted
- [ ] ChronoShift project reloaded
- [ ] No errors in Output panel on startup

---

### Step 6: Verify Cutover (The Moment of Truth!)

**Why:** Confirm refactored version now launches and works.

#### Test 6.1: Launch Game

**Actions:**
1. **Press F5** (Run Project)
2. **Watch Output panel** for initialization messages

**Expected Output:**
```
=================================================
  ChronoShift - GameController Initializing...
=================================================

🔧 Initializing systems...
  ✅ CombatResolver created
  ✅ CardManager created
  ✅ TargetingSystem created
  All systems initialized

🎮 Initializing game - Wave 1

✅ GameController ready!
```

**Checkpoint:**
- [ ] Game window opens
- [ ] Console shows "GameController Initializing..." (NOT "GameManager")
- [ ] Console shows "GameController ready!"
- [ ] No red errors in Output panel
- [ ] Game displays correctly (entities, cards, UI visible)

**If errors appear:** STOP, read error messages, check `ROLLBACK_INSTRUCTIONS.md`

---

#### Test 6.2: Basic Functionality

**With game running, test:**

1. **Visual Verification:**
   - [ ] Player entity visible on grid
   - [ ] Enemy entities visible on grid
   - [ ] Cards visible in 3 decks (Past, Present, Future)
   - [ ] PLAY button visible and enabled
   - [ ] Timer shows (e.g., "1:00")
   - [ ] Wave counter shows (e.g., "Wave 1/10")

2. **Interaction Test:**
   - [ ] Click a card → Card responds (highlights or plays)
   - [ ] Click PLAY button → Turn executes
   - [ ] Combat animations play
   - [ ] Carousel slides
   - [ ] New turn starts
   - [ ] No crashes

3. **Console Check:**
   - [ ] Events are firing (`[EVENT] combat_started`, etc.)
   - [ ] No null reference errors
   - [ ] No "Failed to load" errors

**Checkpoint:**
- [ ] Game is playable
- [ ] All basic features work
- [ ] No critical errors

**If game doesn't work:** See `ROLLBACK_INSTRUCTIONS.md` → Quick Rollback

---

### Step 7: Run Quick Regression Tests

**Why:** Verify no features broken by cutover.

**Quick Test Suite (5 minutes):**

1. **Play 1 Full Turn:**
   - [ ] Click PLAY
   - [ ] Combat executes
   - [ ] Carousel slides
   - [ ] Turn completes

2. **Test Instant Card:**
   - [ ] Click "Meal Time" or similar instant card
   - [ ] Card effect applies immediately
   - [ ] HP or stat changes as expected

3. **Test Targeting Card:**
   - [ ] Click "Chrono Strike" or similar targeting card
   - [ ] Targeting mode activates
   - [ ] Click enemy
   - [ ] Damage applies

4. **Test ESC Cancel:**
   - [ ] Click targeting card
   - [ ] Press ESC
   - [ ] Targeting cancels

5. **Play 3 Turns:**
   - [ ] Execute 3 complete turns
   - [ ] Timer resets each turn
   - [ ] Cards recycle
   - [ ] No crashes

**Checkpoint:**
- [ ] All quick tests passed
- [ ] No regressions detected

**If regressions found:** Document in `KNOWN_ISSUES.md`, decide if critical

---

### Step 8: Commit Cutover Changes

**Why:** Lock in the cutover in Git, easy to track what changed.

**Actions:**

```bash
cd /path/to/ChronoShift

# Check what changed
git status

# Should show:
#   renamed: scenes/main.tscn -> scenes/main_legacy.tscn
#   renamed: scenes/main_refactored.tscn -> scenes/main.tscn
#   renamed: scripts/game_manager.gd -> scripts/game_manager_legacy.gd
#   modified: project.godot (main scene changed)

# Stage changes
git add -A

# Commit cutover
git commit -m "$(cat <<'EOF'
Cutover to refactored architecture

BREAKING CHANGE: Primary scene is now main.tscn (refactored version)

File renames:
- main.tscn → main_legacy.tscn (old architecture)
- main_refactored.tscn → main.tscn (new architecture, now primary)
- game_manager.gd → game_manager_legacy.gd (old monolith)

Project settings:
- Main Scene: res://scenes/main.tscn (refactored version)

Verification:
- ✅ Game launches with refactored code
- ✅ GameController initializes successfully
- ✅ Basic functionality verified
- ✅ No critical regressions

Rollback:
- Old code preserved as *_legacy.tscn and *_legacy.gd
- See ROLLBACK_INSTRUCTIONS.md for emergency procedures

Next steps:
- Monitor for 1 week
- Document any issues in KNOWN_ISSUES.md
- Delete legacy files after 1 week stability
EOF
)"

# Push to remote
git push -u origin claude/final-integration-testing-01Q5Jj4RZMGAQH11gQHQ5MEu
```

**Checkpoint:**
- [ ] Changes committed
- [ ] Changes pushed to remote

---

### Step 9: Test Rollback Procedure (Optional but Recommended)

**Why:** Verify rollback works if you need it later.

**This is a DRY RUN - we'll revert back to new code after testing.**

#### Rollback Test 9.1: Switch Back to Old

**Actions:**
1. Open: **Project → Project Settings**
2. Navigate to: **Application → Run → Main Scene**
3. Change to: `res://scenes/main_legacy.tscn`
4. Click: **"Close"**
5. Press F5 to run game

**Expected:**
- [ ] Game launches with OLD code
- [ ] Console shows "GameManager ready!" (not GameController)
- [ ] Game still works (old architecture)

**Checkpoint:**
- [ ] Rollback to old code works

---

#### Rollback Test 9.2: Switch Back to New

**Actions:**
1. Open: **Project → Project Settings**
2. Navigate to: **Application → Run → Main Scene**
3. Change to: `res://scenes/main.tscn`
4. Click: **"Close"**
5. Press F5 to run game

**Expected:**
- [ ] Game launches with NEW code
- [ ] Console shows "GameController Initializing..."
- [ ] Game works (refactored architecture)

**Checkpoint:**
- [ ] Switched back to new code successfully

**Result:** ✅ Rollback procedure verified, you can safely revert if needed

---

## ✅ POST-CUTOVER VERIFICATION

### Final Checklist

Confirm all of these:

**File Structure:**
- [ ] `scenes/main.tscn` exists (refactored, primary)
- [ ] `scenes/main_legacy.tscn` exists (old, backup)
- [ ] `scripts/game_manager_legacy.gd` exists (old, backup)
- [ ] `scripts/controllers/game_controller.gd` exists (refactored, primary)

**Project Settings:**
- [ ] Main Scene = `res://scenes/main.tscn` (refactored)

**Functionality:**
- [ ] F5 launches refactored version
- [ ] Game initializes without errors
- [ ] All core features work
- [ ] No critical regressions
- [ ] Performance acceptable

**Git:**
- [ ] Backup branch created
- [ ] Cutover changes committed
- [ ] Changes pushed to remote

**Rollback:**
- [ ] Rollback procedure tested (optional but recommended)
- [ ] `ROLLBACK_INSTRUCTIONS.md` exists and is understood

**Documentation:**
- [ ] `SUCCESS_METRICS.md` exists
- [ ] `KNOWN_ISSUES.md` updated with any issues found

---

## 📊 CUTOVER SUCCESS CRITERIA

### ✅ **CUTOVER SUCCESSFUL** if:

- ✅ All file renames completed
- ✅ Project settings updated
- ✅ F5 launches refactored version
- ✅ Game is playable
- ✅ No critical errors
- ✅ Basic features work
- ✅ Changes committed to Git

### ⚠️ **CUTOVER PARTIAL** if:

- ⚠️ Minor issues found but acceptable
- ⚠️ Performance slightly worse but still playable
- ⚠️ Non-critical features broken (can be fixed later)

**Action:** Document issues in `KNOWN_ISSUES.md`, continue with cutover

### ❌ **CUTOVER FAILED** if:

- ❌ Game won't launch
- ❌ Critical errors on startup
- ❌ Major features broken
- ❌ Unplayable due to bugs
- ❌ Performance unacceptable (< 30 FPS, crashes)

**Action:** Follow `ROLLBACK_INSTRUCTIONS.md` → Quick Rollback

---

## 📋 POST-CUTOVER TASKS

### Immediate (Today):

- [ ] Update `SUCCESS_METRICS.md` with performance data (if measured)
- [ ] Document any issues found in `KNOWN_ISSUES.md`
- [ ] Notify team that cutover is complete
- [ ] Play game for 10-15 minutes to catch obvious issues

### This Week:

- [ ] **Monitor Daily:**
  - Play game for at least 5 minutes per day
  - Test different features each day
  - Note any bugs or issues

- [ ] **Document Issues:**
  - Add to `KNOWN_ISSUES.md`
  - Classify severity (Critical/High/Medium/Low)
  - Create GitHub issues for critical bugs

- [ ] **Watch Performance:**
  - Monitor FPS during gameplay
  - Check memory usage (Debugger → Monitors)
  - Note any stuttering or lag

### After 1 Week Stability:

**If NO critical issues found:**

- [ ] **Delete Legacy Files:**
  ```bash
  # In Godot FileSystem, delete:
  # - scenes/main_legacy.tscn
  # - scripts/game_manager_legacy.gd

  # Commit cleanup
  git add -A
  git commit -m "Remove legacy files after 1 week stability"
  git push
  ```

- [ ] **Archive Documentation:**
  ```bash
  # Optional: Move rollback docs to archive/
  mkdir -p archive/refactoring-2025-11
  mv ROLLBACK_INSTRUCTIONS.md archive/refactoring-2025-11/
  mv ROLLBACK_PLAN.md archive/refactoring-2025-11/

  # Keep these active:
  # - SUCCESS_METRICS.md
  # - KNOWN_ISSUES.md
  # - MANUAL_TEST_CHECKLIST.md (for regression testing)
  ```

**If critical issues found:**

- [ ] Review `ROLLBACK_PLAN.md` decision matrix
- [ ] Fix issues or rollback
- [ ] Extend monitoring period

---

## 🚨 TROUBLESHOOTING

### Issue: "Failed to load resource" errors on launch

**Cause:** File paths may not have updated correctly

**Fix:**
1. Open `scenes/main.tscn` in Godot
2. Check Inspector for missing resources
3. Relink any broken resource paths
4. Save scene

---

### Issue: Game launches but uses old GameManager

**Cause:** Project Settings not updated or Godot not restarted

**Fix:**
1. Verify Project Settings → Main Scene = `res://scenes/main.tscn`
2. Restart Godot completely
3. Try again

---

### Issue: Autoload errors (Events or GameState not found)

**Cause:** Autoloads may not be configured

**Fix:**
1. Open Project Settings → Autoload
2. Verify these exist:
   - Events: `res://scripts/managers/events.gd`
   - GameState: `res://scripts/managers/game_state.gd`
   - CardDatabase: `res://scripts/card_database.gd`
3. If missing, add them
4. Restart Godot

---

### Issue: Cutover failed, want to rollback

**Fix:**
See `ROLLBACK_INSTRUCTIONS.md` → Quick Rollback (5 minutes)

---

## 📝 CUTOVER LOG

**Fill this out after completing cutover:**

**Cutover Performed By:** ______________________

**Date:** ______________________

**Time Started:** ______________________

**Time Completed:** ______________________

**Total Duration:** ______________________

**Cutover Result:** [ ] ✅ Success [ ] ⚠️ Partial [ ] ❌ Failed

**Issues Encountered:**
```


```

**Rollback Required:** [ ] Yes [ ] No

**Current Status:** [ ] Running refactored code [ ] Rolled back

**Next Steps:**
```


```

---

## ✅ CUTOVER COMPLETE

**Congratulations!** 🎉

You've successfully switched ChronoShift to the refactored architecture!

**What Changed:**
- ✅ Modular event-driven architecture
- ✅ 57% reduction in main file size
- ✅ Testable, maintainable code
- ✅ Better organization and documentation

**What Stayed the Same:**
- ✅ All game features preserved
- ✅ Same gameplay experience
- ✅ Same performance (or better)

**What to Do Now:**
1. Play the game regularly
2. Monitor for issues
3. Document any bugs in `KNOWN_ISSUES.md`
4. After 1 week, delete legacy files
5. Enjoy your improved codebase!

---

**Last Updated:** 2025-11-19
**Version:** 1.0
**Status:** Ready for execution
