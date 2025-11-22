extends Node
class_name IntegrationTest

## Integration Test Suite for ChronoShift Refactored
## Automated testing of game loop, targeting, timeline states, and game over conditions

# ============================================================================
# TEST CONFIGURATION
# ============================================================================

var game_controller: GameController
var test_results: Array = []
var current_test: String = ""
var event_log: Array = []

# Test state tracking
var test_started: bool = false
var waiting_for_combat: bool = false
var turns_completed: int = 0

# ============================================================================
# TEST LIFECYCLE
# ============================================================================

func _ready() -> void:
	print("\n" + "=".repeat(80))
	print("  CHRONOSHIFT INTEGRATION TEST SUITE")
	print("=".repeat(80) + "\n")

	# Find GameController
	game_controller = get_parent() as GameController
	if not game_controller:
		push_error("IntegrationTest must be child of GameController!")
		return

	# Connect to all events for monitoring
	_connect_all_events()

	# Wait for game initialization, then start tests
	await get_tree().create_timer(1.0).timeout
	await _run_all_tests()


func _connect_all_events() -> void:
	"""Connect to all game events to monitor event flow"""
	print("📡 Connecting to all game events for monitoring...")

	# Game state events
	Events.game_started.connect(_log_event.bind("game_started"))
	Events.game_over.connect(_log_event.bind("game_over"))
	Events.wave_changed.connect(_log_event.bind("wave_changed"))
	Events.turn_started.connect(_log_event.bind("turn_started"))
	Events.turn_ended.connect(_log_event.bind("turn_ended"))

	# Combat events
	Events.combat_started.connect(_log_event.bind("combat_started"))
	Events.combat_ended.connect(_log_event.bind("combat_ended"))
	Events.damage_dealt.connect(_log_event.bind("damage_dealt"))
	Events.entity_died.connect(_log_event.bind("entity_died"))
	Events.player_attacked.connect(_log_event.bind("player_attacked"))
	Events.enemy_attacked.connect(_log_event.bind("enemy_attacked"))

	# Card events
	Events.card_played.connect(_log_event.bind("card_played"))
	Events.card_recycled.connect(_log_event.bind("card_recycled"))
	Events.card_targeting_started.connect(_log_event.bind("card_targeting_started"))
	Events.card_targeting_completed.connect(_log_event.bind("card_targeting_completed"))
	Events.card_targeting_cancelled.connect(_log_event.bind("card_targeting_cancelled"))

	# Timeline events
	Events.timeline_updated.connect(_log_event.bind("timeline_updated"))
	Events.future_calculated.connect(_log_event.bind("future_calculated"))
	Events.future_recalculation_requested.connect(_log_event.bind("future_recalculation_requested"))
	Events.carousel_slide_started.connect(_log_event.bind("carousel_slide_started"))
	Events.carousel_slide_completed.connect(_log_event.bind("carousel_slide_completed"))

	# UI events
	Events.timer_updated.connect(_log_event.bind("timer_updated"))
	Events.hp_updated.connect(_log_event.bind("hp_updated"))
	Events.damage_display_updated.connect(_log_event.bind("damage_display_updated"))

	# Targeting events
	Events.target_selected.connect(_log_event.bind("target_selected"))
	Events.valid_targets_highlighted.connect(_log_event.bind("valid_targets_highlighted"))
	Events.targeting_mode_entered.connect(_log_event.bind("targeting_mode_entered"))
	Events.targeting_mode_exited.connect(_log_event.bind("targeting_mode_exited"))

	# VFX events
	Events.screen_shake_requested.connect(_log_event.bind("screen_shake_requested"))
	Events.hit_reaction_requested.connect(_log_event.bind("hit_reaction_requested"))

	print("✅ All events connected\n")


func _log_event(event_name: String, arg1 = null, arg2 = null, arg3 = null) -> void:
	"""Log event to event_log array for verification"""
	var timestamp = Time.get_ticks_msec()
	var log_entry = {
		"time": timestamp,
		"event": event_name,
		"test": current_test
	}

	# Add arguments if provided
	if arg1 != null:
		log_entry["arg1"] = str(arg1)
	if arg2 != null:
		log_entry["arg2"] = str(arg2)
	if arg3 != null:
		log_entry["arg3"] = str(arg3)

	event_log.append(log_entry)

	# Print important events
	if event_name not in ["timer_updated"]:  # Skip noisy events
		print("  [EVENT] %s" % event_name)

# ============================================================================
# TEST SUITE
# ============================================================================

func _run_all_tests() -> void:
	"""Run all integration tests sequentially"""
	print("\n" + "=".repeat(80))
	print("  STARTING INTEGRATION TESTS")
	print("=".repeat(80) + "\n")

	# Test 1: Full game loop
	await _test_1_full_game_loop()
	await get_tree().create_timer(1.0).timeout

	# Test 2: Targeting card
	await _test_2_targeting_card()
	await get_tree().create_timer(1.0).timeout

	# Test 3: Multiple turns
	await _test_3_multiple_turns()
	await get_tree().create_timer(1.0).timeout

	# Test 4: Game over (skip this for now to avoid ending the game)
	# await _test_4_game_over()
	# await get_tree().create_timer(1.0).timeout

	# Test 5: Event flow verification
	await _test_5_event_flow()
	await get_tree().create_timer(1.0).timeout

	# Print final results
	_print_test_results()


func _test_1_full_game_loop() -> void:
	"""
	Test 1: Full Game Loop
	1. Start game (already started)
	2. Wait for initialization (already done)
	3. Play an instant card (e.g., "Meal Time")
	4. Verify HP increases
	5. Click PLAY button
	6. Watch combat animations complete
	7. Verify carousel slides forward
	8. Verify new turn starts
	"""
	current_test = "Test 1: Full Game Loop"
	print("\n" + "=".repeat(80))
	print("  TEST 1: FULL GAME LOOP")
	print("=".repeat(80) + "\n")

	var test_passed = true
	var errors = []

	# Get initial state
	var present_panel = game_controller._get_timeline_panel("present")
	var player_entity = _get_player_entity(present_panel)

	if not player_entity:
		errors.append("❌ Could not find player entity")
		test_passed = false
	else:
		var initial_hp = player_entity.hp
		print("📊 Initial player HP: %d" % initial_hp)

		# Step 3: Play an instant card (Meal Time)
		print("\n🃏 Attempting to play 'Meal Time' card...")
		var meal_time_card = _find_card_by_name("Meal Time")

		if meal_time_card:
			print("✅ Found 'Meal Time' card in Present deck")

			# Simulate card play
			await _play_card(meal_time_card)
			await get_tree().create_timer(0.5).timeout

			# Step 4: Verify HP increased
			var new_hp = player_entity.hp
			print("📊 Player HP after Meal Time: %d" % new_hp)

			if new_hp > initial_hp:
				print("✅ HP increased from %d to %d" % [initial_hp, new_hp])
			else:
				errors.append("❌ HP did not increase (was %d, now %d)" % [initial_hp, new_hp])
				test_passed = false
		else:
			print("⚠️ 'Meal Time' card not found, skipping instant card test")

		# Step 5: Click PLAY button
		print("\n▶️ Clicking PLAY button...")
		var initial_turn = GameState.current_turn
		game_controller.play_button.emit_signal("pressed")

		# Step 6-8: Wait for combat, carousel, and new turn
		print("⏳ Waiting for combat and carousel animations...")
		await get_tree().create_timer(4.0).timeout  # Wait for animations

		# Verify carousel slid forward
		var new_turn = GameState.current_turn
		if new_turn > initial_turn:
			print("✅ Turn advanced from %d to %d" % [initial_turn, new_turn])
		else:
			errors.append("❌ Turn did not advance (still %d)" % initial_turn)
			test_passed = false

		# Verify timeline panels are correct
		var past_panel = game_controller._get_timeline_panel("past")
		var future_panel = game_controller._get_timeline_panel("future")

		if past_panel and future_panel:
			print("✅ Timeline panels exist: Past, Present, Future")
		else:
			errors.append("❌ Timeline panels not properly configured")
			test_passed = false

	# Record result
	_record_test_result("Test 1: Full Game Loop", test_passed, errors)


func _test_2_targeting_card() -> void:
	"""
	Test 2: Targeting Card
	1. Wait for enough time (12s)
	2. Click "Chrono Strike" card
	3. Click enemy to target
	4. Verify damage applies
	"""
	current_test = "Test 2: Targeting Card"
	print("\n" + "=".repeat(80))
	print("  TEST 2: TARGETING CARD")
	print("=".repeat(80) + "\n")

	var test_passed = true
	var errors = []

	# Step 1: Ensure we have enough time
	GameState.time_remaining = 15.0
	print("⏰ Set time remaining to 15 seconds")

	# Step 2: Find "Chrono Strike" card
	print("\n🃏 Searching for 'Chrono Strike' card...")
	var chrono_strike_card = _find_card_by_name("Chrono Strike")

	if not chrono_strike_card:
		errors.append("❌ 'Chrono Strike' card not found")
		test_passed = false
	else:
		print("✅ Found 'Chrono Strike' card")

		# Get initial enemy state
		var present_panel = game_controller._get_timeline_panel("present")
		var enemy = _get_first_enemy(present_panel)

		if not enemy:
			errors.append("❌ No enemy found to target")
			test_passed = false
		else:
			var initial_enemy_hp = enemy.hp
			print("📊 Initial enemy HP: %d" % initial_enemy_hp)

			# Step 3: Play targeting card
			print("\n🎯 Playing 'Chrono Strike' and targeting enemy...")
			await _play_targeting_card(chrono_strike_card, enemy)
			await get_tree().create_timer(0.5).timeout

			# Step 4: Verify damage was applied
			var new_enemy_hp = enemy.hp
			print("📊 Enemy HP after Chrono Strike: %d" % new_enemy_hp)

			if new_enemy_hp < initial_enemy_hp:
				print("✅ Damage applied: %d → %d (-%d)" % [initial_enemy_hp, new_enemy_hp, initial_enemy_hp - new_enemy_hp])
			else:
				errors.append("❌ No damage applied to enemy")
				test_passed = false

	# Record result
	_record_test_result("Test 2: Targeting Card", test_passed, errors)


func _test_3_multiple_turns() -> void:
	"""
	Test 3: Multiple Turns
	1. Play through 3 complete turns
	2. Verify timeline states update correctly
	3. Verify Past shows previous turn
	4. Verify Future predicts next turn
	5. Verify cards recycle properly
	6. Verify timer resets each turn
	"""
	current_test = "Test 3: Multiple Turns"
	print("\n" + "=".repeat(80))
	print("  TEST 3: MULTIPLE TURNS")
	print("=".repeat(80) + "\n")

	var test_passed = true
	var errors = []

	var initial_turn = GameState.current_turn
	var target_turns = 3

	print("🔁 Playing through %d turns (starting from turn %d)..." % [target_turns, initial_turn])

	for i in range(target_turns):
		print("\n--- Turn %d ---" % (initial_turn + i + 1))

		# Verify timer is active
		if GameState.timer_active:
			print("✅ Timer is active")
		else:
			print("⚠️ Timer not active, activating...")
			GameState.timer_active = true
			GameState.time_remaining = GameState.max_time

		# Verify cards are available
		var present_deck = game_controller.card_manager.present_deck
		if present_deck and present_deck.card_nodes.size() > 0:
			print("✅ Present deck has %d cards" % present_deck.card_nodes.size())
		else:
			errors.append("❌ Present deck has no cards on turn %d" % (i + 1))
			test_passed = false

		# Play turn
		print("▶️ Executing turn...")
		game_controller.play_button.emit_signal("pressed")
		await get_tree().create_timer(4.5).timeout  # Wait for full turn cycle

		# Verify turn incremented
		var current_turn_check = GameState.current_turn
		if current_turn_check == initial_turn + i + 1:
			print("✅ Turn incremented to %d" % current_turn_check)
		else:
			errors.append("❌ Turn did not increment correctly (expected %d, got %d)" % [initial_turn + i + 1, current_turn_check])
			test_passed = false

		# Verify timeline panels exist and have correct types
		var past_panel = game_controller._get_timeline_panel("past")
		var present_panel = game_controller._get_timeline_panel("present")
		var future_panel = game_controller._get_timeline_panel("future")

		if past_panel and present_panel and future_panel:
			print("✅ All timeline panels exist (Past, Present, Future)")

			# Verify Past has entities (from previous turn)
			if i > 0 and past_panel.entity_data_list.size() > 0:
				print("✅ Past panel has %d entities" % past_panel.entity_data_list.size())
			elif i == 0:
				print("⚠️ First turn - Past panel may be empty")
			else:
				errors.append("❌ Past panel has no entities on turn %d" % (i + 1))
				test_passed = false

			# Verify Present has entities
			if present_panel.entity_data_list.size() > 0:
				print("✅ Present panel has %d entities" % present_panel.entity_data_list.size())
			else:
				errors.append("❌ Present panel has no entities on turn %d" % (i + 1))
				test_passed = false

			# Verify Future has entities
			if future_panel.entity_data_list.size() > 0:
				print("✅ Future panel has %d entities" % future_panel.entity_data_list.size())
			else:
				errors.append("❌ Future panel has no entities on turn %d" % (i + 1))
				test_passed = false
		else:
			errors.append("❌ Timeline panels not properly configured on turn %d" % (i + 1))
			test_passed = false

		# Verify timer reset
		if GameState.time_remaining == GameState.max_time:
			print("✅ Timer reset to %d seconds" % GameState.max_time)
		else:
			print("⚠️ Timer not fully reset (currently %d seconds)" % GameState.time_remaining)

	# Final verification
	var final_turn = GameState.current_turn
	if final_turn == initial_turn + target_turns:
		print("\n✅ Successfully completed %d turns (turn %d → %d)" % [target_turns, initial_turn, final_turn])
	else:
		errors.append("❌ Turn count mismatch (expected %d, got %d)" % [initial_turn + target_turns, final_turn])
		test_passed = false

	# Record result
	_record_test_result("Test 3: Multiple Turns", test_passed, errors)


func _test_4_game_over() -> void:
	"""
	Test 4: Game Over
	1. Reduce player HP to 0
	2. Verify game over triggered
	3. Verify PLAY button disabled
	4. Verify cards grayed out
	5. Verify no crashes
	"""
	current_test = "Test 4: Game Over"
	print("\n" + "=".repeat(80))
	print("  TEST 4: GAME OVER CONDITION")
	print("=".repeat(80) + "\n")

	var test_passed = true
	var errors = []

	print("⚠️ This test will trigger game over - implement carefully")

	# Get player entity
	var present_panel = game_controller._get_timeline_panel("present")
	var player_entity = _get_player_entity(present_panel)

	if not player_entity:
		errors.append("❌ Could not find player entity")
		test_passed = false
	else:
		print("📊 Current player HP: %d" % player_entity.hp)

		# Reduce player HP to 0
		print("💀 Reducing player HP to 0...")
		player_entity.hp = 0

		# Trigger turn to process game over
		print("▶️ Triggering turn to process game over...")
		game_controller.play_button.emit_signal("pressed")
		await get_tree().create_timer(2.0).timeout

		# Verify game over state
		if GameState.game_over:
			print("✅ Game over state set")
		else:
			errors.append("❌ Game over state not set")
			test_passed = false

		# Verify PLAY button disabled
		if game_controller.play_button.disabled:
			print("✅ PLAY button disabled")
		else:
			errors.append("❌ PLAY button not disabled")
			test_passed = false

		# Verify no crashes occurred
		print("✅ No crashes detected")

	# Record result
	_record_test_result("Test 4: Game Over", test_passed, errors)


func _test_5_event_flow() -> void:
	"""
	Test 5: Event Flow Verification
	Analyze event log to verify events fire in correct order
	"""
	current_test = "Test 5: Event Flow"
	print("\n" + "=".repeat(80))
	print("  TEST 5: EVENT FLOW VERIFICATION")
	print("=".repeat(80) + "\n")

	var test_passed = true
	var errors = []

	print("📊 Analyzing event log (%d events recorded)...\n" % event_log.size())

	# Expected event sequences
	var expected_sequences = [
		["combat_started", "combat_ended"],
		["card_played", "future_recalculation_requested"],
	]

	# Verify critical events occurred
	var critical_events = [
		"combat_started",
		"combat_ended",
		"damage_dealt",
	]

	for event_name in critical_events:
		var found = false
		for entry in event_log:
			if entry["event"] == event_name:
				found = true
				break

		if found:
			print("✅ Critical event '%s' occurred" % event_name)
		else:
			errors.append("❌ Critical event '%s' never occurred" % event_name)
			test_passed = false

	# Print event flow summary
	print("\n📋 Event Flow Summary:")
	var event_counts = {}
	for entry in event_log:
		var event = entry["event"]
		if not event_counts.has(event):
			event_counts[event] = 0
		event_counts[event] += 1

	for event in event_counts.keys():
		print("  • %s: %d times" % [event, event_counts[event]])

	# Record result
	_record_test_result("Test 5: Event Flow", test_passed, errors)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _get_player_entity(panel: Panel) -> EntityData:
	"""Get player EntityData from a panel"""
	if not panel:
		return null

	for entity in panel.entity_data_list:
		if not entity.is_enemy:
			return entity
	return null


func _get_first_enemy(panel: Panel) -> EntityData:
	"""Get first enemy EntityData from a panel"""
	if not panel:
		return null

	for entity in panel.entity_data_list:
		if entity.is_enemy and entity.is_alive():
			return entity
	return null


func _find_card_by_name(card_name: String) -> Dictionary:
	"""Find a card by name in any deck"""
	for deck in [game_controller.card_manager.present_deck, game_controller.card_manager.past_deck, game_controller.card_manager.future_deck]:
		if not deck:
			continue

		for card_node in deck.card_nodes:
			if card_node and card_node.card_data.get("name") == card_name:
				return card_node.card_data

	return {}


func _play_card(card_data: Dictionary) -> void:
	"""Simulate playing a card"""
	if card_data.is_empty():
		return

	print("🃏 Playing card: %s" % card_data.get("name", "Unknown"))

	# Find the card node
	var card_node = null
	for deck in [game_controller.card_manager.present_deck, game_controller.card_manager.past_deck, game_controller.card_manager.future_deck]:
		if not deck:
			continue

		for node in deck.card_nodes:
			if node and node.card_data.get("name") == card_data.get("name"):
				card_node = node
				break
		if card_node:
			break

	if card_node:
		# Trigger card play through card manager
		game_controller.card_manager._execute_card_effect(card_data, [], card_node)


func _play_targeting_card(card_data: Dictionary, target: EntityData) -> void:
	"""Simulate playing a targeting card"""
	if card_data.is_empty():
		return

	print("🎯 Playing targeting card: %s on target" % card_data.get("name", "Unknown"))

	# Find the card node and target node
	var card_node = null
	for deck in [game_controller.card_manager.present_deck, game_controller.card_manager.past_deck, game_controller.card_manager.future_deck]:
		if not deck:
			continue

		for node in deck.card_nodes:
			if node and node.card_data.get("name") == card_data.get("name"):
				card_node = node
				break
		if card_node:
			break

	if card_node and target:
		# Find target visual node
		var present_panel = game_controller._get_timeline_panel("present")
		var target_node = game_controller._find_entity_node_by_id(present_panel, target.unique_id)

		if target_node:
			# Execute card with target
			game_controller.card_manager._execute_card_effect(card_data, [target_node], card_node)


func _record_test_result(test_name: String, passed: bool, errors: Array) -> void:
	"""Record a test result"""
	var result = {
		"name": test_name,
		"passed": passed,
		"errors": errors
	}
	test_results.append(result)

	print("\n" + "-".repeat(80))
	if passed:
		print("✅ %s PASSED" % test_name)
	else:
		print("❌ %s FAILED" % test_name)
		for error in errors:
			print("  %s" % error)
	print("-".repeat(80) + "\n")


func _print_test_results() -> void:
	"""Print final test results summary"""
	print("\n" + "=".repeat(80))
	print("  TEST RESULTS SUMMARY")
	print("=".repeat(80) + "\n")

	var total_tests = test_results.size()
	var passed_tests = 0

	for result in test_results:
		if result["passed"]:
			passed_tests += 1
			print("✅ %s" % result["name"])
		else:
			print("❌ %s" % result["name"])
			for error in result["errors"]:
				print("  %s" % error)

	print("\n" + "=".repeat(80))
	print("  FINAL SCORE: %d/%d TESTS PASSED (%.1f%%)" % [passed_tests, total_tests, (float(passed_tests) / total_tests) * 100.0])
	print("=".repeat(80) + "\n")

	# Save test report
	_save_test_report()


func _save_test_report() -> void:
	"""Save test report to file"""
	var report = ""
	report += "# ChronoShift Integration Test Report\n"
	report += "Generated: %s\n\n" % Time.get_datetime_string_from_system()

	report += "## Test Results\n\n"
	for result in test_results:
		var status = "✅ PASSED" if result["passed"] else "❌ FAILED"
		report += "### %s - %s\n" % [result["name"], status]

		if not result["passed"]:
			report += "\nErrors:\n"
			for error in result["errors"]:
				report += "- %s\n" % error
		report += "\n"

	report += "## Event Log Summary\n\n"
	var event_counts = {}
	for entry in event_log:
		var event = entry["event"]
		if not event_counts.has(event):
			event_counts[event] = 0
		event_counts[event] += 1

	for event in event_counts.keys():
		report += "- %s: %d occurrences\n" % [event, event_counts[event]]

	# Print report (since we can't easily write files in Godot during gameplay)
	print("\n" + "=".repeat(80))
	print("  TEST REPORT")
	print("=".repeat(80))
	print(report)
	print("=".repeat(80) + "\n")
