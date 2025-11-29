# Cleanup Old Files Guide

**⚠️ WARNING:** Only run this AFTER successful cutover and 1 week of stability!

**Purpose:** Remove legacy/old architecture files after refactored version is proven stable

---

## ⚠️ WHEN TO RUN THIS CLEANUP

**✅ SAFE to cleanup if:**
- ✅ Cutover completed successfully (refactored code is now `main.tscn`)
- ✅ 1+ week of stable operation (no critical bugs)
- ✅ All known issues documented and acceptable
- ✅ Team is confident in refactored architecture
- ✅ You have recent Git backup

**❌ DO NOT cleanup if:**
- ❌ Cutover not completed yet
- ❌ Less than 1 week since cutover
- ❌ Critical bugs still present
- ❌ Considering rollback

---

## 📋 FILES TO DELETE

### Old Scene Files (Created During Cutover)

After cutover, these files are legacy backups:

1. **`scenes/main_legacy.tscn`**
   - This is the OLD main scene (with game_manager.gd)
   - Created when you renamed `main.tscn` → `main_legacy.tscn`
   - No longer needed after 1 week stability

2. **`scripts/game_manager_legacy.gd`**
   - This is the OLD monolithic game manager (2,694 lines)
   - Created when you renamed `game_manager.gd` → `game_manager_legacy.gd`
   - No longer needed after 1 week stability

### Original Old Files (If They Still Exist)

These may have been created as backups before refactoring:

3. **`scenes/main_old.tscn`** (if exists)
   - Old backup from before refactoring
   - Can be deleted

4. **`scripts/game_manager_old.gd`** (if exists)
   - Old backup from before refactoring
   - Can be deleted

5. **`scenes/entity_old.tscn`** (if exists)
   - Old entity scene backup
   - Can be deleted

6. **`scenes/arrow_old.tscn`** (if exists)
   - Old arrow scene backup
   - Can be deleted

---

## 🗑️ CLEANUP PROCEDURE

### Step 1: Create Final Backup (Safety First!)

```bash
cd /path/to/ChronoShift

# Create final backup before cleanup
git branch backup/before-cleanup-$(date +%Y%m%d)

# Verify backup
git branch --list backup/*
```

**Checkpoint:**
- [ ] Backup branch created

---

### Step 2: Delete Legacy Files in Godot

**⚠️ Do this in Godot FileSystem panel, NOT in file explorer!**

#### Delete Legacy Scene Files

1. **Open Godot Editor**
2. **Navigate to FileSystem panel**
3. **Find:** `res://scenes/main_legacy.tscn`
4. **Right-click** → **Delete**
5. **Confirm deletion**

**Checkpoint:**
- [ ] `main_legacy.tscn` deleted

---

#### Delete Legacy Script Files

1. **Navigate to:** `res://scripts/`
2. **Find:** `game_manager_legacy.gd`
3. **Right-click** → **Delete**
4. **Confirm deletion**

**Checkpoint:**
- [ ] `game_manager_legacy.gd` deleted

---

#### Delete Old Backup Files (If They Exist)

Check for and delete if present:

- [ ] `scenes/main_old.tscn` (if exists)
- [ ] `scenes/entity_old.tscn` (if exists)
- [ ] `scenes/arrow_old.tscn` (if exists)
- [ ] `scripts/game_manager_old.gd` (if exists)

---

### Step 3: Verify Project Still Works

**Critical: Test after deletion!**

1. **Close all scenes in Godot**
2. **Restart Godot** (File → Quit → Reopen)
3. **Press F5** to run project
4. **Verify:**
   - [ ] Game launches without errors
   - [ ] No "Failed to load resource" errors
   - [ ] Game is playable
   - [ ] No missing file warnings

**If any errors:**
- STOP immediately
- Restore from Git backup
- Investigate what went wrong

---

### Step 4: Commit Cleanup

**Only commit if Step 3 verification passed!**

```bash
cd /path/to/ChronoShift

# Check what was deleted
git status

# Should show:
# deleted: scenes/main_legacy.tscn
# deleted: scripts/game_manager_legacy.gd
# (and any other old files)

# Stage deletions
git add -A

# Commit cleanup
git commit -m "$(cat <<'EOF'
Remove legacy files after 1 week of stable refactored architecture

Files deleted:
- scenes/main_legacy.tscn (old main scene, 2,694 lines)
- scripts/game_manager_legacy.gd (old monolithic manager)
- [list any other files deleted]

Reason:
- Cutover completed on [DATE]
- 1+ week of stable operation
- No critical issues with refactored architecture
- Legacy files no longer needed

Refactored architecture proven stable:
- ✅ All features working
- ✅ Performance acceptable
- ✅ No critical bugs
- ✅ Team confident in new architecture

Legacy code preserved in Git history if needed.
EOF
)"

# Push to remote
git push origin <your-branch>
```

**Checkpoint:**
- [ ] Changes committed
- [ ] Changes pushed

---

### Step 5: Archive Rollback Documentation (Optional)

After cleanup, rollback is no longer easily possible. You may want to archive rollback docs:

```bash
# Create archive directory
mkdir -p archive/refactoring-2025-11

# Move rollback docs to archive
mv ROLLBACK_INSTRUCTIONS.md archive/refactoring-2025-11/
mv ROLLBACK_PLAN.md archive/refactoring-2025-11/

# Keep these active:
# - SUCCESS_METRICS.md
# - KNOWN_ISSUES.md
# - MANUAL_TEST_CHECKLIST.md (for regression testing)
# - POST_CUTOVER_MONITORING.md (for reference)

# Commit archive
git add archive/
git commit -m "Archive rollback documentation after successful refactoring"
git push
```

**Checkpoint:**
- [ ] Rollback docs archived (optional)

---

## 📊 SPACE SAVED

After cleanup, you'll have removed:

| File | Lines | Savings |
|------|-------|---------|
| `game_manager_legacy.gd` | ~2,694 | ✅ Removed monolith |
| `main_legacy.tscn` | ~156 | ✅ Removed old scene |
| `main_old.tscn` (if exists) | ~156 | ✅ Removed backup |
| `game_manager_old.gd` (if exists) | ~2,694 | ✅ Removed backup |

**Total:** ~5,000-6,000 lines of obsolete code removed

**Result:** Cleaner, more maintainable codebase

---

## 🔄 IF YOU NEED TO ROLLBACK AFTER CLEANUP

**If you deleted legacy files but need to rollback:**

### Option 1: Restore from Git History

```bash
# Find commit before cleanup
git log --oneline -10

# Checkout files from before cleanup
git checkout <commit-before-cleanup> -- scenes/main_legacy.tscn
git checkout <commit-before-cleanup> -- scripts/game_manager_legacy.gd

# Now follow ROLLBACK_INSTRUCTIONS.md
```

---

### Option 2: Restore from Backup Branch

```bash
# List backup branches
git branch --list backup/*

# Find appropriate backup
# Example: backup/before-cleanup-20251119

# Checkout files from backup
git checkout backup/before-cleanup-20251119 -- scenes/main_legacy.tscn
git checkout backup/before-cleanup-20251119 -- scripts/game_manager_legacy.gd

# Now follow ROLLBACK_INSTRUCTIONS.md
```

---

### Option 3: Revert Cleanup Commit

```bash
# Find cleanup commit
git log --oneline -10

# Revert cleanup (restores deleted files)
git revert <cleanup-commit-hash>

# Files are restored, now follow ROLLBACK_INSTRUCTIONS.md
```

---

## ✅ CLEANUP SUCCESS CHECKLIST

Confirm all of these after cleanup:

- [ ] Legacy files deleted in Godot
- [ ] Project opens without errors
- [ ] Game runs without errors
- [ ] No "Failed to load resource" warnings
- [ ] Changes committed to Git
- [ ] Changes pushed to remote
- [ ] Backup branch created before cleanup
- [ ] Team notified of cleanup

---

## 📝 CLEANUP LOG

**Fill this out after cleanup:**

**Cleanup Performed By:** ______________________
**Date:** ______________________
**Time:** ______________________

**Files Deleted:**
- [ ] scenes/main_legacy.tscn
- [ ] scripts/game_manager_legacy.gd
- [ ] scenes/main_old.tscn (if existed)
- [ ] scripts/game_manager_old.gd (if existed)
- [ ] Other: ______________________

**Verification:**
- [ ] Game tested after cleanup
- [ ] No errors detected
- [ ] Changes committed
- [ ] Backup created

**Notes:**
```


```

---

## 🎉 CLEANUP COMPLETE

**Congratulations!** You've successfully removed all legacy code from the refactored ChronoShift project.

**What You've Achieved:**
- ✅ Removed obsolete legacy files (~5,000 lines)
- ✅ Cleaner codebase (refactored only)
- ✅ No more confusion about which files to use
- ✅ Fully committed to new architecture

**Benefits:**
- **Clarity:** Only one version of files (no more *_legacy.* files)
- **Simplicity:** Less code to maintain
- **Confidence:** Proven stable for 1+ week
- **Future:** Positioned for easy feature development

**Next Steps:**
1. Continue using refactored architecture
2. Add new features with confidence
3. Enjoy improved maintainability
4. Share success metrics with team

---

**Maintained By:** Development Team
**Last Updated:** 2025-11-19
**Version:** 1.0
