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

# Entity tracking (ADD THESE LINES)
var past_entities = []
var present_entities = []
var future_entities = []

# Card tracking
var available_cards = []  # Card data from CardDatabase
var card_nodes = []        # Visual card nodes

var present_arrows = []
var future_arrows = []

# References to UI elements (we'll connect these soon)
# References to UI elements
@onready var past_panel = $UIRoot/PastPanel
@onready var present_panel = $UIRoot/PresentPanel
@onready var future_panel = $UIRoot/FuturePanel
@onready var play_button = $UIRoot/PlayButton
@onready var wave_counter_label = $UIRoot/WaveCounter/WaveLabel
@onready var damage_label = $UIRoot/DamageDisplay/DamageLabel
@onready var card_container = $UIRoot/CardContainer

func _ready():
	print("ChronoShift - Game Manager Ready!")
	play_button.pressed.connect(_on_play_button_pressed)
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
	
	# Get the appropriate panel
	var panel = null
	match timeline_name:
		"past":
			panel = past_panel
		"present":
			panel = present_panel
		"future":
			panel = future_panel
	
	if panel == null:
		print("ERROR: Could not find panel for ", timeline_name)
		return
	
	# Panel dimensions (600x750)
	var panel_width = 600
	var panel_height = 750
	var center_x = panel_width / 2
	
	# Create enemy entities in semicircle formation at top
	if state_data.has("enemies"):
		var enemy_count = state_data["enemies"].size()
		
		# Semicircle parameters
		var arc_center_x = center_x
		var arc_center_y = 250
		var arc_radius = 120
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
		
		# Position player at bottom center
		player_entity.position = Vector2(center_x, panel_height - 150)
		
		# Now add to scene tree
		panel.add_child(player_entity)
		entity_array.append(player_entity)
	
	print("=== Finished creating entities for ", timeline_name, " ===\n")

func create_attack_arrows(timeline_name: String, state_data: Dictionary, entity_array: Array, arrow_array: Array):
	"""Create attack arrows for a timeline"""
	# Clear existing arrows
	for old_arrow in arrow_array:
		old_arrow.queue_free()
	arrow_array.clear()
	
	# Get the appropriate panel
	var panel = null
	match timeline_name:
		"present":
			panel = present_panel
		"future":
			panel = future_panel
		_:
			return  # No arrows for Past
	
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
		# Optional: could disable Play button here as a warning
		# play_button.disabled = true

func update_all_timelines():
	"""Update visual displays for all three timelines"""	
	# Update Past timeline
	if not past_state.is_empty():
		create_entity_visuals("past", past_state, past_entities)
	
	# Update Present timeline
	create_entity_visuals("present", present_state, present_entities)
	create_attack_arrows("present", present_state, present_entities, present_arrows)  # ADD THIS
	
	# Update Future timeline
	create_entity_visuals("future", future_state, future_entities)
	create_attack_arrows("future", future_state, future_entities, future_arrows)  # ADD THIS
	
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
	
	# Disable ALL cards (ADD THIS SECTION)
	for card_node in card_nodes:
		card_node.mark_as_used()
	
	# Recalculate future based on new present state
	calculate_future()
	update_all_timelines()
	
func _on_play_button_pressed():
	print("PLAY button pressed! Executing turn...")
	
	# Hide arrows before animations (ADD THIS SECTION)
	for arrow in present_arrows:
		arrow.hide_arrow()
	for arrow in future_arrows:
		arrow.hide_arrow()
	
	execute_turn()

func execute_turn():
	# Reset card system for new turn
	card_played_this_turn = false
	for card_node in card_nodes:
		card_node.reset()
	
	# Shift: Present becomes Past
	past_state = present_state.duplicate(true)
	
	# Execute combat (Present becomes what Future predicted)
	present_state = future_state.duplicate(true)
	
	# Check win/loss
	if present_state["player"]["hp"] <= 0:
		print("GAME OVER - You died!")
		game_over = true
		play_button.disabled = true      # DISABLE PLAY BUTTON
		update_all_timelines()
		disable_all_cards()                # DISABLE ALL CARDS
		return
	
	if present_state["enemies"].size() == 0:
		print("Wave ", current_wave, " complete!")
		advance_wave()
		return
	
	# Calculate new future
	calculate_future()
	update_all_timelines()
	turn_number += 1

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
	card_played_this_turn = true  # Prevent card plays
	
	for card_node in card_nodes:
		if card_node and is_instance_valid(card_node):  # ← ADD THIS CHECK
			card_node.mark_as_used()
			card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	print("All cards disabled")
