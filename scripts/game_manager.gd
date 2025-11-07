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
		"position": Vector2(50, 200),
		"scale": Vector2(0.4, 0.4),
		"modulate": Color(1.0, 1.0, 1.0, 1.0),
		"z_index": 0
	},
	# Slot 1: Past (fully visible)
	{
		"position": Vector2(200, 150),
		"scale": Vector2(0.75, 0.75),
		"modulate": Color(1.0, 1.0, 1.0, 1.0),
		"z_index": 1
	},
	# Slot 2: Present (center, focused)
	{
		"position": Vector2(585, 90),
		"scale": Vector2(1.0, 1.0),
		"modulate": Color(1.0, 1.0, 1.0, 1.0),
		"z_index": 2
	},
	# Slot 3: Future (fully visible)
	{
		"position": Vector2(1270, 150),
		"scale": Vector2(0.75, 0.75),
		"modulate": Color(1.0, 1.0, 1.0, 1.0),
		"z_index": 1
	},
	# Slot 4: Far-right decorative
	{
		"position": Vector2(1570, 200),
		"scale": Vector2(0.4, 0.4),
		"modulate": Color(1.0, 1.0, 1.0, 1.0),
		"z_index": 0
	},
	# Slot 5: Hidden off-screen right (for rotation)
	{
		"position": Vector2(2000, 250),
		"scale": Vector2(0.2, 0.2),
		"modulate": Color(1.0, 1.0, 1.0, 1.0),
		"z_index": -1
	}
]

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
	
	print("Carousel system initialized with 6 positions")

func apply_carousel_position(panel: Panel, slot_index: int):
	"""Apply position, scale, modulate, and z-index to a panel based on slot"""
	if slot_index < 0 or slot_index >= carousel_positions.size():
		return
	
	var pos_data = carousel_positions[slot_index]
	
	# Apply visual properties
	panel.position = pos_data["position"]
	panel.scale = pos_data["scale"]
	panel.modulate = pos_data["modulate"]
	
	# CRITICAL FIX: Use z_as_relative = false and set explicit z_index
	panel.z_as_relative = false
	panel.z_index = pos_data["z_index"]
	
	# Force panel to move to correct layer in scene tree
	# Higher z_index panels need to be LATER in draw order
	var parent = panel.get_parent()
	if parent:
		parent.move_child(panel, -1)  # Move to end first
		# Then reorder based on z_index
		if slot_index == 2:  # Present - draw last (on top)
			parent.move_child(panel, parent.get_child_count() - 1)
	
	# Update panel size based on slot (decorative panels are smaller)
	if slot_index == 0 or slot_index == 4 or slot_index == 5:
		# Decorative panels: 300x500
		panel.size = Vector2(300, 500)
	elif slot_index == 1 or slot_index == 3:
		# Past/Future panels: 450x600
		panel.size = Vector2(450, 600)
	else:
		# Present panel: 750x750
		panel.size = Vector2(750, 750)

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
	
	# Clear existing entities
	for old_entity in entity_array:
		old_entity.queue_free()
	entity_array.clear()
	
	# Get the appropriate panel based on carousel state
	var panel = get_panel_for_timeline(timeline_name)
	
	if panel == null:
		print("ERROR: Could not find panel for ", timeline_name)
		return
	
	# Use each panel's actual dimensions for proper centering
	var panel_width = panel.size.x
	var panel_height = panel.size.y
	var center_x = panel_width / 2
	
	# Create enemy entities in semicircle formation at top
	if state_data.has("enemies"):
		var enemy_count = state_data["enemies"].size()
		
		# Semicircle parameters (scale with actual panel size)
		var arc_center_x = center_x
		var arc_center_y = panel_height * 0.33
		var arc_radius = panel_width * 0.2
		var arc_span = PI * 0.6
		
		for i in range(enemy_count):
			var enemy_entity = ENTITY_SCENE.instantiate()
			
			# CRITICAL: Call setup() BEFORE add_child()
			enemy_entity.setup(state_data["enemies"][i], false, timeline_name)
			
			# Calculate angle for this enemy
			var angle_offset = 0
			if enemy_count > 1:
				angle_offset = (float(i) / (enemy_count - 1) - 0.5) * arc_span
			
			# Convert angle to position
			var pos_x = arc_center_x + arc_radius * sin(angle_offset)
			var pos_y = arc_center_y - arc_radius * cos(angle_offset)
			
			enemy_entity.position = Vector2(pos_x, pos_y)
			
			# Now add to scene tree (_ready() will see correct timeline_type)
			panel.add_child(enemy_entity)
			entity_array.append(enemy_entity)
	
	# Create player entity at bottom center
	if state_data.has("player"):
		var player_entity = ENTITY_SCENE.instantiate()
		
		# CRITICAL: Call setup() BEFORE add_child()
		player_entity.setup(state_data["player"], true, timeline_name)
		
		# Position player at bottom center (based on actual panel size)
		player_entity.position = Vector2(center_x, panel_height * 0.8)
		
		# Now add to scene tree
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
	print("PLAY button pressed! Executing turn...")
	
	# Hide arrows before animations
	for arrow in present_arrows:
		arrow.hide_arrow()
	for arrow in future_arrows:
		arrow.hide_arrow()
	
	execute_turn()

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