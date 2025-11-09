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


# ===== CAROUSEL ANIMATION =====

func carousel_slide_animation():
	"""Execute elegant 7-panel carousel slide"""
	print("\n🎠 Starting 7-panel carousel slide...")
	print("  Panel array size: ", timeline_panels.size())
	
	# Verify all panels exist
	for i in range(timeline_panels.size()):
		var tp = timeline_panels[i]
		if tp.panel_node == null:
			print("  ⚠️ WARNING: Panel ", i, " is NULL!")
		else:
			print("  ✓ Panel ", i, " exists (", tp.timeline_type, ")")
	
	# STEP 1: Snapshots
	var present_tp = get_timeline_panel("present")
	var snapshot_present_state = present_tp.state.duplicate(true)
	
	# STEP 2: Hide UI and delete arrows
	hide_ui_for_carousel()
	delete_all_arrows()
	
	# STEP 3: Get panels BY SLOT INDEX (safer than by timeline_type)
	# After rotations, timeline_type might not match slot position!
	var slot_2_tp = timeline_panels[2]  # Present
	var slot_3_tp = timeline_panels[3]  # Future
	var slot_4_tp = timeline_panels[4]  # Decorative Future
	var slot_5_tp = timeline_panels[5]  # Intermediate
	
	# Update Future entities to match Present formation
	if slot_3_tp.state.get("enemies", []).size() < slot_2_tp.state.get("enemies", []).size():
		slot_3_tp.state["enemies"] = snapshot_present_state["enemies"].duplicate(true)
		create_timeline_entities(slot_3_tp)
	
	# STEP 4: Prepare new Future in slot 4 (Decorative Future position)
	var new_future_state = calculate_future_from_state(snapshot_present_state)
	slot_4_tp.timeline_type = "future"
	slot_4_tp.state = new_future_state
	create_timeline_entities(slot_4_tp)
	
	# STEP 5: Prepare Intermediate (slot 5)
	var future_plus_one_state = calculate_future_from_state(new_future_state)
	slot_5_tp.timeline_type = "decorative"
	slot_5_tp.state = future_plus_one_state
	create_timeline_entities(slot_5_tp)
	print("✅ Intermediate panel prepared")
	
	# STEP 6: Duplicate StyleBoxes (use slot indices!)
	var present_stylebox = slot_2_tp.panel_node.get_theme_stylebox("panel").duplicate()
	slot_2_tp.panel_node.add_theme_stylebox_override("panel", present_stylebox)
	
	var future_stylebox = slot_3_tp.panel_node.get_theme_stylebox("panel").duplicate()
	slot_3_tp.panel_node.add_theme_stylebox_override("panel", future_stylebox)
	
	# STEP 7: Z-index management - ADD NULL CHECKS
	if timeline_panels[0].panel_node != null:
		timeline_panels[0].panel_node.z_index = 0   # Decorative Past
	
	if timeline_panels[1].panel_node != null:
		timeline_panels[1].panel_node.z_index = 1   # Past
	
	if slot_2_tp.panel_node != null:
		slot_2_tp.panel_node.z_index = 2            # Present
	
	if slot_3_tp.panel_node != null:
		slot_3_tp.panel_node.z_index = 1            # Future
	
	if slot_4_tp.panel_node != null:
		slot_4_tp.panel_node.z_index = 0            # Decorative Future
	
	if slot_5_tp.panel_node != null:
		slot_5_tp.panel_node.z_index = -1           # Intermediate
	else:
		print("  ⚠️ ERROR: slot_5_tp.panel_node is NULL at line 512!")
	
	# STEP 8: Animate ALL 6 panels
	var tween = create_tween()
	tween.set_parallel(true)
	
	animate_slot_to_void(tween, timeline_panels[0].panel_node)
	animate_slot_to_snapshot(tween, timeline_panels[1].panel_node, carousel_snapshot[0])
	animate_slot_to_snapshot(tween, slot_2_tp.panel_node, carousel_snapshot[1])
	animate_slot_to_snapshot(tween, slot_3_tp.panel_node, carousel_snapshot[2])
	animate_slot_to_snapshot(tween, slot_4_tp.panel_node, carousel_snapshot[3])
	animate_slot_to_snapshot(tween, slot_5_tp.panel_node, carousel_snapshot[4])
	
	# Color animations (on the panels that are changing timeline_type)
	animate_panel_colors(tween, slot_2_tp.panel_node, "past")     # Present → Past
	animate_panel_colors(tween, slot_3_tp.panel_node, "present")  # Future → Present
	animate_panel_colors(tween, timeline_panels[0].panel_node, "future")

	await tween.finished
	print("✅ Panel animations complete!")
	
	# STEP 9: Rotate panels
	rotate_timeline_panels_7()
	
	# STEP 10: Update states
	update_after_carousel_slide(snapshot_present_state)
	
	# STEP 11: Recreate displays
	update_all_timeline_displays()
	
	# STEP 12: Update labels
	update_panel_labels()
	
	print("✅ Carousel slide complete!")

func update_after_carousel_slide(snapshot_present_state: Dictionary):
	"""Update timeline types and states after carousel slide"""
	print("🔄 Updating timeline types and states...")
	
	# After rotation:
	# - timeline_panels[0] (was slot 1) → Decorative Past
	# - timeline_panels[1] (was slot 2) → Past
	# - timeline_panels[2] (was slot 3) → Present
	# - timeline_panels[3] (was slot 4) → Future
	# - timeline_panels[4] (was slot 5) → Decorative Future ✨
	# - timeline_panels[5] (new null) → void placeholder
	
	# Update timeline types
	timeline_panels[0].timeline_type = "decorative"
	timeline_panels[1].timeline_type = "past"
	timeline_panels[2].timeline_type = "present"
	timeline_panels[3].timeline_type = "future"
	timeline_panels[4].timeline_type = "decorative"  # This is now Decorative Future!
	
	# Update states
	timeline_panels[1].state = snapshot_present_state.duplicate(true)
	timeline_panels[2].state = snapshot_present_state.duplicate(true)
	# timeline_panels[3] and [4] already have correct states
	
	# Update timeline_type on entities
	for i in range(5):  # Only first 5 panels (skip void placeholder)
		var tp = timeline_panels[i]
		for entity in tp.entities:
			if entity and is_instance_valid(entity):
				# Set timeline_type based on panel's timeline_type
				match tp.timeline_type:
					"decorative":
						entity.timeline_type = "future"  # Decorative panels show future-style
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
	print("PLAY button pressed!")
	carousel_slide_animation()

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
