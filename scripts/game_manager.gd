extends Node2D

# ===== TIMELINE PANEL CLASS =====
# Self-contained panel with all its data and entities

class TimelinePanel:
	var panel_node: Panel = null  # The actual Panel UI node
	var timeline_type: String = "decorative"  # "past", "present", "future", "decorative"
	var state: Dictionary = {}  # Game state: { player: {...}, enemies: [...] }
	var entities: Array = []  # Entity visual nodes
	var arrows: Array = []  # Arrow visual nodes
	var slot_index: int = -1  # Current carousel slot position
	
	func _init(node: Panel, type: String, slot: int):
		panel_node = node
		timeline_type = type
		slot_index = slot
	
	func clear_entities():
		"""Remove all entity nodes from panel"""
		for entity in entities:
			if entity and is_instance_valid(entity):
				entity.queue_free()
		entities.clear()
	
	func clear_arrows():
		"""Remove all arrow nodes from panel"""
		for arrow in arrows:
			if arrow and is_instance_valid(arrow):
				arrow.queue_free()
		arrows.clear()
	
	func clear_all():
		"""Clear both entities and arrows"""
		clear_entities()
		clear_arrows()


# ===== PRELOADS =====
const ENTITY_SCENE = preload("res://scenes/entity.tscn")
const CARD_SCENE = preload("res://scenes/card.tscn")
const ARROW_SCENE = preload("res://scenes/arrow.tscn")

# ===== GAME STATE =====
var current_wave = 1
var turn_number = 0
var game_over = false
var card_played_this_turn = false

# ===== CARD SYSTEM =====
var available_cards = []  # Card data from CardDatabase
var card_nodes = []        # Visual card nodes

# ===== SCREEN SHAKE =====
var shake_strength = 0.0
var shake_decay = 5.0

# ===== CAROUSEL SYSTEM =====
var timeline_panels: Array[TimelinePanel] = []  # 6 TimelinePanel objects

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
@onready var decorative_past_panel = $UIRoot/CarouselContainer/DecorativePastPanel
@onready var past_panel = $UIRoot/CarouselContainer/PastPanel
@onready var present_panel = $UIRoot/CarouselContainer/PresentPanel
@onready var future_panel = $UIRoot/CarouselContainer/FuturePanel
@onready var decorative_future_panel = $UIRoot/CarouselContainer/DecorativeFuturePanel
@onready var intermediate_future_panel = $UIRoot/CarouselContainer/IntermediateFuturePanel
@onready var play_button = $UIRoot/PlayButton
@onready var wave_counter_label = $UIRoot/WaveCounter/WaveLabel
@onready var damage_label = $UIRoot/DamageDisplay/DamageLabel
@onready var card_container = $UIRoot/CardContainer
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
	"""Initialize carousel with 6 real panels (no null placeholder)"""
	print("Setting up carousel with 6 panels...")
	
	timeline_panels = [
		TimelinePanel.new(decorative_past_panel, "decorative", 0),
		TimelinePanel.new(past_panel, "past", 1),
		TimelinePanel.new(present_panel, "present", 2),
		TimelinePanel.new(future_panel, "future", 3),
		TimelinePanel.new(decorative_future_panel, "decorative", 4),
		TimelinePanel.new(intermediate_future_panel, "decorative", 5)
	]  # Only 6 panels!
	
	for i in range(timeline_panels.size()):
		if timeline_panels[i].panel_node != null:
			apply_carousel_position(timeline_panels[i].panel_node, i)
	
	if present_panel:
		carousel_container.move_child(present_panel, -1)
	
	build_carousel_snapshot()
	print("✅ Carousel initialized with ", timeline_panels.size(), " panels")

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
	
	# Calculate initial Future
	calculate_future_state()
	
	# Create visuals for all timelines
	update_all_timeline_displays()
	update_wave_counter()
	setup_cards()

func get_timeline_panel(timeline_type: String) -> TimelinePanel:
	"""Get the TimelinePanel with the specified timeline_type"""
	for tp in timeline_panels:
		if tp.timeline_type == timeline_type:
			return tp
	return null


# ===== ENTITY & ARROW CREATION =====

func create_timeline_entities(tp: TimelinePanel):
	"""Create entity visuals for a TimelinePanel"""
	print("\n=== Creating entities for ", tp.timeline_type, " timeline ===")
	
	# Clear old entities
	tp.clear_entities()
	
	if tp.panel_node == null or tp.state.is_empty():
		print("  No panel or empty state, skipping")
		return
	
	# Clear any orphaned nodes from panel
	for child in tp.panel_node.get_children():
		if child is Node2D and "Label" not in child.name:
			child.queue_free()
	
	# Panel dimensions
	var center_x = 300.0
	var standard_height = 750.0
	
	# Create enemy entities in semicircle
	if tp.state.has("enemies"):
		var enemy_count = tp.state["enemies"].size()
		var arc_center_x = center_x
		var arc_center_y = standard_height * 0.33
		var arc_radius = 120.0
		var arc_span = PI * 0.6
		
		for i in range(enemy_count):
			var enemy_entity = ENTITY_SCENE.instantiate()
			enemy_entity.setup(tp.state["enemies"][i], false, tp.timeline_type)
			
			var angle_offset = 0
			if enemy_count > 1:
				angle_offset = (float(i) / (enemy_count - 1) - 0.5) * arc_span
			
			var pos_x = arc_center_x + arc_radius * sin(angle_offset)
			var pos_y = arc_center_y - arc_radius * cos(angle_offset)
			
			enemy_entity.position = Vector2(pos_x, pos_y)
			tp.panel_node.add_child(enemy_entity)
			tp.entities.append(enemy_entity)
	
	# Create player entity at bottom center
	if tp.state.has("player"):
		var player_entity = ENTITY_SCENE.instantiate()
		player_entity.setup(tp.state["player"], true, tp.timeline_type)
		player_entity.position = Vector2(center_x, standard_height * 0.8)
		tp.panel_node.add_child(player_entity)
		tp.entities.append(player_entity)
	
	print("  Created ", tp.entities.size(), " entities")

func create_timeline_arrows(tp: TimelinePanel):
	"""Create arrows for a TimelinePanel based on its timeline_type"""
	print("🏹 Creating arrows for ", tp.timeline_type, " timeline...")
	
	# Clear old arrows
	tp.clear_arrows()
	
	if tp.panel_node == null or tp.state.is_empty():
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
			# Future: Enemy → Player arrows
			create_enemy_attack_arrows(tp)
			print("  Created enemy → player arrows")

func create_player_attack_arrows(tp: TimelinePanel):
	"""Create arrow from player to leftmost enemy"""
	var player_entity = null
	var target_enemy = null
	
	for entity in tp.entities:
		if entity.is_player:
			player_entity = entity
		elif target_enemy == null:
			target_enemy = entity
	
	if player_entity and target_enemy:
		var arrow = ARROW_SCENE.instantiate()
		tp.panel_node.add_child(arrow)
		
		var curve = calculate_smart_curve(player_entity.position, target_enemy.position)
		arrow.setup(player_entity.position, target_enemy.position, curve)
		
		tp.arrows.append(arrow)

func create_enemy_attack_arrows(tp: TimelinePanel):
	"""Create arrows from each enemy to player"""
	var player_entity = null
	for entity in tp.entities:
		if entity.is_player:
			player_entity = entity
			break
	
	if not player_entity:
		return
	
	for entity in tp.entities:
		if not entity.is_player:
			var arrow = ARROW_SCENE.instantiate()
			tp.panel_node.add_child(arrow)
			
			var curve = calculate_smart_curve(entity.position, player_entity.position)
			arrow.setup(entity.position, player_entity.position, curve)
			
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

func update_timeline_ui_visibility(tp: TimelinePanel):
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
	
	# Simulate combat
	if future_tp.state["enemies"].size() > 0:
		var target_enemy = future_tp.state["enemies"][0]
		target_enemy["hp"] -= future_tp.state["player"]["damage"]
		
		# Remove dead enemies
		future_tp.state["enemies"] = future_tp.state["enemies"].filter(func(e): return e["hp"] > 0)
		
		# Enemies attack back
		for enemy in future_tp.state["enemies"]:
			future_tp.state["player"]["hp"] -= enemy["damage"]
	
	print("Future calculated: Player will have ", future_tp.state["player"]["hp"], " HP")

func update_after_carousel_slide_correct(state_for_past: Dictionary, first_turn: bool):
	"""Update timeline types and states after carousel slide"""
	print("🔄 Updating timeline types and states...")
	
	# Update timeline types
	timeline_panels[0].timeline_type = "decorative"
	timeline_panels[1].timeline_type = "past"
	timeline_panels[2].timeline_type = "present"
	timeline_panels[3].timeline_type = "future"
	timeline_panels[4].timeline_type = "decorative"
	
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
	if timeline_panels[1].panel_node:
		for child in timeline_panels[1].panel_node.get_children():
			if "Label" in child.name:
				child.text = "⟲ PAST"
	
	# timeline_panels[2] is now Present
	if timeline_panels[2].panel_node:
		for child in timeline_panels[2].panel_node.get_children():
			if "Label" in child.name:
				child.text = "◉ PRESENT"
	
	# timeline_panels[3] is now Future
	if timeline_panels[3].panel_node:
		for child in timeline_panels[3].panel_node.get_children():
			if "Label" in child.name:
				child.text = "⟳ FUTURE"
	
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


# ===== CARD SYSTEM =====

func setup_cards():
	"""Initialize card slots"""
	for card_node in card_nodes:
		card_node.queue_free()
	card_nodes.clear()
	
	var all_cards = CardDatabase.get_all_cards()
	available_cards.clear()
	
	for i in range(min(4, all_cards.size())):
		available_cards.append(all_cards[i])
	
	for card_data in available_cards:
		var card_node = CARD_SCENE.instantiate()
		card_container.add_child(card_node)
		card_node.setup(card_data)
		card_node.card_clicked.connect(_on_card_played)
		card_nodes.append(card_node)
	
	card_played_this_turn = false
	print("Cards set up: ", available_cards.size(), " cards available")

func _on_card_played(card_data: Dictionary):
	"""Handle card click"""
	if card_played_this_turn:
		print("Already played a card this turn!")
		return
	
	print("Playing card: ", card_data.get("name", "Unknown"))
	
	apply_card_effect(card_data)
	card_played_this_turn = true
	
	for card_node in card_nodes:
		card_node.mark_as_used()
	
	calculate_future_state()
	
	# Only update Future timeline (don't recreate Past/Present)
	var future_tp = get_timeline_panel("future")
	create_timeline_entities(future_tp)
	create_timeline_arrows(future_tp)
	update_timeline_ui_visibility(future_tp)

func apply_card_effect(card_data: Dictionary):
	"""Apply card effect to Present timeline"""
	var present_tp = get_timeline_panel("present")
	var effect_type = card_data.get("effect_type")
	var effect_value = card_data.get("effect_value", 0)
	
	match effect_type:
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
			print("Boosted damage by ", effect_value)


# ===== TURN EXECUTION =====

func _on_play_button_pressed():
	"""Execute complete turn: carousel slide → combat → future calculation"""
	print("\n▶ PLAY button pressed - Starting complete turn sequence!")
	
	# Disable Play button during turn
	play_button.disabled = true
	
	# Execute complete turn with combat
	await execute_complete_turn()
	
	# Re-enable Play button
	play_button.disabled = false
	
	print("✅ Turn complete - Ready for next turn!")

func execute_turn():
	"""Execute turn with combat animations (to be implemented)"""
	# TODO: Implement combat animations
	pass


# ===== SCREEN SHAKE =====

func _process(delta):
	"""Handle screen shake"""
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

func calculate_future_from_state(base_state: Dictionary) -> Dictionary:
	"""Calculate future state from any given state"""
	var future = base_state.duplicate(true)
	
	if future["enemies"].size() > 0:
		var target_enemy = future["enemies"][0]
		target_enemy["hp"] -= future["player"]["damage"]
		future["enemies"] = future["enemies"].filter(func(e): return e["hp"] > 0)
		
		for enemy in future["enemies"]:
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
	
	if old_slot_0.panel_node != null:
		apply_carousel_position(old_slot_0.panel_node, 5)
	
	for i in range(timeline_panels.size()):
		timeline_panels[i].slot_index = i
	
	print("✅ Rotated! Array size: ", timeline_panels.size())

func execute_complete_turn():
	"""Execute complete turn: slide → combat → recalculate"""
	
	# PHASE 1: Carousel slide animation
	print("\n🎠 PHASE 1: Carousel slide animation")
	await carousel_slide_animation_with_blanks()
	
	# CRITICAL: At this point, rotation is complete!
	# - timeline_panels[2] is the NEW Present (was Future before slide)
	# - Its state is what we should use for combat!
	
	# PHASE 2: Show HP/DMG on new Present AND Past
	print("\n💚 PHASE 2: Show HP/DMG labels")
	show_present_ui_labels()
	
	# PHASE 3: Combat animations (using NEW Present state)
	print("\n⚔️ PHASE 3: Combat animations")
	await execute_combat_animations()
	
	# PHASE 4: Recalculate Future and Decorative Future
	print("\n🔮 PHASE 4: Recalculate Future timelines")
	recalculate_future_timelines()
	
	# PHASE 5: Show arrows
	print("\n🏹 PHASE 5: Show arrows")
	show_timeline_arrows()
	
	print("✅ Complete turn executed!")

func carousel_slide_animation_with_blanks():
	"""Carousel slide with Decorative Future starting blank"""
	print("\n🎠 Starting carousel slide (Decorative Future blank)...")
	
	hide_ui_for_carousel()
	delete_all_arrows()
	
	var slot_2_tp = timeline_panels[2]  # Current Present
	var slot_3_tp = timeline_panels[3]  # Current Future
	var slot_4_tp = timeline_panels[4]
	var slot_5_tp = timeline_panels[5]
	
	# CRITICAL FIX: ALWAYS capture current Present state for Past update
	var state_for_past = slot_2_tp.state.duplicate(true)
	
	if is_first_turn:
		print("  🔵 First turn - Past will get original Present state (full HP)")
	else:
		print("  🔄 Subsequent turn - Past will get current Present state (post-combat from last turn)")
	
	# Check if we need enemy revival animation
	var old_enemy_count = slot_3_tp.state.get("enemies", []).size()
	var new_enemy_count = slot_2_tp.state.get("enemies", []).size()
	var needs_revival = new_enemy_count > old_enemy_count
	
	# Prepare enemy repositioning during slide
	var enemy_repositioning_tween = null
	if needs_revival:
		print("  🔄 Preparing enemy repositioning: ", old_enemy_count, " → ", new_enemy_count)
	
	# Get current enemy entities in Future (before adding revived one)
	var existing_enemies = []
	for entity in slot_3_tp.entities:
		if not entity.is_player:
			existing_enemies.append(entity)
	
	# Update state to include revived enemy
	slot_3_tp.state["enemies"] = slot_2_tp.state["enemies"].duplicate(true)
	
	# Create the revived enemy entity
	var panel_center_x = 300.0
	var panel_height = 750.0
	var arc_center_y = panel_height * 0.33
	var arc_radius = 120.0
	var arc_span = PI * 0.6
	
	# Calculate position for revived enemy (it's the last one in the list)
	var revived_index = new_enemy_count - 1
	var revived_angle = 0
	if new_enemy_count > 1:
		revived_angle = (float(revived_index) / (new_enemy_count - 1) - 0.5) * arc_span
	
	var revived_pos_x = panel_center_x + arc_radius * sin(revived_angle)
	var revived_pos_y = arc_center_y - arc_radius * cos(revived_angle)
	
	# Create revived enemy entity
	var revived_enemy = ENTITY_SCENE.instantiate()
	revived_enemy.setup(slot_3_tp.state["enemies"][revived_index], false, "future")
	revived_enemy.position = Vector2(revived_pos_x, revived_pos_y)
	revived_enemy.modulate.a = 0.0  # Start invisible
	
	# CRITICAL FIX: Hide HP/DMG labels on revived enemy (carousel slide in progress!)
	if revived_enemy.has_node("HPLabel"):
		revived_enemy.get_node("HPLabel").visible = false
	if revived_enemy.has_node("DamageLabel"):
		revived_enemy.get_node("DamageLabel").visible = false
	
	slot_3_tp.panel_node.add_child(revived_enemy)
	slot_3_tp.entities.append(revived_enemy)
	
	# Create tween for enemy repositioning (runs in parallel with carousel slide)
	enemy_repositioning_tween = create_tween()
	enemy_repositioning_tween.set_parallel(true)
	
	# Fade in the revived enemy
	enemy_repositioning_tween.tween_property(revived_enemy, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Reposition existing enemies based on new count
	for i in range(existing_enemies.size()):
		var entity = existing_enemies[i]
		
		# CRITICAL FIX: Ensure HP/DMG labels stay hidden during repositioning
		if entity.has_node("HPLabel"):
			entity.get_node("HPLabel").visible = false
		if entity.has_node("DamageLabel"):
			entity.get_node("DamageLabel").visible = false
		
		# Calculate new position with new enemy count
		var new_angle = 0
		if new_enemy_count > 1:
			new_angle = (float(i) / (new_enemy_count - 1) - 0.5) * arc_span
		
		var new_pos_x = panel_center_x + arc_radius * sin(new_angle)
		var new_pos_y = arc_center_y - arc_radius * cos(new_angle)
		var new_pos = Vector2(new_pos_x, new_pos_y)
		
		# Slide existing enemy to new position
		enemy_repositioning_tween.tween_property(entity, "position", new_pos, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Duplicate StyleBoxes
	var present_stylebox = slot_2_tp.panel_node.get_theme_stylebox("panel").duplicate()
	slot_2_tp.panel_node.add_theme_stylebox_override("panel", present_stylebox)
	
	var future_stylebox = slot_3_tp.panel_node.get_theme_stylebox("panel").duplicate()
	slot_3_tp.panel_node.add_theme_stylebox_override("panel", future_stylebox)
	
	var decorative_past_stylebox = timeline_panels[0].panel_node.get_theme_stylebox("panel").duplicate()
	timeline_panels[0].panel_node.add_theme_stylebox_override("panel", decorative_past_stylebox)
	
	# Z-index
	timeline_panels[0].panel_node.z_index = 0
	timeline_panels[1].panel_node.z_index = 1
	slot_2_tp.panel_node.z_index = 2
	slot_3_tp.panel_node.z_index = 1
	slot_4_tp.panel_node.z_index = 0
	slot_5_tp.panel_node.z_index = -1
	
	# Animate carousel slide
	var carousel_tween = create_tween()
	carousel_tween.set_parallel(true)
	
	animate_slot_to_void(carousel_tween, timeline_panels[0].panel_node)
	animate_slot_to_snapshot(carousel_tween, timeline_panels[1].panel_node, carousel_snapshot[0])
	animate_slot_to_snapshot(carousel_tween, slot_2_tp.panel_node, carousel_snapshot[1])
	animate_slot_to_snapshot(carousel_tween, slot_3_tp.panel_node, carousel_snapshot[2])
	animate_slot_to_snapshot(carousel_tween, slot_4_tp.panel_node, carousel_snapshot[3])
	animate_slot_to_snapshot(carousel_tween, slot_5_tp.panel_node, carousel_snapshot[4])
	
	# Colors
	animate_panel_colors(carousel_tween, slot_2_tp.panel_node, "past")
	animate_panel_colors(carousel_tween, slot_3_tp.panel_node, "present")
	animate_panel_colors(carousel_tween, timeline_panels[0].panel_node, "future")
	
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


func animate_enemy_attacks() -> void:
	"""Animate all enemies attacking player sequentially"""
	var present_tp = timeline_panels[2]
	
	# Find player
	var player_entity = null
	for entity in present_tp.entities:
		if entity.is_player:
			player_entity = entity
			break
	
	if not player_entity:
		print("  Cannot animate - missing player")
		return
	
	# Get all enemies with data
	var enemy_list = []
	for i in range(present_tp.state["enemies"].size()):
		var enemy_data = present_tp.state["enemies"][i]
		for entity in present_tp.entities:
			if not entity.is_player and entity.entity_data["name"] == enemy_data["name"]:
				enemy_list.append({"node": entity, "data": enemy_data})
				break
	
	if enemy_list.size() == 0:
		return
	
	print("  Enemy attacks starting...")
	
	# Animate each enemy sequentially
	for enemy_info in enemy_list:
		await animate_single_enemy_attack(enemy_info["node"], player_entity, enemy_info["data"])
	
	print("  All enemy attacks complete!")


func animate_single_enemy_attack(enemy: Node2D, player: Node2D, enemy_data: Dictionary) -> void:
	"""Animate single enemy attacking player"""
	var present_tp = timeline_panels[2]
	
	var original_pos = enemy.position
	var target_pos = player.position
	var direction = (target_pos - original_pos).normalized()
	var attack_pos = target_pos - direction * 50.0
	
	# Dash to player
	var tween = create_tween()
	tween.tween_property(enemy, "position", attack_pos, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	
	# APPLY DAMAGE AT IMPACT
	var damage = enemy_data["damage"]
	present_tp.state["player"]["hp"] -= damage
	print("  ", enemy_data["name"], " dealt ", damage, " damage! Player HP: ", present_tp.state["player"]["hp"])
	
	# Play attack sound
	enemy.play_attack_sound()
	
	# Screen shake
	apply_screen_shake(damage * 0.5)
	
	# Hit reaction
	var hit_direction = (player.position - enemy.position).normalized()
	player.play_hit_reaction(hit_direction)
	
	# Update player visual
	player.entity_data = present_tp.state["player"]
	player.update_display()
	
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
	
	# Create arrows for Future (enemies → player)
	create_timeline_arrows(future_tp)
	
	# Make sure arrows are visible
	for tp in [present_tp, future_tp]:
		for arrow in tp.arrows:
			if arrow and is_instance_valid(arrow):
				arrow.visible = true
				arrow.show_arrow()
	
	print("  ✅ Arrows shown")

func animate_enemy_repositioning_after_death(tp: TimelinePanel):
	"""Animate remaining enemies repositioning after one dies"""
	var enemy_entities = []
	for entity in tp.entities:
		if not entity.is_player and is_instance_valid(entity) and entity.visible:
			enemy_entities.append(entity)
	
	var enemy_count = enemy_entities.size()
	if enemy_count == 0:
		return  # No repositioning needed for 0 or 1 enemy
	
	print("  ↔️ Repositioning ", enemy_count, " remaining enemies...")
	
	# Panel dimensions
	var center_x = 300.0
	var standard_height = 750.0
	var arc_center_x = center_x
	var arc_center_y = standard_height * 0.33
	var arc_radius = 120.0
	var arc_span = PI * 0.6
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Calculate and animate to new positions
	for i in range(enemy_count):
		var entity = enemy_entities[i]
		
		var angle_offset = 0
		if enemy_count > 1:
			angle_offset = (float(i) / (enemy_count - 1) - 0.5) * arc_span
		
		var new_pos_x = arc_center_x + arc_radius * sin(angle_offset)
		var new_pos_y = arc_center_y - arc_radius * cos(angle_offset)
		var new_pos = Vector2(new_pos_x, new_pos_y)
		
		tween.tween_property(entity, "position", new_pos, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	print("  ✅ Enemy repositioning complete")