extends Node2D

# Preload the entity scene
const ENTITY_SCENE = preload("res://scenes/entity.tscn")
const CARD_SCENE = preload("res://scenes/card.tscn")
const ARROW_SCENE = preload("res://scenes/arrow.tscn")

# Timeline data structures
var past_state = {}
var present_state = {}
var future_state = {}

# Game state
var current_wave = 1
var turn_number = 0
var game_over = false
var card_played_this_turn = false

# Entity tracking
var past_entities = []
var present_entities = []
var future_entities = []

# Card tracking
var available_cards = []  # Card data from CardDatabase
var card_nodes = []        # Visual card nodes

var present_arrows = []
var future_arrows = []

# Screen shake variables
var shake_strength = 0.0
var shake_decay = 5.0

# CAROUSEL SYSTEM - 6 Timeline Panels
var carousel_panels = []  # Array of all 6 panel nodes
var carousel_states = []  # Which state each panel represents

# Carousel position definitions (slot 0 = far-left, slot 2 = center/present)
# ALL panels are 750x750 base size (using scale for perspective, not size changes)
var carousel_positions = [
	# Slot 0: Far-left decorative
	{
		"position": Vector2(0, 150),  # Match scene: offset_left=0, offset_top=150
		"scale": Vector2(0.6, 0.6),   # Match scene scale
		"modulate": Color(1.0, 1.0, 1.0, 1.0),
		"z_index": 0
	},
	# Slot 1: Past
	{
		"position": Vector2(135, 125),  # Match scene: offset_left=135, offset_top=125
		"scale": Vector2(0.75, 0.75),   # Match scene scale
		"modulate": Color(1.0, 1.0, 1.0, 1.0),
		"z_index": 1
	},
	# Slot 2: Present
	{
		"position": Vector2(660, 90),  # Match scene: offset_left=660, offset_top=90
		"scale": Vector2(1.0, 1.0),
		"modulate": Color(1.0, 1.0, 1.0, 1.0),
		"z_index": 2
	},
	# Slot 3: Future
	{
		"position": Vector2(1185, 125),  # Match scene: offset_left=1185, offset_top=125
		"scale": Vector2(0.75, 0.75),    # Match scene scale
		"modulate": Color(1.0, 1.0, 1.0, 1.0),
		"z_index": 1
	},
	# Slot 4: Far-right decorative
	{
		"position": Vector2(1320, 150),  # Match scene: offset_left=1320, offset_top=150
		"scale": Vector2(0.6, 0.6),      # Match scene scale
		"modulate": Color(1.0, 1.0, 1.0, 1.0),
		"z_index": 0
	},
	# Slot 5: Hidden off-screen right
	{
		"position": Vector2(2000, 250),
		"scale": Vector2(0.2, 0.2),
		"modulate": Color(1.0, 1.0, 1.0, 1.0),
		"z_index": -1
	}
]

var carousel_snapshot = []

# References to UI elements
@onready var carousel_container = $UIRoot/CarouselContainer
@onready var decorative_past_panel = $UIRoot/CarouselContainer/DecorativePastPanel
@onready var past_panel = $UIRoot/CarouselContainer/PastPanel
@onready var present_panel = $UIRoot/CarouselContainer/PresentPanel
@onready var future_panel = $UIRoot/CarouselContainer/FuturePanel
@onready var decorative_future_panel = $UIRoot/CarouselContainer/DecorativeFuturePanel
@onready var play_button = $UIRoot/PlayButton
@onready var wave_counter_label = $UIRoot/WaveCounter/WaveLabel
@onready var damage_label = $UIRoot/DamageDisplay/DamageLabel
@onready var card_container = $UIRoot/CardContainer
@onready var camera = $Camera2D

func _ready():
	print("ChronoShift - Game Manager Ready!")
	play_button.pressed.connect(_on_play_button_pressed)
	
	# Initialize carousel system
	setup_carousel()
	
	initialize_game()

func _input(event):
	"""Handle global input events"""
	# Toggle fullscreen with F11
	if event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()

func toggle_fullscreen():
	"""Switch between windowed and fullscreen mode"""
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		print("Switched to Windowed mode")
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		print("Switched to Fullscreen mode")

func setup_carousel():
	"""Initialize the 6-panel carousel system"""
	# Add all 6 panels to carousel array (order matters for rotation)
	carousel_panels = [
		decorative_past_panel,  # Slot 0
		past_panel,             # Slot 1
		present_panel,          # Slot 2
		future_panel,           # Slot 3
		decorative_future_panel,# Slot 4
		null                    # Slot 5 (no panel yet, will be created during rotation)
	]
	
	# Track which timeline state each panel represents
	# "decorative" = empty panel, "past" = past_state, "present" = present_state, "future" = future_state
	carousel_states = [
		"decorative",  # Slot 0
		"past",        # Slot 1
		"present",     # Slot 2
		"future",      # Slot 3
		"decorative",  # Slot 4
		"decorative"   # Slot 5 (off-screen)
	]
	
	# Apply initial carousel positions to all panels
	for i in range(carousel_panels.size()):
		if carousel_panels[i] != null:
			apply_carousel_position(carousel_panels[i], i)
	
	# CRITICAL: Force Present panel to be drawn last (on top)
	if present_panel:
		carousel_container.move_child(present_panel, -1)
	
	build_carousel_snapshot()
	
	print("Carousel system initialized with 6 positions")

func build_carousel_snapshot():
	"""Build snapshot of target states for all 6 carousel positions"""
	carousel_snapshot = []
	
	for i in range(6):
		var snapshot = {
			"position": carousel_positions[i]["position"],
			"scale": carousel_positions[i]["scale"],
			"modulate": carousel_positions[i]["modulate"],
			"z_index": carousel_positions[i]["z_index"],
			# Determine size based on slot
			"size": get_size_for_slot(i),
			# Determine timeline type
			"timeline": get_timeline_for_slot(i)
		}
		carousel_snapshot.append(snapshot)
	
	print("📸 Carousel snapshot built with ", carousel_snapshot.size(), " positions")

func get_size_for_slot(slot_index: int) -> Vector2:
	"""Return the appropriate panel size for a given slot"""
	# All panels are 600x750 in the scene file
	return Vector2(600, 750)

func get_timeline_for_slot(slot_index: int) -> String:
	"""Return the timeline type for a given slot"""
	match slot_index:
		0: return "decorative"
		1: return "past"
		2: return "present"
		3: return "future"
		4: return "decorative"
		5: return "decorative"
		_: return "decorative"

func apply_carousel_position(panel: Panel, slot_index: int):
	"""Apply position, scale, modulate, and z-index to a panel based on slot"""
	if slot_index < 0 or slot_index >= carousel_positions.size():
		return
	
	var pos_data = carousel_positions[slot_index]
	
	# Apply visual properties
	panel.position = pos_data["position"]
	panel.scale = pos_data["scale"]
	panel.modulate = pos_data["modulate"]
	
	# Set z-index
	panel.z_as_relative = false
	panel.z_index = pos_data["z_index"]
	
	# Force panel to move to correct layer in scene tree
	var parent = panel.get_parent()
	if parent:
		parent.move_child(panel, -1)
		if slot_index == 2:  # Present - draw last (on top)
			parent.move_child(panel, parent.get_child_count() - 1)
	
	# REMOVED: panel.size = Vector2(600, 750)
	# Let the scene file control the size! ✅

func initialize_game():
	# Set up initial game state
	print("Initializing Wave ", current_wave)
	
	# Create player
	present_state["player"] = {
		"name": "Chronomancer",
		"hp": 100,
		"max_hp": 100,
		"damage": 15
	}
	
	# Create enemies
	present_state["enemies"] = [
		{"name": "Chrono-Beast A", "hp": 45, "max_hp": 45, "damage": 12},
		{"name": "Chrono-Beast B", "hp": 30, "max_hp": 30, "damage": 8}
	]
	
	# Calculate initial future projection
	calculate_future()
	
	# Update displays
	update_all_timelines()
	update_wave_counter()
	setup_cards()
	
func create_entity_visuals(timeline_name: String, state_data: Dictionary, entity_array: Array):
	"""Create visual entity nodes for a timeline"""
	print("\n=== Creating entities for timeline: ", timeline_name, " ===")
	
	# Clear existing entities from ARRAY
	for old_entity in entity_array:
		old_entity.queue_free()
	entity_array.clear()
	
	# Get the appropriate panel
	var panel = get_panel_for_timeline(timeline_name)
	
	if panel == null:
		print("ERROR: Could not find panel for ", timeline_name)
		return
	
	# CRITICAL FIX: Also clear the panel itself!
	# Remove any old entity nodes that might still be in the panel
	print("🧹 Clearing panel ", panel.name, " of old entities...")
	for child in panel.get_children():
		# Keep labels, remove entities and arrows
		if child is Node2D and "Label" not in child.name:
			if child not in entity_array:  # Don't remove entities we're about to add
				print("  Removing old node: ", child.name)
				child.queue_free()
	
	# Use 600x750 dimensions for entity positioning
	var standard_width = 600.0   # Changed from 750.0
	var standard_height = 750.0
	var center_x = 300.0  # Half of 600 (changed from 375)
	
	# Create enemy entities in semicircle formation at top
	if state_data.has("enemies"):
		var enemy_count = state_data["enemies"].size()
		
		# Semicircle parameters
		var arc_center_x = center_x
		var arc_center_y = standard_height * 0.33
		var arc_radius = standard_width * 0.2
		var arc_span = PI * 0.6
		
		for i in range(enemy_count):
			var enemy_entity = ENTITY_SCENE.instantiate()
			enemy_entity.setup(state_data["enemies"][i], false, timeline_name)
			
			# Calculate angle for this enemy
			var angle_offset = 0
			if enemy_count > 1:
				angle_offset = (float(i) / (enemy_count - 1) - 0.5) * arc_span
			
			# Convert angle to position
			var pos_x = arc_center_x + arc_radius * sin(angle_offset)
			var pos_y = arc_center_y - arc_radius * cos(angle_offset)
			
			enemy_entity.position = Vector2(pos_x, pos_y)
			panel.add_child(enemy_entity)
			entity_array.append(enemy_entity)
	
	# Create player entity at bottom center
	if state_data.has("player"):
		var player_entity = ENTITY_SCENE.instantiate()
		player_entity.setup(state_data["player"], true, timeline_name)
		player_entity.position = Vector2(center_x, standard_height * 0.8)
		panel.add_child(player_entity)
		entity_array.append(player_entity)
	
	print("=== Finished creating entities for ", timeline_name, " ===")

func get_panel_for_timeline(timeline_name: String) -> Panel:
	"""Find which panel currently represents the given timeline"""
	for i in range(carousel_states.size()):
		if carousel_states[i] == timeline_name:
			return carousel_panels[i]
	return null

func create_attack_arrows(timeline_name: String, state_data: Dictionary, entity_array: Array, arrow_array: Array):
	"""Create attack arrows for a timeline"""
	# Clear existing arrows
	for old_arrow in arrow_array:
		old_arrow.queue_free()
	arrow_array.clear()
	
	# Get the appropriate panel
	var panel = get_panel_for_timeline(timeline_name)
	
	if panel == null:
		return
	
	# Only create arrows if there are enemies
	if not state_data.has("enemies") or state_data["enemies"].size() == 0:
		return
	
	if timeline_name == "present":
		# PRESENT: Arrow from player to leftmost enemy
		create_player_attack_arrow(panel, entity_array, arrow_array)
	elif timeline_name == "future":
		# FUTURE: Arrows from each enemy to player
		create_enemy_attack_arrows(panel, entity_array, arrow_array)

func create_player_attack_arrow(panel, entity_array: Array, arrow_array: Array):
	"""Create arrow from player to leftmost enemy in Present"""
	# Find player and first enemy entities
	var player_entity = null
	var target_enemy = null
	
	for entity in entity_array:
		if entity.is_player:
			player_entity = entity
		elif target_enemy == null:  # First enemy found = leftmost
			target_enemy = entity
	
	if player_entity and target_enemy:
		# Create arrow
		var arrow = ARROW_SCENE.instantiate()
		panel.add_child(arrow)
		
		# Calculate smart curve based on position and distance
		var curve_amount = calculate_smart_curve(player_entity.position, target_enemy.position)
		
		# Setup arrow with LOCAL positions and smart curve
		arrow.setup(player_entity.position, target_enemy.position, curve_amount)
		
		arrow_array.append(arrow)
		print("Created player attack arrow with dynamic curve: ", curve_amount)

func create_enemy_attack_arrows(panel, entity_array: Array, arrow_array: Array):
	"""Create arrows from each enemy to player in Future"""
	# Find player entity
	var player_entity = null
	for entity in entity_array:
		if entity.is_player:
			player_entity = entity
			break
	
	if not player_entity:
		return
	
	# Create arrow from each enemy to player
	for entity in entity_array:
		if not entity.is_player:  # It's an enemy
			var arrow = ARROW_SCENE.instantiate()
			panel.add_child(arrow)
			
			# Calculate smart curve based on position and distance
			var curve_amount = calculate_smart_curve(entity.position, player_entity.position)
			
			# Setup arrow with LOCAL positions and smart curve
			arrow.setup(entity.position, player_entity.position, curve_amount)
			
			arrow_array.append(arrow)
	
	print("Created ", arrow_array.size(), " enemy attack arrows with dynamic curves")

func calculate_smart_curve(from: Vector2, to: Vector2) -> float:
	"""
	Calculate arrow curve amount based on spatial relationship
	Returns a curve value that makes visual sense
	"""
	# Get direction vector
	var direction = to - from
	var horizontal_distance = abs(direction.x)
	var vertical_distance = abs(direction.y)
	
	# Calculate angle in radians
	var angle = direction.angle()
	
	# Base curve strength (scales with distance)
	var base_curve = 30.0
	
	# Adjust curve based on how horizontal vs vertical the connection is
	var horizontal_factor = horizontal_distance / max(direction.length(), 1.0)
	
	# More horizontal = more curve, more vertical = less curve
	var curve_strength = base_curve * (0.5 + horizontal_factor * 0.5)
	
	# Determine curve direction based on horizontal position
	if direction.x < 0:
		# Target is to the LEFT → curve LEFT (negative)
		return -curve_strength
	else:
		# Target is to the RIGHT → curve RIGHT (positive)
		return curve_strength

func calculate_future():
	# Copy present state to future
	future_state = present_state.duplicate(true)
	
	# Simulate combat (player attacks first enemy, enemies attack player)
	if future_state["enemies"].size() > 0:
		var target_enemy = future_state["enemies"][0]
		target_enemy["hp"] -= future_state["player"]["damage"]
		
		# Remove dead enemies
		future_state["enemies"] = future_state["enemies"].filter(func(e): return e["hp"] > 0)
		
		# Enemies attack back
		for enemy in future_state["enemies"]:
			future_state["player"]["hp"] -= enemy["damage"]
	
	print("Future calculated: Player will have ", future_state["player"]["hp"], " HP")
	
	if future_state["player"]["hp"] <= 0:
		print("WARNING: Future shows player death!")

func update_all_timelines():
	"""Update visual displays for all three timelines"""	
	# Update Past timeline
	if not past_state.is_empty():
		create_entity_visuals("past", past_state, past_entities)
	
	# Update Present timeline
	create_entity_visuals("present", present_state, present_entities)
	create_attack_arrows("present", present_state, present_entities, present_arrows)
	
	# Update Future timeline
	create_entity_visuals("future", future_state, future_entities)
	create_attack_arrows("future", future_state, future_entities, future_arrows)
	
	# Update UI displays
	update_damage_display()
	
	print("Timelines updated visually")

func update_wave_counter():
	"""Update the wave counter display"""
	wave_counter_label.text = "Wave %d/10" % current_wave

func update_damage_display():
	"""Update the damage stat display"""
	var player_damage = present_state.get("player", {}).get("damage", 0)
	damage_label.text = str(player_damage)
	
func setup_cards():
	"""Initialize the 4 card slots with random cards"""
	# Clear existing card nodes
	for card_node in card_nodes:
		card_node.queue_free()
	card_nodes.clear()
	
	# Get 4 random cards from database
	var all_cards = CardDatabase.get_all_cards()
	available_cards.clear()
	
	# Pick 4 cards (for MVP, just take first 4 - randomize later)
	for i in range(min(4, all_cards.size())):
		available_cards.append(all_cards[i])
	
	# Create visual card nodes
	for card_data in available_cards:
		var card_node = CARD_SCENE.instantiate()
		card_container.add_child(card_node)
		card_node.setup(card_data)
		
		# Connect card click signal
		card_node.card_clicked.connect(_on_card_played)
		
		card_nodes.append(card_node)
	
	# Reset turn flag
	card_played_this_turn = false
	
	print("Cards set up: ", available_cards.size(), " cards available")

func _on_card_played(card_data: Dictionary):
	"""Called when player clicks a card"""
	# Check if already played a card this turn
	if card_played_this_turn:
		print("Already played a card this turn!")
		return
	
	print("Playing card: ", card_data.get("name", "Unknown"))
	
	# Apply card effect
	apply_card_effect(card_data)
	
	# Mark that a card was played
	card_played_this_turn = true
	
	# Disable ALL cards
	for card_node in card_nodes:
		card_node.mark_as_used()
	
	# Recalculate future based on new present state
	calculate_future()
	update_all_timelines()
	
func _on_play_button_pressed():
	print("PLAY button pressed! Testing slot 0 animation...")
	
	# TEMPORARY: Test slot 0 animation
	test_slot_0_1_2_3_animation()
	
	# TODO: Re-enable this after testing
	# Hide arrows before animations
	#for arrow in present_arrows:
	#	arrow.hide_arrow()
	#for arrow in future_arrows:
	#	arrow.hide_arrow()
	#execute_turn()

func execute_turn():
	"""Execute the turn with animations and real-time damage"""
	# Disable Play button during animations
	play_button.disabled = true
	
	# STEP 1: Shift Present to Past BEFORE animations
	past_state = present_state.duplicate(true)
	update_past_timeline()
	
	# STEP 2: Animate player attack
	await animate_player_attack()
	
	# STEP 3: Animate enemy attacks
	await animate_enemy_attacks()
	
	# CRITICAL FIX: Wait for all animations to fully complete
	await get_tree().create_timer(0.3).timeout
	
	# STEP 4: Reset card system
	card_played_this_turn = false
	for card_node in card_nodes:
		card_node.reset()
	
	# STEP 5: Check win/loss conditions
	if present_state["player"]["hp"] <= 0:
		print("GAME OVER - You died!")
		game_over = true
		play_button.disabled = true
		calculate_future()
		update_all_timelines()
		disable_all_cards()
		return
	
	if present_state["enemies"].size() == 0:
		print("Wave ", current_wave, " complete!")
		advance_wave()
		play_button.disabled = false
		return
	
	# STEP 6: Calculate new future and update displays
	calculate_future()
	update_all_timelines()
	turn_number += 1
	
	# Re-enable Play button
	play_button.disabled = false
	
	print("Turn ", turn_number, " complete!")

func update_past_timeline():
	"""Update only the Past timeline visuals"""
	if not past_state.is_empty():
		create_entity_visuals("past", past_state, past_entities)

func animate_player_attack() -> void:
	"""Animate player dashing to enemy and back with damage on impact"""
	# Find player entity in Present timeline
	var player_entity = null
	var target_enemy = null
	
	for entity in present_entities:
		if entity.is_player:
			player_entity = entity
		elif target_enemy == null:
			target_enemy = entity
	
	# Safety check
	if not player_entity or not target_enemy:
		print("Cannot animate - missing player or enemy")
		return
	
	# Store original position
	var original_pos = player_entity.position
	var target_pos = target_enemy.position
	
	# Calculate position near enemy (not exactly at center)
	var direction = (target_pos - original_pos).normalized()
	var attack_pos = target_pos - direction * 50.0
	
	print("Player attack animation starting...")
	
	# Create tween for smooth animation
	var tween = create_tween()
	
	# Phase 1: Dash to enemy (0.3 seconds)
	tween.tween_property(player_entity, "position", attack_pos, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Wait for dash to complete
	await tween.finished
	
	# APPLY DAMAGE AT IMPACT MOMENT
	if present_state["enemies"].size() > 0:
		var target_enemy_data = present_state["enemies"][0]
		var damage = present_state["player"]["damage"]
		target_enemy_data["hp"] -= damage
		print("Player dealt ", damage, " damage! Enemy HP: ", target_enemy_data["hp"])
		
		# PLAY PLAYER'S ATTACK SOUND
		player_entity.play_attack_sound()
		
		# SCREEN SHAKE
		apply_screen_shake(damage * 0.5)
		
		# HIT REACTION: Enemy recoils backward
		var hit_direction = (target_enemy.position - player_entity.position).normalized()
		target_enemy.play_hit_reaction(hit_direction)
		
		# Update visual immediately
		target_enemy.entity_data = target_enemy_data
		target_enemy.update_display()
		
		# Remove enemy if dead
		if target_enemy_data["hp"] <= 0:
			print(target_enemy_data["name"], " defeated!")
			present_state["enemies"].remove_at(0)
			present_entities.erase(target_enemy)
			
			# Make enemy invisible but keep it alive for sound
			target_enemy.visible = false
			
			# Schedule destruction after sound finishes
			get_tree().create_timer(0.5).timeout.connect(func():
				if is_instance_valid(target_enemy):
					target_enemy.queue_free()
			)
	
	# Phase 2: Brief pause at enemy (0.1 seconds)
	await get_tree().create_timer(0.1).timeout
	
	# Phase 3: Dash back to original position (0.25 seconds)
	var tween2 = create_tween()
	tween2.tween_property(player_entity, "position", original_pos, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween2.finished
	
	print("Player attack animation complete!")

func animate_single_enemy_attack(enemy: Node2D, player: Node2D, enemy_data: Dictionary) -> void:
	"""Animate a single enemy dashing to player and back with damage on impact"""
	# Store original position
	var original_pos = enemy.position
	var target_pos = player.position
	
	# Calculate position near player (not exactly at center)
	var direction = (target_pos - original_pos).normalized()
	var attack_pos = target_pos - direction * 50.0
	
	# Create tween for smooth animation
	var tween = create_tween()
	
	# Phase 1: Dash to player (0.25 seconds)
	tween.tween_property(enemy, "position", attack_pos, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Wait for dash to complete
	await tween.finished
	
	# APPLY DAMAGE AT IMPACT MOMENT
	var damage = enemy_data["damage"]
	present_state["player"]["hp"] -= damage
	print(enemy_data["name"], " dealt ", damage, " damage! Player HP: ", present_state["player"]["hp"])
	
	# PLAY ENEMY'S ATTACK SOUND
	enemy.play_attack_sound()
	
	# SCREEN SHAKE
	apply_screen_shake(damage * 0.5)
	
	# HIT REACTION
	var hit_direction = (player.position - enemy.position).normalized()
	player.play_hit_reaction(hit_direction)
	
	# Update player visual immediately
	player.entity_data = present_state["player"]
	player.update_display()
	
	# Phase 2: Brief pause at player (0.08 seconds)
	await get_tree().create_timer(0.08).timeout
	
	# Phase 3: Dash back to original position (0.2 seconds)
	var tween2 = create_tween()
	tween2.tween_property(enemy, "position", original_pos, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween2.finished

func animate_enemy_attacks() -> void:
	"""Animate all enemies attacking the player sequentially"""
	# Find player entity in Present timeline
	var player_entity = null
	for entity in present_entities:
		if entity.is_player:
			player_entity = entity
			break
	
	# Safety check
	if not player_entity:
		print("Cannot animate - missing player")
		return
	
	# Get all enemy entities WITH their data
	var enemy_list = []
	for i in range(present_state["enemies"].size()):
		var enemy_data = present_state["enemies"][i]
		# Find corresponding entity node
		for entity in present_entities:
			if not entity.is_player and entity.entity_data["name"] == enemy_data["name"]:
				enemy_list.append({"node": entity, "data": enemy_data})
				break
	
	# If no enemies, skip animation
	if enemy_list.size() == 0:
		print("No enemies to animate")
		return
	
	print("Enemy attack animations starting...")
	
	# Animate each enemy attacking sequentially
	for enemy_info in enemy_list:
		await animate_single_enemy_attack(enemy_info["node"], player_entity, enemy_info["data"])
	
	print("All enemy attack animations complete!")

func advance_wave():
	current_wave += 1
	print("Starting Wave ", current_wave)
	
	# Spawn new enemies
	present_state["enemies"] = [
		{"name": "Chrono-Beast C", "hp": 50, "max_hp": 50, "damage": 14},
		{"name": "Chrono-Beast D", "hp": 35, "max_hp": 35, "damage": 10}
	]
	
	calculate_future()
	update_all_timelines()
	update_wave_counter()
	
	# Re-enable Play button for new wave
	play_button.disabled = false
	card_played_this_turn = false

func apply_card_effect(card_data: Dictionary):
	"""Apply the card's effect to the Present timeline"""
	var effect_type = card_data.get("effect_type")
	var effect_value = card_data.get("effect_value", 0)
	
	match effect_type:
		CardDatabase.EffectType.HEAL_PLAYER:
			# Heal player
			var current_hp = present_state["player"]["hp"]
			var max_hp = present_state["player"]["max_hp"]
			present_state["player"]["hp"] = min(current_hp + effect_value, max_hp)
			print("Healed ", effect_value, " HP. Now at: ", present_state["player"]["hp"])
		
		CardDatabase.EffectType.DAMAGE_ENEMY:
			# Damage first enemy
			if present_state["enemies"].size() > 0:
				present_state["enemies"][0]["hp"] -= effect_value
				print("Dealt ", effect_value, " damage to ", present_state["enemies"][0]["name"])
				# Remove if dead
				if present_state["enemies"][0]["hp"] <= 0:
					print(present_state["enemies"][0]["name"], " defeated!")
					present_state["enemies"].remove_at(0)
		
		CardDatabase.EffectType.DAMAGE_ALL_ENEMIES:
			# Damage all enemies
			var defeated = []
			for enemy in present_state["enemies"]:
				enemy["hp"] -= effect_value
				if enemy["hp"] <= 0:
					defeated.append(enemy)
			# Remove defeated enemies
			for enemy in defeated:
				present_state["enemies"].erase(enemy)
			print("Dealt ", effect_value, " damage to all enemies")
		
		CardDatabase.EffectType.BOOST_DAMAGE:
			# Temporarily boost player damage
			present_state["player"]["damage"] += effect_value
			print("Boosted damage by ", effect_value, ". Now: ", present_state["player"]["damage"])
		
		_:
			print("Unknown card effect type: ", effect_type)
			
func disable_all_cards():
	"""Disable all cards (used when player dies or game over)"""
	card_played_this_turn = true
	
	for card_node in card_nodes:
		if card_node and is_instance_valid(card_node):
			card_node.mark_as_used()
			card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	print("All cards disabled")

func _process(delta):
	"""Handle screen shake decay"""
	if shake_strength > 0:
		camera.offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
		if shake_strength < 0.1:
			shake_strength = 0.0
			camera.offset = Vector2.ZERO

func apply_screen_shake(strength: float = 10.0):
	"""Trigger screen shake effect"""
	shake_strength = strength

func animate_slot_to_snapshot(tween: Tween, panel: Panel, target_snapshot: Dictionary):
	"""Animate a panel to match a target snapshot (position, scale, modulate only)"""
	if panel == null:
		return
	
	print("🎯 Animating panel ", panel.name, " to snapshot position")
	
	# Animate position
	tween.tween_property(panel, "position", target_snapshot["position"], 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	# Animate scale
	tween.tween_property(panel, "scale", target_snapshot["scale"], 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	# Animate modulate (color/alpha)
	tween.tween_property(panel, "modulate", target_snapshot["modulate"], 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func animate_slot_0_to_void(tween: Tween, panel: Panel):
	"""Animate slot 0 (leftmost decorative) shrinking backward into carousel center"""
	if panel == null:
		return
	
	print("🌊 Animating slot 0 backward into void: ", panel.name)
	
	# Calculate center-back position (behind the carousel, smaller)
	# Move toward carousel center X, slightly back in Y
	var carousel_center_x = 960  # Screen center
	var backward_pos = Vector2(carousel_center_x - 200, panel.position.y + 50)
	
	# Animate position (slide toward center-back)
	tween.tween_property(panel, "position", backward_pos, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	# Animate scale (shrink to tiny)
	tween.tween_property(panel, "scale", Vector2(0.1, 0.1), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	# Animate fade out
	tween.tween_property(panel, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


# ===== TEST FUNCTION for Slot 0 =====
# Add this temporary test function to test just slot 0 animation

func test_slot_0_1_2_3_animation():
	"""Complete carousel with clean arrow management"""
	print("\n🧪 TESTING with clean arrow recreation...")
	
	# STEP 1: Take snapshots
	var snapshot_present_state = present_state.duplicate(true)
	var snapshot_future_state = future_state.duplicate(true)
	
	# STEP 2: Hide and DELETE ALL arrows
	print("🗑️ Deleting ALL arrows...")
	for arrow in present_arrows:
		if arrow and is_instance_valid(arrow):
			arrow.queue_free()
	for arrow in future_arrows:
		if arrow and is_instance_valid(arrow):
			arrow.queue_free()
	present_arrows.clear()
	future_arrows.clear()
	print("✅ All arrows deleted!")
	
	# STEP 3: Hide HP and damage labels
	hide_ui_elements_for_animation()
	
	# STEP 4: Update Future entities to match Present formation
	update_future_entities_to_present_formation(snapshot_present_state)
	
	# STEP 5: Instant z-index swap
	carousel_panels[2].z_index = 1
	carousel_panels[3].z_index = 2
	
	# STEP 6: Panel animations
	var tween = create_tween()
	tween.set_parallel(true)
	
	animate_slot_0_to_void(tween, carousel_panels[0])
	animate_slot_to_snapshot(tween, carousel_panels[1], carousel_snapshot[0])
	animate_slot_to_snapshot(tween, carousel_panels[2], carousel_snapshot[1])
	animate_slot_to_snapshot(tween, carousel_panels[3], carousel_snapshot[2])
	
	# Color animations
	var present_stylebox = carousel_panels[2].get_theme_stylebox("panel")
	if present_stylebox is StyleBoxFlat:
		var past_bg_color = Color(0.23921569, 0.14901961, 0.078431375, 1)
		var past_border_color = Color(0.54509807, 0.43529412, 0.2784314, 1)
		tween.tween_property(present_stylebox, "bg_color", past_bg_color, 1.0)
		tween.tween_property(present_stylebox, "border_color", past_border_color, 1.0)
	
	var future_stylebox = carousel_panels[3].get_theme_stylebox("panel")
	if future_stylebox is StyleBoxFlat:
		var present_bg_color = Color(0.11764706, 0.22745098, 0.37254903, 1)
		var present_border_color = Color(0.2901961, 0.61960787, 1, 1)
		tween.tween_property(future_stylebox, "bg_color", present_bg_color, 1.0)
		tween.tween_property(future_stylebox, "border_color", present_border_color, 1.0)
	
	# STEP 7: Wait for animation
	await tween.finished
	print("✅ Panel animations complete!")
	
	# STEP 8: Swap entity arrays
	print("\n🔄 Swapping entity arrays...")
	var temp_present = present_entities
	var temp_future = future_entities
	
	past_entities = temp_present
	present_entities = temp_future
	print("✅ Entity arrays swapped!")
	
	# STEP 9: Update timeline_type
	update_timeline_types_after_slide()
	
	# STEP 10: Update game states
	past_state = snapshot_present_state.duplicate(true)
	present_state = snapshot_present_state.duplicate(true)
	
	# STEP 11: Update entity data
	update_entity_data_no_display(past_entities, snapshot_present_state)
	update_entity_data_no_display(present_entities, snapshot_present_state)
	
	# STEP 12: Calculate Future and recreate Future entities
	calculate_future()
	create_entity_visuals("future", future_state, future_entities)
	
	# STEP 13: Show labels
	show_ui_elements_after_animation()
	
	# STEP 14: Update display (now that labels are visible)
	print("🎨 Updating displays...")
	for entity in past_entities:
		if entity and is_instance_valid(entity):
			entity.update_display()
	for entity in present_entities:
		if entity and is_instance_valid(entity):
			entity.update_display()
	
	# STEP 15: RECREATE ALL ARROWS FROM SCRATCH
	print("🏹 Recreating ALL arrows from scratch...")
	
	# Past: NO arrows (timeline_type = "past")
	# (past_arrows already empty)
	
	# Present: player → enemy arrows (timeline_type = "present")
	var present_panel = get_panel_for_timeline("present")
	if present_panel and present_state.get("enemies", []).size() > 0:
		create_player_attack_arrow(present_panel, present_entities, present_arrows)
		print("  ✅ Created Present arrows (player → enemy)")
	
	# Future: enemy → player arrows (timeline_type = "future")  
	var future_panel = get_panel_for_timeline("future")
	if future_panel and future_state.get("enemies", []).size() > 0:
		create_enemy_attack_arrows(future_panel, future_entities, future_arrows)
		print("  ✅ Created Future arrows (enemy → player)")
	
	print("✅ All arrows recreated based on timeline_type!")
	
	# STEP 16: Update panel labels
	update_panel_labels_after_slide()
	
	print("✅ Complete carousel finished!")
	
func update_entity_data_without_recreating(entity_array: Array, new_state: Dictionary):
	"""Update entity HP/damage data without recreating the visual nodes"""
	print("📊 Updating entity data for existing visuals...")
	
	# Update player
	for entity in entity_array:
		if entity and is_instance_valid(entity) and entity.is_player:
			print("  Updating player: HP ", entity.entity_data.get("hp"), " → ", new_state["player"]["hp"])
			entity.entity_data = new_state["player"].duplicate(true)
			entity.update_display()
			print("    Called update_display()")
			break
	
	# Update enemies
	var enemy_index = 0
	for entity in entity_array:
		if entity and is_instance_valid(entity) and not entity.is_player:
			if enemy_index < new_state["enemies"].size():
				var old_hp = entity.entity_data.get("hp")
				var new_hp = new_state["enemies"][enemy_index]["hp"]
				print("  Updating enemy ", enemy_index, ": HP ", old_hp, " → ", new_hp)
				
				entity.entity_data = new_state["enemies"][enemy_index].duplicate(true)
				entity.update_display()
				print("    Called update_display()")
				
				enemy_index += 1

func update_future_entities_to_present_formation(snapshot_present: Dictionary):
	"""Update Future entities to match Present formation (add missing entities)"""
	print("🔄 Updating Future entities to match Present formation...")
	
	var present_enemy_count = snapshot_present.get("enemies", []).size()
	var future_enemy_count = future_state.get("enemies", []).size()
	
	# If Future has fewer enemies, we need to add them back visually
	if future_enemy_count < present_enemy_count:
		print("⚠️ Future has fewer enemies (", future_enemy_count, " vs ", present_enemy_count, ")")
		print("   Recreating Future entities to match Present formation...")
		
		# Temporarily use Present enemy data for Future visuals
		var temp_future_state = future_state.duplicate(true)
		temp_future_state["enemies"] = snapshot_present["enemies"].duplicate(true)
		
		# Recreate Future entities with Present formation
		create_entity_visuals("future", temp_future_state, future_entities)
		
		# Update the entity data to show correct HP (will be from Present snapshot)
		for i in range(future_entities.size()):
			if not future_entities[i].is_player and i < snapshot_present["enemies"].size():
				future_entities[i].entity_data = snapshot_present["enemies"][i].duplicate(true)
				future_entities[i].update_display()

func hide_ui_elements_for_animation():
	"""Hide only HP and damage labels"""
	print("👻 Hiding HP and damage labels...")
	
	var all_entities = past_entities + present_entities + future_entities
	for entity in all_entities:
		if entity and is_instance_valid(entity):
			if entity.has_node("HPLabel"):
				entity.get_node("HPLabel").visible = false
			if entity.has_node("DamageLabel"):
				entity.get_node("DamageLabel").visible = false
	
	print("✅ Labels hidden")

func update_timeline_types_after_slide():
	"""Update timeline_type on all entities after carousel slide"""
	print("🔄 Updating timeline_type on entities...")
	
	# Past entities (were Present): timeline_type = "past"
	for entity in past_entities:
		if entity and is_instance_valid(entity):
			entity.timeline_type = "past"
			# FORCE hide damage label if it's an enemy
			if not entity.is_player and entity.has_node("DamageLabel"):
				entity.get_node("DamageLabel").visible = false
			print("  - ", entity.entity_data.get("name", "Entity"), " → past (damage hidden)")
	
	# Present entities (were Future): timeline_type = "present"
	for entity in present_entities:
		if entity and is_instance_valid(entity):
			entity.timeline_type = "present"
			# FORCE show damage label if it's an enemy
			if not entity.is_player and entity.has_node("DamageLabel"):
				entity.get_node("DamageLabel").visible = true
			print("  - ", entity.entity_data.get("name", "Entity"), " → present (damage visible)")
	
	# Future entities stay "future"
	for entity in future_entities:
		if entity and is_instance_valid(entity):
			# Should already be "future" from create_entity_visuals()
			if not entity.is_player and entity.has_node("DamageLabel"):
				entity.get_node("DamageLabel").visible = false
			print("  - ", entity.entity_data.get("name", "Entity"), " → future (damage hidden)")
	
	print("✅ Timeline types updated with forced damage visibility!")


func recreate_arrows_after_slide():
	"""Recreate ONLY Present arrows (player→enemy)"""
	print("🏹 Recreating Present arrows only...")
	
	# Present arrows should already be cleared in step 7
	# But clear again just to be safe
	for arrow in present_arrows:
		if arrow and is_instance_valid(arrow):
			arrow.queue_free()
	present_arrows.clear()
	
	# Create new Present arrows (player → enemy)
	var present_panel = get_panel_for_timeline("present")
	if present_panel and present_state.get("enemies", []).size() > 0:
		create_player_attack_arrow(present_panel, present_entities, present_arrows)
		print("✅ Created player→enemy arrow for Present")
	
	# Past has NO arrows (don't create any!)
	# Future arrows were already created in step 12
	
	print("✅ Arrows recreated!")


func show_ui_elements_after_animation():
	"""Show UI elements with correct visibility rules for each timeline"""
	print("✨ Showing UI elements with timeline-specific rules...")
	
	# === PAST (was Present) ===
	for entity in past_entities:
		if entity and is_instance_valid(entity):
			# Show HP labels
			if entity.has_node("HPLabel"):
				entity.get_node("HPLabel").visible = true
			
			# CRITICAL: Force damage labels HIDDEN in Past
			if entity.has_node("DamageLabel") and not entity.is_player:
				var damage_label = entity.get_node("DamageLabel")
				damage_label.visible = false
				# The entity's _process() will handle hover behavior now that timeline_type = "past"
	
	# NO ARROWS in Past
	
	# === PRESENT (was Future) ===
	for entity in present_entities:
		if entity and is_instance_valid(entity):
			# Show HP labels
			if entity.has_node("HPLabel"):
				entity.get_node("HPLabel").visible = true
			
			# CRITICAL: Force damage labels VISIBLE for Present enemies
			if entity.has_node("DamageLabel") and not entity.is_player:
				var damage_label = entity.get_node("DamageLabel")
				damage_label.visible = true
				# Note: entity.gd _process() returns early for Present, so labels stay visible
	
	# Show Present arrows (player → enemy)
	for arrow in present_arrows:
		if arrow and is_instance_valid(arrow):
			arrow.visible = true
			arrow.show_arrow()
	
	# === FUTURE ===
	for entity in future_entities:
		if entity and is_instance_valid(entity):
			# Show HP labels
			if entity.has_node("HPLabel"):
				entity.get_node("HPLabel").visible = true
			
			# CRITICAL: Force damage labels HIDDEN in Future
			if entity.has_node("DamageLabel") and not entity.is_player:
				var damage_label = entity.get_node("DamageLabel")
				damage_label.visible = false
				# The entity's _process() will handle hover behavior now that timeline_type = "future"
	
	# Show Future arrows (enemies → player)
	for arrow in future_arrows:
		if arrow and is_instance_valid(arrow):
			arrow.visible = true
			arrow.show_arrow()
	
	print("✅ UI elements shown with correct timeline rules!")


func hide_all_entities_completely():
	"""Hide ALL entities (sprites, HP, damage) during carousel animation"""
	print("👻 Hiding all entities completely...")
	
	var all_entities = past_entities + present_entities + future_entities
	
	for entity in all_entities:
		if entity and is_instance_valid(entity):
			# Hide the entire entity (sprite + labels)
			entity.visible = false


func show_arrows_and_damage_labels_for_present():
	"""Show arrows and damage labels after carousel animation"""
	print("✨ Showing arrows and damage labels for new Present...")
	
	# Show present arrows (player → enemy)
	for arrow in present_arrows:
		if arrow and is_instance_valid(arrow):
			arrow.visible = true
			arrow.show_arrow()
	
	# Show future arrows (enemies → player)
	for arrow in future_arrows:
		if arrow and is_instance_valid(arrow):
			arrow.visible = true
			arrow.show_arrow()
	
	# Show damage labels ONLY for Present timeline entities
	for entity in present_entities:
		if entity and is_instance_valid(entity) and not entity.is_player:
			if entity.has_node("DamageLabel"):
				entity.get_node("DamageLabel").visible = true

func hide_arrows_and_damage_labels():
	"""Hide arrows and damage labels before carousel animation"""
	print("👻 Hiding arrows and damage labels...")
	
	# Hide all present arrows
	for arrow in present_arrows:
		if arrow and is_instance_valid(arrow):
			arrow.visible = false
	
	# Hide all future arrows
	for arrow in future_arrows:
		if arrow and is_instance_valid(arrow):
			arrow.visible = false
	
	# Hide damage labels on all entities
	var all_entities = past_entities + present_entities + future_entities
	for entity in all_entities:
		if entity and is_instance_valid(entity):
			if entity.has_node("DamageLabel"):
				entity.get_node("DamageLabel").visible = false


func fade_out_hp_labels():
	"""Fade out only HP labels (not damage labels)"""
	print("👻 Fading out HP labels...")
	
	var all_entities = past_entities + present_entities + future_entities
	for entity in all_entities:
		if entity and is_instance_valid(entity):
			if entity.has_node("HPLabel"):
				entity.get_node("HPLabel").modulate.a = 0.0


func fade_in_hp_labels():
	"""Fade in HP labels after animation"""
	print("✨ Fading in HP labels...")
	
	var all_entities = past_entities + present_entities + future_entities
	for entity in all_entities:
		if entity and is_instance_valid(entity):
			if entity.has_node("HPLabel"):
				entity.get_node("HPLabel").modulate.a = 1.0

func update_panel_labels_after_slide():
	"""Update the text labels inside panels to match their new timeline positions"""
	print("🏷️ Updating panel labels...")
	
	# After carousel slide:
	# - carousel_panels[1] (was Past) → now Decorative Past
	# - carousel_panels[2] (was Present) → now Past
	# - carousel_panels[3] (was Future) → now Present
	
	# Update the panel that's now in Past position (was Present)
	var new_past_panel = carousel_panels[2]
	if new_past_panel and new_past_panel.has_node("PresentLabel"):
		var label = new_past_panel.get_node("PresentLabel")
		label.text = "⟲ PAST"
		print("  Updated past panel label")
	
	# Update the panel that's now in Present position (was Future)  
	var new_present_panel = carousel_panels[3]
	if new_present_panel and new_present_panel.has_node("FutureLabel"):
		var label = new_present_panel.get_node("FutureLabel")
		label.text = "◉ PRESENT"
		print("  Updated present panel label")
	
	# The new Future panel will be created in step 12, so its label is already correct
	
	print("✅ Panel labels updated!")

func debug_panel_children(panel_name: String):
	"""Debug helper to see what nodes are in a panel"""
	var panel = get_panel_for_timeline(panel_name)
	if panel:
		print("\n🔍 DEBUG: Children of ", panel_name, " panel:")
		for child in panel.get_children():
			print("  - ", child.name, " (", child.get_class(), ")")
			if child is Node2D:
				print("    Position: ", child.position)
				if child.has_node("HPLabel"):
					print("    HP Label: ", child.get_node("HPLabel").text)
		print()

func update_entity_data_no_display(entity_array: Array, new_state: Dictionary):
	"""Update entity data WITHOUT calling update_display()"""
	print("📊 Updating entity internal data...")
	
	# Update player
	for entity in entity_array:
		if entity and is_instance_valid(entity) and entity.is_player:
			entity.entity_data = new_state["player"].duplicate(true)
			print("  Player data updated: HP=", entity.entity_data.get("hp"))
			break
	
	# Update enemies
	var enemy_index = 0
	for entity in entity_array:
		if entity and is_instance_valid(entity) and not entity.is_player:
			if enemy_index < new_state["enemies"].size():
				entity.entity_data = new_state["enemies"][enemy_index].duplicate(true)
				print("  Enemy ", enemy_index, " data updated: HP=", entity.entity_data.get("hp"))
				enemy_index += 1