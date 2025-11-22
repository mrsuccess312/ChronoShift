# ChronoShift Refactoring - Rollback Plan

**Generated:** 2025-11-19
**Branch:** claude/final-integration-testing-01Q5Jj4RZMGAQH11gQHQ5MEu
**Purpose:** Safety plan for reverting refactored architecture if critical issues are found

---

## 📋 Pre-Rollback Checklist

Before deciding to rollback, verify:

- [ ] Issue is **critical** (game-breaking, data corruption, or major functionality loss)
- [ ] Issue **cannot be fixed** with a targeted patch within 4 hours
- [ ] Issue has been **reproduced** multiple times
- [ ] Alternative solutions have been **evaluated and rejected**

---

## 🔄 Rollback Strategy

### Option 1: Git Revert (Recommended)

**Use when:** You want to preserve history and can cleanly revert specific commits

```bash
# 1. Identify the commit range to revert
git log --oneline -20

# 2. Create a new branch for rollback
git checkout -b rollback/revert-refactoring-$(date +%Y%m%d)

# 3. Revert the refactoring commits (replace with actual commit hashes)
git revert --no-commit <latest_refactor_commit>..<first_refactor_commit>
git commit -m "Revert refactoring - critical issue found"

# 4. Test the rollback
# Run game and verify it works

# 5. Push rollback branch
git push -u origin rollback/revert-refactoring-$(date +%Y%m%d)
```

**Pros:**
- ✅ Preserves full history
- ✅ Can review exactly what was reverted
- ✅ Easy to re-apply later with fixes

**Cons:**
- ❌ May have merge conflicts if files changed significantly
- ❌ Requires manual conflict resolution

---

### Option 2: Hard Reset to Pre-Refactor Commit (Nuclear Option)

**Use when:** Refactoring is completely broken and Option 1 has conflicts

```bash
# 1. Find the last known good commit (before refactoring started)
git log --oneline --all --graph -30

# 2. Create a backup branch of current work
git branch backup/refactoring-attempt-$(date +%Y%m%d)

# 3. Reset to last known good commit
git reset --hard <last_good_commit_hash>

# 4. Force push (WARNING: destructive!)
git push -u origin claude/final-integration-testing-01Q5Jj4RZMGAQH11gQHQ5MEu --force

# 5. Verify game works
# Test thoroughly
```

**Pros:**
- ✅ Clean slate - back to known working state
- ✅ No merge conflicts
- ✅ Fast

**Cons:**
- ❌ Loses all refactoring work
- ❌ Destructive - cannot easily recover
- ❌ Requires force push

---

### Option 3: Cherry-Pick Good Changes

**Use when:** Some parts of refactoring work, others don't

```bash
# 1. Create new branch from last known good state
git checkout <last_good_commit>
git checkout -b selective-rollback-$(date +%Y%m%d)

# 2. Cherry-pick only the working commits
git cherry-pick <commit_hash_1>
git cherry-pick <commit_hash_2>
# ... continue for each good commit

# 3. Push selective rollback
git push -u origin selective-rollback-$(date +%Y%m%d)
```

**Pros:**
- ✅ Keeps working improvements
- ✅ Discards broken changes
- ✅ Flexible

**Cons:**
- ❌ Time-consuming
- ❌ Requires understanding each commit
- ❌ May have dependency issues

---

## 📦 Backup Files (Critical Originals)

**Location:** These files existed before refactoring and may still be in the repo

### Core Game Files (Pre-Refactor)
```
scenes/main.tscn                    # Original main scene
scripts/game_manager.gd             # Original monolithic game manager
scenes/entity_old.tscn              # Backup entity scene
scenes/arrow_old.tscn               # Backup arrow scene
```

### Recovery Commands
```bash
# If old files still exist, restore them
git checkout <last_good_commit> -- scenes/main.tscn
git checkout <last_good_commit> -- scripts/game_manager.gd

# Rename restored files
mv scenes/main.tscn scenes/main_refactored_backup.tscn
mv scenes/main_old.tscn scenes/main.tscn
```

---

## 🧪 Post-Rollback Verification

After rollback, **MUST verify**:

### 1. Game Launches
- [ ] Scene loads without errors
- [ ] No missing script references
- [ ] No null reference errors in console

### 2. Core Gameplay
- [ ] Player can see entities
- [ ] Cards are visible and clickable
- [ ] PLAY button works
- [ ] Combat animations play
- [ ] Carousel slides properly

### 3. Game Loop
- [ ] Full turn can complete
- [ ] Timeline states update (Past, Present, Future)
- [ ] Cards recycle after turn
- [ ] Timer resets

### 4. Card System
- [ ] Instant cards work (Meal Time)
- [ ] Targeting cards work (Chrono Strike)
- [ ] Card effects apply correctly

### 5. No Regressions
- [ ] No new bugs introduced by rollback
- [ ] Performance is acceptable
- [ ] Game can be played for 5+ minutes without crashes

---

## 🔍 Root Cause Analysis Template

**After rollback, document what went wrong:**

### Issue Description
```
What happened?
-
-
```

### Reproduction Steps
```
1.
2.
3.
```

### Expected vs Actual Behavior
```
Expected:


Actual:

```

### Why Rollback Was Necessary
```
-
-
```

### Lessons Learned
```
-
-
```

### Next Steps for Re-Implementation
```
1.
2.
3.
```

---

## 📝 Commit References

### Known Good Commits (Pre-Refactoring)
```bash
# Find with: git log --oneline --before="2025-11-15" -10

# Example (replace with actual):
# a28615b - Fix grid cells being interactive during combat
# 8698ed2 - Fix grid cells becoming unresponsive after combat
```

### Refactoring Commits (To Revert if Needed)
```bash
# Find with: git log --oneline --after="2025-11-15" -20

# Will be filled in based on actual commits made during refactoring
```

---

## 🚨 Emergency Rollback (Under 5 Minutes)

**If production is on fire and you need to rollback NOW:**

```bash
# 1. Quick backup
git branch emergency-backup-$(date +%Y%m%d-%H%M%S)

# 2. Find last known good commit (check git log)
LAST_GOOD_COMMIT="<commit_hash>"  # Replace with actual hash

# 3. Hard reset
git reset --hard $LAST_GOOD_COMMIT

# 4. Force push
git push -u origin claude/final-integration-testing-01Q5Jj4RZMGAQH11gQHQ5MEu --force

# 5. Verify game works
# Open Godot and run scenes/main.tscn

# 6. Document what happened
echo "Emergency rollback performed at $(date)" >> ROLLBACK_LOG.txt
echo "Reason: <describe issue>" >> ROLLBACK_LOG.txt
```

---

## 📊 Decision Matrix: To Rollback or Not?

| Severity | Impact | Timeframe | Action |
|----------|--------|-----------|--------|
| **Critical** | Game won't launch | Any | ✅ Rollback immediately |
| **Critical** | Game crashes within 1 turn | Any | ✅ Rollback immediately |
| **High** | Major feature broken | > 4 hours to fix | ✅ Rollback |
| **High** | Major feature broken | < 4 hours to fix | ⚠️ Attempt fix first |
| **Medium** | Minor feature broken | Any | ❌ Fix forward, don't rollback |
| **Low** | UI glitch or cosmetic issue | Any | ❌ Fix forward, don't rollback |

---

## 🛡️ Prevention for Future Refactorings

**To avoid needing rollback in future:**

1. **Branch Early**: Always work in feature branches
2. **Test Often**: Run integration tests after each major change
3. **Commit Small**: Many small commits > one large commit
4. **Keep Backups**: Don't delete old files until new system is proven
5. **Feature Flags**: Use flags to toggle between old/new systems during transition
6. **Parallel Systems**: Keep old system working while building new one
7. **Incremental Migration**: Migrate one subsystem at a time, not all at once

---

## 📞 Escalation Contacts

**If rollback fails or causes new issues:**

1. Check GitHub Issues: https://github.com/mrsuccess312/ChronoShift/issues
2. Review commit history: `git log --graph --oneline --all -30`
3. Compare working branch with main: `git diff main..HEAD`
4. Create detailed issue report with:
   - Error messages
   - Reproduction steps
   - Expected vs actual behavior
   - Environment info (Godot version, OS, etc.)

---

## ✅ Rollback Success Criteria

Rollback is successful when:

- ✅ Game launches without errors
- ✅ All core features work (combat, cards, carousel, timeline)
- ✅ No new bugs introduced
- ✅ Performance is acceptable
- ✅ Can play for 10+ minutes without crashes
- ✅ All integration tests pass (if automated tests exist)

---

## 📅 Review Schedule

- **Immediate (Day 1):** Test thoroughly after rollback
- **Day 3:** Verify no new issues emerged
- **Week 1:** Analyze root cause and plan fix/re-implementation
- **Week 2:** Begin careful re-implementation with lessons learned

---

**Remember:** Rollback is a **safety net**, not a failure. It's better to rollback quickly and regroup than to struggle with a broken system for days.

**Last Updated:** 2025-11-19
**Maintained By:** Development Team
**Version:** 1.0
