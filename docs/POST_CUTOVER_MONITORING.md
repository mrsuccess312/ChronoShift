# Post-Cutover Monitoring Guide

**Purpose:** Monitor refactored architecture for stability after cutover
**Monitoring Period:** 1 week minimum
**Review Frequency:** Daily for week 1, then weekly

---

## 📅 MONITORING SCHEDULE

### Week 1 (Critical Period)

**Daily Checks (5-10 minutes per day):**
- [ ] Day 1: Comprehensive feature test
- [ ] Day 2: Combat and carousel test
- [ ] Day 3: Card system test
- [ ] Day 4: Targeting and events test
- [ ] Day 5: Performance and memory test
- [ ] Day 6: Edge cases test
- [ ] Day 7: Full playthrough (30+ minutes)

### Week 2-4 (Stability Period)

**Weekly Checks (15-20 minutes per week):**
- [ ] Week 2: Random feature testing
- [ ] Week 3: Stress testing (10+ turns)
- [ ] Week 4: Final verification

**After 1 Month:**
- ✅ Consider refactoring stable if no critical issues
- ✅ Delete legacy files
- ✅ Archive rollback documentation

---

## 🔍 DAILY MONITORING CHECKLIST

### Day 1: Comprehensive Feature Test

**Date:** ________________

**Test All Core Features:**

1. **Game Launch:**
   - [ ] Game opens without errors
   - [ ] Console shows "GameController Initializing..."
   - [ ] All UI elements visible
   - **Notes:**
   ```

   ```

2. **Combat System:**
   - [ ] Play 1 full turn
   - [ ] Combat animations play
   - [ ] Damage applies correctly
   - [ ] HP updates properly
   - **Notes:**
   ```

   ```

3. **Carousel System:**
   - [ ] Carousel slides smoothly
   - [ ] Timeline states update (Past/Present/Future)
   - [ ] Panel colors transition correctly
   - **Notes:**
   ```

   ```

4. **Card System:**
   - [ ] Instant card works ("Meal Time")
   - [ ] Targeting card works ("Chrono Strike")
   - [ ] Card recycling works
   - [ ] Affordability updates with timer
   - **Notes:**
   ```

   ```

5. **Performance:**
   - [ ] FPS stable (check Debugger → Monitors)
   - [ ] No stuttering or lag
   - [ ] Memory stable (not growing)
   - **FPS:** ________ | **Memory:** ________ MB
   - **Notes:**
   ```

   ```

**Issues Found:** [ ] None [ ] Minor [ ] Major [ ] Critical

**Action Taken:**
```


```

---

### Day 2: Combat and Carousel Test

**Date:** ________________

**Focus:** Combat logic and carousel animations

1. **Combat Sequences:**
   - [ ] Player attacks execute correctly
   - [ ] Enemy attacks execute correctly
   - [ ] Death handling works (entities removed)
   - [ ] Combat events fire in order
   - **Notes:**
   ```

   ```

2. **Carousel Behavior:**
   - [ ] Carousel slide duration acceptable (~0.6s)
   - [ ] No entities lost during slide
   - [ ] HP values persist correctly
   - [ ] Entity data transfers correctly
   - **Notes:**
   ```

   ```

3. **Multiple Turns:**
   - [ ] Play 5 complete turns
   - [ ] No errors in console
   - [ ] Game state consistent
   - **Notes:**
   ```

   ```

**Issues Found:** [ ] None [ ] Minor [ ] Major [ ] Critical

**Action Taken:**
```


```

---

### Day 3: Card System Test

**Date:** ________________

**Focus:** Card mechanics and effects

1. **All Card Types:**
   - [ ] Test at least 5 different cards
   - [ ] All effects apply correctly
   - [ ] No null reference errors
   - **Cards Tested:**
   ```
   1. ________________
   2. ________________
   3. ________________
   4. ________________
   5. ________________
   ```

2. **Card Affordability:**
   - [ ] Unaffordable cards grayed out
   - [ ] Affordability updates with timer
   - [ ] Can't play unaffordable cards
   - **Notes:**
   ```

   ```

3. **Card Recycling:**
   - [ ] Cards move to correct decks
   - [ ] No duplicate cards
   - [ ] No missing cards
   - **Notes:**
   ```

   ```

**Issues Found:** [ ] None [ ] Minor [ ] Major [ ] Critical

**Action Taken:**
```


```

---

### Day 4: Targeting and Events Test

**Date:** ________________

**Focus:** Targeting system and event flow

1. **Targeting Mode:**
   - [ ] Activates on targeting card click
   - [ ] Valid targets highlighted
   - [ ] Invalid targets not selectable
   - [ ] ESC cancels targeting
   - [ ] Empty click cancels targeting
   - **Notes:**
   ```

   ```

2. **Event Flow:**
   - [ ] Watch console for event order
   - [ ] `combat_started` before `damage_dealt`
   - [ ] `combat_ended` after all damage
   - [ ] No duplicate events
   - **Event Order Correct:** [ ] Yes [ ] No
   - **Notes:**
   ```

   ```

3. **Future Recalculation:**
   - [ ] Future updates after card play
   - [ ] Future shows predicted HP correctly
   - [ ] Dead entities grayed in Future
   - **Notes:**
   ```

   ```

**Issues Found:** [ ] None [ ] Minor [ ] Major [ ] Critical

**Action Taken:**
```


```

---

### Day 5: Performance and Memory Test

**Date:** ________________

**Focus:** Performance metrics and memory leaks

1. **Performance Measurement:**
   - **Initial FPS:** ________
   - **After 10 turns FPS:** ________
   - **Minimum FPS observed:** ________
   - **Frame drops:** [ ] None [ ] Occasional [ ] Frequent
   - **Notes:**
   ```

   ```

2. **Memory Tracking:**
   - **Initial Memory:** ________ MB
   - **After 10 turns:** ________ MB
   - **Memory growth:** ________ MB
   - **Memory leak detected:** [ ] No [ ] Possible [ ] Yes
   - **Notes:**
   ```

   ```

3. **Turn Execution Time:**
   - **Turn 1:** ________ seconds
   - **Turn 5:** ________ seconds
   - **Turn 10:** ________ seconds
   - **Average:** ________ seconds
   - **Acceptable:** [ ] Yes [ ] No
   - **Notes:**
   ```

   ```

**Issues Found:** [ ] None [ ] Minor [ ] Major [ ] Critical

**Action Taken:**
```


```

---

### Day 6: Edge Cases Test

**Date:** ________________

**Focus:** Edge cases and error handling

1. **Game Over:**
   - [ ] Trigger game over (player dies)
   - [ ] PLAY button disables
   - [ ] No crashes after game over
   - [ ] Can restart game
   - **Notes:**
   ```

   ```

2. **Empty Scenarios:**
   - [ ] All enemies dead (player only)
   - [ ] Try to execute turn
   - [ ] No errors
   - **Notes:**
   ```

   ```

3. **Timer Edge Cases:**
   - [ ] Let timer expire (don't click PLAY)
   - [ ] Auto-execute turn works
   - [ ] Timer resets correctly
   - **Notes:**
   ```

   ```

4. **Spam Clicking:**
   - [ ] Rapidly click cards
   - [ ] Rapidly click PLAY button
   - [ ] No crashes or freezes
   - **Notes:**
   ```

   ```

**Issues Found:** [ ] None [ ] Minor [ ] Major [ ] Critical

**Action Taken:**
```


```

---

### Day 7: Full Playthrough

**Date:** ________________

**Focus:** Extended play session (30+ minutes)

1. **Playthrough Stats:**
   - **Start Time:** ________
   - **End Time:** ________
   - **Total Duration:** ________ minutes
   - **Turns Played:** ________
   - **Waves Completed:** ________

2. **Overall Experience:**
   - [ ] Smooth gameplay throughout
   - [ ] No crashes
   - [ ] No freezes
   - [ ] Performance stable
   - [ ] Fun to play (subjective!)

3. **Observations:**
   ```




   ```

4. **Final Assessment:**
   - **Refactoring Quality:** [ ] Excellent [ ] Good [ ] Acceptable [ ] Poor
   - **Stability:** [ ] Very Stable [ ] Stable [ ] Unstable [ ] Broken
   - **Performance:** [ ] Better [ ] Same [ ] Worse [ ] Unacceptable

**Issues Found:** [ ] None [ ] Minor [ ] Major [ ] Critical

**Overall Week 1 Status:** [ ] ✅ Success [ ] ⚠️ Needs fixes [ ] ❌ Rollback needed

---

## 📊 WEEKLY SUMMARY (End of Week 1)

**Monitoring Period:** ________ to ________

**Days Tested:** _____ / 7

**Total Issues Found:**
- 🔴 Critical: _____
- 🟡 High: _____
- 🟠 Medium: _____
- 🟢 Low: _____

**Most Common Issue:**
```


```

**Performance Trends:**
- **FPS:** [ ] Stable [ ] Degrading [ ] Improving
- **Memory:** [ ] Stable [ ] Leaking [ ] Improving
- **Turn Time:** [ ] Stable [ ] Slower [ ] Faster

**Stability Assessment:**
- **Crashes:** _____ times
- **Freezes:** _____ times
- **Errors:** _____ times
- **Overall:** [ ] Very Stable [ ] Stable [ ] Unstable

**Recommendation:**
- [ ] ✅ Continue with refactored code
- [ ] ⚠️ Fix issues then continue
- [ ] ❌ Rollback to legacy code

**Next Steps:**
```


```

---

## 🐛 ISSUE TRACKING

### Issue Log Template

Use this template to document issues found during monitoring:

```markdown
### Issue #__: [Short Description]

**Discovered:** Day __ (Date: ______)
**Severity:** [ ] 🔴 Critical [ ] 🟡 High [ ] 🟠 Medium [ ] 🟢 Low

**Description:**
[What is the issue?]

**Steps to Reproduce:**
1.
2.
3.

**Expected Behavior:**
[What should happen?]

**Actual Behavior:**
[What actually happens?]

**Frequency:**
[ ] Always [ ] Frequent (>50%) [ ] Occasional [ ] Rare

**Workaround:**
[If any workaround exists]

**Impact:**
[ ] Blocks gameplay [ ] Degrades experience [ ] Cosmetic only

**Action Required:**
[ ] Immediate fix [ ] Fix this week [ ] Fix later [ ] Monitor

**Status:**
[ ] Open [ ] In Progress [ ] Fixed [ ] Won't Fix
```

---

## 📈 METRICS TRACKING

### Performance Metrics Over Time

| Day | FPS (avg) | FPS (min) | Memory (MB) | Turn Time (s) | Issues |
|-----|-----------|-----------|-------------|---------------|--------|
| 1   |           |           |             |               |        |
| 2   |           |           |             |               |        |
| 3   |           |           |             |               |        |
| 4   |           |           |             |               |        |
| 5   |           |           |             |               |        |
| 6   |           |           |             |               |        |
| 7   |           |           |             |               |        |

**Trends:**
- FPS: [ ] ↑ Improving [ ] → Stable [ ] ↓ Degrading
- Memory: [ ] ↑ Growing [ ] → Stable [ ] ↓ Decreasing
- Turn Time: [ ] ↑ Slower [ ] → Stable [ ] ↓ Faster

---

## ✅ STABILITY CRITERIA

### Week 1 Success Criteria

**Refactoring is STABLE if:**

- ✅ No critical issues found (crashes, data loss)
- ✅ High/medium issues < 3 total
- ✅ Performance acceptable (FPS > 30, no leaks)
- ✅ All core features work
- ✅ No regressions vs old code

**If stable:** Continue monitoring, proceed to Week 2

**If unstable:** Fix issues or consider rollback

---

### Month 1 Success Criteria

**After 1 month, refactoring is PRODUCTION-READY if:**

- ✅ 4 weeks of stable operation
- ✅ All critical issues resolved
- ✅ High priority issues resolved
- ✅ Performance stable or better
- ✅ User satisfaction acceptable
- ✅ No major bugs discovered

**If production-ready:**
- ✅ Delete legacy files
- ✅ Archive rollback documentation
- ✅ Consider refactoring complete

---

## 📞 ESCALATION

### When to Escalate

**Immediate Escalation (Critical):**
- 🔴 Game crashes on launch
- 🔴 Data corruption
- 🔴 Frequent crashes (>3 per session)
- 🔴 Performance < 15 FPS
- 🔴 Memory leak causing crashes

**Action:** Follow `ROLLBACK_INSTRUCTIONS.md` immediately

---

**Same Day Escalation (High):**
- 🟡 Core feature broken
- 🟡 Performance degradation (30-50 FPS)
- 🟡 Frequent errors (not crashes)

**Action:** Document in `KNOWN_ISSUES.md`, plan fix within 24 hours

---

**This Week Escalation (Medium):**
- 🟠 Minor feature broken
- 🟠 Visual glitches
- 🟠 Occasional errors

**Action:** Document in `KNOWN_ISSUES.md`, plan fix this week

---

**Later Escalation (Low):**
- 🟢 Cosmetic issues
- 🟢 Nice-to-have improvements
- 🟢 Documentation updates

**Action:** Document in `KNOWN_ISSUES.md`, backlog for later

---

## 📝 MONITORING NOTES

**Use this space for daily notes:**

### Day 1 Notes:
```


```

### Day 2 Notes:
```


```

### Day 3 Notes:
```


```

### Day 4 Notes:
```


```

### Day 5 Notes:
```


```

### Day 6 Notes:
```


```

### Day 7 Notes:
```


```

---

## 🎯 FINAL ASSESSMENT (End of Week 1)

**Overall Refactoring Success:** [ ] ✅ Success [ ] ⚠️ Partial [ ] ❌ Failed

**Stability:** [ ] Excellent [ ] Good [ ] Acceptable [ ] Poor

**Performance:** [ ] Better than old [ ] Same as old [ ] Worse than old

**Recommendation:**
- [ ] ✅ Continue with refactored architecture
- [ ] ⚠️ Fix issues then reassess
- [ ] ❌ Rollback to legacy architecture

**Justification:**
```


```

**Next Steps:**
```


```

---

**Monitoring Started:** ________________
**Monitoring Completed:** ________________
**Monitored By:** ________________

**Last Updated:** 2025-11-19
**Version:** 1.0
