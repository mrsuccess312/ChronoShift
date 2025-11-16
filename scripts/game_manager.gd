extends Node2D

# ===== PRELOADS =====
const TIMELINE_PANEL_SCENE = preload("res://scenes/timeline_panel.tscn")
const ENTITY_SCENE = preload("res://scenes/entity.tscn")
const CARD_SCENE = preload("res://scenes/card.tscn")
const ARROW_SCENE = preload("res://scenes/arrow.tscn")

# ===== GAME STATE =====
var current_wave = 1
var turn_number = 0
var game_over = false

# ===== TIMER STATE =====
var timer_active = true
var time_remaining = 60.0  # Default: 60 seconds (1 minute)
var max_time = 60.0

# Track base damage (for resetting after damage boost)
var base_player_damage = 15

# Track temporary effects
var damage_boost_active = false  # Whether damage boost was used this turn
var temporary_entities = []  # Past Twins, Conscripted Enemies

# Track conscription state
var conscription_active = false  # Whether an enemy is fighting in player's place
var original_player_data = {}  # Original player stats before conscription
var conscripted_enemy_data = {}  # The enemy currently fighting as player

# Track Future manipulation flags
var future_miss_flags = {}  # { enemy_index: true } for enemies that will miss
var future_redirect_flag = null  # { from_enemy: index, to_enemy: index }

# ===== TARGETING MODE STATE =====
var targeting_mode_active = false  # Whether we're in targeting mode
var targeting_card_data = {}  # The card being played
var targeting_card_node = null  # The card node that's targeting
var targeting_source_deck = null  # Which deck the card came from
var selected_targets = []  # Array of selected targets (entities or cells)
var required_target_count = 0  # How many targets this card needs
var targeting_click_handled = false  # Flag to track if last click was on valid target
var valid_target_timelines = []  # Array of timeline types that can be targeted

# ===== UI/UX SETTINGS =====
var enable_panel_hover: bool = true  # Enable floating hover animation on panels
var show_grid_lines: bool = false    # Show grid cell borders
var show_debug_grid: bool = false    # Show grid cell coordinates

# ===== CARD DECK SYSTEM =====
class CardDeck:
	"""Manages a deck of cards for one timeline type"""
	var timeline_type: int  # CardDatabase.TimelineType enum
	var container: Control  # UI container for this deck
	var cards: Array = []   # Card data array (all cards in deck)
	var card_nodes: Array = []  # Visual card nodes (stacked)
	
	func _init(type: int, cont: Control):
		timeline_type = type
		container = cont
	
	func get_top_card() -> Node:
		"""Get the top (visible) card node"""
		if card_nodes.size() > 0:
			return card_nodes[card_nodes.size() - 1]
		return null
	
	func get_top_card_data() -> Dictionary:
		"""Get the top card's data"""
		if cards.size() > 0:
			return cards[cards.size() - 1]
		return {}

var past_deck: CardDeck
var present_deck: CardDeck
var future_deck: CardDeck

# ===== SCREEN SHAKE =====
var shake_strength = 0.0
var shake_decay = 5.0

# ===== CAROUSEL SYSTEM =====
var timeline_panels: Array = []  # 6 timeline panel nodes (Panel instances)

var is_first_turn = true

# Carousel position definitions (slot 0 = far-left, slot 2 = center/present)
var carousel_positions = [
	# Slot 0: Far-left decorative
	{
		"position": Vector2(0, 150),
		"scale": Vector2(0.6, 0.6),
		"modulate": Color(1.0, 1.0, 1.0, 1.0),
		"z_index": 0
	},
	# Slot 1: Past
	{
		"position": Vector2(136, 125),
		"scale": Vector2(0.75, 0.75),
		"modulate": Color(1.0, 1.0, 1.0, 1.0),
		"z_index": 1
	},
	# Slot 2: Present
	{
		"position": Vector2(660, 90),
		"scale": Vector2(1.0, 1.0),
		"modulate": Color(1.0, 1.0, 1.0, 1.0),
		"z_index": 2
	},
	# Slot 3: Future
	{
		"position": Vector2(1184, 125),
		"scale": Vector2(0.75, 0.75),
		"modulate": Color(1.0, 1.0, 1.0, 1.0),
		"z_index": 1
	},
	# Slot 4: Decorative Future
	{
		"position": Vector2(1320, 150),
		"scale": Vector2(0.6, 0.6),
		"modulate": Color(1.0, 1.0, 1.0, 1.0),
		"z_index": 0
	},
	# Slot 5: Intermediate (VISIBLE, further right)
	{
		"position": Vector2(1300, 175),   # Visible position!
		"scale": Vector2(0.5, 0.5),        # Smaller than decorative
		"modulate": Color(1.0, 1.0, 1.0, 0.7),  # Semi-transparent!
		"z_index": -1
	}
]

var carousel_snapshot = []

# ===== UI REFERENCES =====
@onready var carousel_container = $UIRoot/CarouselContainer
@onready var play_button = $UIRoot/PlayButton
@onready var timer_label = $UIRoot/TimerLabel
@onready var wave_counter_label = $UIRoot/WaveCounter/WaveLabel
@onready var damage_label = $UIRoot/DamageDisplay/DamageLabel
@onready var past_deck_container = $UIRoot/DeckContainers/PastDeckContainer
@onready var present_deck_container = $UIRoot/DeckContainers/PresentDeckContainer
@onready var future_deck_container = $UIRoot/DeckContainers/FutureDeckContainer
@onready var camera = $Camera2D


# ===== INITIALIZATION =====

func _ready():
	print("ChronoShift - Game Manager Ready!")
	play_button.pressed.connect(_on_play_button_pressed)
	
	setup_carousel()
	initialize_game()

func _input(event):
	"""Handle global input events"""
	if event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()

	# Handle ESC key to cancel targeting mode
	if event.is_action_pressed("ui_cancel") and targeting_mode_active:
		print("ESC pressed - canceling targeting mode")
		cancel_targeting_mode()

	# Handle clicks on empty space to cancel targeting
	if targeting_mode_active and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Reset the flag - will be set to true if entity is clicked
			targeting_click_handled = false
			# Use call_deferred to check after entity clicks have been processed
			call_deferred("_check_cancel_targeting_from_click")

func _check_cancel_targeting_from_click():
	"""Called after a click to check if targeting should be canceled"""
	if not targeting_mode_active:
		return

	# If the click wasn't handled by a valid target, cancel targeting
	if not targeting_click_handled:
		print("Clicked on empty space - canceling targeting mode")
		cancel_targeting_mode()

	# Reset flag for next click
	targeting_click_handled = false

func toggle_fullscreen():
	"""Switch between windowed and fullscreen mode"""
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		print("Switched to Windowed mode")
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		print("Switched to Fullscreen mode")


# ===== CAROUSEL SETUP =====

func setup_carousel():
	"""Initialize carousel with 6 dynamically created timeline panels"""
	print("Setting up carousel with 6 panels...")

	# Create 6 timeline panel instances
	var panel_types = ["decorative", "past", "present", "future", "decorative", "decorative"]

	for i in range(6):
		var panel = TIMELINE_PANEL_SCENE.instantiate()
		panel.initialize(panel_types[i], i)

		# Apply styling based on type
		apply_panel_styling(panel, panel_types[i], i)

		# Add to carousel container
		carousel_container.add_child(panel)

		# Apply carousel position
		apply_carousel_position(panel, i)

		# Store in array
		timeline_panels.append(panel)

		print("  Created panel ", i, " (", panel_types[i], ")")

	# Move present panel to front for proper z-ordering
	if timeline_panels.size() > 2:
		carousel_container.move_child(timeline_panels[2], -1)

	# Set mouse filters: only topmost panel blocks input from reaching lower panels
	update_panel_mouse_filters()

	# Apply UI settings to all panels
	apply_ui_settings_to_panels()

	build_carousel_snapshot()
	print("✅ Carousel initialized with ", timeline_panels.size(), " panels")

func apply_panel_styling(panel: Panel, timeline_type: String, i: int):
	"""Apply visual styling to panel based on timeline type"""
	var stylebox = StyleBoxFlat.new()
	stylebox.border_width_left = 2
	stylebox.border_width_top = 2
	stylebox.border_width_right = 2
	stylebox.border_width_bottom = 2

	if timeline_type == "past":
		stylebox.bg_color = Color(0.23921569, 0.14901961, 0.078431375, 1)
		stylebox.border_color = Color(0.54509807, 0.43529412, 0.2784314, 1)
		update_panel_label_text(panel, "⟲ PAST")
	if timeline_type == "present":
		stylebox.bg_color = Color(0.11764706, 0.22745098, 0.37254903, 1)
		stylebox.border_color = Color(0.2901961, 0.61960787, 1, 1)
		update_panel_label_text(panel, "◉ PRESENT")
	if timeline_type == "future":
		stylebox.bg_color = Color(0.1764706, 0.105882354, 0.23921569, 1)
		stylebox.border_color = Color(0.7058824, 0.47843137, 1, 1)
		update_panel_label_text(panel, "⟳ FUTURE")
	if timeline_type == "decorative" and i == 0:
		stylebox.bg_color = Color(0.23921569, 0.14901961, 0.078431375, 1)
		stylebox.border_color = Color(0.54509807, 0.43529412, 0.2784314, 1)
		update_panel_label_text(panel, "")
	if timeline_type == "decorative" and i > 3:
		stylebox.bg_color = Color(0.1764706, 0.105882354, 0.23921569, 1)
		stylebox.border_color = Color(0.7058824, 0.47843137, 1, 1)
		update_panel_label_text(panel, "")

	panel.add_theme_stylebox_override("panel", stylebox)

func update_panel_label_text(panel: Panel, text: String):
	"""Update the label text of a panel"""
	if panel.has_node("PanelLabel"):
		panel.get_node("PanelLabel").text = text

func update_panel_mouse_filters():
	"""Enable grids and effects only on panels with z_index > 0"""
	print("🔧 Updating panel interactivity based on z_index...")

	for panel in timeline_panels:
		if panel.z_index > 0:
			# Panel is visible and should be interactive
			panel.set_grid_interactive(true)  # Enable grid cells
		else:
			# Panel is decorative/background (z <= 0) - should not be interactive
			panel.set_grid_interactive(false)  # Disable grid cells
			print("  Panel ", panel.timeline_type, " (z=", panel.z_index, ") - NON-INTERACTIVE")
		panel.start_hover_animation()

func apply_ui_settings_to_panels():
	"""Apply UI/UX settings to all timeline panels"""
	print("🎨 Applying UI settings to panels...")

	for panel in timeline_panels:
		# Grid lines visibility
		panel.show_grid_lines(show_grid_lines)

		# Debug grid coordinates visibility
		panel.show_debug_info(show_debug_grid)

	print("  Grid lines: ", show_grid_lines)
	print("  Debug grid: ", show_debug_grid)
	print("  Panel hover: ", enable_panel_hover)

func build_carousel_snapshot():
	"""Build snapshot of target states for all 6 carousel positions"""
	carousel_snapshot = []
	
	for i in range(6):
		var snapshot = {
			"position": carousel_positions[i]["position"],
			"scale": carousel_positions[i]["scale"],
			"modulate": carousel_positions[i]["modulate"],
			"z_index": carousel_positions[i]["z_index"]
		}
		carousel_snapshot.append(snapshot)
	
	print("📸 Carousel snapshot built")

func apply_carousel_position(panel: Panel, slot_index: int):
	"""Apply position, scale, modulate, and z-index to a panel"""
	if slot_index < 0 or slot_index >= carousel_positions.size():
		return
	
	var pos_data = carousel_positions[slot_index]
	
	panel.position = pos_data["position"]
	panel.scale = pos_data["scale"]
	panel.modulate = pos_data["modulate"]
	panel.z_as_relative = false
	panel.z_index = pos_data["z_index"]
	
	# CRITICAL FIX: Force scene tree draw order based on z_index
	var parent = panel.get_parent()
	if parent:
		# Move to correct position in scene tree based on z_index
		# Lower z_index = earlier in tree (drawn first, appears behind)
		# Higher z_index = later in tree (drawn last, appears on top)
		
		# Get all panels and sort by z_index
		var all_panels = []
		for child in parent.get_children():
			if child is Panel and child != panel:
				all_panels.append(child)
		
		# Find correct insert position based on z_index
		var insert_position = 0
		for other_panel in all_panels:
			if other_panel.z_index < panel.z_index:
				insert_position += 1
		
		# Move panel to correct position
		parent.move_child(panel, insert_position)
		
		print("  Applied position to ", panel.name, " at slot ", slot_index, 
			  " with z_index ", panel.z_index, " at scene position ", insert_position)


# ===== GAME INITIALIZATION =====

func initialize_game():
	"""Set up initial game state"""
	print("Initializing Wave ", current_wave)
	
	# Get the Present timeline panel
	var present_timeline = get_timeline_panel("present")
	
	# Create initial state
	present_timeline.state = {
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
	
	# Store base damage
	base_player_damage = 15

	# Calculate initial Future
	calculate_future_state()

	# Create visuals for all timelines
	update_all_timeline_displays()
	update_wave_counter()
	setup_cards()

	# Initialize timer display
	update_timer_display()

func get_timeline_panel(timeline_type: String) -> Panel:
	"""Get the timeline panel with the specified timeline_type"""
	for tp in timeline_panels:
		if tp.timeline_type == timeline_type:
			return tp
	return null


# ===== ENTITY & ARROW CREATION =====

func find_empty_cell_left_of_player(tp: Panel, player_pos: Vector2i, enemy_count: int) -> Vector2i:
	"""Find the nearest empty cell to the left of the player for twin placement
	Returns grid coordinates (row, col)
	"""
	# Try cells to the left of player first (same row, col-1)
	var test_positions = [
		Vector2i(player_pos.x, player_pos.y - 1),  # Directly left
		Vector2i(player_pos.x - 1, player_pos.y - 1),  # Up-left diagonal
		Vector2i(player_pos.x + 1, player_pos.y - 1),  # Down-left diagonal
		Vector2i(player_pos.x, player_pos.y + 1),  # Right (fallback)
		Vector2i(player_pos.x - 1, player_pos.y),  # Up
		Vector2i(player_pos.x + 1, player_pos.y),  # Down
	]

	# Check each position to see if it's empty and valid
	for pos in test_positions:
		if pos.x >= 0 and pos.x < tp.GRID_ROWS and pos.y >= 0 and pos.y < tp.GRID_COLS:
			if not tp.is_cell_occupied(pos.x, pos.y):
				return pos

	# Fallback: return position left of player even if occupied
	return Vector2i(player_pos.x, max(0, player_pos.y - 1))

func create_timeline_entities(tp: Panel):
	"""Create entity visuals for a timeline panel using grid-based positioning"""
	print("\n=== Creating entities for ", tp.timeline_type, " timeline ===")

	# Clear old entities
	tp.clear_entities()

	if tp == null or tp.state.is_empty():
		print("  No panel or empty state, skipping")
		return

	# Clear any orphaned nodes from panel
	for child in tp.get_children():
		if child is Node2D and "Label" not in child.name:
			child.queue_free()

	var enemy_count = tp.state.get("enemies", []).size()

	# Create enemy entities using grid positioning
	if tp.state.has("enemies"):
		for i in range(enemy_count):
			var enemy_entity = ENTITY_SCENE.instantiate()
			enemy_entity.setup(tp.state["enemies"][i], false, tp.timeline_type)

			# Get grid position for this enemy
			var grid_pos = tp.get_grid_position_for_entity(i, false, enemy_count)
			var world_pos = tp.get_cell_center_position(grid_pos.x, grid_pos.y)

			enemy_entity.position = world_pos
			tp.add_child(enemy_entity)
			tp.entities.append(enemy_entity)

			print("  Enemy ", i, " placed at grid (", grid_pos.x, ", ", grid_pos.y, ") -> world ", world_pos)

	# Create player entity using grid positioning
	var player_grid_pos = Vector2i(-1, -1)
	if tp.state.has("player"):
		var player_entity = ENTITY_SCENE.instantiate()
		player_entity.setup(tp.state["player"], true, tp.timeline_type)

		# Get grid position for player
		player_grid_pos = tp.get_grid_position_for_entity(0, true, enemy_count)
		var world_pos = tp.get_cell_center_position(player_grid_pos.x, player_grid_pos.y)

		player_entity.position = world_pos
		tp.add_child(player_entity)
		tp.entities.append(player_entity)

		print("  Player placed at grid (", player_grid_pos.x, ", ", player_grid_pos.y, ") -> world ", world_pos)

	# Create twin entity if it exists
	if tp.state.has("twin"):
		var twin_entity = ENTITY_SCENE.instantiate()
		twin_entity.setup(tp.state["twin"], true, tp.timeline_type)  # is_player=true for similar visual

		# Place twin directly to the left of player (same row, col-1)
		var twin_grid_pos = Vector2i(player_grid_pos.x, player_grid_pos.y - 1)

		# Ensure twin is within grid bounds
		if twin_grid_pos.y < 0:
			twin_grid_pos.y = 0  # Can't go further left, place at leftmost column

		var world_pos = tp.get_cell_center_position(twin_grid_pos.x, twin_grid_pos.y)

		twin_entity.position = world_pos
		tp.add_child(twin_entity)
		tp.entities.append(twin_entity)

		print("  Twin placed at grid (", twin_grid_pos.x, ", ", twin_grid_pos.y, ") -> world ", world_pos)

	print("  Created ", tp.entities.size(), " entities")

func create_timeline_arrows(tp: Panel):
	"""Create arrows for a timeline panel based on its timeline_type"""
	print("🏹 Creating arrows for ", tp.timeline_type, " timeline...")

	# Clear old arrows
	tp.clear_arrows()

	if tp == null or tp.state.is_empty():
		return
	
	if not tp.state.has("enemies") or tp.state["enemies"].size() == 0:
		print("  No enemies, no arrows needed")
		return
	
	match tp.timeline_type:
		"past":
			# Past: NO arrows
			print("  Past timeline - no arrows")
		
		"present":
			# Present: Player → Enemy arrows
			create_player_attack_arrows(tp)
			print("  Created player → enemy arrows")
		
		"future":
			# Future: Enemy → Player arrows (or Enemy → Enemy if redirected)
			create_enemy_attack_arrows(tp)
			print("  Created enemy → player arrows")

func create_player_attack_arrows(tp: Panel):
	"""Create arrows from player and twin to leftmost enemy (grid-based targeting)"""
	var player_entity = null
	var twin_entity = null

	# Find player and twin entities
	for entity in tp.entities:
		if entity.is_player:
			if entity.entity_data.get("is_twin", false):
				twin_entity = entity
			else:
				player_entity = entity

	if not player_entity:
		return

	# Get leftmost enemy using grid-based targeting
	var target_enemy = tp.get_leftmost_enemy()

	if not target_enemy:
		return

	# Create arrow from player to enemy
	if player_entity:
		var arrow = ARROW_SCENE.instantiate()
		arrow.z_index = 50  # Above grid cells (z=0), below entities (z=100)
		arrow.z_as_relative = true
		tp.add_child(arrow)

		var curve = calculate_smart_curve(player_entity.position, target_enemy.position)
		arrow.setup(player_entity.position, target_enemy.position, curve)

		tp.arrows.append(arrow)

	# Create arrow from twin to enemy (if twin exists)
	if twin_entity:
		var twin_arrow = ARROW_SCENE.instantiate()
		twin_arrow.z_index = 50
		twin_arrow.z_as_relative = true
		tp.add_child(twin_arrow)

		var twin_curve = calculate_smart_curve(twin_entity.position, target_enemy.position)
		twin_arrow.setup(twin_entity.position, target_enemy.position, twin_curve)

		tp.arrows.append(twin_arrow)
		print("  Created twin → enemy arrow")

func create_enemy_attack_arrows(tp: Panel):
	"""Create arrows from each enemy to player/twin (or to other enemies if redirected)"""
	var player_entity = null
	var twin_entity = null

	# Find player and twin entities
	for entity in tp.entities:
		if entity.is_player:
			if entity.entity_data.get("is_twin", false):
				twin_entity = entity
			else:
				player_entity = entity

	if not player_entity:
		return

	# Determine default target: twin first (leftmost), then player
	var default_target = twin_entity if twin_entity else player_entity

	# Get enemy entities
	var enemy_entities = []
	for entity in tp.entities:
		if not entity.is_player:
			enemy_entities.append(entity)

	# Track if twin is still alive for sequential targeting
	var twin_alive = (twin_entity != null)

	# Create arrows based on redirect/miss flags
	for i in range(enemy_entities.size()):
		var enemy = enemy_entities[i]

		# Check if this enemy will miss (no arrow)
		if future_miss_flags.get(i, false):
			print("  Enemy ", i, " will miss - no arrow")
			continue

		# Check if this enemy's attack is redirected
		var target = null
		if future_redirect_flag != null and future_redirect_flag.get("from_enemy", -1) == i:
			var to_index = future_redirect_flag.get("to_enemy", -1)
			if to_index >= 0 and to_index < enemy_entities.size():
				target = enemy_entities[to_index]
				print("  Enemy ", i, " arrow redirected to enemy ", to_index)
		else:
			# Target twin first, then player when twin dies
			if twin_alive:
				target = twin_entity
				# Check if twin would die from this attack (based on state)
				if tp.state.has("twin"):
					var twin_hp = tp.state["twin"]["hp"]
					var enemy_damage = enemy.entity_data.get("damage", 0)
					if twin_hp <= enemy_damage:
						# Twin will die, next enemies target player
						twin_alive = false
			else:
				target = player_entity

		if target:
			var arrow = ARROW_SCENE.instantiate()
			arrow.z_index = 50  # Above grid cells (z=0), below entities (z=100)
			arrow.z_as_relative = true
			tp.add_child(arrow)

			var curve = calculate_smart_curve(enemy.position, target.position)
			arrow.setup(enemy.position, target.position, curve)

			tp.arrows.append(arrow)

func calculate_smart_curve(from: Vector2, to: Vector2) -> float:
	"""Calculate arrow curve based on spatial relationship"""
	var direction = to - from
	var horizontal_distance = abs(direction.x)
	var base_curve = 30.0
	var horizontal_factor = horizontal_distance / max(direction.length(), 1.0)
	var curve_strength = base_curve * (0.5 + horizontal_factor * 0.5)
	
	return -curve_strength if direction.x < 0 else curve_strength


# ===== TIMELINE DISPLAY MANAGEMENT =====

func update_all_timeline_displays():
	"""Update visuals for all timeline panels"""
	print("\n=== Updating all timeline displays ===")
	
	for tp in timeline_panels:
		if tp.timeline_type in ["past", "present", "future"]:
			create_timeline_entities(tp)
			create_timeline_arrows(tp)
			update_timeline_ui_visibility(tp)
	
	update_damage_display()
	print("=== All timelines updated ===")

func update_timeline_ui_visibility(tp: Panel):
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
					dmg_label.visible = false  # Hidden, shows on hover
				"present":
					dmg_label.visible = true   # Always visible
				"future":
					dmg_label.visible = false  # Hidden, shows on hover
	
	# Arrows visibility
	for arrow in tp.arrows:
		if arrow and is_instance_valid(arrow):
			arrow.visible = true
			arrow.show_arrow()


# ===== FUTURE STATE CALCULATION =====

func calculate_future_state():
	"""Calculate Future timeline state based on Present"""
	var present_tp = get_timeline_panel("present")
	var future_tp = get_timeline_panel("future")
	
	if not present_tp or not future_tp:
		return
	
	# Copy Present state to Future
	future_tp.state = present_tp.state.duplicate(true)
	
	# Apply Future manipulation flags if active
	apply_future_manipulations(future_tp)
	
	# Simulate combat
	if future_tp.state["enemies"].size() > 0:
		# Player attacks
		var target_enemy = future_tp.state["enemies"][0]
		target_enemy["hp"] -= future_tp.state["player"]["damage"]
		
		# Remove dead enemies
		future_tp.state["enemies"] = future_tp.state["enemies"].filter(func(e): return e["hp"] > 0)
		
		# Enemies attack back (considering miss chances and redirects)
		for i in range(future_tp.state["enemies"].size()):
			# Check if enemy misses
			if future_miss_flags.get(i, false):
				continue
			
			# Check if attack is redirected
			if future_redirect_flag != null and future_redirect_flag.get("from_enemy", -1) == i:
				var to_index = future_redirect_flag.get("to_enemy", -1)
				if to_index >= 0 and to_index < future_tp.state["enemies"].size():
					# Damage redirected to another enemy
					future_tp.state["enemies"][to_index]["hp"] -= future_tp.state["enemies"][i]["damage"]
					print("  Future: Enemy ", i, " attacks enemy ", to_index)
					continue
			
			# Normal attack on player
			var enemy = future_tp.state["enemies"][i]
			future_tp.state["player"]["hp"] -= enemy["damage"]
	
	print("Future calculated: Player will have ", future_tp.state["player"]["hp"], " HP")

func apply_future_manipulations(future_tp: Panel):
	"""Apply active Future manipulation flags to the calculation"""
	# This function is called before combat simulation
	# The flags themselves are checked during calculate_future_state()
	pass

func update_after_carousel_slide_correct(state_for_past: Dictionary, first_turn: bool):
	"""Update timeline types and states after carousel slide"""
	print("🔄 Updating timeline types and states...")

	# Update timeline types
	timeline_panels[0].timeline_type = "decorative"
	timeline_panels[1].timeline_type = "past"
	timeline_panels[2].timeline_type = "present"
	timeline_panels[3].timeline_type = "future"
	timeline_panels[4].timeline_type = "decorative"

	# Clear entities and state from decorative panels
	for panel in timeline_panels:
		if panel.timeline_type == "decorative":
			panel.clear_entities()
			panel.state = {}
			print("  🧹 Cleared entities from decorative panel (slot ", panel.slot_index, ")")

	# Update grid cell hover colors for all panels
	for panel in timeline_panels:
		panel.update_cell_hover_colors()

	# Update Past with captured state
	timeline_panels[1].state = state_for_past.duplicate(true)
	
	# CRITICAL FIX: ALWAYS restore Present to the pre-combat state
	# state_for_past contains the HP values BEFORE combat was calculated
	# This ensures combat animation starts from correct HP values
	timeline_panels[2].state = state_for_past.duplicate(true)
	print("  ✅ Present RESTORED to pre-combat state from previous Present")
	
	# Recreate entities with correct HP values
	create_timeline_entities(timeline_panels[2])
	
	# Update entity timeline_types
	for i in range(5):
		var tp = timeline_panels[i]
		for entity in tp.entities:
			if entity and is_instance_valid(entity):
				match tp.timeline_type:
					"decorative":
						entity.timeline_type = "future"
					"past":
						entity.timeline_type = "past"
					"present":
						entity.timeline_type = "present"
					"future":
						entity.timeline_type = "future"
	
	print("✅ Timeline types and states updated!")
	
	# Update entity timeline_types
	for i in range(5):
		var tp = timeline_panels[i]
		for entity in tp.entities:
			if entity and is_instance_valid(entity):
				match tp.timeline_type:
					"decorative":
						entity.timeline_type = "future"
					"past":
						entity.timeline_type = "past"
					"present":
						entity.timeline_type = "present"
					"future":
						entity.timeline_type = "future"
	
	print("✅ Timeline types and states updated!")

func delete_all_arrows():
	"""Delete all arrows from all panels"""
	print("🗑️ Deleting all arrows...")
	for tp in timeline_panels:
		tp.clear_arrows()

func animate_slot_to_snapshot(tween: Tween, panel: Panel, target_snapshot: Dictionary):
	"""Animate panel to target snapshot"""
	if panel == null:
		return
	
	tween.tween_property(panel, "position", target_snapshot["position"], 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(panel, "scale", target_snapshot["scale"], 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(panel, "modulate", target_snapshot["modulate"], 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func hide_ui_for_carousel():
	"""Hide HP and damage labels ONLY (no entity hiding)"""
	print("👻 Hiding UI elements...")
	
	for tp in timeline_panels:
		# Hide labels on all entities
		for entity in tp.entities:
			if entity and is_instance_valid(entity):
				if entity.has_node("HPLabel"):
					entity.get_node("HPLabel").visible = false
				if entity.has_node("DamageLabel"):
					entity.get_node("DamageLabel").visible = false
		
		# REMOVED: No more special hiding for intermediate panel!
		# Entities stay visible, just labels hidden
	
	print("✅ UI elements hidden")

func animate_slot_to_void(tween: Tween, panel: Panel):
	"""Animate panel rotating BACKWARD through carousel (to the right/center)"""
	if panel == null:
		return
	
	print("🌊 Animating slot 0 backward through carousel")
	
	var carousel_center_x = 960  # Screen center (carousel rotation point)
	var backward_pos = Vector2(carousel_center_x - 200, panel.position.y + 50)
	
	# Animate toward center-back (RIGHT direction, not left!)
	tween.tween_property(panel, "position", backward_pos, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	# Shrink as it goes "behind" the carousel
	tween.tween_property(panel, "scale", Vector2(0.1, 0.1), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	# Fade out
	tween.tween_property(panel, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func animate_void_to_decorative_future(tween: Tween, panel: Panel):
	"""Animate panel emerging from void to Decorative Future position"""
	if panel == null:
		return
	
	print("✨ Animating void → Decorative Future")
	
	# Target: Decorative Future position (slot 4)
	var target_pos = carousel_positions[4]["position"]      # Vector2(1320, 150)
	var target_scale = carousel_positions[4]["scale"]       # Vector2(0.6, 0.6)
	var target_modulate = carousel_positions[4]["modulate"] # Full opacity
	
	# Animate emergence
	tween.tween_property(panel, "position", target_pos, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(panel, "scale", target_scale, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func animate_panel_colors(tween: Tween, panel: Panel, new_type: String):
	"""Animate panel background color to match new timeline type"""
	var stylebox = panel.get_theme_stylebox("panel")
	if not stylebox is StyleBoxFlat:
		return
	
	if new_type == "past":
		# Brown colors
		var past_bg = Color(0.23921569, 0.14901961, 0.078431375, 1)
		var past_border = Color(0.54509807, 0.43529412, 0.2784314, 1)
		tween.tween_property(stylebox, "bg_color", past_bg, 1.0)
		tween.tween_property(stylebox, "border_color", past_border, 1.0)
	
	elif new_type == "present":
		# Blue colors
		var present_bg = Color(0.11764706, 0.22745098, 0.37254903, 1)
		var present_border = Color(0.2901961, 0.61960787, 1, 1)
		tween.tween_property(stylebox, "bg_color", present_bg, 1.0)
		tween.tween_property(stylebox, "border_color", present_border, 1.0)
	
	elif new_type == "future":
		# Purple colors (NEW!)
		var future_bg = Color(0.1764706, 0.105882354, 0.23921569, 1)
		var future_border = Color(0.7058824, 0.47843137, 1, 1)
		tween.tween_property(stylebox, "bg_color", future_bg, 1.0)
		tween.tween_property(stylebox, "border_color", future_border, 1.0)

func update_panel_labels():
	"""Update panel label text to match timeline types"""
	print("🏷️ Updating panel labels...")

	# timeline_panels[1] is now Past
	if timeline_panels.size() > 1:
		update_panel_label_text(timeline_panels[1], "⟲ PAST")

	# timeline_panels[2] is now Present
	if timeline_panels.size() > 2:
		update_panel_label_text(timeline_panels[2], "◉ PRESENT")

	# timeline_panels[3] is now Future
	if timeline_panels.size() > 3:
		update_panel_label_text(timeline_panels[3], "⟳ FUTURE")

	print("✅ Panel labels updated!")


# ===== UI & DISPLAY =====

func update_wave_counter():
	"""Update wave counter display"""
	wave_counter_label.text = "Wave %d/10" % current_wave

func update_damage_display():
	"""Update damage stat display"""
	var present_tp = get_timeline_panel("present")
	if present_tp and present_tp.state.has("player"):
		damage_label.text = str(present_tp.state["player"]["damage"])

func update_timer_display():
	"""Update timer display with minutes:seconds format"""
	var minutes = int(time_remaining) / 60
	var seconds = int(time_remaining) % 60
	timer_label.text = "%d:%02d" % [minutes, seconds]

	# Change color based on time remaining
	if time_remaining <= 10:
		timer_label.modulate = Color(1.0, 0.3, 0.3)  # Red when low
	elif time_remaining <= 30:
		timer_label.modulate = Color(1.0, 0.8, 0.4)  # Orange/yellow
	else:
		timer_label.modulate = Color(1.0, 0.8, 0.4)  # Default yellow


# ===== CARD SYSTEM =====

func setup_cards():
	"""Initialize three card decks (Past, Present, Future)"""
	print("\n=== Setting up card decks ===")
	
	# Create deck objects
	past_deck = CardDeck.new(CardDatabase.TimelineType.PAST, past_deck_container)
	present_deck = CardDeck.new(CardDatabase.TimelineType.PRESENT, present_deck_container)
	future_deck = CardDeck.new(CardDatabase.TimelineType.FUTURE, future_deck_container)
	
	# Get all cards from database
	var all_cards = CardDatabase.get_all_cards()
	
	# Organize cards by timeline type
	for card_data in all_cards:
		var timeline_type = card_data.get("timeline_type")
		
		match timeline_type:
			CardDatabase.TimelineType.PAST:
				past_deck.cards.append(card_data)
			CardDatabase.TimelineType.PRESENT:
				present_deck.cards.append(card_data)
			CardDatabase.TimelineType.FUTURE:
				future_deck.cards.append(card_data)
	
	# Shuffle each deck
	past_deck.cards.shuffle()
	present_deck.cards.shuffle()
	future_deck.cards.shuffle()
	
	# Create visual cards for each deck
	create_deck_visuals(past_deck)
	create_deck_visuals(present_deck)
	create_deck_visuals(future_deck)

	# Initialize card affordability based on timer
	update_all_cards_affordability()

	print("✅ Decks created:")
	print("  Past: ", past_deck.cards.size(), " cards")
	print("  Present: ", present_deck.cards.size(), " cards")
	print("  Future: ", future_deck.cards.size(), " cards")

func create_deck_visuals(deck: CardDeck):
	"""Create stacked card visuals for a deck"""
	# Clear old nodes
	for node in deck.card_nodes:
		if node and is_instance_valid(node):
			node.queue_free()
	deck.card_nodes.clear()
	
	# Create cards in stack (bottom to top)
	for i in range(deck.cards.size()):
		var card_data = deck.cards[i]
		var card_node = CARD_SCENE.instantiate()
		
		# Position cards in stack (small vertical offset)
		card_node.position = Vector2(0, 40 + i * 3)  # 3px offset per card
		
		deck.container.add_child(card_node)
		card_node.setup(card_data)
		
		# Only top card is interactive
		var is_top_card = (i == deck.cards.size() - 1)
		if is_top_card:
			card_node.card_clicked.connect(_on_card_played)
			card_node.mouse_filter = Control.MOUSE_FILTER_STOP
			card_node.modulate = Color(0.4, 0.4, 0.4, 0.8)  # Grayed out initially
		else:
			# Hidden cards (stacked below)
			card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_node.modulate = Color(0.2, 0.2, 0.2, 0.6)  # Darker
			card_node.z_index = -1 - i  # Stack order
		
		deck.card_nodes.append(card_node)
	
	print("  Created ", deck.card_nodes.size(), " visual cards for deck")

func _on_card_played(card_data: Dictionary):
	"""Handle card click"""
	var time_cost = card_data.get("time_cost", 0)

	# Check if player has enough time
	if time_remaining < time_cost:
		print("Not enough time for card: ", card_data.get("name", "Unknown"))
		return

	print("Playing card: ", card_data.get("name", "Unknown"), " (Cost: ", time_cost, "s)")

	# Find which deck this card belongs to
	var source_deck: CardDeck = null
	if card_data.get("timeline_type") == CardDatabase.TimelineType.PAST:
		source_deck = past_deck
	elif card_data.get("timeline_type") == CardDatabase.TimelineType.PRESENT:
		source_deck = present_deck
	elif card_data.get("timeline_type") == CardDatabase.TimelineType.FUTURE:
		source_deck = future_deck

	if not source_deck:
		print("ERROR: Could not find source deck for card!")
		return

	# CHECK IF CARD REQUIRES TARGETING
	if card_requires_targeting(card_data):
		print("  🎯 Card requires targeting - entering targeting mode")
		var card_node = source_deck.get_top_card()
		enter_targeting_mode(card_data, card_node, source_deck)
		return  # Don't apply effect yet - wait for target selection

	# INSTANT EFFECT CARDS (no targeting required)

	# Mark card as used immediately for visual feedback
	var card_node = source_deck.get_top_card()
	if card_node and is_instance_valid(card_node):
		card_node.mark_as_used()

	# Deduct time cost from timer
	time_remaining -= time_cost
	if time_remaining < 0:
		time_remaining = 0
	update_timer_display()
	print("  Time remaining: ", time_remaining)

	# Update all cards' affordability
	update_all_cards_affordability()

	# Apply card effect
	apply_card_effect(card_data)

	# SIMPLIFIED: Recycle card immediately (no animation for now)
	recycle_card_simple(source_deck)

	# Recalculate Future to show card effects
	calculate_future_state()

	# Update Future timeline visuals
	var future_tp = get_timeline_panel("future")
	create_timeline_entities(future_tp)
	create_timeline_arrows(future_tp)
	update_timeline_ui_visibility(future_tp)

	# Update Present visuals (for healing, damage boosts, etc.)
	var present_tp = get_timeline_panel("present")
	create_timeline_entities(present_tp)
	create_timeline_arrows(present_tp)
	update_timeline_ui_visibility(present_tp)

	# CRITICAL: Also update Decorative Future
	var dec_future_tp = get_timeline_panel("decorative")
	if dec_future_tp and dec_future_tp.timeline_type == "decorative":
		# Recalculate decorative future based on updated Future
		dec_future_tp.state = calculate_future_from_state(future_tp.state)
		create_timeline_entities(dec_future_tp)

	# Update damage display in UI
	update_damage_display()

	print("  ✅ Card effect applied and visuals updated")

func apply_card_effect(card_data: Dictionary):
	"""Apply card effect to appropriate timeline"""
	var present_tp = get_timeline_panel("present")
	var past_tp = get_timeline_panel("past")
	var effect_type = card_data.get("effect_type")
	var effect_value = card_data.get("effect_value", 0)

	match effect_type:
		# ===== PRESENT EFFECTS =====
		CardDatabase.EffectType.HEAL_PLAYER:
			var current_hp = present_tp.state["player"]["hp"]
			var max_hp = present_tp.state["player"]["max_hp"]
			present_tp.state["player"]["hp"] = min(current_hp + effect_value, max_hp)
			print("Healed ", effect_value, " HP")
		
		CardDatabase.EffectType.DAMAGE_ENEMY:
			if present_tp.state["enemies"].size() > 0:
				present_tp.state["enemies"][0]["hp"] -= effect_value
				if present_tp.state["enemies"][0]["hp"] <= 0:
					present_tp.state["enemies"].remove_at(0)
				print("Dealt ", effect_value, " damage")
		
		CardDatabase.EffectType.DAMAGE_ALL_ENEMIES:
			var defeated = []
			for enemy in present_tp.state["enemies"]:
				enemy["hp"] -= effect_value
				if enemy["hp"] <= 0:
					defeated.append(enemy)
			for enemy in defeated:
				present_tp.state["enemies"].erase(enemy)
			print("Dealt ", effect_value, " damage to all")
		
		CardDatabase.EffectType.BOOST_DAMAGE:
			present_tp.state["player"]["damage"] += effect_value
			damage_boost_active = true  # Mark for reset next turn
			print("Boosted damage by ", effect_value, " (will reset next turn)")
		
		CardDatabase.EffectType.ENEMY_SWAP:
			if present_tp.state["enemies"].size() >= 2:
				# Swap first two enemies
				var temp = present_tp.state["enemies"][0]
				present_tp.state["enemies"][0] = present_tp.state["enemies"][1]
				present_tp.state["enemies"][1] = temp
				print("Swapped enemy positions")
		
		# ===== PAST EFFECTS =====
		CardDatabase.EffectType.HP_SWAP_FROM_PAST:
			if past_tp and not past_tp.state.is_empty():
				var past_hp = past_tp.state["player"]["hp"]
				present_tp.state["player"]["hp"] = past_hp
				print("HP swapped from Past: now at ", past_hp, " HP")
			else:
				print("No Past state available - card has no effect")
		
		CardDatabase.EffectType.SUMMON_PAST_TWIN:
			if past_tp and not past_tp.state.is_empty():
				print("\n🔄 Summoning Past Twin")

				# Create twin entity data based on PAST player stats
				var twin_data = {
					"name": "Past Twin",
					"hp": int(past_tp.state["player"]["hp"] * 0.5),  # 0.5x HP from PAST
					"max_hp": int(past_tp.state["player"]["max_hp"] * 0.5),
					"damage": int(past_tp.state["player"]["damage"] * 0.5),  # 0.5x damage from PAST
					"is_twin": true
				}

				print("  Twin stats: HP=", twin_data["hp"], " DMG=", twin_data["damage"])

				# Add twin to PRESENT state
				present_tp.state["twin"] = twin_data

				print("  ✅ Past Twin summoned to fight alongside you!")
		
		CardDatabase.EffectType.CONSCRIPT_PAST_ENEMY:
			if past_tp and not past_tp.state.is_empty() and past_tp.state["enemies"].size() > 0:
				# Take first enemy from Past
				var conscripted = past_tp.state["enemies"][0].duplicate()
				conscripted["name"] = "Conscripted " + conscripted["name"]
				print("Conscripted ", conscripted["name"], " to fight for you")
				# For simplicity: deal that enemy's damage to Present enemies
				if present_tp.state["enemies"].size() > 0:
					present_tp.state["enemies"][0]["hp"] -= conscripted["damage"]
					if present_tp.state["enemies"][0]["hp"] <= 0:
						present_tp.state["enemies"].remove_at(0)
		
		CardDatabase.EffectType.WOUND_TRANSFER:
			if past_tp and not past_tp.state.is_empty():
				# Find matching enemy and calculate damage taken
				if present_tp.state["enemies"].size() > 0 and past_tp.state["enemies"].size() > 0:
					var present_enemy = present_tp.state["enemies"][0]
					var past_enemy = past_tp.state["enemies"][0]
					
					# Damage = how much HP the enemy lost
					var damage_taken = past_enemy["hp"] - present_enemy["hp"]
					if damage_taken > 0:
						present_enemy["hp"] -= damage_taken
						print("Transferred ", damage_taken, " wound damage")
						if present_enemy["hp"] <= 0:
							present_tp.state["enemies"].remove_at(0)
		
		# ===== FUTURE EFFECTS =====
		CardDatabase.EffectType.REDIRECT_FUTURE_ATTACK:
			if present_tp.state["enemies"].size() >= 2:
				# Redirect first enemy to attack second enemy
				future_redirect_flag = {
					"from_enemy": 0,
					"to_enemy": 1
				}
				print("Future: Enemy 0 will attack Enemy 1")
		
		CardDatabase.EffectType.CHAOS_INJECTION:
			# Mark random enemies to miss
			var enemy_count = present_tp.state["enemies"].size()
			if enemy_count > 0:
				var num_to_miss = min(effect_value, enemy_count)
				var indices = range(enemy_count)
				indices.shuffle()
				
				future_miss_flags.clear()
				for i in range(num_to_miss):
					future_miss_flags[indices[i]] = true
				print("Chaos Injection: ", num_to_miss, " enemies will miss")
		
		CardDatabase.EffectType.FUTURE_SELF_AID:
			if present_tp.state["player"]["hp"] <= 25:
				# Borrow HP from Future
				present_tp.state["player"]["hp"] += effect_value
				print("Borrowed ", effect_value, " HP from Future")
				# Note: Future will show player dying due to this
			else:
				print("Cannot use Future Self Aid - HP too high (must be ≤ 25)")
		
		CardDatabase.EffectType.TIMELINE_SCRAMBLE:
			var enemy_count = present_tp.state["enemies"].size()
			if enemy_count > 0:
				for i in range(enemy_count):
					if randf() < effect_value:
						future_miss_flags[i] = true
			print("Timeline Scramble: All attacks randomized in Future!")

func update_all_cards_affordability():
	"""Update all cards' affordability based on remaining time"""
	for deck in [past_deck, present_deck, future_deck]:
		var top_card = deck.get_top_card()
		if top_card and is_instance_valid(top_card):
			top_card.update_affordability(time_remaining)

func recycle_card_simple(deck: CardDeck):
	"""Simple card recycling without animations - for testing"""
	print("♻️ Recycling card from deck (simple mode)...")
	
	# Get top card data
	var played_card_data = deck.get_top_card_data()
	
	if played_card_data.is_empty():
		print("  ERROR: No card data to recycle")
		return
	
	print("  Playing card: ", played_card_data.get("name", "Unknown"))
	print("  Deck size before: ", deck.cards.size())
	
	# Remove card from end (it was the top)
	deck.cards.remove_at(deck.cards.size() - 1)
	
	print("  Deck size after removal: ", deck.cards.size())
	
	# Add card to front (index 0)
	deck.cards.insert(0, played_card_data)
	
	print("  Deck size after insertion: ", deck.cards.size())
	print("  New top card should be: ", deck.cards[deck.cards.size() - 1].get("name", "Unknown"))
	
	# Recreate all card visuals
	create_deck_visuals(deck)
	
	print("  ✅ Card recycled - deck recreated with ", deck.card_nodes.size(), " visual cards")

func recycle_card(deck: CardDeck):
	"""Recycle used card: animate out, move to front of queue, reveal next card"""
	print("♻️ Recycling card from deck...")
	
	# Get top card (the one just played)
	var played_card = deck.get_top_card()
	var played_card_data = deck.get_top_card_data()
	
	if not played_card or not is_instance_valid(played_card):
		print("  ERROR: No valid top card to recycle")
		return
	
	print("  Playing card: ", played_card_data.get("name", "Unknown"))
	print("  Deck size before recycle: ", deck.cards.size())
	
	# Animate card shrinking and fading
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(played_card, "scale", Vector2(0.5, 0.5), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(played_card, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished
	
	print("  Card shrink animation complete")
	
	# Remove from visual array and scene
	deck.card_nodes.erase(played_card)
	deck.cards.erase(played_card_data)
	played_card.queue_free()
	
	print("  Card removed. Deck size now: ", deck.cards.size())
	
	# SIMPLE QUEUE ROTATION: Move played card to front (index 0)
	# This creates a rotation: [A, B, C, D] → play D → [D, A, B, C] → next top is C
	deck.cards.insert(0, played_card_data)
	print("  Card moved to front. Deck size now: ", deck.cards.size())
	print("  New top card should be: ", deck.cards[deck.cards.size() - 1].get("name", "Unknown"))
	
	# Recreate entire deck visuals (to maintain proper stacking)
	create_deck_visuals(deck)
	
	print("  Deck visuals recreated. Card nodes: ", deck.card_nodes.size())
	
	# Reveal animation for new top card
	await reveal_top_card(deck)
	
	print("  ✅ Card recycled and new top card revealed")

func reveal_top_card(deck: CardDeck):
	"""Animate new top card appearing"""
	print("  🎴 Revealing new top card...")
	
	var top_card = deck.get_top_card()
	if not top_card or not is_instance_valid(top_card):
		print("  ERROR: No valid top card to reveal!")
		return
	
	print("  Top card found: ", top_card.card_data.get("name", "Unknown"))
	print("  Starting modulate: ", top_card.modulate)
	print("  Starting scale: ", top_card.scale)
	
	# Start invisible
	top_card.modulate = Color(0.4, 0.4, 0.4, 0.0)  # Grayed color with 0 alpha
	top_card.scale = Vector2(0.8, 0.8)
	
	# Animate in
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(top_card, "modulate", Color(0.4, 0.4, 0.4, 0.8), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(top_card, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	
	print("  ✅ Top card reveal complete. Final modulate: ", top_card.modulate)

func reset_turn_effects():
	"""Reset temporary effects at end of turn"""
	var present_tp = get_timeline_panel("present")

	# Reset damage boost
	if damage_boost_active:
		present_tp.state["player"]["damage"] = base_player_damage
		damage_boost_active = false
		update_damage_display()  # Update UI
		print("  Damage boost reset to base: ", base_player_damage)

	# Remove twin from PAST after combat (twin was in PRESENT, rotated to PAST)
	var past_tp = get_timeline_panel("past")
	if past_tp and past_tp.state.has("twin"):
		print("  Removing twin from PAST after combat")
		past_tp.state.erase("twin")
		# Update PAST visuals to remove twin entity
		create_timeline_entities(past_tp)
		create_timeline_arrows(past_tp)

	# Clear Future manipulation flags
	future_miss_flags.clear()
	future_redirect_flag = null
	print("  Future manipulation flags cleared")


# ===== TURN EXECUTION =====

func _on_play_button_pressed():
	"""Execute complete turn: carousel slide → combat → future calculation"""
	print("\n▶ PLAY button pressed - Starting complete turn sequence!")

	# Don't execute if game over
	if game_over:
		return

	# Stop timer during combat
	timer_active = false

	# Disable Play button AND cards during turn
	play_button.disabled = true
	disable_all_card_input()

	# Execute complete turn with combat
	await execute_complete_turn()

	# Re-enable Play button AND cards (only if not game over)
	if not game_over:
		play_button.disabled = false
		enable_all_card_input()

		# Reset and restart timer for next turn
		time_remaining = max_time
		timer_active = true
		update_timer_display()

	print("✅ Turn complete - Ready for next turn!")

func execute_turn():
	"""Execute turn with combat animations (to be implemented)"""
	# TODO: Implement combat animations
	pass


# ===== SCREEN SHAKE =====

func _process(delta):
	"""Handle screen shake and timer countdown"""
	# Screen shake
	if shake_strength > 0:
		camera.offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		shake_strength = lerp(shake_strength, 0.0, shake_decay * delta)
		if shake_strength < 0.1:
			shake_strength = 0.0
			camera.offset = Vector2.ZERO

	# Timer countdown
	if timer_active and not game_over:
		time_remaining -= delta
		if time_remaining <= 0:
			time_remaining = 0
			timer_active = false
			# Auto-press PLAY button when timer reaches 0
			if not play_button.disabled:
				print("\n⏰ Time's up! Auto-pressing PLAY button...")
				_on_play_button_pressed()
		else:
			update_timer_display()
			# Update card affordability as time changes
			update_all_cards_affordability()

func apply_screen_shake(strength: float = 10.0):
	"""Trigger screen shake effect"""
	shake_strength = strength

func calculate_future_from_state(base_state: Dictionary) -> Dictionary:
	"""Calculate future state from any given state"""
	var future = base_state.duplicate(true)

	if future["enemies"].size() > 0:
		# Player attacks first enemy
		var target_enemy = future["enemies"][0]
		target_enemy["hp"] -= future["player"]["damage"]

		# Twin also attacks first enemy if twin exists
		if future.has("twin"):
			target_enemy["hp"] -= future["twin"]["damage"]
			print("  Twin deals ", future["twin"]["damage"], " damage to enemy")

		# Remove defeated enemies
		future["enemies"] = future["enemies"].filter(func(e): return e["hp"] > 0)

		# Enemies counter-attack
		# If twin exists, enemies attack twin first (leftmost)
		var twin_alive = future.has("twin")
		for enemy in future["enemies"]:
			if twin_alive:
				# Attack twin
				future["twin"]["hp"] -= enemy["damage"]
				print("  Enemy deals ", enemy["damage"], " damage to twin (HP: ", future["twin"]["hp"], ")")

				# Check if twin died
				if future["twin"]["hp"] <= 0:
					print("  Twin defeated!")
					future.erase("twin")
					twin_alive = false
			else:
				# Attack player
				future["player"]["hp"] -= enemy["damage"]

	return future

func rotate_timeline_panels_7():
	"""Rotate 6-panel carousel"""
	print("🔄 Rotating carousel...")

	var old_slot_0 = timeline_panels[0]
	old_slot_0.clear_all()

	timeline_panels.remove_at(0)  # Now we have 5 elements
	timeline_panels.append(old_slot_0)  # Add back at end - now we have 6 again!

	old_slot_0.timeline_type = "decorative"
	old_slot_0.slot_index = 5

	# Update slot_index for all panels
	for i in range(timeline_panels.size()):
		timeline_panels[i].slot_index = i

	# Re-apply carousel positions to ALL panels to update z_indices
	for i in range(timeline_panels.size()):
		apply_carousel_position(timeline_panels[i], i)

	print("✅ Rotated! Array size: ", timeline_panels.size())

func execute_complete_turn():
	"""Execute complete turn: slide → combat → recalculate"""

	# PHASE 1: Carousel slide animation
	print("\n🎠 PHASE 1: Carousel slide animation")
	await carousel_slide_animation_with_blanks()

	# Update mouse filters after z-indices changed during carousel slide
	update_panel_mouse_filters()

	# PHASE 2: Show HP/DMG on new Present AND Past
	print("\n💚 PHASE 2: Show HP/DMG labels")
	show_present_ui_labels()
	
	# PHASE 3: Combat animations (using NEW Present state)
	print("\n⚔️ PHASE 3: Combat animations")
	await execute_combat_animations()
	
	# PHASE 4: Reset turn effects from last turn
	print("\n🔄 PHASE 4: Reset turn effects")
	reset_turn_effects()

	# CRITICAL: Check for game over BEFORE recalculating future
	var present_tp = timeline_panels[2]
	if present_tp.state["player"]["hp"] <= 0:
		# If conscription is active, the conscripted enemy died - not game over
		if conscription_active:
			print("\n💀 Conscripted enemy died - restoring original player")
			# Restore original player
			present_tp.state["player"] = original_player_data.duplicate(true)
			conscription_active = false
			original_player_data = {}
			conscripted_enemy_data = {}
			print("  ✅ Player restored: HP=", present_tp.state["player"]["hp"], " DMG=", present_tp.state["player"]["damage"])

			# Update visuals to show restored player
			create_timeline_entities(present_tp)
			create_timeline_arrows(present_tp)
		else:
			# Real player died - game over
			print("\n💀 GAME OVER - Player died!")
			handle_game_over()
			return  # Stop turn execution
	elif conscription_active:
		# Conscripted enemy survived - restore player anyway
		print("\n✅ Conscripted enemy survived - restoring original player")
		present_tp.state["player"] = original_player_data.duplicate(true)
		conscription_active = false
		original_player_data = {}
		conscripted_enemy_data = {}
		print("  ✅ Player restored: HP=", present_tp.state["player"]["hp"], " DMG=", present_tp.state["player"]["damage"])

		# Update visuals to show restored player
		create_timeline_entities(present_tp)
		create_timeline_arrows(present_tp)

	# PHASE 4: Recalculate Future and Decorative Future
	print("\n🔮 PHASE 5: Recalculate Future timelines")
	recalculate_future_timelines()
	
	# PHASE 5: Show arrows
	print("\n🏹 PHASE 6: Show arrows")
	show_timeline_arrows()
	
	# PHASE 6: Reset cards for next turn
	print("\n🎴 PHASE 7: Reset cards")
	reset_cards_for_new_turn()
	
	print("✅ Complete turn executed!")

func reset_cards_for_new_turn():
	"""Reset all cards for the new turn"""
	# Don't reset if game is over!
	if game_over:
		return

	# Reset top card in each deck
	for deck in [past_deck, present_deck, future_deck]:
		var top_card = deck.get_top_card()
		if top_card and is_instance_valid(top_card):
			top_card.reset()

	# Update affordability based on timer
	update_all_cards_affordability()

	print("  ✅ Cards reset and ready for next turn")

func carousel_slide_animation_with_blanks():
	"""Carousel slide with Decorative Future starting blank"""
	print("\n🎠 Starting carousel slide (Decorative Future blank)...")

	# Stop all hover animations during carousel transition
	for panel in timeline_panels:
		panel.stop_hover_animation()

	hide_ui_for_carousel()
	delete_all_arrows()
	
	var slot_2_tp = timeline_panels[2]  # Current Present
	var slot_3_tp = timeline_panels[3]  # Current Future
	var slot_4_tp = timeline_panels[4]  # Current Decorative Future
	var slot_5_tp = timeline_panels[5]  # Current Intermediate
	
	# Capture state for Past
	var state_for_past = slot_2_tp.state.duplicate(true)
	
	if is_first_turn:
		print("  🔵 First turn - Past will get original Present state (full HP)")
	else:
		print("  🔄 Subsequent turn - Past will get current Present state (post-combat from last turn)")
	
	# Check if we need enemy revival animation in Future (slot 3)
	var old_enemy_count = slot_3_tp.state.get("enemies", []).size()
	var new_enemy_count = slot_2_tp.state.get("enemies", []).size()
	var needs_revival = new_enemy_count > old_enemy_count
	
	# Prepare enemy repositioning during slide (only for slot 3 - Future)
	var enemy_repositioning_tween = null
	if needs_revival:
		print("  🔄 Preparing enemy repositioning: ", old_enemy_count, " → ", new_enemy_count)
		
		# [... existing revival code for slot 3 ...]
		# (Keep all the enemy revival/repositioning code as-is)
	
	# CRITICAL FIX: Clear Decorative Future (slot 4) - it should be BLANK!
	slot_4_tp.timeline_type = "future"
	slot_4_tp.state = {}  # Empty state
	slot_4_tp.clear_entities()  # Remove all entities
	print("  ✅ Decorative Future (slot 4) cleared - will be blank during slide")
	
	# Clear Intermediate (slot 5) - also blank
	slot_5_tp.timeline_type = "decorative"
	slot_5_tp.state = {}  # Empty state
	slot_5_tp.clear_entities()  # Remove all entities
	print("  ✅ Intermediate (slot 5) cleared - blank")

	# Get current enemy entities in Future (before adding revived one)
	var existing_enemies = []
	for entity in slot_3_tp.entities:
		if not entity.is_player:
			existing_enemies.append(entity)
	
	# Update state to include revived enemy
	slot_3_tp.state["enemies"] = slot_2_tp.state["enemies"].duplicate(true)

	# Calculate grid position for revived enemy (it's the last one in the list)
	var revived_index = new_enemy_count - 1
	var revived_grid_pos = slot_3_tp.get_grid_position_for_entity(revived_index, false, new_enemy_count)
	var revived_world_pos = slot_3_tp.get_cell_center_position(revived_grid_pos.x, revived_grid_pos.y)

	# Create revived enemy entity
	var revived_enemy = ENTITY_SCENE.instantiate()
	revived_enemy.setup(slot_3_tp.state["enemies"][revived_index], false, "future")
	revived_enemy.position = revived_world_pos
	revived_enemy.modulate.a = 0.0  # Start invisible

	# CRITICAL FIX: Hide HP/DMG labels on revived enemy (carousel slide in progress!)
	if revived_enemy.has_node("HPLabel"):
		revived_enemy.get_node("HPLabel").visible = false
	if revived_enemy.has_node("DamageLabel"):
		revived_enemy.get_node("DamageLabel").visible = false

	slot_3_tp.add_child(revived_enemy)
	slot_3_tp.entities.append(revived_enemy)

	print("  🔄 Revived enemy at grid (", revived_grid_pos.x, ", ", revived_grid_pos.y, ") → ", revived_world_pos)

	# Create tween for enemy repositioning (runs in parallel with carousel slide)
	enemy_repositioning_tween = create_tween()
	enemy_repositioning_tween.set_parallel(true)

	# Fade in the revived enemy
	enemy_repositioning_tween.tween_property(revived_enemy, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Reposition existing enemies based on new grid layout with new count
	for i in range(existing_enemies.size()):
		var entity = existing_enemies[i]

		# CRITICAL FIX: Ensure HP/DMG labels stay hidden during repositioning
		if entity.has_node("HPLabel"):
			entity.get_node("HPLabel").visible = false
		if entity.has_node("DamageLabel"):
			entity.get_node("DamageLabel").visible = false

		# Calculate new grid position with new enemy count
		var new_grid_pos = slot_3_tp.get_grid_position_for_entity(i, false, new_enemy_count)
		var new_world_pos = slot_3_tp.get_cell_center_position(new_grid_pos.x, new_grid_pos.y)

		print("  ↔️ Existing enemy ", i, " → grid (", new_grid_pos.x, ", ", new_grid_pos.y, ") at ", new_world_pos)

		# Slide existing enemy to new grid position
		enemy_repositioning_tween.tween_property(entity, "position", new_world_pos, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Duplicate StyleBoxes
	var present_stylebox = slot_2_tp.get_theme_stylebox("panel").duplicate()
	slot_2_tp.add_theme_stylebox_override("panel", present_stylebox)

	var future_stylebox = slot_3_tp.get_theme_stylebox("panel").duplicate()
	slot_3_tp.add_theme_stylebox_override("panel", future_stylebox)

	var decorative_past_stylebox = timeline_panels[0].get_theme_stylebox("panel").duplicate()
	timeline_panels[0].add_theme_stylebox_override("panel", decorative_past_stylebox)

	# Z-index
	timeline_panels[0].z_index = 0
	timeline_panels[1].z_index = 1
	slot_2_tp.z_index = 2
	slot_3_tp.z_index = 1
	slot_4_tp.z_index = 0
	slot_5_tp.z_index = -1
	
	# Animate carousel slide
	var carousel_tween = create_tween()
	carousel_tween.set_parallel(true)

	animate_slot_to_void(carousel_tween, timeline_panels[0])
	animate_slot_to_snapshot(carousel_tween, timeline_panels[1], carousel_snapshot[0])
	animate_slot_to_snapshot(carousel_tween, slot_2_tp, carousel_snapshot[1])
	animate_slot_to_snapshot(carousel_tween, slot_3_tp, carousel_snapshot[2])
	animate_slot_to_snapshot(carousel_tween, slot_4_tp, carousel_snapshot[3])  # Slides blank!
	animate_slot_to_snapshot(carousel_tween, slot_5_tp, carousel_snapshot[4])  # Slides blank!

	# Colors
	animate_panel_colors(carousel_tween, slot_2_tp, "past")
	animate_panel_colors(carousel_tween, slot_3_tp, "present")
	animate_panel_colors(carousel_tween, timeline_panels[0], "future")
	
	# Both animations happen simultaneously
	await carousel_tween.finished
	
	print("✅ Carousel slide complete!")
	
	# Rotate
	rotate_timeline_panels_7()
	
	# Update with correct state
	update_after_carousel_slide_correct(state_for_past, is_first_turn)
	
	update_panel_labels()
	
	# Mark first turn as complete
	is_first_turn = false

func show_present_ui_labels():
	"""Show HP and DMG labels on the new Present timeline"""
	var present_tp = timeline_panels[2]  # After rotation, slot 2 is Present
	
	for entity in present_tp.entities:
		if entity and is_instance_valid(entity):
			if entity.has_node("HPLabel"):
				entity.get_node("HPLabel").visible = true
			if entity.has_node("DamageLabel") and not entity.is_player:
				entity.get_node("DamageLabel").visible = true  # Present shows damage
	
	# CRITICAL FIX: Also show HP bars on Past (slot 1)
	var past_tp = timeline_panels[1]  # After rotation, slot 1 is Past
	for entity in past_tp.entities:
		if entity and is_instance_valid(entity):
			if entity.has_node("HPLabel"):
				entity.get_node("HPLabel").visible = true  # HP always visible
			if entity.has_node("DamageLabel"):
				entity.get_node("DamageLabel").visible = false  # Damage hidden (shows on hover)
	
	print("  ✅ HP/DMG labels shown on Present")
	print("  ✅ HP labels shown on Past")

func execute_combat_animations():
	"""Execute combat on NEW Present (was Future)"""
	var present_tp = timeline_panels[2]  # This is the NEW Present (was Future)
	
	# Check state
	print("  Present state before combat:")
	print("    Player HP: ", present_tp.state.get("player", {}).get("hp", 0))
	print("    Enemies: ", present_tp.state.get("enemies", []).size())
	
	if present_tp.state.get("enemies", []).size() == 0:
		print("  No enemies - skipping combat")
		return
	
	# Track if any enemy died during combat
	var enemies_before = present_tp.state.get("enemies", []).size()
	
	# Twin attacks first (leftmost entity)
	if present_tp.state.has("twin"):
		print("  ⚔️ Twin attacking...")
		await animate_twin_attack()
		await get_tree().create_timer(0.2).timeout

	# Player attacks
	print("  ⚔️ Player attacking...")
	await animate_player_attack()

	await get_tree().create_timer(0.2).timeout

	# Check if enemy died
	var enemies_after_player = present_tp.state.get("enemies", []).size()
	var enemy_died_during_player_attack = enemies_after_player < enemies_before

	# Enemies attack (if any left)
	if present_tp.state.get("enemies", []).size() > 0:
		print("  ⚔️ Enemies attacking...")
		await animate_enemy_attacks()

	print("  ✅ Combat complete!")
	print("    Player HP after: ", present_tp.state.get("player", {}).get("hp", 0))

	# NOW reposition enemies if any died during combat
	if enemy_died_during_player_attack:
		print("  ↔️ Enemy died during combat - repositioning remaining enemies...")
		await animate_enemy_repositioning_after_death(present_tp)

func animate_player_attack() -> void:
	"""Animate player attacking leftmost enemy in Present"""
	var present_tp = timeline_panels[2]
	
	# Find player and target enemy
	var player_entity = null
	var target_enemy = null
	
	for entity in present_tp.entities:
		if entity.is_player:
			player_entity = entity
		elif target_enemy == null:
			target_enemy = entity
	
	if not player_entity or not target_enemy:
		print("  Cannot animate - missing player or enemy")
		return
	
	# Store original position
	var original_pos = player_entity.position
	var target_pos = target_enemy.position
	
	# Calculate attack position
	var direction = (target_pos - original_pos).normalized()
	var attack_pos = target_pos - direction * 50.0
	
	print("  Player attack animation starting...")
	
	# Dash to enemy
	var tween = create_tween()
	tween.tween_property(player_entity, "position", attack_pos, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	
	# APPLY DAMAGE AT IMPACT
	if present_tp.state["enemies"].size() > 0:
		var target_enemy_data = present_tp.state["enemies"][0]
		var damage = present_tp.state["player"]["damage"]
		target_enemy_data["hp"] -= damage
		print("  Player dealt ", damage, " damage! Enemy HP: ", target_enemy_data["hp"])
		
		# Play attack sound
		player_entity.play_attack_sound()
		
		# Screen shake
		apply_screen_shake(damage * 0.5)
		
		# Hit reaction
		var hit_direction = (target_enemy.position - player_entity.position).normalized()
		target_enemy.play_hit_reaction(hit_direction)
		
		# Update visual
		target_enemy.entity_data = target_enemy_data
		target_enemy.update_display()
		
		# Remove enemy if dead
		if target_enemy_data["hp"] <= 0:
			print("  ", target_enemy_data["name"], " defeated!")
			present_tp.state["enemies"].remove_at(0)
			present_tp.entities.erase(target_enemy)
			target_enemy.visible = false
			
			# Queue for deletion (don't delete immediately - let combat finish)
			get_tree().create_timer(1.5).timeout.connect(func():
				if is_instance_valid(target_enemy):
					target_enemy.queue_free()
			)
	
	# Pause at enemy
	await get_tree().create_timer(0.1).timeout
	
	# Dash back
	var tween2 = create_tween()
	tween2.tween_property(player_entity, "position", original_pos, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween2.finished
	
	print("  Player attack complete!")

func animate_twin_attack() -> void:
	"""Animate twin attacking leftmost enemy in Present"""
	var present_tp = timeline_panels[2]

	# Find twin and target enemy
	var twin_entity = null
	var target_enemy = null

	for entity in present_tp.entities:
		if entity.is_player and entity.entity_data.get("is_twin", false):
			twin_entity = entity
		elif target_enemy == null and not entity.is_player:
			target_enemy = entity

	if not twin_entity or not target_enemy:
		print("  Cannot animate - missing twin or enemy")
		return

	# Store original position
	var original_pos = twin_entity.position
	var target_pos = target_enemy.position

	# Calculate attack position
	var direction = (target_pos - original_pos).normalized()
	var attack_pos = target_pos - direction * 50.0

	print("  Twin attack animation starting...")

	# Dash to enemy
	var tween = create_tween()
	tween.tween_property(twin_entity, "position", attack_pos, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

	# APPLY DAMAGE AT IMPACT
	if present_tp.state["enemies"].size() > 0 and present_tp.state.has("twin"):
		var target_enemy_data = present_tp.state["enemies"][0]
		var damage = present_tp.state["twin"]["damage"]
		target_enemy_data["hp"] -= damage
		print("  Twin dealt ", damage, " damage! Enemy HP: ", target_enemy_data["hp"])

		# Play attack sound
		twin_entity.play_attack_sound()

		# Screen shake
		apply_screen_shake(damage * 0.5)

		# Hit reaction
		var hit_direction = (target_enemy.position - twin_entity.position).normalized()
		target_enemy.play_hit_reaction(hit_direction)

		# Update visual
		target_enemy.entity_data = target_enemy_data
		target_enemy.update_display()

		# Remove enemy if dead
		if target_enemy_data["hp"] <= 0:
			print("  ", target_enemy_data["name"], " defeated by twin!")
			present_tp.state["enemies"].remove_at(0)
			present_tp.entities.erase(target_enemy)
			target_enemy.visible = false

			# Queue for deletion
			get_tree().create_timer(1.5).timeout.connect(func():
				if is_instance_valid(target_enemy):
					target_enemy.queue_free()
			)

	# Pause at enemy
	await get_tree().create_timer(0.1).timeout

	# Dash back
	var tween2 = create_tween()
	tween2.tween_property(twin_entity, "position", original_pos, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween2.finished

	print("  Twin attack complete!")


func animate_enemy_attacks() -> void:
	"""Animate all enemies attacking twin/player sequentially"""
	var present_tp = timeline_panels[2]

	# Find player and twin
	var player_entity = null
	var twin_entity = null
	for entity in present_tp.entities:
		if entity.is_player:
			if entity.entity_data.get("is_twin", false):
				twin_entity = entity
			else:
				player_entity = entity

	if not player_entity:
		print("  Cannot animate - missing player")
		return

	# Get all enemies with data
	var enemy_list = []
	for i in range(present_tp.state["enemies"].size()):
		var enemy_data = present_tp.state["enemies"][i]
		for entity in present_tp.entities:
			if not entity.is_player and entity.entity_data["name"] == enemy_data["name"]:
				enemy_list.append({"node": entity, "data": enemy_data, "index": i})
				break

	if enemy_list.size() == 0:
		return

	print("  Enemy attacks starting...")

	# Track if twin is still alive
	var twin_alive = (twin_entity != null and present_tp.state.has("twin"))

	# Animate each enemy sequentially
	for enemy_info in enemy_list:
		var enemy_index = enemy_info["index"]

		# CHECK MISS FLAGS
		if future_miss_flags.get(enemy_index, false):
			print("  Enemy ", enemy_index, " misses (Chaos Injection effect)")
			continue

		# Determine target: twin first, then player
		var target = null
		var target_is_twin = false

		# CHECK REDIRECT
		if future_redirect_flag != null and future_redirect_flag.get("from_enemy", -1) == enemy_index:
			var to_index = future_redirect_flag.get("to_enemy", -1)
			if to_index >= 0 and to_index < enemy_list.size():
				target = enemy_list[to_index]["node"]
				print("  Enemy ", enemy_index, " attacks enemy ", to_index, " (Redirect effect)")
		else:
			# Target twin first (leftmost), then player
			if twin_alive:
				target = twin_entity
				target_is_twin = true
			else:
				target = player_entity

		await animate_single_enemy_attack(enemy_info["node"], target, enemy_info["data"], target_is_twin)

		# Check if twin died from this attack
		if target_is_twin and present_tp.state.has("twin"):
			if present_tp.state["twin"]["hp"] <= 0:
				print("  Twin defeated! Remaining enemies will attack player.")
				twin_alive = false
				# Remove twin from entities
				if twin_entity and is_instance_valid(twin_entity):
					present_tp.entities.erase(twin_entity)
					twin_entity.visible = false
					get_tree().create_timer(1.0).timeout.connect(func():
						if is_instance_valid(twin_entity):
							twin_entity.queue_free()
					)
				twin_entity = null

	print("  All enemy attacks complete!")


func animate_single_enemy_attack(enemy: Node2D, target: Node2D, enemy_data: Dictionary, target_is_twin: bool = false) -> void:
	"""Animate single enemy attacking target (player, twin, or another enemy)"""
	var present_tp = timeline_panels[2]

	var original_pos = enemy.position
	var target_pos = target.position
	var direction = (target_pos - original_pos).normalized()
	var attack_pos = target_pos - direction * 50.0

	# Dash to target
	var tween = create_tween()
	tween.tween_property(enemy, "position", attack_pos, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

	# APPLY DAMAGE AT IMPACT
	var damage = enemy_data["damage"]

	# Check if target is player, twin, or enemy
	if target.is_player:
		if target_is_twin:
			# Attacking twin
			present_tp.state["twin"]["hp"] -= damage
			print("  ", enemy_data["name"], " dealt ", damage, " damage to twin! Twin HP: ", present_tp.state["twin"]["hp"])

			# Update twin visual
			target.entity_data = present_tp.state["twin"]
			target.update_display()
		else:
			# Attacking player
			present_tp.state["player"]["hp"] -= damage
			print("  ", enemy_data["name"], " dealt ", damage, " damage! Player HP: ", present_tp.state["player"]["hp"])

			# Update player visual
			target.entity_data = present_tp.state["player"]
			target.update_display()
	else:
		# Attacking another enemy (redirect)
		# Find target enemy in state
		for enemy_state in present_tp.state["enemies"]:
			if enemy_state["name"] == target.entity_data["name"]:
				enemy_state["hp"] -= damage
				print("  ", enemy_data["name"], " dealt ", damage, " damage to ", enemy_state["name"], "! Enemy HP: ", enemy_state["hp"])

				# Update enemy visual
				target.entity_data = enemy_state
				target.update_display()

				# Remove if dead
				if enemy_state["hp"] <= 0:
					print("  ", enemy_state["name"], " defeated by redirect!")
					present_tp.state["enemies"].erase(enemy_state)
					present_tp.entities.erase(target)
					target.visible = false
					get_tree().create_timer(1.5).timeout.connect(func():
						if is_instance_valid(target):
							target.queue_free()
					)
				break
	
	# Play attack sound
	enemy.play_attack_sound()
	
	# Screen shake
	apply_screen_shake(damage * 0.5)
	
	# Hit reaction
	var hit_direction = (target.position - enemy.position).normalized()
	target.play_hit_reaction(hit_direction)
	
	# Pause
	await get_tree().create_timer(0.08).timeout
	
	# Dash back
	var tween2 = create_tween()
	tween2.tween_property(enemy, "position", original_pos, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween2.finished

func recalculate_future_timelines():
	"""Recalculate Future (slot 3) and Decorative Future (slot 4) after combat"""
	var present_tp = timeline_panels[2]  # Present at slot 2
	var future_tp = timeline_panels[3]    # Future at slot 3
	var dec_future_tp = timeline_panels[4] # Decorative Future at slot 4
	
	# Check if all enemies defeated
	if present_tp.state.get("enemies", []).size() == 0:
		print("  🎉 All enemies defeated! Spawning new wave...")
		
		# Spawn new wave (same as initial for testing)
		present_tp.state["enemies"] = [
			{"name": "Chrono-Beast A", "hp": 45, "max_hp": 45, "damage": 12},
			{"name": "Chrono-Beast B", "hp": 30, "max_hp": 30, "damage": 8}
		]
		
		# Recreate Present entities with new enemies
		create_timeline_entities(present_tp)
		
		# Update labels visibility
		update_timeline_ui_visibility(present_tp)
	
	# Calculate Future based on current Present (after combat)
	future_tp.state = calculate_future_from_state(present_tp.state)
	future_tp.timeline_type = "future"
	create_timeline_entities(future_tp)
	print("  ✅ Future recalculated")
	
	# Calculate Decorative Future based on new Future
	dec_future_tp.state = calculate_future_from_state(future_tp.state)
	dec_future_tp.timeline_type = "decorative"
	create_timeline_entities(dec_future_tp)
	print("  ✅ Decorative Future recalculated")

func show_timeline_arrows():
	"""Create and show arrows for Present and Future"""
	var present_tp = timeline_panels[2]
	var future_tp = timeline_panels[3]
	
	# Create arrows for Present (player → enemy)
	create_timeline_arrows(present_tp)
	
	# Create arrows for Future (enemies → player, with redirects/misses)
	create_timeline_arrows(future_tp)
	
	# Make sure arrows are visible
	for tp in [present_tp, future_tp]:
		for arrow in tp.arrows:
			if arrow and is_instance_valid(arrow):
				arrow.visible = true
				arrow.show_arrow()
	
	print("  ✅ Arrows shown")

func animate_enemy_repositioning_after_death(tp: Panel):
	"""Animate remaining enemies repositioning after one dies using grid-based layout"""
	var enemy_entities = []
	for entity in tp.entities:
		if not entity.is_player and is_instance_valid(entity) and entity.visible:
			enemy_entities.append(entity)

	var enemy_count = enemy_entities.size()
	if enemy_count == 0:
		return  # No repositioning needed for 0 enemies

	print("  ↔️ Repositioning ", enemy_count, " remaining enemies to grid cells...")

	var tween = create_tween()
	tween.set_parallel(true)

	# Calculate and animate to new grid-based positions
	for i in range(enemy_count):
		var entity = enemy_entities[i]

		# Get grid position for this enemy based on new count
		var grid_pos = tp.get_grid_position_for_entity(i, false, enemy_count)
		var new_pos = tp.get_cell_center_position(grid_pos.x, grid_pos.y)

		print("    Enemy ", i, " → grid (", grid_pos.x, ", ", grid_pos.y, ") at ", new_pos)
		tween.tween_property(entity, "position", new_pos, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await tween.finished
	print("  ✅ Enemy repositioning complete")

func disable_all_card_input():
	"""Disable mouse input on all top cards"""
	for deck in [past_deck, present_deck, future_deck]:
		var top_card = deck.get_top_card()
		if top_card and is_instance_valid(top_card):
			top_card.mouse_filter = Control.MOUSE_FILTER_IGNORE


func enable_all_card_input():
	"""Re-enable mouse input on all top cards after animations"""
	# Don't enable if game is over!
	if game_over:
		return
	
	for deck in [past_deck, present_deck, future_deck]:
		var top_card = deck.get_top_card()
		if top_card and is_instance_valid(top_card):
			# Only enable if not used
			if not top_card.is_used:
				top_card.mouse_filter = Control.MOUSE_FILTER_STOP

# ===== TARGETING MODE SYSTEM =====

func card_requires_targeting(card_data: Dictionary) -> bool:
	"""Check if a card requires target selection"""
	var effect_type = card_data.get("effect_type")

	# Cards that require targeting
	match effect_type:
		CardDatabase.EffectType.DAMAGE_ENEMY:
			return true  # Select which enemy to damage
		CardDatabase.EffectType.ENEMY_SWAP:
			return true  # Select two enemies to swap
		CardDatabase.EffectType.REDIRECT_FUTURE_ATTACK:
			return true  # Select source enemy and target
		CardDatabase.EffectType.WOUND_TRANSFER:
			return true  # Select which enemy to transfer wounds from
		CardDatabase.EffectType.CONSCRIPT_PAST_ENEMY:
			return true  # Select enemy in PAST to swap with player
		_:
			return false

func get_required_target_count(card_data: Dictionary) -> int:
	"""Get number of targets required for this card"""
	var effect_type = card_data.get("effect_type")

	match effect_type:
		CardDatabase.EffectType.DAMAGE_ENEMY:
			return 1  # One enemy
		CardDatabase.EffectType.ENEMY_SWAP:
			return 2  # Two enemies
		CardDatabase.EffectType.REDIRECT_FUTURE_ATTACK:
			return 2  # Source enemy and target enemy
		CardDatabase.EffectType.WOUND_TRANSFER:
			return 1  # One enemy
		CardDatabase.EffectType.CONSCRIPT_PAST_ENEMY:
			return 1  # One enemy in PAST
		_:
			return 0

func get_valid_target_timelines(card_data: Dictionary) -> Array:
	"""Get array of timeline types that can be targeted for this card
	Returns array of strings: ["past"], ["present"], ["future"], or combinations
	"""
	var effect_type = card_data.get("effect_type")

	match effect_type:
		CardDatabase.EffectType.DAMAGE_ENEMY:
			# Chrono Strike - ONLY PRESENT enemies
			return ["present"]

		CardDatabase.EffectType.ENEMY_SWAP:
			# Enemy Swap - ONLY PRESENT enemies
			return ["present"]

		CardDatabase.EffectType.REDIRECT_FUTURE_ATTACK:
			# Redirect Attack - ONLY PRESENT enemies (affects Future)
			return ["present"]

		CardDatabase.EffectType.WOUND_TRANSFER:
			# Wound Transfer - ONLY PAST enemies
			return ["past"]

		CardDatabase.EffectType.CONSCRIPT_PAST_ENEMY:
			# Conscript Enemy - ONLY PAST enemies
			return ["past"]

		_:
			# Default: all timelines
			return ["past", "present", "future"]

func enter_targeting_mode(card_data: Dictionary, card_node: Node, source_deck: CardDeck):
	"""Enter targeting mode for a card"""
	print("\n🎯 ENTERING TARGETING MODE")
	print("  Card: ", card_data.get("name", "Unknown"))

	targeting_mode_active = true
	targeting_card_data = card_data
	targeting_card_node = card_node
	targeting_source_deck = source_deck
	selected_targets = []
	required_target_count = get_required_target_count(card_data)
	valid_target_timelines = get_valid_target_timelines(card_data)

	# Set card visual state
	if card_node:
		card_node.enter_targeting_mode()

	# Disable all other cards
	for deck in [past_deck, present_deck, future_deck]:
		var top_card = deck.get_top_card()
		if top_card and is_instance_valid(top_card) and top_card != card_node:
			top_card.disable_for_targeting()

	# Highlight valid targets based on card effect
	highlight_valid_targets_for_card(card_data)

	# Enable entity targeting
	enable_entity_targeting()

	print("  Required targets: ", required_target_count)
	print("  ✅ Targeting mode active")

func cancel_targeting_mode():
	"""Cancel targeting mode and restore normal state"""
	print("\n❌ CANCELING TARGETING MODE")

	if not targeting_mode_active:
		return

	targeting_mode_active = false
	selected_targets = []

	# Restore card visual states
	for deck in [past_deck, present_deck, future_deck]:
		var top_card = deck.get_top_card()
		if top_card and is_instance_valid(top_card):
			top_card.exit_targeting_mode()

	# Clear highlights
	clear_all_target_highlights()

	# Disable entity targeting
	disable_entity_targeting()

	# Clear targeting variables
	targeting_card_data = {}
	targeting_card_node = null
	targeting_source_deck = null
	required_target_count = 0

	print("  ✅ Targeting mode canceled")

func on_target_selected(target):
	"""Handle when a target is selected (entity or cell)"""
	if not targeting_mode_active:
		return

	# Validate that the target is from a valid timeline
	if target is Node2D:  # Entity
		var target_timeline = target.timeline_type
		if target_timeline not in valid_target_timelines:
			print("❌ Invalid target: ", target.entity_data.get("name", "Unknown"), " is in ", target_timeline, " (valid: ", valid_target_timelines, ")")
			# Don't mark click as handled - this will cancel targeting
			return

	# Mark that this click was handled by a valid target
	targeting_click_handled = true

	print("🎯 Target selected: ", target)

	# Add to selected targets
	selected_targets.append(target)

	# Visual feedback for selected target
	if target is Node2D:  # Entity
		target.mark_as_targeted()

	print("  Selected ", selected_targets.size(), "/", required_target_count, " targets")

	# Check if we have all required targets
	if selected_targets.size() >= required_target_count:
		complete_targeting()

func complete_targeting():
	"""All targets selected - apply card effect and finish"""
	print("\n✅ TARGETING COMPLETE")
	print("  Applying effect with targets: ", selected_targets)

	# Validate that player still has enough time
	var time_cost = targeting_card_data.get("time_cost", 0)
	if time_remaining < time_cost:
		print("❌ Not enough time! Card cost: ", time_cost, ", Time remaining: ", time_remaining)

		# Play shake animation on the card
		if targeting_card_node and is_instance_valid(targeting_card_node):
			targeting_card_node.play_shake_animation()

		# Cancel targeting mode
		cancel_targeting_mode()
		return

	# Deduct time cost
	time_remaining -= time_cost
	if time_remaining < 0:
		time_remaining = 0
	update_timer_display()

	# Update all cards' affordability
	update_all_cards_affordability()

	# Apply card effect with targets
	apply_card_effect_with_targets(targeting_card_data, selected_targets)

	# Recycle the card
	if targeting_source_deck:
		recycle_card_simple(targeting_source_deck)

	# Recalculate Future to show card effects
	calculate_future_state()

	# Update timeline visuals
	var future_tp = get_timeline_panel("future")
	create_timeline_entities(future_tp)
	create_timeline_arrows(future_tp)
	update_timeline_ui_visibility(future_tp)

	var present_tp = get_timeline_panel("present")
	create_timeline_entities(present_tp)
	create_timeline_arrows(present_tp)
	update_timeline_ui_visibility(present_tp)

	# Update damage display in UI
	update_damage_display()

	# Exit targeting mode
	cancel_targeting_mode()

	print("  ✅ Card effect applied and targeting complete")

func highlight_valid_targets_for_card(card_data: Dictionary):
	"""Highlight valid targets based on card effect type and valid timelines"""
	var valid_timelines = get_valid_target_timelines(card_data)

	# Iterate through all panels and highlight entities in valid timelines
	for panel in timeline_panels:
		# Check if this panel's timeline is valid for targeting
		if panel.timeline_type in valid_timelines:
			for entity in panel.entities:
				if is_instance_valid(entity) and not entity.is_player:
					entity.show_as_valid_target()

func clear_all_target_highlights():
	"""Clear all target highlights from all panels"""
	for panel in timeline_panels:
		for entity in panel.entities:
			if is_instance_valid(entity):
				entity.clear_target_visuals()
		panel.clear_all_highlights()

func enable_entity_targeting():
	"""Enable clicking on entities for targeting"""
	# Enable targeting on all entities across all timelines
	# (only highlighted ones will be visibly clickable)
	for panel in timeline_panels:
		for entity in panel.entities:
			if is_instance_valid(entity) and not entity.is_player:
				entity.enable_targeting(self)

func disable_entity_targeting():
	"""Disable clicking on entities"""
	for panel in timeline_panels:
		for entity in panel.entities:
			if is_instance_valid(entity):
				entity.disable_targeting()

func apply_card_effect_with_targets(card_data: Dictionary, targets: Array):
	"""Apply card effect using selected targets"""
	var present_tp = get_timeline_panel("present")
	var effect_type = card_data.get("effect_type")
	var effect_value = card_data.get("effect_value", 0)

	match effect_type:
		CardDatabase.EffectType.DAMAGE_ENEMY:
			# Damage the selected enemy
			if targets.size() > 0 and is_instance_valid(targets[0]):
				var target_entity = targets[0]
				# Find enemy in state
				for i in range(present_tp.state["enemies"].size()):
					if present_tp.state["enemies"][i]["name"] == target_entity.entity_data["name"]:
						present_tp.state["enemies"][i]["hp"] -= effect_value
						print("Dealt ", effect_value, " damage to ", present_tp.state["enemies"][i]["name"])
						if present_tp.state["enemies"][i]["hp"] <= 0:
							present_tp.state["enemies"].remove_at(i)
							print("  Enemy defeated!")
						break

		CardDatabase.EffectType.ENEMY_SWAP:
			# Swap two enemies
			if targets.size() >= 2 and is_instance_valid(targets[0]) and is_instance_valid(targets[1]):
				var enemy1_name = targets[0].entity_data["name"]
				var enemy2_name = targets[1].entity_data["name"]
				var idx1 = -1
				var idx2 = -1

				# Find indices in state
				for i in range(present_tp.state["enemies"].size()):
					if present_tp.state["enemies"][i]["name"] == enemy1_name:
						idx1 = i
					if present_tp.state["enemies"][i]["name"] == enemy2_name:
						idx2 = i

				# Swap
				if idx1 >= 0 and idx2 >= 0:
					var temp = present_tp.state["enemies"][idx1]
					present_tp.state["enemies"][idx1] = present_tp.state["enemies"][idx2]
					present_tp.state["enemies"][idx2] = temp
					print("Swapped ", enemy1_name, " and ", enemy2_name)

		CardDatabase.EffectType.REDIRECT_FUTURE_ATTACK:
			# Set redirect flag
			if targets.size() >= 2:
				var source_enemy = targets[0]
				var target_enemy = targets[1]
				var source_idx = -1
				var target_idx = -1

				# Find indices
				for i in range(present_tp.state["enemies"].size()):
					if present_tp.state["enemies"][i]["name"] == source_enemy.entity_data["name"]:
						source_idx = i
					if present_tp.state["enemies"][i]["name"] == target_enemy.entity_data["name"]:
						target_idx = i

				if source_idx >= 0 and target_idx >= 0:
					future_redirect_flag = {
						"from_enemy": source_idx,
						"to_enemy": target_idx
					}
					print("Future: Enemy ", source_idx, " will attack Enemy ", target_idx)

		CardDatabase.EffectType.WOUND_TRANSFER:
			# Calculate and apply wound transfer
			var past_tp = get_timeline_panel("past")
			if targets.size() > 0 and past_tp and not past_tp.state.is_empty():
				var target_entity = targets[0]
				var target_name = target_entity.entity_data["name"]

				# Find matching enemy in Past and Present
				for i in range(present_tp.state["enemies"].size()):
					if present_tp.state["enemies"][i]["name"] == target_name:
						# Find in past
						for past_enemy in past_tp.state.get("enemies", []):
							if past_enemy["name"] == target_name:
								var damage_taken = past_enemy["hp"] - present_tp.state["enemies"][i]["hp"]
								if damage_taken > 0:
									present_tp.state["enemies"][i]["hp"] -= damage_taken
									print("Transferred ", damage_taken, " wound damage to ", target_name)
									if present_tp.state["enemies"][i]["hp"] <= 0:
										present_tp.state["enemies"].remove_at(i)
								break
						break

		CardDatabase.EffectType.CONSCRIPT_PAST_ENEMY:
			# Conscript enemy from PAST to swap with player
			var past_tp = get_timeline_panel("past")
			if targets.size() > 0 and past_tp and not past_tp.state.is_empty():
				var target_entity = targets[0]
				var conscripted_data = target_entity.entity_data.duplicate()

				print("🔄 Conscripting ", conscripted_data["name"], " to fight in player's place")

				# Store original player data (for restoration after combat)
				original_player_data = present_tp.state["player"].duplicate(true)
				print("  Stored original player: HP=", original_player_data["hp"], " DMG=", original_player_data["damage"])

				# Replace player with conscripted enemy in PRESENT
				conscripted_enemy_data = conscripted_data.duplicate()
				conscripted_enemy_data["name"] = "Conscripted " + conscripted_data["name"]
				conscripted_enemy_data["is_conscripted_enemy"] = true  # Flag for visual rendering as enemy
				present_tp.state["player"] = conscripted_enemy_data.duplicate()

				# Mark conscription as active
				conscription_active = true

				print("  ✅ Player replaced with ", conscripted_enemy_data["name"])
				print("  Conscripted stats: HP=", conscripted_enemy_data["hp"], " DMG=", conscripted_enemy_data.get("damage", 0))

func handle_game_over():
	"""Handle player death - disable all inputs"""
	game_over = true

	# Disable Play button
	play_button.disabled = true
	play_button.text = "GAME OVER"

	# Disable all cards permanently
	disable_all_card_input()
	for deck in [past_deck, present_deck, future_deck]:
		var top_card = deck.get_top_card()
		if top_card and is_instance_valid(top_card):
			top_card.mark_as_used()  # Gray out all top cards

	print("💀 All controls disabled - Game Over!")