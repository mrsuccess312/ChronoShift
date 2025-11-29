# Known Issues (Non-Critical)

**Last Updated:** 2025-11-19
**Version:** 1.0 (Refactored Architecture)
**Branch:** claude/final-integration-testing-01Q5Jj4RZMGAQH11gQHQ5MEu

---

## 📊 Overview

This document tracks known issues in the refactored architecture that are **NOT critical** but should be addressed in future updates.

**Issue Severity Levels:**
- 🔴 **Critical:** Blocks gameplay, must fix immediately
- 🟡 **High:** Major feature impacted, fix soon
- 🟠 **Medium:** Minor feature impacted, fix when convenient
- 🟢 **Low:** Cosmetic or minor quality-of-life issue

---

## 🐛 Current Known Issues

### Issue Template
```
### [Issue Title]
**Severity:** [🔴 Critical / 🟡 High / 🟠 Medium / 🟢 Low]
**Discovered:** [Date]
**Affected Systems:** [List systems]

**Description:**
[What is the issue?]

**Steps to Reproduce:**
1. [Step 1]
2. [Step 2]
3. [Expected vs Actual behavior]

**Workaround:**
[If any workaround exists]

**Fix Status:** [ ] Not Started [ ] In Progress [ ] Fixed [ ] Won't Fix

**Notes:**
[Additional context]
```

---

## 📋 Active Issues

*No critical issues reported yet. This section will be populated after testing.*

### Example Issue (DELETE THIS AFTER TESTING)
### Card Animation Not Smooth
**Severity:** 🟢 Low
**Discovered:** 2025-11-19
**Affected Systems:** CardManager

**Description:**
When a card is played, there's a slight stutter before the card disappears from the deck.

**Steps to Reproduce:**
1. Click any card in Present deck
2. Observe card disappearance animation
3. Notice brief pause before card fades

**Workaround:**
None needed - cosmetic issue only

**Fix Status:** [ ] Not Started

**Notes:**
Likely caused by synchronous card effect execution. Consider async card animations.

---

## 🔧 Architecture Improvements

These are not bugs, but areas where the architecture could be improved:

### 1. Extract Carousel System
**Priority:** Medium
**Effort:** Medium (2-4 hours)

**Current State:**
Carousel logic is embedded in `GameController._carousel_slide_animation()` (lines 465-547)

**Proposed:**
Extract into `TimelineCarousel` system:
```
scripts/systems/timeline_carousel.gd
- Manages carousel positions
- Handles slide animations
- Manages panel rotation
- Updates panel types
```

**Benefits:**
- Reduces GameController from 1,155 lines to ~1,000 lines
- Improves separation of concerns
- Easier to test carousel in isolation

---

### 2. Extract UI Management
**Priority:** Medium
**Effort:** Large (4-6 hours)

**Current State:**
UI updates scattered across GameController:
- `_update_timer_display()` (line 1037)
- `_update_wave_counter()` (line 1049)
- `_update_damage_display()` (line 1053)
- `_hide_ui_for_carousel()` (line 1059)
- `_show_ui_after_carousel()` (line 1077)

**Proposed:**
Extract into `UIController` system:
```
scripts/controllers/ui_controller.gd
- Manages all UI labels (timer, wave, damage)
- Handles UI show/hide during animations
- Responds to Events for UI updates
```

**Benefits:**
- Further reduces GameController complexity
- Centralizes all UI logic
- Easier to modify UI without touching game logic

---

### 3. Create TurnManager
**Priority:** Low
**Effort:** Large (6-8 hours)

**Current State:**
Turn flow logic in `GameController._execute_complete_turn()` (lines 371-462)

**Proposed:**
Extract into `TurnManager` system:
```
scripts/managers/turn_manager.gd
- Orchestrates turn phases
- Manages turn state machine
- Handles turn flow: pre-combat → combat → carousel → post-combat
```

**Benefits:**
- GameController becomes pure coordinator
- Turn flow easier to modify (add/remove phases)
- Better testability

---

### 4. Add VFXManager
**Priority:** Low
**Effort:** Small (1-2 hours)

**Current State:**
Screen shake logic in `GameController._apply_screen_shake()` and `_process()` (lines 1012, 1104)

**Proposed:**
Extract into `VFXManager` system:
```
scripts/managers/vfx_manager.gd
- Handles screen shake
- Manages hit reactions
- Handles particle effects (if added)
```

**Benefits:**
- Clean separation of visual effects
- Easier to add more VFX in future
- Can disable VFX for low-end devices

---

## ⚡ Performance Notes

*To be filled after performance testing*

### Load Time
- **OLD (main.tscn):** ________ seconds
- **NEW (main_refactored.tscn):** ________ seconds
- **Difference:** ________ seconds
- **Status:** [ ] ✅ Acceptable [ ] ⚠️ Needs investigation [ ] ❌ Regression

**Notes:**
```


```

---

### Frame Rate (FPS)
- **OLD Idle FPS:** ________ fps
- **NEW Idle FPS:** ________ fps
- **OLD Combat FPS:** ________ fps
- **NEW Combat FPS:** ________ fps
- **Status:** [ ] ✅ Acceptable [ ] ⚠️ Needs investigation [ ] ❌ Regression

**Notes:**
```


```

---

### Memory Usage
- **OLD Initial Memory:** ________ MB
- **NEW Initial Memory:** ________ MB
- **OLD After 5 Turns:** ________ MB
- **NEW After 5 Turns:** ________ MB
- **Status:** [ ] ✅ Acceptable [ ] ⚠️ Needs investigation [ ] ❌ Memory leak

**Notes:**
```


```

---

### Turn Execution Time
- **OLD Average:** ________ seconds
- **NEW Average:** ________ seconds
- **Difference:** ________ seconds
- **Status:** [ ] ✅ Acceptable [ ] ⚠️ Needs investigation [ ] ❌ Regression

**Notes:**
```


```

---

## 🔮 Future Enhancements

These are ideas for future improvements, not current issues:

### 1. Save/Load System
**Priority:** Medium
**Effort:** Large

Implement game state persistence:
- Save current turn, HP, card states
- Load saved games
- Multiple save slots

---

### 2. Card Animation System
**Priority:** Low
**Effort:** Medium

Add visual flair to card plays:
- Card fly animations
- Card glow on hover
- Particle effects on powerful cards

---

### 3. Enemy AI Variety
**Priority:** Medium
**Effort:** Large

Add different enemy behaviors:
- Some enemies attack strongest target
- Some enemies prioritize low-HP targets
- Boss enemies with special behaviors

---

### 4. Audio System
**Priority:** High
**Effort:** Medium

Add sound effects and music:
- Combat sounds
- Card play sounds
- Background music
- UI feedback sounds

---

### 5. Ability System
**Priority:** High
**Effort:** Large

Expand card effects beyond instant/targeting:
- AOE effects (hit all enemies)
- Status effects (poison, stun, shield)
- Multi-turn effects
- Conditional effects

---

## 📈 Code Quality Metrics

*To be filled after code review*

### File Sizes

| File | Lines | Status | Notes |
|------|-------|--------|-------|
| game_controller.gd | 1,155 | [ ] ✅ [ ] ⚠️ [ ] ❌ | Target: < 1,200 |
| combat_resolver.gd | _____ | [ ] ✅ [ ] ⚠️ [ ] ❌ | Target: < 400 |
| card_manager.gd | _____ | [ ] ✅ [ ] ⚠️ [ ] ❌ | Target: < 400 |
| targeting_system.gd | _____ | [ ] ✅ [ ] ⚠️ [ ] ❌ | Target: < 400 |

**Criteria:**
- ✅ Under target
- ⚠️ Slightly over target (< 50 lines)
- ❌ Significantly over target (> 50 lines)

---

### Complexity Metrics

| System | Complexity | Status | Notes |
|--------|------------|--------|-------|
| GameController | Medium-High | [ ] ✅ [ ] ⚠️ [ ] ❌ | Could extract carousel, UI |
| CombatResolver | Low | [ ] ✅ [ ] ⚠️ [ ] ❌ | Single responsibility |
| CardManager | Medium | [ ] ✅ [ ] ⚠️ [ ] ❌ | Well-structured |
| TargetingSystem | Low | [ ] ✅ [ ] ⚠️ [ ] ❌ | Single responsibility |

**Criteria:**
- ✅ Low complexity, easy to understand
- ⚠️ Medium complexity, could be simplified
- ❌ High complexity, needs refactoring

---

## 🧪 Test Coverage Gaps

These areas have limited or no test coverage:

### 1. All Card Types
**Current:** Only "Meal Time" and "Chrono Strike" tested
**Missing:** Need tests for all 15+ cards in database

---

### 2. Edge Cases
**Missing Tests:**
- All enemies dead mid-combat
- Player at exactly 1 HP
- Timer expires during targeting mode
- Multiple cards played in same turn

---

### 3. Wave Progression
**Current:** Only tested Wave 1
**Missing:** Wave 2-10 progression, difficulty scaling

---

### 4. Multi-Turn Effects
**Missing:** Cards that affect multiple turns (if any exist)

---

### 5. Error Recovery
**Missing:**
- What happens if script error during combat?
- What happens if entity deleted during animation?
- What happens if scene tree corrupted?

---

## 📝 Developer Notes

### Known Limitations

1. **Carousel Hardcoded:**
   - 6 panels hardcoded (lines 148-166 in game_controller.gd)
   - Changing panel count requires code changes
   - Could be made data-driven

2. **Grid Size Hardcoded:**
   - 4x4 grid assumed in many places
   - Changing grid size requires widespread changes
   - Could be configurable

3. **Event Dependencies:**
   - Some systems tightly coupled via Events
   - Changing event signatures breaks multiple systems
   - Need versioned event system or better documentation

---

### Technical Debt

**Low Priority Items:**

1. **Magic Numbers:**
   - Animation durations (0.6s) hardcoded
   - Screen shake decay (0.1) hardcoded
   - Should be constants or configurable

2. **Backwards Compatibility:**
   - `panel.state` dictionary still maintained for legacy systems
   - Can be removed once all systems use `EntityData`

3. **Debug Prints:**
   - Many `print()` statements for debugging
   - Should use proper logging system with levels (INFO, WARN, ERROR)

---

## 🎯 Prioritization

**If limited time, focus on:**

1. **Critical Bugs First:** Fix any game-breaking issues
2. **Performance Issues:** Address any FPS < 30 or memory leaks
3. **High-Priority Enhancements:** Audio, save/load
4. **Architecture Improvements:** Only if blocking future work

**Can Wait:**
- Cosmetic issues
- Low-priority enhancements
- Code quality improvements (unless blocking)

---

## ✅ Issue Resolution

When an issue is fixed:

1. **Update this document:**
   - Change status to "Fixed"
   - Add fix date
   - Link to commit that fixed it

2. **Add regression test:**
   - Add test case to prevent re-occurrence
   - Document in `MANUAL_TEST_CHECKLIST.md`

3. **Close related GitHub issues:**
   - Reference this document in issue
   - Link issue number here

---

## 📊 Issue Statistics

*To be updated as issues are discovered and fixed*

**Total Issues Tracked:** 0
- 🔴 Critical: 0
- 🟡 High: 0
- 🟠 Medium: 0
- 🟢 Low: 0

**Resolved Issues:** 0
**Open Issues:** 0

**Average Time to Fix:**
- Critical: N/A
- High: N/A
- Medium: N/A
- Low: N/A

---

**This document is living and should be updated regularly as issues are discovered and fixed.**

**Maintained By:** Development Team
**Review Frequency:** Weekly during active development
