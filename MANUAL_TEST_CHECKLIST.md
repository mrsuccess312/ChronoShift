# ChronoShift - Manual Integration Test Checklist

**Purpose:** Systematic testing of refactored game architecture
**Scene to Test:** `scenes/main_refactored.tscn`
**Testing Mode:** Manual (run in Godot Editor with F6)

---

## 🎯 Pre-Test Setup

### Before You Begin
- [ ] Open project in Godot 4.x
- [ ] Ensure no compile errors in Output panel
- [ ] Open `scenes/main_refactored.tscn`
- [ ] Clear Output panel (Right-click > Clear)
- [ ] Prepare to monitor console output for debug messages

### Expected Initial State
- [ ] Game loads without errors
- [ ] Player visible in center grid
- [ ] 2 enemies visible on grid
- [ ] Cards visible in 3 decks (Past, Present, Future)
- [ ] PLAY button enabled
- [ ] Timer shows "1:00" or configured max time
- [ ] Wave counter shows "Wave 1/10"

---

## ✅ TEST 1: FULL GAME LOOP

**Goal:** Verify complete turn cycle works end-to-end

### Steps
1. **Start Game**
   - [ ] Press F6 in Godot to run `main_refactored.tscn`
   - [ ] Wait 2 seconds for initialization
   - [ ] Verify console shows: `✅ GameController ready!`

2. **Initial State Check**
   - [ ] Player entity visible with HP bar
   - [ ] Enemy entities visible with HP/DMG labels
   - [ ] Cards are visible and interactive
   - [ ] Timer is counting down

3. **Play Instant Card (Meal Time)**
   - [ ] Locate "Meal Time" card in Present deck
   - [ ] Note current player HP: **_____**
   - [ ] Click "Meal Time" card
   - [ ] Verify card plays immediately (should disappear from deck)
   - [ ] Verify player HP increases
   - [ ] New player HP: **_____**
   - [ ] HP should increase by amount shown on card

4. **Execute Turn**
   - [ ] Click **PLAY** button
   - [ ] Button should disable during turn execution
   - [ ] Watch console for event flow (see Event Flow section)

5. **Combat Phase**
   - [ ] Verify combat animations play
   - [ ] Player attack animation should occur
   - [ ] Enemy attack animations should occur
   - [ ] HP values should update
   - [ ] Screen shake effect on hits
   - [ ] Damage numbers appear (if implemented)

6. **Carousel Animation**
   - [ ] After combat, carousel should slide
   - [ ] Panels should smoothly move positions
   - [ ] Colors should transition:
     - Old Present → becomes Past (blue → brown)
     - Old Future → becomes Present (purple → blue)
     - New Future appears (purple)
   - [ ] Animation duration: ~0.6 seconds

7. **Post-Turn Verification**
   - [ ] New turn started (check console)
   - [ ] Timer reset to max time (1:00 or configured value)
   - [ ] PLAY button re-enabled
   - [ ] Past panel shows previous turn state
   - [ ] Present panel shows current state
   - [ ] Future panel shows prediction
   - [ ] Cards recycled (new cards appear in Present deck)

### Expected Console Output
```
=================================================
  EXECUTING TURN
=================================================

  [EVENT] combat_started
  [CombatResolver] Player team attacks...
  [CombatResolver] <Player> → <Enemy> (<HP>/<MaxHP>)
  [EVENT] damage_dealt
  [EVENT] player_attacked
  [CombatResolver] Enemy team attacks...
  [EVENT] enemy_attacked
  [EVENT] damage_dealt
  [EVENT] combat_ended
  🎠 Carousel slide animation...
  ✅ Carousel slide complete
  🔮 Recalculating Future timeline...
  ✅ Future recalculated
  ✅ Turn complete
```

### ✅ TEST 1 RESULT
- [ ] **PASS** - All steps completed without errors
- [ ] **FAIL** - Errors encountered (document below)

**Errors/Issues:**
```


```

---

## ✅ TEST 2: TARGETING CARD SYSTEM

**Goal:** Verify targeting cards work correctly

### Steps

1. **Ensure Sufficient Time**
   - [ ] If timer < 12 seconds, wait for new turn or modify in code
   - [ ] Chrono Strike costs 12 seconds (or check actual cost)
   - [ ] Current time: **_____**

2. **Locate Targeting Card**
   - [ ] Find "Chrono Strike" card in Present deck
   - [ ] Card should show targeting icon or "Target: Enemy"
   - [ ] Note card cost: **_____** seconds

3. **Pre-Attack State**
   - [ ] Select an enemy to target
   - [ ] Note enemy HP before attack: **_____**
   - [ ] Note enemy name: **_____**

4. **Execute Targeting Card**
   - [ ] Click "Chrono Strike" card
   - [ ] Targeting mode should activate
   - [ ] Valid targets should highlight (glow/outline)
   - [ ] Cursor may change to targeting reticle
   - [ ] Console shows: `[EVENT] card_targeting_started`

5. **Select Target**
   - [ ] Click on highlighted enemy
   - [ ] Console shows: `[EVENT] card_targeting_completed`
   - [ ] Card effect should execute immediately
   - [ ] Arrow may appear showing targeting

6. **Verify Damage Applied**
   - [ ] Enemy HP should decrease
   - [ ] New enemy HP: **_____**
   - [ ] Damage dealt: **_____**
   - [ ] Matches card description: [ ] Yes [ ] No
   - [ ] Future timeline should update (shows predicted state after this damage)

7. **Verify Future Recalculation**
   - [ ] Console shows: `🔄 Future recalculation requested...`
   - [ ] Future timeline visuals update
   - [ ] Arrows may change direction if enemy died

### Expected Console Output
```
🃏 Playing targeting card: Chrono Strike
  [EVENT] card_targeting_started
  [EVENT] targeting_mode_entered
  🎯 Targeting mode activated
  [EVENT] target_selected
  [EVENT] card_targeting_completed
  ⚔️ Applying damage: 20 to <Enemy>
  [EVENT] damage_dealt
  [EVENT] card_played
  🔄 Future recalculation requested...
  ✅ Future recalculated
```

### Edge Cases to Test
- [ ] **Cancel Targeting**: Press ESC during targeting mode
  - Should cancel and return card to deck
- [ ] **Click Invalid Target**: Click non-enemy entity
  - Should not execute, remain in targeting mode
- [ ] **Click Empty Space**: Click outside any entity
  - Should cancel targeting mode

### ✅ TEST 2 RESULT
- [ ] **PASS** - Targeting works correctly
- [ ] **FAIL** - Issues encountered (document below)

**Errors/Issues:**
```


```

---

## ✅ TEST 3: MULTIPLE TURNS (3 FULL CYCLES)

**Goal:** Verify game state consistency across multiple turns

### Turn 1

**Before Turn 1:**
- [ ] Turn number: **_____**
- [ ] Player HP: **_____**
- [ ] Enemy #1 HP: **_____**
- [ ] Enemy #2 HP: **_____**
- [ ] Present deck card count: **_____**

**Execute Turn 1:**
- [ ] Click PLAY button
- [ ] Combat executes
- [ ] Carousel slides
- [ ] Turn completes

**After Turn 1:**
- [ ] Turn number: **_____** (should increment by 1)
- [ ] Player HP: **_____**
- [ ] Enemy #1 HP: **_____**
- [ ] Enemy #2 HP: **_____**
- [ ] Timer reset: [ ] Yes [ ] No
- [ ] Cards recycled: [ ] Yes [ ] No
- [ ] Present deck card count: **_____**

**Timeline Verification:**
- [ ] **Past panel** shows previous turn state
  - Entities present: [ ] Yes [ ] No
  - HP values frozen: [ ] Yes [ ] No
  - No damage labels on enemies: [ ] Correct
- [ ] **Present panel** is active timeline
  - Entities clickable: [ ] Yes [ ] No
  - HP/DMG labels visible: [ ] Yes [ ] No
  - Arrows visible (green for player): [ ] Yes [ ] No
- [ ] **Future panel** shows prediction
  - Entities have predicted HP: [ ] Yes [ ] No
  - Dead entities grayed out: [ ] Yes [ ] No
  - Arrows visible (red for enemies): [ ] Yes [ ] No

---

### Turn 2

**Before Turn 2:**
- [ ] Turn number: **_____**
- [ ] Player HP: **_____**
- [ ] Enemy #1 HP: **_____**
- [ ] Enemy #2 HP: **_____**

**Execute Turn 2:**
- [ ] Click PLAY button
- [ ] Combat executes
- [ ] Carousel slides
- [ ] Turn completes

**After Turn 2:**
- [ ] Turn number: **_____** (should increment by 1)
- [ ] Player HP: **_____**
- [ ] Timer reset: [ ] Yes [ ] No
- [ ] Cards recycled: [ ] Yes [ ] No

**Timeline Verification:**
- [ ] Past shows Turn 1 state
- [ ] Present shows Turn 2 state
- [ ] Future shows Turn 3 prediction
- [ ] Carousel history preserved: [ ] Yes [ ] No

---

### Turn 3

**Before Turn 3:**
- [ ] Turn number: **_____**
- [ ] Player HP: **_____**

**Execute Turn 3:**
- [ ] Click PLAY button
- [ ] Combat executes
- [ ] Carousel slides
- [ ] Turn completes

**After Turn 3:**
- [ ] Turn number: **_____** (should increment by 1)
- [ ] Player HP: **_____**
- [ ] Timer reset: [ ] Yes [ ] No
- [ ] Cards recycled: [ ] Yes [ ] No

### Cross-Turn Consistency Checks

- [ ] **Turn counter increments correctly** each turn
- [ ] **Player HP changes are persistent** (doesn't reset unexpectedly)
- [ ] **Enemy HP changes are persistent**
- [ ] **Dead enemies stay dead** (don't respawn)
- [ ] **Cards recycle** into deck each turn
- [ ] **Timer resets** to max time each turn
- [ ] **Past timeline never changes** once set (history is immutable)
- [ ] **Future updates** each turn to reflect new Present state
- [ ] **No memory leaks** (entities don't duplicate, arrows don't accumulate)

### Performance Check
- [ ] Frame rate stable (no significant drops)
- [ ] Animations smooth across all 3 turns
- [ ] No console errors/warnings
- [ ] Memory usage stable (check Debugger > Monitors)

### ✅ TEST 3 RESULT
- [ ] **PASS** - 3 turns completed successfully
- [ ] **FAIL** - Issues encountered (document below)

**Errors/Issues:**
```


```

---

## ✅ TEST 4: GAME OVER CONDITION

**Goal:** Verify game over state is handled correctly

### Setup
- [ ] Play game until player HP is low (< 20 HP)
- OR
- [ ] Manually reduce player HP in code for testing

### Trigger Game Over

**Method 1: Natural Death**
1. [ ] Let enemies reduce player HP to 0 or below
2. [ ] Execute turn via PLAY button
3. [ ] Watch combat phase

**Method 2: Manual Testing** (modify code temporarily)
```gdscript
# In game_controller.gd, add this to _execute_complete_turn() before Phase 5:
var player_entity = _get_player_entity(present_panel)
if player_entity:
    player_entity.hp = 0
```

### Verify Game Over Behavior

**Immediate Effects:**
- [ ] Console shows: `💀 GAME OVER`
- [ ] PLAY button disabled: [ ] Yes [ ] No
- [ ] PLAY button text changes to "GAME OVER": [ ] Yes [ ] No
- [ ] `GameState.game_over` set to `true`
- [ ] Timer stops counting down: [ ] Yes [ ] No

**UI State:**
- [ ] Cards become non-interactive (grayed out or disabled)
- [ ] Cannot click entities
- [ ] Cannot click grid cells
- [ ] All hover effects disabled
- [ ] Wave counter still visible
- [ ] Player HP shows 0

**No Crashes:**
- [ ] Game doesn't crash
- [ ] No null reference errors in console
- [ ] Can still interact with Godot editor
- [ ] Scene tree intact

**Event Flow:**
- [ ] Console shows: `[EVENT] game_over`
- [ ] No further combat events trigger
- [ ] No carousel animation after game over

### Optional: Recovery Testing
- [ ] Restart scene (F6 again)
- [ ] Game initializes normally: [ ] Yes [ ] No
- [ ] Can play again: [ ] Yes [ ] No

### ✅ TEST 4 RESULT
- [ ] **PASS** - Game over handled gracefully
- [ ] **FAIL** - Issues encountered (document below)

**Errors/Issues:**
```


```

---

## ✅ TEST 5: EVENT FLOW VERIFICATION

**Goal:** Verify events fire in correct order and with correct data

### Setup
- [ ] Clear console output (Right-click > Clear Output)
- [ ] Enable verbose logging if available
- [ ] Run game (F6)

### Expected Event Order - Full Turn

**Initialization:**
```
Events singleton initialized
ChronoShift - GameController Initializing...
✅ GameController ready!
```

**Card Play (Instant):**
```
[EVENT] card_played
[EVENT] future_recalculation_requested
🔄 Future recalculation requested...
✅ Future recalculated
```

**Card Play (Targeting):**
```
[EVENT] card_targeting_started
[EVENT] targeting_mode_entered
[EVENT] target_selected
[EVENT] card_targeting_completed
[EVENT] damage_dealt
[EVENT] card_played
[EVENT] future_recalculation_requested
```

**Turn Execution:**
```
=================================================
  EXECUTING TURN
=================================================

[EVENT] combat_started
  Player team attacks...
  [EVENT] player_attacked
  [EVENT] damage_dealt
  Enemy team attacks...
  [EVENT] enemy_attacked
  [EVENT] damage_dealt
[EVENT] combat_ended

🎠 Carousel slide animation...
[EVENT] carousel_slide_started (if implemented)
✅ Carousel slide complete
[EVENT] carousel_slide_completed (if implemented)

🔮 Recalculating Future timeline...
[EVENT] future_calculated
✅ Future recalculated

[EVENT] turn_ended
[EVENT] turn_started (next turn)
[EVENT] timer_updated

✅ Turn complete
```

### Event Sequence Verification

**Check these event orders are ALWAYS maintained:**

1. **Combat Sequence:**
   - [ ] `combat_started` → `damage_dealt` → `combat_ended`
   - [ ] Never: `damage_dealt` before `combat_started`
   - [ ] Never: `combat_ended` before all `damage_dealt`

2. **Carousel Sequence:**
   - [ ] Combat ends → Carousel starts → Carousel ends → Future recalc
   - [ ] Never: Future recalc before carousel completes
   - [ ] Never: New turn starts before carousel completes

3. **Card Targeting Sequence:**
   - [ ] `card_targeting_started` → `target_selected` → `card_targeting_completed`
   - [ ] OR: `card_targeting_started` → `card_targeting_cancelled` (if ESC pressed)
   - [ ] Never: `card_played` before `card_targeting_completed`

4. **Turn Sequence:**
   - [ ] `turn_ended` → `carousel_slide` → `turn_started` (next)
   - [ ] Turn numbers increment sequentially (1 → 2 → 3, never skip)

### Event Frequency Check

**Play 3 full turns and count:**

- `combat_started`: **_____** (should be 3)
- `combat_ended`: **_____** (should be 3)
- `damage_dealt`: **_____** (varies, but should be > 0)
- `turn_started`: **_____** (should be 3 or 4 including initial)
- `turn_ended`: **_____** (should be 3)
- `card_played`: **_____** (depends on cards you played)
- `future_recalculation_requested`: **_____** (should equal card plays)

### Event Data Verification

**For `damage_dealt` events:**
- [ ] Target is valid Node2D (not null)
- [ ] Damage value is > 0
- [ ] Target's HP decreases after event

**For `card_played` events:**
- [ ] `card_data` Dictionary is not empty
- [ ] `card_data.name` is a valid string
- [ ] `card_data.cost` is a number

**For `timer_updated` events:**
- [ ] `time_remaining` is >= 0
- [ ] `time_remaining` decreases over time (until reset)

### ✅ TEST 5 RESULT
- [ ] **PASS** - Events fire in correct order
- [ ] **FAIL** - Event sequence issues (document below)

**Errors/Issues:**
```


```

---

## 🐛 Common Issues & Troubleshooting

### Issue: Cards Not Responding to Clicks
**Symptoms:** Clicking cards does nothing
**Causes:**
- Cards have `mouse_filter = IGNORE` during animations
- Targeting mode is active but not visible
- Card cost > available time

**Debug:**
```gdscript
# In card.gd or card_manager.gd, add:
print("Card clicked: ", card_data.name)
print("Mouse filter: ", mouse_filter)
print("Cost: ", card_data.cost, " | Time: ", GameState.time_remaining)
```

**Fix:**
- Wait for animations to complete
- Press ESC to cancel any active targeting
- Check timer has enough time for card cost

---

### Issue: Carousel Doesn't Slide
**Symptoms:** PLAY button pressed but carousel doesn't move
**Causes:**
- Tween not completing
- Timeline panels not properly initialized
- Animation blocked by error

**Debug:**
- Check console for errors during `_carousel_slide_animation()`
- Verify `timeline_panels.size() == 6`
- Check `carousel_positions.size() == 6`

**Fix:**
- Ensure no errors in console before pressing PLAY
- Verify all 6 panels exist in scene tree

---

### Issue: Entities Disappear or Duplicate
**Symptoms:** Entities vanish or appear multiple times
**Causes:**
- Entity nodes not properly cleared before recreation
- `entity_data_list` and `entity_nodes` out of sync

**Debug:**
```gdscript
# In game_controller.gd, add to _create_timeline_entities():
print("Creating entities for panel: ", tp.timeline_type)
print("Entity data count: ", tp.entity_data_list.size())
print("Existing entity nodes: ", tp.entity_nodes.size())
```

**Fix:**
- Ensure `panel.clear_entities()` is called before creating new ones
- Verify `entity_data_list` has correct entries

---

### Issue: Future Timeline Shows Wrong HP
**Symptoms:** Future predictions don't match expected values
**Causes:**
- Combat simulation logic incorrect
- Target calculation wrong
- Entity data not duplicated properly

**Debug:**
- Check `_simulate_combat()` output
- Verify `TargetCalculator.calculate_targets()` is called
- Ensure entities are duplicated, not referenced

---

### Issue: Game Freezes During Combat
**Symptoms:** Game becomes unresponsive when clicking during combat
**Causes:**
- Input not disabled during animations
- Grid cells still interactive during combat
- Cards still clickable during turn execution

**Debug:**
- Check if `_disable_all_input()` is called before combat
- Verify `_enable_all_input()` is called after turn completes

**Fix:**
- Ensure `set_grid_interactive(false)` is called before combat
- Ensure `mouse_filter = MOUSE_FILTER_IGNORE` on cards during turn

---

## 📊 Test Summary Report

**Date:** ______________________
**Tester:** ______________________
**Godot Version:** ______________________
**Branch/Commit:** ______________________

### Overall Results

| Test | Status | Notes |
|------|--------|-------|
| Test 1: Full Game Loop | ⬜ Pass ⬜ Fail | |
| Test 2: Targeting Card | ⬜ Pass ⬜ Fail | |
| Test 3: Multiple Turns | ⬜ Pass ⬜ Fail | |
| Test 4: Game Over | ⬜ Pass ⬜ Fail | |
| Test 5: Event Flow | ⬜ Pass ⬜ Fail | |

### Critical Issues Found
```
1.

2.

3.
```

### Minor Issues Found
```
1.

2.

3.
```

### Performance Observations
- **Frame Rate:** ________ FPS (average)
- **Turn Execution Time:** ________ seconds (average)
- **Memory Usage:** ________ MB
- **Console Errors:** ________ (count)

### Recommendation
- [ ] ✅ **APPROVE** - Ready for merge/production
- [ ] ⚠️ **APPROVE WITH MINOR FIXES** - Minor issues, not blocking
- [ ] ❌ **REJECT** - Critical issues, needs fixes
- [ ] 🔄 **ROLLBACK** - Too many issues, revert refactoring

### Next Steps
```


```

---

**Testing completed:** ______________________
**Sign-off:** ______________________
