# Emergency Rollback Instructions

**Version:** 1.0
**Last Updated:** 2025-11-19
**Purpose:** Quick reference for reverting to old architecture if critical issues found

---

## 🚨 When to Use This Guide

Use this rollback procedure if:

- ❌ Game crashes on launch
- ❌ Game freezes during gameplay
- ❌ Critical features completely broken (combat, cards, carousel)
- ❌ Data corruption (HP/stats not persisting)
- ❌ Performance < 30 FPS or severe stuttering
- ❌ Memory leaks causing crashes

**DO NOT rollback for:**
- ⚠️ Minor visual glitches (fix forward)
- ⚠️ Single card not working (fix forward)
- ⚠️ Console warnings that don't break gameplay (fix forward)

See `ROLLBACK_PLAN.md` for detailed decision matrix.

---

## 🔄 QUICK ROLLBACK (5 Minutes)

**This keeps refactored code but switches back to old main scene.**

### Step 1: Change Main Scene

1. **Open Godot Project Settings:**
   - Menu: Project → Project Settings
   - Navigate to: Application → Run

2. **Change Main Scene:**
   - Current: `res://scenes/main_refactored.tscn`
   - Change to: `res://scenes/main.tscn`
   - Click: "Apply" or "Close" to save

3. **Restart Godot:**
   - File → Quit (Ctrl+Q)
   - Reopen Godot
   - Load ChronoShift project

4. **Verify:**
   - Press F5 (Run Project)
   - Should launch old `main.tscn` scene
   - Game should work as before refactoring

### Step 2: Test Old Scene Works

- [ ] Game launches without errors
- [ ] Entities appear on grid
- [ ] Cards are visible
- [ ] PLAY button works
- [ ] Combat executes
- [ ] Carousel slides
- [ ] No crashes

**If old scene works:** ✅ Rollback successful, investigate refactored issues

**If old scene also broken:** ❌ Issue may not be refactoring-related, check recent commits

---

## 🔙 PARTIAL ROLLBACK (15 Minutes)

**Disable new systems but keep new scene structure.**

### Step 1: Disable New Autoloads

1. **Open Godot Project Settings:**
   - Project → Project Settings → Autoload

2. **Disable (don't delete) new autoloads:**
   - [ ] Uncheck "Events" (keep in list, just disable)
   - [ ] Uncheck "GameState" (keep in list, just disable)

3. **Keep existing autoloads:**
   - ✅ CardDatabase should remain enabled

4. **Click:** "Apply" or "Close" to save

### Step 2: Swap Scripts

1. **Open `scenes/main_refactored.tscn`**

2. **Change root node script:**
   - Select root "Main" node
   - In Inspector → Script
   - Current: `res://scripts/controllers/game_controller.gd`
   - Change to: `res://scripts/game_manager.gd`
   - Save scene (Ctrl+S)

3. **Restart Godot:**
   - File → Quit
   - Reopen Godot

4. **Test:**
   - Run `main_refactored.tscn` (F6)
   - Should now use old GameManager logic with new scene

**Note:** This may cause errors if scene structure changed significantly.

---

## 🗑️ FULL ROLLBACK (30 Minutes)

**Remove all refactored code and restore original files.**

### Step 1: Create Backup of Current Work

**IMPORTANT:** Before deleting anything, backup your work!

```bash
# In terminal/command prompt, navigate to project folder:
cd /path/to/ChronoShift

# Create backup branch (if not done already)
git branch backup/refactoring-attempt-$(date +%Y%m%d-%H%M%S)

# Verify backup created
git branch --list backup/*
```

### Step 2: Remove New Autoloads

1. **Open Godot Project Settings:**
   - Project → Project Settings → Autoload

2. **Remove new autoloads:**
   - Select "Events" → Click "Remove" (trash icon)
   - Select "GameState" → Click "Remove" (trash icon)

3. **Verify CardDatabase still exists:**
   - ✅ CardDatabase should remain

4. **Close settings**

### Step 3: Delete Refactored Folders

**WARNING:** This is destructive! Ensure backup created first.

1. **In Godot FileSystem panel, delete these folders:**
   - `res://scripts/managers/` (contains Events, GameState)
   - `res://scripts/systems/` (contains CombatResolver, CardManager, TargetingSystem)
   - `res://scripts/controllers/` (contains GameController)
   - `res://scripts/utilities/` (contains TargetCalculator)
   - `res://scripts/data/` (contains EntityData)

2. **Confirm deletion for each folder**

### Step 4: Restore Original Files

**If you created backups:**

1. **Check if backup files exist:**
   - `res://scenes/main_old.tscn`
   - `res://scripts/game_manager_old.gd`

2. **If they exist, restore them:**

**In Godot FileSystem:**
- Right-click `main_old.tscn` → Duplicate → Rename to `main.tscn`
- Right-click `game_manager_old.gd` → Duplicate → Rename to `game_manager.gd`

**Or via Git:**

```bash
# Find last known good commit before refactoring
git log --oneline --before="2025-11-15" -10

# Restore specific files from that commit (replace COMMIT_HASH)
git checkout COMMIT_HASH -- scenes/main.tscn
git checkout COMMIT_HASH -- scripts/game_manager.gd
```

### Step 5: Update Project Settings

1. **Set Main Scene:**
   - Project → Project Settings → Application → Run
   - Main Scene: `res://scenes/main.tscn`

2. **Save and close settings**

### Step 6: Restart Godot

1. File → Quit
2. Reopen Godot
3. Load ChronoShift project

### Step 7: Verify Rollback

- [ ] Project opens without errors
- [ ] No missing script warnings
- [ ] No "Failed to load resource" errors
- [ ] Run main.tscn (F6) - should work
- [ ] Game is playable

---

## 🧪 POST-ROLLBACK TESTING

After rollback, test these critical features:

### Core Functionality
- [ ] Game launches
- [ ] Entities visible
- [ ] Cards visible and clickable
- [ ] PLAY button works
- [ ] Combat executes
- [ ] Carousel slides
- [ ] Timer counts down
- [ ] Cards recycle
- [ ] Game over triggers

### Performance
- [ ] FPS stable (30-60)
- [ ] No stuttering
- [ ] Turn execution < 6 seconds
- [ ] Memory usage stable

### No Regressions
- [ ] No NEW bugs introduced by rollback
- [ ] Old bugs (if any) are acceptable

**If all tests pass:** ✅ Rollback successful

**If tests fail:** ❌ Something went wrong during rollback, check:
1. Did you restore the correct file versions?
2. Are all autoloads configured correctly?
3. Are there uncommitted changes causing issues?

---

## 📋 ROLLBACK CHECKLIST

Use this checklist to ensure rollback is complete:

### Pre-Rollback
- [ ] Backup created (`git branch backup/...`)
- [ ] Team notified of rollback decision
- [ ] Root cause of issue documented

### During Rollback
- [ ] Main scene changed to `main.tscn`
- [ ] New autoloads removed (Events, GameState)
- [ ] Refactored folders deleted
- [ ] Original files restored
- [ ] Project settings updated
- [ ] Godot restarted

### Post-Rollback
- [ ] Project opens without errors
- [ ] Game launches and runs
- [ ] Critical features tested
- [ ] Performance acceptable
- [ ] No new bugs introduced
- [ ] Rollback logged in `ROLLBACK_LOG.md`

---

## 📝 ROLLBACK LOG TEMPLATE

**Create/update file:** `ROLLBACK_LOG.md`

```markdown
# Rollback Log

## Rollback Event: [Date/Time]

**Performed By:** [Name]
**Date:** [YYYY-MM-DD]
**Time:** [HH:MM]
**Branch:** [branch name]

### Reason for Rollback
[Describe the critical issue that necessitated rollback]

### Rollback Method Used
- [ ] Quick Rollback (main scene change)
- [ ] Partial Rollback (disable autoloads)
- [ ] Full Rollback (delete refactored code)

### Files Affected
- [List files changed/deleted/restored]

### Backup Location
- Branch: [backup branch name]
- Commit: [commit hash]

### Post-Rollback Status
- [ ] Game functional
- [ ] Performance acceptable
- [ ] No regressions

### Root Cause Analysis
[What went wrong and why?]

### Lessons Learned
[What to do differently next time]

### Next Steps
[Plan for fixing issues and re-attempting refactoring]
```

---

## 🔍 TROUBLESHOOTING

### Issue: "Script not found" errors after rollback

**Cause:** Scene references script that was deleted

**Fix:**
1. Find affected scene (error message shows path)
2. Open scene in text editor
3. Find line with `[ext_resource ... path="res://scripts/..."]`
4. Update path to correct script
5. Save and reopen in Godot

### Issue: "Failed to load autoload" errors

**Cause:** Autoload still referenced but file deleted

**Fix:**
1. Project → Project Settings → Autoload
2. Remove the failing autoload entry
3. Restart Godot

### Issue: Game works but performance is poor

**Cause:** Old codebase may have existing performance issues

**Fix:**
1. Check if performance was always like this (check notes)
2. Profile the game (Debugger → Monitors)
3. This is likely not rollback-related

### Issue: Old scene doesn't exist anymore

**Cause:** `main.tscn` or `game_manager.gd` were deleted/renamed

**Fix:**
```bash
# Restore from Git
git checkout HEAD~10 -- scenes/main.tscn
git checkout HEAD~10 -- scripts/game_manager.gd

# Adjust ~10 to however many commits back before refactoring
```

---

## 🛡️ PREVENTION

**To avoid needing rollback in the future:**

1. **Feature Flags:**
   ```gdscript
   # In project settings or config
   const USE_REFACTORED_ARCHITECTURE = true

   # In main scene
   func _ready():
       if USE_REFACTORED_ARCHITECTURE:
           # Use new systems
       else:
           # Use old GameManager
   ```

2. **Parallel Systems:**
   - Keep old GameManager working
   - Build new GameController alongside
   - Switch between them with a flag
   - Only delete old code after 1-2 weeks of stable new code

3. **Incremental Migration:**
   - Refactor one system at a time
   - Test after each system
   - Easier to identify what broke

4. **Comprehensive Testing:**
   - Use `MANUAL_TEST_CHECKLIST.md` before every major change
   - Run performance tests regularly
   - Catch issues before they require rollback

---

## 📞 SUPPORT

### If Rollback Fails

1. **Check Git history:**
   ```bash
   git log --oneline --all --graph -30
   git reflog  # Shows all branch changes
   ```

2. **Find last known good state:**
   ```bash
   git checkout <commit-hash>
   # Test if this works
   # If yes, create new branch: git checkout -b recovery
   ```

3. **Nuclear Option - Clone Fresh:**
   ```bash
   # Backup current directory
   mv ChronoShift ChronoShift_broken

   # Clone fresh copy from GitHub
   git clone <repo-url> ChronoShift

   # Checkout last known good commit
   cd ChronoShift
   git checkout <last-good-commit>
   ```

### Getting Help

1. Review `ROLLBACK_PLAN.md` for detailed strategies
2. Check GitHub issues for similar problems
3. Review commit history: `git log --oneline -30`
4. Check for uncommitted changes: `git status`

---

## ✅ ROLLBACK SUCCESS CRITERIA

Rollback is successful when:

- ✅ Game launches without errors
- ✅ All core features work (combat, cards, carousel)
- ✅ Performance is acceptable (30-60 FPS)
- ✅ No crashes during 10-minute play session
- ✅ No new bugs introduced by rollback
- ✅ Game is in playable state

---

## 🎯 AFTER ROLLBACK

Once rollback is complete and game is stable:

1. **Document the issue:**
   - What went wrong
   - Why rollback was necessary
   - What to fix before re-attempting

2. **Plan the fix:**
   - Identify root cause
   - Design solution
   - Test solution in separate branch

3. **Re-attempt carefully:**
   - Fix issues first
   - Test thoroughly in feature branch
   - Get team review before merge

4. **Keep backups for 1 week:**
   - Don't delete backup files immediately
   - Keep `main_old.tscn` and `game_manager_old.gd` for at least 1 week
   - Ensure new version is stable first

---

**Remember:** Rollback is a safety net, not a failure. Better to rollback quickly and fix properly than to struggle with a broken system.

**Last Updated:** 2025-11-19
**Version:** 1.0
