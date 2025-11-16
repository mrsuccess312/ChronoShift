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
	Events.combat_ended.connect(_on_combat_ended)
	Events.timer_updated.connect(_on_timer_updated)
	Events.wave_changed.connect(_on_wave_changed)
	Events.game_over.connect(_on_game_over)
	Events.screen_shake_requested.connect(_apply_screen_shake)
	Events.card_played.connect(_on_card_played)

# ============================================================================
# CAROUSEL SETUP
# ============================================================================

func _setup_carousel() -> void:
	"""Initialize carousel with 6 dynamically created timeline panels"""
	print("🎠 Setting up carousel with 6 panels...")

	# Define carousel positions (extracted from game_manager.gd)
	carousel_positions = [
		{"position": Vector2(-400, 0), "scale": Vector2(0.7, 0.7), "modulate": Color(1, 1, 1, 0.3), "z_index": -2},
		{"position": Vector2(-250, -50), "scale": Vector2(0.85, 0.85), "modulate": Color(1, 1, 1, 0.6), "z_index": 1},
		{"position": Vector2(0, -100), "scale": Vector2(1.0, 1.0), "modulate": Color(1, 1, 1, 1.0), "z_index": 10},
		{"position": Vector2(250, -50), "scale": Vector2(0.85, 0.85), "modulate": Color(1, 1, 1, 0.6), "z_index": 1},
		{"position": Vector2(400, 0), "scale": Vector2(0.7, 0.7), "modulate": Color(1, 1, 1, 0.3), "z_index": -1},
		{"position": Vector2(550, 50), "scale": Vector2(0.6, 0.6), "modulate": Color(1, 1, 1, 0.15), "z_index": -3}
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
			if i == 0:
				stylebox.bg_color = Color(0.24, 0.15, 0.08, 1)
				stylebox.border_color = Color(0.55, 0.44, 0.28, 1)
			else:
				stylebox.bg_color = Color(0.18, 0.11, 0.24, 1)
				stylebox.border_color = Color(0.71, 0.48, 1, 1)
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
	"""Set up initial game state"""
	print("🎮 Initializing game - Wave ", GameState.current_wave)

	# Get the Present timeline panel
	var present_panel = _get_timeline_panel("present")

	# Create initial state
	present_panel.state = {
		"player": {
			"name": "Chronomancer",
			"hp": 100,
			"max_hp": 100,
			"damage": 15
		},
		"enemies": [
			{"name": "Chrono-Beast A", "hp": 45, "max_hp": 45, "damage": 12},
			{"name": "Chrono-Beast B", "hp": 30, "max_hp": 30, "damage": 8}
		]
	}

	# Store base damage in GameState
	GameState.base_player_damage = 15

	# Calculate initial Future
	_calculate_future_state()

	# Create visuals for all timelines
	_update_all_timeline_displays()
	_update_wave_counter()

	# Initialize timer display
	_update_timer_display()

	print("✅ Game initialized\n")

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

	# Phase 1: Carousel slide
	await _carousel_slide_animation()

	# Phase 2: Combat (via CombatResolver)
	var present_panel = timeline_panels[2]
	await combat_resolver.execute_combat(present_panel)

	# Phase 3: Turn effects
	GameState.reset_turn_effects()
	GameState.increment_turn()

	# Phase 4: Check game over
	if present_panel.state["player"]["hp"] <= 0:
		GameState.set_game_over()
		return

	# Phase 5: Recalculate future
	_recalculate_future_timelines()

	# Phase 6: Update UI
	_update_all_displays()

	print("\n✅ Turn complete\n")


func _carousel_slide_animation() -> void:
	"""Animate carousel sliding to reveal new present"""
	print("🎠 Carousel slide animation...")

	# Stop hover animations
	for panel in timeline_panels:
		panel.stop_hover_animation()

	# Hide UI and arrows
	_hide_ui_for_carousel()
	_delete_all_arrows()

	# Capture Past state from current Present
	var slot_2_panel = timeline_panels[2]
	var state_for_past = slot_2_panel.state.duplicate(true)

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

	# Assign states
	timeline_panels[1].state = state_for_past  # New Past gets old Present

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

	await tween.finished

	# Update panel interactivity
	_update_panel_mouse_filters()

	# Restore UI
	_show_ui_after_carousel()
	_update_all_timeline_displays()

	print("✅ Carousel slide complete")

# ============================================================================
# TIMELINE & STATE MANAGEMENT
# ============================================================================

func _calculate_future_state() -> void:
	"""Calculate Future timeline based on Present"""
	var present_panel = _get_timeline_panel("present")
	var future_panel = _get_timeline_panel("future")

	if not present_panel or not future_panel:
		return

	future_panel.state = _calculate_future_from_state(present_panel.state)
	future_panel.timeline_type = "future"


func _calculate_future_from_state(base_state: Dictionary) -> Dictionary:
	"""Calculate future state from any given state"""
	var future = base_state.duplicate(true)

	if future["enemies"].size() > 0:
		# Player attacks first enemy
		future["enemies"][0]["hp"] -= future["player"]["damage"]
		if future["enemies"][0]["hp"] <= 0:
			future["enemies"].remove_at(0)

	# Enemies attack player
	for enemy in future["enemies"]:
		future["player"]["hp"] -= enemy["damage"]

	return future


func _recalculate_future_timelines() -> void:
	"""Recalculate Future and Decorative Future after combat"""
	var present_panel = timeline_panels[2]
	var future_panel = timeline_panels[3]

	# Calculate Future based on current Present
	future_panel.state = _calculate_future_from_state(present_panel.state)
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
	"""Create entity visuals for a timeline panel"""
	tp.clear_entities()

	if tp == null or tp.state.is_empty():
		return

	var enemy_count = tp.state.get("enemies", []).size()

	# Create enemies
	if tp.state.has("enemies"):
		for i in range(enemy_count):
			var enemy_entity = ENTITY_SCENE.instantiate()
			enemy_entity.setup(tp.state["enemies"][i], false, tp.timeline_type)

			var grid_pos = tp.get_grid_position_for_entity(i, false, enemy_count)
			var world_pos = tp.get_cell_center_position(grid_pos.x, grid_pos.y)

			enemy_entity.position = world_pos
			tp.add_child(enemy_entity)
			tp.entities.append(enemy_entity)

	# Create player
	var player_grid_pos = Vector2i(-1, -1)
	if tp.state.has("player"):
		var player_entity = ENTITY_SCENE.instantiate()
		player_entity.setup(tp.state["player"], true, tp.timeline_type)

		player_grid_pos = tp.get_grid_position_for_entity(0, true, enemy_count)
		var world_pos = tp.get_cell_center_position(player_grid_pos.x, player_grid_pos.y)

		player_entity.position = world_pos
		tp.add_child(player_entity)
		tp.entities.append(player_entity)

	# Create twin if exists
	if tp.state.has("twin"):
		var twin_entity = ENTITY_SCENE.instantiate()
		twin_entity.setup(tp.state["twin"], true, tp.timeline_type)

		var twin_grid_pos = Vector2i(player_grid_pos.x, player_grid_pos.y - 1)
		if twin_grid_pos.y < 0:
			twin_grid_pos.y = 0

		var world_pos = tp.get_cell_center_position(twin_grid_pos.x, twin_grid_pos.y)

		twin_entity.position = world_pos
		tp.add_child(twin_entity)
		tp.entities.append(twin_entity)


func _create_timeline_arrows(tp: Panel) -> void:
	"""Create arrows for a timeline panel based on its timeline_type"""
	tp.clear_arrows()

	if tp == null or tp.state.is_empty():
		return

	if not tp.state.has("enemies") or tp.state["enemies"].size() == 0:
		return

	match tp.timeline_type:
		"past":
			pass  # No arrows
		"present":
			_create_player_attack_arrows(tp)
		"future":
			_create_enemy_attack_arrows(tp)


func _create_player_attack_arrows(tp: Panel) -> void:
	"""Create arrows from player and twin to leftmost enemy"""
	var player_entity = null
	var twin_entity = null

	for entity in tp.entities:
		if entity.is_player:
			if entity.entity_data.get("is_twin", false):
				twin_entity = entity
			else:
				player_entity = entity

	if not player_entity:
		return

	var target_enemy = tp.get_leftmost_enemy()
	if not target_enemy:
		return

	# Player arrow
	if player_entity:
		var arrow = ARROW_SCENE.instantiate()
		arrow.z_index = 50
		arrow.z_as_relative = true
		tp.add_child(arrow)
		var curve = _calculate_smart_curve(player_entity.position, target_enemy.position)
		arrow.setup(player_entity.position, target_enemy.position, curve)
		tp.arrows.append(arrow)

	# Twin arrow
	if twin_entity:
		var twin_arrow = ARROW_SCENE.instantiate()
		twin_arrow.z_index = 50
		twin_arrow.z_as_relative = true
		tp.add_child(twin_arrow)
		var twin_curve = _calculate_smart_curve(twin_entity.position, target_enemy.position)
		twin_arrow.setup(twin_entity.position, target_enemy.position, twin_curve)
		tp.arrows.append(twin_arrow)


func _create_enemy_attack_arrows(tp: Panel) -> void:
	"""Create arrows from each enemy to player/twin"""
	var player_entity = null
	var twin_entity = null

	for entity in tp.entities:
		if entity.is_player:
			if entity.entity_data.get("is_twin", false):
				twin_entity = entity
			else:
				player_entity = entity

	if not player_entity:
		return

	var default_target = twin_entity if twin_entity else player_entity

	var enemy_entities = []
	for entity in tp.entities:
		if not entity.is_player:
			enemy_entities.append(entity)

	for i in range(enemy_entities.size()):
		var enemy = enemy_entities[i]
		var target = default_target

		# Check for redirect
		if GameState.future_redirect_flag != null and GameState.future_redirect_flag.get("from_enemy", -1) == i:
			var to_index = GameState.future_redirect_flag.get("to_enemy", -1)
			if to_index >= 0 and to_index < enemy_entities.size():
				target = enemy_entities[to_index]

		# Skip if miss flag
		if GameState.will_enemy_miss(i):
			continue

		var arrow = ARROW_SCENE.instantiate()
		arrow.z_index = 50
		arrow.z_as_relative = true
		tp.add_child(arrow)
		var curve = _calculate_smart_curve(enemy.position, target.position)
		arrow.setup(enemy.position, target.position, curve)
		tp.arrows.append(arrow)


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
	for entity in tp.entities:
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


func _on_timer_updated(time_remaining: float) -> void:
	"""Update timer display"""
	_update_timer_display()


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
	for panel in timeline_panels:
		if panel.has_node("PanelLabel"):
			panel.get_node("PanelLabel").visible = false


func _show_ui_after_carousel() -> void:
	for panel in timeline_panels:
		if panel.has_node("PanelLabel"):
			panel.get_node("PanelLabel").visible = true

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
