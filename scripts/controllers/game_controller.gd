extends Node2D
class_name GameController

## GameController - Main game orchestrator
## Delegates to specialized systems instead of implementing everything
## This replaces the massive game_manager.gd with a slim coordinator

# ============================================================================
# SYSTEM REFERENCES
# ============================================================================

var combat_resolver: CombatResolver
var card_manager: CardManager
var targeting_system: TargetingSystem

# ============================================================================
# SCENE REFERENCES
# ============================================================================

const TIMELINE_PANEL_SCENE = preload("res://scenes/timeline_panel.tscn")
const ENTITY_SCENE = preload("res://scenes/entity.tscn")
const ARROW_SCENE = preload("res://scenes/arrow.tscn")

# ============================================================================
# TIMELINE & UI
# ============================================================================

var timeline_panels: Array = []
var carousel_positions: Array = []
var carousel_snapshot: Array = []

# UI Settings
var show_grid_lines: bool = false
var show_debug_grid: bool = false
var enable_panel_hover: bool = true

# ============================================================================
# NODE REFERENCES
# ============================================================================

@onready var carousel_container = $UIRoot/CarouselContainer
@onready var play_button = $UIRoot/PlayButton
@onready var timer_label = $UIRoot/TimerLabel
@onready var wave_counter_label = $UIRoot/WaveCounter/WaveLabel
@onready var damage_label = $UIRoot/DamageDisplay/DamageLabel
@onready var camera = $Camera2D
@onready var ui_root = $UIRoot

# Deck containers
@onready var past_deck_container = $UIRoot/DeckContainers/PastDeckContainer
@onready var present_deck_container = $UIRoot/DeckContainers/PresentDeckContainer
@onready var future_deck_container = $UIRoot/DeckContainers/FutureDeckContainer

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("  ChronoShift - GameController Initializing...")
	print("=".repeat(60) + "\n")

	# Setup carousel FIRST (creates timeline_panels)
	_setup_carousel()

	# THEN initialize systems (they need timeline_panels reference)
	_initialize_systems()

	# Initialize game state
	_initialize_game()

	# Connect events
	_connect_events()

	# Connect UI
	play_button.pressed.connect(_on_play_button_pressed)

	print("\n✅ GameController ready!\n")


func _initialize_systems() -> void:
	"""Create and configure all game systems"""
	print("🔧 Initializing systems...")

	# Combat system
	combat_resolver = CombatResolver.new()
	add_child(combat_resolver)
	# CRITICAL: Set timeline_panels AFTER adding as child
	combat_resolver.timeline_panels = timeline_panels
	print("  ✅ CombatResolver created")

	# Card system
	card_manager = CardManager.new()
	add_child(card_manager)
	# Set references AFTER adding as child
	card_manager.past_deck_container = past_deck_container
	card_manager.present_deck_container = present_deck_container
	card_manager.future_deck_container = future_deck_container
	card_manager.timeline_panels = timeline_panels
	card_manager.initialize_decks()
	print("  ✅ CardManager created")

	# Targeting system
	targeting_system = TargetingSystem.new()
	add_child(targeting_system)
	# Set references AFTER adding as child
	targeting_system.timeline_panels = timeline_panels
	targeting_system.ui_root = ui_root
	targeting_system.card_manager = card_manager
	targeting_system.initialize()
	print("  ✅ TargetingSystem created")

	print("  All systems initialized\n")


func _connect_events() -> void:
	"""Connect to global event bus"""
	Events.damage_dealt.connect(_on_damage_dealt)
	Events.combat_ended.connect(_on_combat_ended)
	Events.timer_updated.connect(_on_timer_updated)
	Events.wave_changed.connect(_on_wave_changed)
	Events.game_over.connect(_on_game_over)
	Events.screen_shake_requested.connect(_apply_screen_shake)
	Events.card_played.connect(_on_card_played)
	Events.future_recalculation_requested.connect(_on_future_recalculation_requested)
	print("  Events connected")

# ============================================================================
# CAROUSEL SETUP
# ============================================================================

func _setup_carousel() -> void:
	"""Initialize carousel with 6 dynamically created timeline panels"""
	print("🎠 Setting up carousel with 6 panels...")

	# Define carousel positions (extracted from game_manager.gd)
	carousel_positions = [
		{ "position": Vector2(0, 150), "scale": Vector2(0.6, 0.6), "modulate": Color(1.0, 1.0, 1.0, 1.0), "z_index": 0 },
		{ "position": Vector2(136, 125), "scale": Vector2(0.75, 0.75), "modulate": Color(1.0, 1.0, 1.0, 1.0), "z_index": 1 },
		{ "position": Vector2(660, 90), "scale": Vector2(1.0, 1.0), "modulate": Color(1.0, 1.0, 1.0, 1.0), "z_index": 2 },
		{ "position": Vector2(1184, 125), "scale": Vector2(0.75, 0.75), "modulate": Color(1.0, 1.0, 1.0, 1.0), "z_index": 1 },
		{ "position": Vector2(1320, 150), "scale": Vector2(0.6, 0.6), "modulate": Color(1.0, 1.0, 1.0, 1.0), "z_index": 0 },
		{ "position": Vector2(1300, 175), "scale": Vector2(0.5, 0.5), "modulate": Color(1.0, 1.0, 1.0, 0.7), "z_index": -1 }
	]

	# Create 6 timeline panel instances
	var panel_types = ["decorative", "past", "present", "future", "decorative", "decorative"]

	for i in range(6):
		var panel = TIMELINE_PANEL_SCENE.instantiate()
		panel.initialize(panel_types[i], i)

		# Apply styling based on type
		_apply_panel_styling(panel, panel_types[i], i)

		# Add to carousel container
		carousel_container.add_child(panel)

		# Apply carousel position
		_apply_carousel_position(panel, i)

		# Store in array
		timeline_panels.append(panel)

		print("  Created panel ", i, " (", panel_types[i], ")")

	# Move present panel to front for proper z-ordering
	if timeline_panels.size() > 2:
		carousel_container.move_child(timeline_panels[2], -1)

	# Set mouse filters and UI settings
	_update_panel_mouse_filters()
	_apply_ui_settings_to_panels()
	_build_carousel_snapshot()

	print("✅ Carousel initialized with ", timeline_panels.size(), " panels\n")


func _apply_panel_styling(panel: Panel, timeline_type: String, i: int) -> void:
	"""Apply visual styling to panel based on timeline type"""
	var stylebox = StyleBoxFlat.new()
	stylebox.border_width_left = 2
	stylebox.border_width_top = 2
	stylebox.border_width_right = 2
	stylebox.border_width_bottom = 2

	match timeline_type:
		"past":
			stylebox.bg_color = Color(0.24, 0.15, 0.08, 1)
			stylebox.border_color = Color(0.55, 0.44, 0.28, 1)
			_update_panel_label_text(panel, "⟲ PAST")
		"present":
			stylebox.bg_color = Color(0.12, 0.23, 0.37, 1)
			stylebox.border_color = Color(0.29, 0.62, 1, 1)
			_update_panel_label_text(panel, "◉ PRESENT")
		"future":
			stylebox.bg_color = Color(0.18, 0.11, 0.24, 1)
			stylebox.border_color = Color(0.71, 0.48, 1, 1)
			_update_panel_label_text(panel, "⟳ FUTURE")
		"decorative":
			# All decorative panels start with neutral gray/black colors
			stylebox.bg_color = Color(0.1, 0.1, 0.1, 1)
			stylebox.border_color = Color(0.3, 0.3, 0.3, 1)
			_update_panel_label_text(panel, "")

	panel.add_theme_stylebox_override("panel", stylebox)


func _update_panel_label_text(panel: Panel, text: String) -> void:
	if panel.has_node("PanelLabel"):
		panel.get_node("PanelLabel").text = text


func _apply_carousel_position(panel: Panel, slot_index: int) -> void:
	"""Apply position, scale, modulate, and z-index to a panel"""
	if slot_index < 0 or slot_index >= carousel_positions.size():
		return

	var pos_data = carousel_positions[slot_index]

	panel.position = pos_data["position"]
	panel.scale = pos_data["scale"]
	panel.modulate = pos_data["modulate"]
	panel.z_as_relative = false
	panel.z_index = pos_data["z_index"]


func _update_panel_mouse_filters() -> void:
	for panel in timeline_panels:
		if panel.z_index > 0:
			panel.set_grid_interactive(true)
		else:
			panel.set_grid_interactive(false)
		panel.start_hover_animation()


func _disable_all_input() -> void:
	"""Disable all mouse input during animations to prevent freezing"""
	# Disable panel interaction
	for panel in timeline_panels:
		panel.set_grid_interactive(false)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Disable all entity interaction
	for panel in timeline_panels:
		for entity in panel.entity_nodes:
			if entity and is_instance_valid(entity) and entity.has_node("Sprite"):
				entity.get_node("Sprite").mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Disable card interaction
	if card_manager:
		for deck in [card_manager.past_deck, card_manager.present_deck, card_manager.future_deck]:
			if deck:
				for card_node in deck.card_nodes:
					if card_node and is_instance_valid(card_node):
						card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _enable_all_input() -> void:
	"""Re-enable mouse input after animations complete"""
	# Re-enable panel interaction based on z_index
	_update_panel_mouse_filters()

	# Re-enable panels' mouse filters
	for panel in timeline_panels:
		panel.mouse_filter = Control.MOUSE_FILTER_PASS

	# Re-enable entity interaction (targeting system will handle this)
	# Entities will be re-enabled by targeting system when needed

	# Re-enable card interaction
	if card_manager:
		for deck in [card_manager.past_deck, card_manager.present_deck, card_manager.future_deck]:
			if deck:
				var top_card = deck.get_top_card()
				if top_card and is_instance_valid(top_card):
					top_card.mouse_filter = Control.MOUSE_FILTER_STOP


func _apply_ui_settings_to_panels() -> void:
	for panel in timeline_panels:
		panel.show_grid_lines(show_grid_lines)
		panel.show_debug_info(show_debug_grid)


func _build_carousel_snapshot() -> void:
	carousel_snapshot = []
	for i in range(6):
		var snapshot = {
			"position": carousel_positions[i]["position"],
			"scale": carousel_positions[i]["scale"],
			"modulate": carousel_positions[i]["modulate"],
			"z_index": carousel_positions[i]["z_index"]
		}
		carousel_snapshot.append(snapshot)

# ============================================================================
# GAME INITIALIZATION
# ============================================================================

func _initialize_game() -> void:
	"""Set up initial game state with EntityData"""
	print("🎮 Initializing game - Wave ", GameState.current_wave)

	# Get the Present timeline panel
	var present_panel = _get_timeline_panel("present")

	# Clear any existing entities
	present_panel.entity_data_list.clear()

	# Create player entity using EntityData
	var player = EntityData.create_player()
	player.entity_name = "Chronomancer"
	player.hp = 100
	player.max_hp = 100
	player.damage = 15
	present_panel.add_entity(player, 1, 0)  # Row 1, Column 0

	# Create enemy entities
	var enemy_a = EntityData.create_enemy("Chrono-Beast A", 45, 12)
	present_panel.add_entity(enemy_a, 0, 2)  # Row 0, Column 2

	var enemy_b = EntityData.create_enemy("Chrono-Beast B", 30, 8)
	present_panel.add_entity(enemy_b, 1, 2)  # Row 1, Column 2

	# Calculate combat targets using TargetCalculator
	TargetCalculator.calculate_targets(present_panel)
	print("  Initial targets calculated:")
	TargetCalculator.print_target_summary(present_panel)

	# Create backwards-compatible state dictionary for systems that still need it
	present_panel.state = present_panel.get_state_dict()

	# Store base damage in GameState
	GameState.base_player_damage = 15

	# Calculate initial Future
	_calculate_future_state()

	# Create visuals for all timelines
	_update_all_timeline_displays()
	_update_wave_counter()

	# Initialize timer display
	_update_timer_display()

	print("✅ Game initialized with EntityData\n")

# ============================================================================
# TURN EXECUTION
# ============================================================================

func _on_play_button_pressed() -> void:
	"""Execute turn - orchestrate systems"""
	if GameState.game_over:
		return

	GameState.timer_active = false
	play_button.disabled = true

	await _execute_complete_turn()

	if not GameState.game_over:
		play_button.disabled = false
		GameState.time_remaining = GameState.max_time
		GameState.timer_active = true
		_update_timer_display()
		card_manager.update_affordability(GameState.time_remaining)


func _execute_complete_turn() -> void:
	"""Orchestrate turn phases via systems"""
	print("\n" + "=".repeat(60))
	print("  EXECUTING TURN")
	print("=".repeat(60) + "\n")

	# Disable all input during turn execution to prevent freezing
	_disable_all_input()

	# Phase 0: Pre-carousel - hide labels/arrows, un-gray Future entities
	_prepare_for_carousel()

	# Phase 1: Carousel slide
	await _carousel_slide_animation()

	# Phase 2: Post-carousel - show labels on new Present
	_show_labels_after_carousel()

	# Phase 3: Combat (via CombatResolver)
	var present_panel = timeline_panels[2]
	await combat_resolver.execute_combat(present_panel)

	# Phase 3.5: Apply REAL_FUTURE if it was set by a card effect
	if GameState.should_apply_real_future():
		print("  🔄 Applying REAL_FUTURE timeline...")
		var real_future_entities = GameState.get_real_future()

		# Replace Present entities with REAL_FUTURE entities
		present_panel.entity_data_list.clear()
		for entity in real_future_entities:
			present_panel.entity_data_list.append(entity.duplicate_entity())

		# Update backwards-compatible state
		present_panel.state = present_panel.get_state_dict()

		# Clear REAL_FUTURE
		GameState.clear_real_future()
		print("  ✅ REAL_FUTURE applied - temporary effects cleaned up")

	# Phase 4: Turn effects cleanup
	GameState.reset_turn_effects()
	GameState.increment_turn()

	# Phase 5: Check game over
	var player_entity = null
	for entity in present_panel.entity_data_list:
		if not entity.is_enemy:
			player_entity = entity
			break

	if player_entity and player_entity.hp <= 0:
		_enable_all_input()  # Re-enable input before game over
		GameState.set_game_over()
		return

	# Phase 6: Recalculate future
	_recalculate_future_timelines()

	# Phase 7: Update timeline displays (recreate entities/arrows for new future)
	_update_all_timeline_displays()

	# Phase 8: Update UI labels
	_update_all_displays()

	# Phase 9: Show arrows after combat
	_show_timeline_arrows()

	# Phase 10: Re-enable input after all animations complete
	_enable_all_input()

	print("\n✅ Turn complete\n")


func _carousel_slide_animation() -> void:
	"""Animate carousel sliding to reveal new present with EntityData"""
	print("🎠 Carousel slide animation...")

	# Stop hover animations
	for panel in timeline_panels:
		panel.stop_hover_animation()

	# Hide UI and arrows
	_hide_ui_for_carousel()
	_delete_all_arrows()

	# Capture EntityData from current Present (slot 2)
	var slot_2_panel = timeline_panels[2]
	var entities_for_past: Array[EntityData] = []
	var entities_for_new_present: Array[EntityData] = []

	# Duplicate entities for Past and new Present
	for entity in slot_2_panel.entity_data_list:
		entities_for_past.append(entity.duplicate_entity())
		entities_for_new_present.append(entity.duplicate_entity())

	# Also capture backwards-compatible state
	var state_for_past = slot_2_panel.state.duplicate(true)
	var state_for_new_present = slot_2_panel.state.duplicate(true)

	# Rotate timeline panels array
	var first_panel = timeline_panels.pop_front()
	timeline_panels.push_back(first_panel)

	# Assign new timeline types after rotation
	timeline_panels[0].timeline_type = "decorative"
	timeline_panels[1].timeline_type = "past"
	timeline_panels[2].timeline_type = "present"
	timeline_panels[3].timeline_type = "future"
	timeline_panels[4].timeline_type = "decorative"
	timeline_panels[5].timeline_type = "decorative"

	# Assign EntityData - CRITICAL: New Present gets actual entities, NOT Future predictions!
	timeline_panels[1].entity_data_list = entities_for_past
	timeline_panels[2].entity_data_list = entities_for_new_present

	# Also assign backwards-compatible state
	timeline_panels[1].state = state_for_past
	timeline_panels[2].state = state_for_new_present

	# Animate panels to new positions
	var tween = create_tween()
	tween.set_parallel(true)

	for i in range(6):
		var panel = timeline_panels[i]
		var target = carousel_snapshot[i]

		tween.tween_property(panel, "position", target["position"], 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(panel, "scale", target["scale"], 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(panel, "modulate", target["modulate"], 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		panel.z_index = target["z_index"]

		# Animate panel color to match new timeline type
		_animate_panel_colors(tween, panel, panel.timeline_type)

	await tween.finished

	# Clear decorative panel states and entities AFTER slide animation
	for i in [0, 4, 5]:
		timeline_panels[i].state = {}
		timeline_panels[i].entity_data_list.clear()
		timeline_panels[i].clear_entities()
		timeline_panels[i].clear_arrows()

	# Update panel interactivity
	_update_panel_mouse_filters()

	# Restore UI (but don't recreate entities/arrows yet - wait until after combat)
	_show_ui_after_carousel()

	print("✅ Carousel slide complete")


func _prepare_for_carousel() -> void:
	"""Prepare for carousel: hide labels/arrows, un-gray Future entities"""
	print("📋 Preparing for carousel...")

	# Hide all HP/DMG labels
	for panel in timeline_panels:
		for entity in panel.entity_nodes:
			if entity and is_instance_valid(entity):
				if entity.has_node("HPLabel"):
					entity.get_node("HPLabel").visible = false
				if entity.has_node("DamageLabel"):
					entity.get_node("DamageLabel").visible = false

	# Un-gray dead entities in Future (they're about to become Present)
	var future_panel = timeline_panels[3]
	if future_panel and future_panel.timeline_type == "future":
		for entity in future_panel.entity_nodes:
			if entity and is_instance_valid(entity):
				entity.modulate = Color(1, 1, 1, 1)  # Restore normal color

	print("  Labels hidden, Future entities un-grayed")


func _show_labels_after_carousel() -> void:
	"""Show HP/DMG labels on new Present after carousel and sync entity data"""
	print("📋 Showing labels after carousel...")

	var present_panel = timeline_panels[2]
	if present_panel and present_panel.timeline_type == "present":
		# First, update entity data to match actual Present state (not Future predictions)
		_sync_entities_to_state(present_panel)

		# Then show labels with correct values
		for entity in present_panel.entity_nodes:
			if entity and is_instance_valid(entity):
				if entity.has_node("HPLabel"):
					entity.get_node("HPLabel").visible = true
				if entity.has_node("DamageLabel"):
					var dmg_label = entity.get_node("DamageLabel")
					# Only show damage labels for enemies
					if not entity.is_player:
						dmg_label.visible = true

	print("  Labels shown on new Present with actual state values")


func _sync_entities_to_state(panel: Panel) -> void:
	"""Sync entity data to match panel state (fixes Future→Present data mismatch)"""
	if panel.state.is_empty():
		return

	var enemy_index = 0
	for entity in panel.entity_nodes:
		if not entity or not is_instance_valid(entity):
			continue

		if entity.is_player:
			# Update player entity data from panel state
			if panel.state.has("player"):
				entity.entity_data = panel.state["player"].duplicate()
				entity.update_display()
				print("  Synced player: HP=", entity.entity_data["hp"])
		else:
			# Update enemy entity data from panel state
			if panel.state.has("enemies") and enemy_index < panel.state["enemies"].size():
				entity.entity_data = panel.state["enemies"][enemy_index].duplicate()
				entity.update_display()
				print("  Synced enemy ", enemy_index, ": HP=", entity.entity_data["hp"])
				enemy_index += 1


func _animate_panel_colors(tween: Tween, panel: Panel, new_type: String) -> void:
	"""Animate panel background color to match new timeline type"""
	var stylebox = panel.get_theme_stylebox("panel")
	if not stylebox is StyleBoxFlat:
		return

	if new_type == "past":
		# Brown colors
		var past_bg = Color(0.23921569, 0.14901961, 0.078431375, 1)
		var past_border = Color(0.54509807, 0.43529412, 0.2784314, 1)
		tween.tween_property(stylebox, "bg_color", past_bg, 0.6)
		tween.tween_property(stylebox, "border_color", past_border, 0.6)

	elif new_type == "present":
		# Blue colors
		var present_bg = Color(0.11764706, 0.22745098, 0.37254903, 1)
		var present_border = Color(0.2901961, 0.61960787, 1, 1)
		tween.tween_property(stylebox, "bg_color", present_bg, 0.6)
		tween.tween_property(stylebox, "border_color", present_border, 0.6)

	elif new_type == "future":
		# Purple colors
		var future_bg = Color(0.1764706, 0.105882354, 0.23921569, 1)
		var future_border = Color(0.7058824, 0.47843137, 1, 1)
		tween.tween_property(stylebox, "bg_color", future_bg, 0.6)
		tween.tween_property(stylebox, "border_color", future_border, 0.6)

	elif new_type == "decorative":
		# Decorative panels can be past or future colored
		# For simplicity, use a neutral dark color
		var dec_bg = Color(0.1, 0.1, 0.1, 1)
		var dec_border = Color(0.3, 0.3, 0.3, 1)
		tween.tween_property(stylebox, "bg_color", dec_bg, 0.6)
		tween.tween_property(stylebox, "border_color", dec_border, 0.6)

# ============================================================================
# TIMELINE & STATE MANAGEMENT
# ============================================================================

func _calculate_future_state() -> void:
	"""Calculate Future timeline based on Present using EntityData"""
	var present_panel = _get_timeline_panel("present")
	var future_panel = _get_timeline_panel("future")

	if not present_panel or not future_panel:
		return

	print("  🔮 Calculating Future timeline...")

	# Clear future entities
	future_panel.entity_data_list.clear()

	# Duplicate all entities from Present to Future
	for entity in present_panel.entity_data_list:
		var future_entity = entity.duplicate_entity()
		future_panel.entity_data_list.append(future_entity)

	# Calculate targets for Future timeline
	TargetCalculator.calculate_targets(future_panel)

	# Simulate combat to get predicted HP values
	_simulate_combat(future_panel)

	# Create backwards-compatible state dictionary
	future_panel.state = future_panel.get_state_dict()
	future_panel.timeline_type = "future"

	print("  ✅ Future timeline calculated")


func _simulate_combat(panel: Panel) -> void:
	"""Simulate combat on a timeline panel (non-animated, data-only)"""
	# Phase 1: Player team attacks
	for attacker in panel.entity_data_list:
		if attacker.is_enemy or not attacker.is_alive():
			continue
		if attacker.attack_target_id == "" or attacker.will_miss:
			continue

		var target = _find_entity_data_by_id(panel, attacker.attack_target_id)
		if target and target.is_alive():
			target.take_damage(attacker.damage)
			print("    [SIM] ", attacker.entity_name, " → ", target.entity_name, " (", target.hp, "/", target.max_hp, " HP)")

	# Phase 2: Enemy team attacks
	for attacker in panel.entity_data_list:
		if not attacker.is_enemy or not attacker.is_alive():
			continue
		if attacker.attack_target_id == "" or attacker.will_miss:
			continue

		var target = _find_entity_data_by_id(panel, attacker.attack_target_id)
		if target and target.is_alive():
			target.take_damage(attacker.damage)
			print("    [SIM] ", attacker.entity_name, " → ", target.entity_name, " (", target.hp, "/", target.max_hp, " HP)")


func _find_entity_data_by_id(panel: Panel, unique_id: String) -> EntityData:
	"""Find EntityData by unique_id in a panel"""
	for entity in panel.entity_data_list:
		if entity.unique_id == unique_id:
			return entity
	return null


func _calculate_future_from_state(base_state: Dictionary) -> Dictionary:
	"""[DEPRECATED] Calculate future state from any given state - kept for backwards compatibility"""
	var future = base_state.duplicate(true)

	if future["enemies"].size() > 0:
		# Player attacks first enemy
		future["enemies"][0]["hp"] -= future["player"]["damage"]
		if future["enemies"][0]["hp"] <= 0:
			# Mark as dead but keep in array (for grayed-out display)
			future["enemies"][0]["hp"] = 0
			future["enemies"][0]["is_dead"] = true

	# Enemies attack player (only alive enemies attack)
	for enemy in future["enemies"]:
		if not enemy.get("is_dead", false):
			future["player"]["hp"] -= enemy["damage"]

	# Mark player as dead if HP <= 0
	if future["player"]["hp"] <= 0:
		future["player"]["hp"] = 0
		future["player"]["is_dead"] = true

	return future


func _recalculate_future_timelines() -> void:
	"""Recalculate Future timeline after combat using EntityData"""
	var present_panel = timeline_panels[2]
	var future_panel = timeline_panels[3]

	print("  🔮 Recalculating Future timeline...")

	# Clear future entities
	future_panel.entity_data_list.clear()

	# Duplicate all entities from Present to Future
	for entity in present_panel.entity_data_list:
		var future_entity = entity.duplicate_entity()
		future_panel.entity_data_list.append(future_entity)

	# Calculate targets for Future timeline
	TargetCalculator.calculate_targets(future_panel)

	# Simulate combat to get predicted HP values
	_simulate_combat(future_panel)

	# Create backwards-compatible state dictionary
	future_panel.state = future_panel.get_state_dict()
	future_panel.timeline_type = "future"

	print("  ✅ Future recalculated")


func _get_timeline_panel(timeline_type: String) -> Panel:
	"""Get the timeline panel with the specified timeline_type"""
	for tp in timeline_panels:
		if tp.timeline_type == timeline_type:
			return tp
	return null

# ============================================================================
# ENTITY & ARROW CREATION
# ============================================================================

func _create_timeline_entities(tp: Panel) -> void:
	"""Create entity visuals for a timeline panel using EntityData"""
	tp.clear_entities()

	if tp == null or tp.entity_data_list.size() == 0:
		return

	# Create visual nodes for each EntityData
	for entity_data in tp.entity_data_list:
		var entity_node = ENTITY_SCENE.instantiate()

		# Convert EntityData to Dictionary for backwards compatibility with entity.gd
		var entity_dict = entity_data.to_dict()
		entity_node.setup(entity_dict, not entity_data.is_enemy, tp.timeline_type)

		# Position entity at grid location
		var world_pos = tp.get_cell_center_position(entity_data.grid_row, entity_data.grid_col)
		entity_node.position = world_pos

		tp.add_child(entity_node)
		tp.entity_nodes.append(entity_node)
		tp.entities.append(entity_node)  # Also append to backwards-compatible array

		# Gray out dead entities in Future timeline
		if tp.timeline_type == "future" and not entity_data.is_alive():
			entity_node.modulate = Color(0.5, 0.5, 0.5, 0.6)  # Grayed out

		# Store reference to EntityData in the visual node
		entity_node.entity_data = entity_dict
		entity_node.entity_data["unique_id"] = entity_data.unique_id


func _create_timeline_arrows(tp: Panel) -> void:
	"""Create arrows for a timeline panel using EntityData and attack targets"""
	tp.clear_arrows()

	if tp == null or tp.entity_data_list.size() == 0:
		return

	# Determine which arrows to show based on timeline type
	var show_player_arrows = (tp.timeline_type == "present")
	var show_enemy_arrows = (tp.timeline_type == "future")

	# Skip arrow creation for PAST and DECORATIVE timelines
	if not show_player_arrows and not show_enemy_arrows:
		return

	# Create arrows based on EntityData attack targets
	for attacker_data in tp.entity_data_list:
		# Skip if no target or will miss
		if attacker_data.attack_target_id == "" or attacker_data.will_miss:
			continue

		# Filter by team based on timeline type
		if show_player_arrows and attacker_data.is_enemy:
			continue
		if show_enemy_arrows and not attacker_data.is_enemy:
			continue

		# Find target EntityData
		var target_data = _find_entity_data_by_id(tp, attacker_data.attack_target_id)
		if not target_data:
			continue

		# Find visual nodes
		var attacker_node = _find_entity_node_by_id(tp, attacker_data.unique_id)
		var target_node = _find_entity_node_by_id(tp, target_data.unique_id)

		if not attacker_node or not target_node:
			continue

		# Create arrow
		var arrow = ARROW_SCENE.instantiate()
		arrow.z_index = 50
		arrow.z_as_relative = true
		arrow.visible = false  # Hide initially
		tp.add_child(arrow)

		var curve = _calculate_smart_curve(attacker_node.position, target_node.position)
		arrow.setup(attacker_node.position, target_node.position, curve, attacker_data.unique_id, target_data.unique_id)
		tp.arrows.append(arrow)


func _find_entity_node_by_id(panel: Panel, unique_id: String) -> Node2D:
	"""Find visual entity node by unique_id"""
	for node in panel.entity_nodes:
		if node.entity_data.get("unique_id") == unique_id:
			return node
	return null


func _calculate_smart_curve(from: Vector2, to: Vector2) -> float:
	"""Calculate arrow curve based on spatial relationship"""
	var direction = to - from
	var horizontal_distance = abs(direction.x)
	var base_curve = 30.0
	var horizontal_factor = horizontal_distance / max(direction.length(), 1.0)
	var curve_strength = base_curve * (0.5 + horizontal_factor * 0.5)
	return -curve_strength if direction.x < 0 else curve_strength


func _delete_all_arrows() -> void:
	"""Delete all arrows from all panels"""
	for panel in timeline_panels:
		panel.clear_arrows()


func _show_timeline_arrows() -> void:
	"""Show arrows on all timeline panels after combat"""
	for panel in timeline_panels:
		for arrow in panel.arrows:
			if arrow and is_instance_valid(arrow):
				arrow.visible = true
				if arrow.has_method("show_arrow"):
					arrow.show_arrow()


func _update_all_timeline_displays() -> void:
	"""Update visuals for all timelines"""
	for panel in timeline_panels:
		if panel.timeline_type in ["past", "present", "future"]:
			_create_timeline_entities(panel)
			_create_timeline_arrows(panel)
			_update_timeline_ui_visibility(panel)
	_update_damage_display()


func _update_timeline_ui_visibility(tp: Panel) -> void:
	"""Update UI element visibility based on timeline_type"""
	for entity in tp.entity_nodes:
		if not entity or not is_instance_valid(entity):
			continue

		# HP labels always visible
		if entity.has_node("HPLabel"):
			entity.get_node("HPLabel").visible = true

		# Damage label visibility depends on timeline_type
		if entity.has_node("DamageLabel") and not entity.is_player:
			var dmg_label = entity.get_node("DamageLabel")
			match tp.timeline_type:
				"past":
					dmg_label.visible = false
				"present":
					dmg_label.visible = true
				"future":
					dmg_label.visible = false

	# Arrows visibility
	for arrow in tp.arrows:
		if arrow and is_instance_valid(arrow):
			arrow.visible = true
			if arrow.has_method("show_arrow"):
				arrow.show_arrow()

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_combat_ended() -> void:
	"""Handle combat end"""
	print("  Combat phase ended")


func _on_damage_dealt(target: Node2D, damage: int) -> void:
	"""Handle damage event - update entity visuals"""
	print("  GameController received damage_dealt event: ", damage, " to ", target)
	if target and is_instance_valid(target):
		target.update_display()  # Refresh HP label


func _on_timer_updated(time_remaining: float) -> void:
	"""Update timer display and card affordability"""
	_update_timer_display()
	card_manager.update_affordability(time_remaining)


func _on_wave_changed(new_wave: int) -> void:
	"""Update wave counter"""
	wave_counter_label.text = "Wave %d/10" % new_wave


func _on_game_over() -> void:
	"""Handle game over state"""
	play_button.disabled = true
	play_button.text = "GAME OVER"
	print("\n💀 GAME OVER")


func _apply_screen_shake(strength: float) -> void:
	"""Apply screen shake effect"""
	GameState.shake_strength = strength


func _on_card_played(card_data: Dictionary) -> void:
	"""Handle card played event"""
	# Recalculate future after card effect
	_recalculate_future_timelines()
	_update_all_timeline_displays()
	_show_timeline_arrows()  # Show arrows including any redirected ones


func _on_future_recalculation_requested() -> void:
	"""Handle request to recalculate future (e.g., after enemy_swap)"""
	print("  🔄 Future recalculation requested by card effect...")
	_recalculate_future_timelines()
	_update_all_timeline_displays()
	_show_timeline_arrows()
	print("  ✅ Future recalculated and displays updated")

# ============================================================================
# UI UPDATES
# ============================================================================

func _update_timer_display() -> void:
	var minutes = int(GameState.time_remaining) / 60
	var seconds = int(GameState.time_remaining) % 60
	timer_label.text = "%d:%02d" % [minutes, seconds]


func _update_all_displays() -> void:
	_update_timer_display()
	_update_wave_counter()
	_update_damage_display()


func _update_wave_counter() -> void:
	wave_counter_label.text = "Wave %d/10" % GameState.current_wave


func _update_damage_display() -> void:
	var present_panel = timeline_panels[2]
	if present_panel and present_panel.state.has("player"):
		damage_label.text = str(present_panel.state["player"]["damage"])


func _hide_ui_for_carousel() -> void:
	"""Hide UI and block input during carousel animation"""
	for panel in timeline_panels:
		# Hide labels
		if panel.has_node("PanelLabel"):
			panel.get_node("PanelLabel").visible = false

		# Block panel mouse input to prevent interaction during animation
		panel.set_grid_interactive(false)

	# Block card input during carousel
	for deck in [card_manager.past_deck, card_manager.present_deck, card_manager.future_deck]:
		if deck and deck.card_nodes:
			for card_node in deck.card_nodes:
				if card_node and is_instance_valid(card_node):
					card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _show_ui_after_carousel() -> void:
	"""Show UI and restore input after carousel animation"""
	for panel in timeline_panels:
		# Show labels
		if panel.has_node("PanelLabel"):
			panel.get_node("PanelLabel").visible = true

		# Mouse filters will be restored by _update_panel_mouse_filters()

	# Restore card input (only top cards should be interactive)
	for deck in [card_manager.past_deck, card_manager.present_deck, card_manager.future_deck]:
		if deck and deck.card_nodes:
			for i in range(deck.card_nodes.size()):
				var card_node = deck.card_nodes[i]
				if card_node and is_instance_valid(card_node):
					# Only top card is interactive
					var is_top_card = (i == deck.card_nodes.size() - 1)
					if is_top_card:
						card_node.mouse_filter = Control.MOUSE_FILTER_STOP
					else:
						card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE

# ============================================================================
# PROCESS & INPUT
# ============================================================================

func _process(delta: float) -> void:
	# Screen shake
	if GameState.shake_strength > 0:
		camera.offset = Vector2(
			randf_range(-GameState.shake_strength, GameState.shake_strength),
			randf_range(-GameState.shake_strength, GameState.shake_strength)
		)
		GameState.shake_strength = lerp(GameState.shake_strength, 0.0, GameState.shake_decay * delta)
		if GameState.shake_strength < 0.1:
			GameState.shake_strength = 0.0
			camera.offset = Vector2.ZERO

	# Timer countdown
	if GameState.timer_active and not GameState.game_over:
		GameState.time_remaining -= delta
		if GameState.time_remaining <= 0:
			GameState.time_remaining = 0
			GameState.timer_active = false
			if not play_button.disabled:
				_on_play_button_pressed()
		else:
			Events.timer_updated.emit(GameState.time_remaining)


func _input(event: InputEvent) -> void:
	# Toggle fullscreen
	if event.is_action_pressed("toggle_fullscreen"):
		_toggle_fullscreen()

	# Cancel targeting with ESC
	if event.is_action_pressed("ui_cancel") and targeting_system.targeting_mode_active:
		print("ESC pressed - canceling targeting mode")
		targeting_system.cancel_targeting_mode()

	# Handle clicks for targeting
	if targeting_system.targeting_mode_active and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			targeting_system.targeting_click_handled = false
			call_deferred("_check_cancel_targeting")


func _check_cancel_targeting() -> void:
	targeting_system.check_cancel_from_empty_click()


func _toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		print("Switched to Windowed mode")
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		print("Switched to Fullscreen mode")
