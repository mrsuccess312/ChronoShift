extends Panel

# ===== TIMELINE PANEL SCRIPT =====
# Self-contained panel with all its data and entities
# Refactored to use EntityData models instead of Dictionary states

const GRID_CELL_SCENE = preload("res://scenes/grid_cell.tscn")
const ARROW_SCENE = preload("res://scenes/arrow.tscn")

var timeline_type: String = "decorative"  # "past", "present", "future", "decorative"

# ===== ENTITY DATA MODEL (NEW) =====
# Entity data (the source of truth)
var entity_data_list: Array[EntityData] = []  # All entities in this timeline
# Grid structure (cells can contain entity references)
var cell_entities: Array = []  # 2D array [row][col] -> EntityData or null

# ===== BACKWARDS COMPATIBILITY =====
var state: Dictionary = {}  # Old Dictionary-based state (for compatibility)
var entities: Array = []  # Alias for entity_nodes (for compatibility)

# ===== VISUAL NODES =====
var entity_nodes: Array = []  # Entity visual nodes
var arrows: Array = []  # Arrow visual nodes

var slot_index: int = -1  # Current carousel slot position

# Grid system
var grid_cells: Array = []  # 2D array [row][col] of grid cell nodes
# Grid dimensions now come from GridConfig (configurable)

# Hover animation
var hover_enabled: bool = false
var time_offset: float = 0.0  # Random phase offset for this panel
var hover_amplitude: float = 6.0  # 8-10 pixels
var hover_period: float = 2.5  # 3-4 seconds
var base_position_y: float = 0.0  # Original Y position
var current_hover_offset: float = 0.0

@onready var grid_container: Control = $GridContainer

func _ready():
	"""Setup grid when panel is added to scene"""
	print("TimelinePanel _ready() called for ", timeline_type)

	# Dynamically resize panel based on GridConfig
	_resize_panel_components()

	# Store base position for hover animation
	base_position_y = position.y

	# Set random time offset for unique phase (0 to 2*PI)
	time_offset = randf() * TAU

	# Initialize cell_entities grid (dynamic size based on GridConfig)
	cell_entities = []
	for row in range(GridConfig.GRID_ROWS):
		var row_array = []
		for col in range(GridConfig.GRID_COLS):
			row_array.append(null)  # No entity in cell
		cell_entities.append(row_array)

	setup_grid()
	# Update hover colors after grid is set up
	update_cell_hover_colors()
	print("TimelinePanel _ready() complete - grid has ", grid_cells.size(), " rows")

func _resize_panel_components():
	"""Dynamically resize panel and child components based on GridConfig"""
	var panel_size = GridConfig.get_panel_size()
	var panel_width = panel_size.x
	var panel_height = panel_size.y

	# Resize the panel itself
	set_size(panel_size)
	size = panel_size
	custom_minimum_size = panel_size

	# Update pivot offset (center of panel for rotation/scaling)
	pivot_offset = Vector2(panel_width / 2, panel_height / 2)

	# Resize grid container
	if grid_container:
		grid_container.set_size(panel_size)
		grid_container.size = panel_size

	print("Panel resized to: ", panel_size, " (", GridConfig.GRID_COLS, "x", GridConfig.GRID_ROWS, " grid)")

func initialize(type: String, slot: int):
	"""Initialize the timeline panel with type and slot index"""
	timeline_type = type
	slot_index = slot
	update_cell_hover_colors()
	apply_timeline_visibility_rules()  # Apply visibility rules for this timeline type

func _process(delta: float):
	"""Handle hover animation each frame"""
	if not hover_enabled:
		return

	# Calculate sine wave for smooth oscillation
	var time = Time.get_ticks_msec() / 1000.0  # Convert to seconds
	var sine_value = sin((time / hover_period) * TAU + time_offset)
	current_hover_offset = sine_value * hover_amplitude

	# Apply vertical offset to panel
	position.y = base_position_y + current_hover_offset

func start_hover_animation():
	"""Enable hover animation for this panel"""
	hover_enabled = true
	base_position_y = position.y  # Update base position in case it changed
	print("  Hover animation started for ", timeline_type, " panel")

func stop_hover_animation():
	"""Disable hover animation and reset to base position"""
	hover_enabled = false
	position.y = base_position_y
	current_hover_offset = 0.0

	print("  Hover animation stopped for ", timeline_type, " panel")

func update_cell_hover_colors():
	"""Update hover colors for all cells based on current timeline type"""
	# Safety check: only update if grid is set up
	if grid_cells.is_empty():
		return

	var hover_color = get_timeline_hover_color()
	var cell_color = get_timeline_cell_color()
	for row in range(GridConfig.GRID_ROWS):
		for col in range(GridConfig.GRID_COLS):
			var cell = grid_cells[row][col]
			if cell:
				cell.set_hover_color(hover_color)
				cell.set_cell_color(cell_color)

# ===== TIMELINE VISIBILITY RULES =====

func set_timeline_type(new_type: String):
	"""Change timeline type and apply visibility rules"""
	if timeline_type != new_type:
		print("Timeline type changed: ", timeline_type, " → ", new_type)
		timeline_type = new_type

		# Update cell hover colors
		update_cell_hover_colors()

		# Apply visibility rules
		apply_timeline_visibility_rules()

func apply_timeline_visibility_rules():
	"""Apply visibility rules based on current timeline_type"""
	print("📋 Applying visibility rules for ", timeline_type, " timeline")

	match timeline_type:
		"past":
			_apply_past_visibility()
		"present":
			_apply_present_visibility()
		"future":
			_apply_future_visibility()
		"decorative":
			_apply_decorative_visibility()

func _apply_past_visibility():
	"""PAST: No arrows, HP visible, DMG on hover"""
	# Hide all arrows
	for arrow in arrows:
		if arrow and is_instance_valid(arrow):
			arrow.visible = false

	# Entity visibility
	for node in entity_nodes:
		if not node or not is_instance_valid(node):
			continue

		# HP always visible
		if node.has_node("HPLabel"):
			node.get_node("HPLabel").visible = true

		# Damage only on hover (handled by entity.gd hover system)
		if node.has_node("DamageLabel"):
			node.get_node("DamageLabel").visible = false

func _apply_present_visibility():
	"""PRESENT: Player arrows visible, HP visible, DMG visible"""
	# Show only player team arrows (is_enemy = false)
	# For now, show all arrows (will be refined with arrow source tracking)
	for arrow in arrows:
		if not arrow or not is_instance_valid(arrow):
			continue
		arrow.visible = true

	# Entity visibility
	for node in entity_nodes:
		if not node or not is_instance_valid(node):
			continue

		# HP always visible
		if node.has_node("HPLabel"):
			node.get_node("HPLabel").visible = true

		# Damage always visible
		if node.has_node("DamageLabel"):
			node.get_node("DamageLabel").visible = true

func _apply_future_visibility():
	"""FUTURE: Enemy arrows visible, HP visible, DMG on hover"""
	# Show only enemy team arrows (is_enemy = true)
	# For now, show all arrows (will be refined with arrow source tracking)
	for arrow in arrows:
		if not arrow or not is_instance_valid(arrow):
			continue
		arrow.visible = true

	# Entity visibility
	for node in entity_nodes:
		if not node or not is_instance_valid(node):
			continue

		# HP always visible
		if node.has_node("HPLabel"):
			node.get_node("HPLabel").visible = true

		# Damage only on hover
		if node.has_node("DamageLabel"):
			node.get_node("DamageLabel").visible = false

func _apply_decorative_visibility():
	"""DECORATIVE: Everything hidden/cleared"""
	# Hide all arrows
	for arrow in arrows:
		if arrow and is_instance_valid(arrow):
			arrow.visible = false

	# Hide all entity UI elements
	for node in entity_nodes:
		if not node or not is_instance_valid(node):
			continue

		if node.has_node("HPLabel"):
			node.get_node("HPLabel").visible = false

		if node.has_node("DamageLabel"):
			node.get_node("DamageLabel").visible = false

# ===== ENTITY DATA MANAGEMENT (NEW) =====

func add_entity(entity: EntityData, row: int, col: int) -> bool:
	"""Add entity to timeline at grid position"""
	if row < 0 or row >= GridConfig.GRID_ROWS or col < 0 or col >= GridConfig.GRID_COLS:
		print("Invalid grid position: (", row, ", ", col, ")")
		return false

	if cell_entities[row][col] != null:
		print("Cell (", row, ", ", col, ") already occupied!")
		return false

	# Set grid position in entity
	entity.grid_row = row
	entity.grid_col = col

	# Add to arrays
	entity_data_list.append(entity)
	cell_entities[row][col] = entity

	print("Added entity '", entity.entity_name, "' at (", row, ", ", col, ")")
	return true

func remove_entity(entity: EntityData):
	"""Remove entity from timeline"""
	if entity in entity_data_list:
		# Clear grid cell
		if entity.grid_row >= 0 and entity.grid_col >= 0:
			cell_entities[entity.grid_row][entity.grid_col] = null

		# Remove from entities list
		entity_data_list.erase(entity)
		print("Removed entity: ", entity.entity_name)

func get_entity_at(row: int, col: int) -> EntityData:
	"""Get entity at grid position (or null)"""
	if row < 0 or row >= GridConfig.GRID_ROWS or col < 0 or col >= GridConfig.GRID_COLS:
		return null
	return cell_entities[row][col]

func move_entity(entity: EntityData, new_row: int, new_col: int) -> bool:
	"""Move entity to new grid position"""
	if new_row < 0 or new_row >= GridConfig.GRID_ROWS or new_col < 0 or new_col >= GridConfig.GRID_COLS:
		return false

	if cell_entities[new_row][new_col] != null:
		return false  # Cell occupied

	# Clear old position
	if entity.grid_row >= 0 and entity.grid_col >= 0:
		cell_entities[entity.grid_row][entity.grid_col] = null

	# Set new position
	cell_entities[new_row][new_col] = entity
	entity.grid_row = new_row
	entity.grid_col = new_col

	return true

func get_player_entities() -> Array[EntityData]:
	"""Get all player/ally entities (is_enemy = false)"""
	var players: Array[EntityData] = []
	for entity in entity_data_list:
		if not entity.is_enemy:
			players.append(entity)
	return players

func get_enemy_entities() -> Array[EntityData]:
	"""Get all enemy entities (is_enemy = true)"""
	var enemies: Array[EntityData] = []
	for entity in entity_data_list:
		if entity.is_enemy:
			enemies.append(entity)
	return enemies

func clear_all_entities():
	"""Remove all entities from timeline (data model)"""
	entity_data_list.clear()
	for row in range(GridConfig.GRID_ROWS):
		for col in range(GridConfig.GRID_COLS):
			cell_entities[row][col] = null

# ===== VISUAL ENTITY NODES =====

func clear_entities():
	"""Remove all entity visual nodes from panel"""
	for entity in entity_nodes:
		if entity and is_instance_valid(entity):
			entity.queue_free()
	entity_nodes.clear()
	# No longer using backwards-compatible entities array

func clear_arrows():
	"""Remove all arrow nodes from panel"""
	for arrow in arrows:
		if arrow and is_instance_valid(arrow):
			arrow.queue_free()
	arrows.clear()

func clear_all():
	"""Clear both data models and visual nodes"""
	clear_all_entities()  # Clear data models
	clear_entities()  # Clear visual nodes
	clear_arrows()

# ===== ARROW CREATION (SIMPLIFIED) =====

func create_timeline_arrows():
	"""Create arrows based on entity attack_target_id properties"""
	print("🏹 Creating arrows for ", timeline_type, " timeline...")

	# Clear old arrows
	clear_arrows()

	if entity_data_list.is_empty():
		print("  No entities - no arrows")
		return

	# Determine which team's arrows to show
	var show_player_arrows = (timeline_type == "present")
	var show_enemy_arrows = (timeline_type == "future")

	if timeline_type == "past" or timeline_type == "decorative":
		print("  ", timeline_type, " - no arrows")
		return

	# Create arrow for each entity with a target
	for attacker in entity_data_list:
		# Skip if no target
		if attacker.attack_target_id == "":
			continue

		# Skip if will miss
		if attacker.will_miss:
			continue

		# Filter by team based on timeline type
		if show_player_arrows and attacker.is_enemy:
			continue  # PRESENT: only player arrows
		if show_enemy_arrows and not attacker.is_enemy:
			continue  # FUTURE: only enemy arrows

		# Find target entity
		var target = _find_entity_data_by_id(attacker.attack_target_id)
		if not target:
			print("  Warning: Entity '", attacker.entity_name, "' has invalid target ID: ", attacker.attack_target_id)
			continue

		# Find visual nodes
		var attacker_node = _find_entity_node_by_id(attacker.unique_id)
		var target_node = _find_entity_node_by_id(target.unique_id)

		if not attacker_node or not target_node:
			print("  Warning: Could not find visual nodes for arrow")
			continue

		# Create arrow
		var arrow = ARROW_SCENE.instantiate()
		arrow.z_index = 50
		arrow.z_as_relative = true
		add_child(arrow)

		var curve = _calculate_smart_curve(attacker_node.position, target_node.position)
		arrow.setup(attacker_node.position, target_node.position, curve, attacker.unique_id, target.unique_id)

		arrows.append(arrow)

		var team = "PLAYER" if not attacker.is_enemy else "ENEMY"
		print("  [", team, "] ", attacker.entity_name, " → ", target.entity_name)

	print("  Created ", arrows.size(), " arrows")

func _find_entity_data_by_id(unique_id: String) -> EntityData:
	"""Find EntityData by unique_id"""
	for entity in entity_data_list:
		if entity.unique_id == unique_id:
			return entity
	return null

func _find_entity_node_by_id(unique_id: String) -> Node2D:
	"""Find visual entity node by unique_id"""
	for node in entity_nodes:
		if not node or not is_instance_valid(node):
			continue

		# Check if node has entity_data with matching unique_id
		if node.has("entity_data"):
			var entity_dict = node.get("entity_data")
			if entity_dict.get("unique_id") == unique_id:
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

# ===== BACKWARDS COMPATIBILITY - REMOVED =====
# These functions have been removed as EntityData is now the sole source of truth.
# The refactored architecture no longer uses state dictionaries.
#
# Previously:
# - get_state_dict() -> Dictionary
# - load_from_state_dict(state: Dictionary)
#
# Now: Use entity_data_list (Array[EntityData]) directly

# ===== GRID SYSTEM =====

func setup_grid():
	"""Create grid of cells (size from GridConfig)"""
	print("DEBUG setup_grid: Starting for ", timeline_type, " - Grid size: ", GridConfig.GRID_COLS, "x", GridConfig.GRID_ROWS)
	print("DEBUG setup_grid: grid_container = ", grid_container)

	if not grid_container:
		print("DEBUG setup_grid: grid_container is null! Aborting.")
		return

	# Initialize 2D array for grid cells
	grid_cells = []
	for row in range(GridConfig.GRID_ROWS):
		var row_array = []
		for col in range(GridConfig.GRID_COLS):
			row_array.append(null)
		grid_cells.append(row_array)

	print("DEBUG setup_grid: Creating ", GridConfig.GRID_ROWS * GridConfig.GRID_COLS, " cells...")

	# Create grid cells
	for row in range(GridConfig.GRID_ROWS):
		for col in range(GridConfig.GRID_COLS):
			var cell = GRID_CELL_SCENE.instantiate()
			cell.initialize(row, col)

			# Connect cell signals
			cell.cell_clicked.connect(_on_cell_clicked)
			cell.cell_hovered.connect(_on_cell_hovered)
			cell.cell_exited.connect(_on_cell_exited)

			# Position cell (dynamic size based on GridConfig)
			cell.position = GridConfig.get_cell_position(row, col)

			# Set timeline-appropriate colors
			cell.set_hover_color(get_timeline_hover_color())
			cell.set_cell_color(get_timeline_cell_color())

			grid_container.add_child(cell)
			grid_cells[row][col] = cell

	print("DEBUG setup_grid: Created all cells. Total children in grid_container: ", grid_container.get_child_count())

func get_timeline_hover_color() -> Color:
	"""Get hover color based on timeline type"""
	match timeline_type:
		"past":
			return Color(0.54509807, 0.43529412, 0.2784314, 0.3)  # Brown
		"present":
			return Color(0.2901961, 0.61960787, 1, 0.3)  # Blue
		"future":
			return Color(0.7058824, 0.47843137, 1, 0.3)  # Purple
		_:
			return Color(1, 1, 1, 0.3)  # White default

func get_timeline_cell_color() -> Color:
	"""Get cell background color based on timeline type"""
	match timeline_type:
		"past":
			return Color(0.58, 0.46, 0.34, 1)  # Darker tan for cells
		"present":
			return Color(0.48, 0.62, 0.8, 1)  # Darker blue for cells
		"future":
			return Color(0.58, 0.48, 0.72, 1)  # Darker purple for cells
		"decorative":
			return Color(0.1, 0.12, 0.15, 1)  # Dark gray/black for cells
		_:
			return Color(0, 0, 0, 0.15)  # Default gray

func get_cell_at_position(row: int, col: int):
	"""Get grid cell at specific row/col coordinates"""
	if row < 0 or row >= GridConfig.GRID_ROWS or col < 0 or col >= GridConfig.GRID_COLS:
		return null
	return grid_cells[row][col]

func highlight_cell(row: int, col: int, color: Color = Color(1, 1, 1, 0.3)):
	"""Highlight a specific grid cell"""
	var cell = get_cell_at_position(row, col)
	if cell:
		cell.show_highlight(color)

func clear_all_highlights():
	"""Clear all grid cell highlights"""
	for row in range(GridConfig.GRID_ROWS):
		for col in range(GridConfig.GRID_COLS):
			var cell = grid_cells[row][col]
			if cell:
				cell.hide_highlight()

func show_grid_lines(visible: bool):
	"""Toggle grid lines visibility for all cells"""
	for row in range(GridConfig.GRID_ROWS):
		for col in range(GridConfig.GRID_COLS):
			var cell = grid_cells[row][col]
			if cell:
				cell.show_grid_lines(visible)

func show_debug_info(visible: bool):
	"""Toggle debug coordinate labels for all cells"""
	for row in range(GridConfig.GRID_ROWS):
		for col in range(GridConfig.GRID_COLS):
			var cell = grid_cells[row][col]
			if cell:
				cell.show_debug_info(visible)

func place_entity_at_cell(entity: Node2D, row: int, col: int):
	"""Place an entity at the center of a specific grid cell"""
	if row < 0 or row >= GridConfig.GRID_ROWS or col < 0 or col >= GridConfig.GRID_COLS:
		print("Warning: Invalid cell position (", row, ", ", col, ")")
		return

	# Calculate cell center position (dynamic based on GridConfig)
	var cell_center = GridConfig.get_cell_center_position(row, col)

	entity.position = cell_center
	print("Placed entity at cell (", row, ", ", col, ") -> position ", cell_center)

func get_cell_from_entity_position(entity: Node2D) -> Vector2i:
	"""Get the grid cell coordinates from an entity's position"""
	var cell_size = GridConfig.get_cell_size()

	var col = int(entity.position.x / cell_size.x)
	var row = int(entity.position.y / cell_size.y)

	# Clamp to valid range
	col = clamp(col, 0, GridConfig.GRID_COLS - 1)
	row = clamp(row, 0, GridConfig.GRID_ROWS - 1)

	return Vector2i(col, row)

# Grid signal handlers
func _on_cell_clicked(row: int, col: int):
	"""Handle cell click"""
	print("Cell clicked: (", row, ", ", col, ") in ", timeline_type, " panel")

func _on_cell_hovered(row: int, col: int):
	"""Handle cell hover"""
	pass  # Can be used for hover effects

func _on_cell_exited(row: int, col: int):
	"""Handle cell hover exit"""
	pass  # Can be used to clear hover effects

func set_grid_interactive(enabled: bool):
	"""Enable or disable grid cell interactivity"""
	for row in range(GridConfig.GRID_ROWS):
		for col in range(GridConfig.GRID_COLS):
			var cell = grid_cells[row][col]
			if cell:
				cell.input_pickable = enabled
				cell.monitoring = enabled
	print("  Grid interactive for ", timeline_type, " panel: ", enabled)

# ===== GRID-BASED ENTITY POSITIONING =====

func get_grid_position_for_entity(entity_index: int, is_player: bool, total_enemies: int) -> Vector2i:
	"""Get grid coordinates (row, col) for entity based on positioning rules
	Grid coordinates: (0,0) is bottom-left, (4,4) is top-right
	Returns Vector2i(row, col)
	"""
	if is_player:
		# Player always at cell (2, 1) - center bottom area
		return Vector2i(3, 2)  # row=1, col=2

	# Enemy positioning based on count
	match total_enemies:
		1:
			# 1 enemy: cell (2, 3)
			return Vector2i(1, 2)
		2:
			# 2 enemies: cells (1, 3) and (3, 3)
			if entity_index == 0:
				return Vector2i(1, 1)
			else:
				return Vector2i(1, 3)
		3:
			# 3 enemies: cells (1, 3), (2, 4), and (3, 3)
			if entity_index == 0:
				return Vector2i(1, 1)
			elif entity_index == 1:
				return Vector2i(0, 2)
			else:
				return Vector2i(1, 3)
		4:
			# 4 enemies: cells (1, 3), (2, 4), (3, 3), and (2, 3)
			if entity_index == 0:
				return Vector2i(1, 1)
			elif entity_index == 1:
				return Vector2i(0, 2)
			elif entity_index == 2:
				return Vector2i(1, 3)
			else:
				return Vector2i(1, 2)
		5:
			# 5 enemies: cells (0, 3), (1, 4), (2, 3), (3, 4), and (4, 3)
			if entity_index == 0:
				return Vector2i(1, 0)
			elif entity_index == 1:
				return Vector2i(0, 1)
			elif entity_index == 2:
				return Vector2i(1, 2)
			elif entity_index == 3:
				return Vector2i(0, 3)
			else:
				return Vector2i(1, 4)
		_:
			# Fallback for 6+ enemies - distribute across row 3 and 4
			if entity_index < 3:
				return Vector2i(3, entity_index + 1)
			else:
				return Vector2i(4, entity_index - 2)

	# Fallback default
	return Vector2i(2, 2)

func get_cell_center_position(row: int, col: int) -> Vector2:
	"""Get the pixel position of a cell's center"""
	return GridConfig.get_cell_center_position(row, col)

func is_cell_occupied(row: int, col: int) -> bool:
	"""Check if a cell is occupied by an entity (using new data model)"""
	return get_entity_at(row, col) != null

func get_leftmost_enemy() -> EntityData:
	"""Get the leftmost enemy entity (lowest col, then lowest row if tied)
	Used for targeting mechanics - NOW RETURNS EntityData"""
	var leftmost: EntityData = null
	var leftmost_pos = Vector2i(999, 999)

	for entity in entity_data_list:
		if entity.is_enemy and entity.is_alive():
			var entity_pos = Vector2i(entity.grid_row, entity.grid_col)
			# Check if this is more to the left (lower col), or same col but lower row
			if entity_pos.y < leftmost_pos.y or (entity_pos.y == leftmost_pos.y and entity_pos.x < leftmost_pos.x):
				leftmost = entity
				leftmost_pos = entity_pos

	return leftmost

# ===== HAZARD SYSTEM =====

# Hazard data per cell: { "row,col": { "type": "fire", "damage": 5, ... } }
var cell_hazards: Dictionary = {}

func mark_cell_as_hazard(row: int, col: int, hazard_type: String, hazard_data: Dictionary = {}):
	"""Mark a cell as containing a hazard
	hazard_type: "fire", "poison", "ice", "spike", etc.
	hazard_data: Additional data like damage, duration, etc.
	"""
	var key = str(row) + "," + str(col)
	cell_hazards[key] = {
		"type": hazard_type,
		"data": hazard_data,
		"row": row,
		"col": col
	}

	# Visual indicator
	var cell = get_cell_at_position(row, col)
	if cell:
		var hazard_color = get_hazard_color(hazard_type)
		cell.show_highlight(hazard_color)

	print("Marked cell (", row, ", ", col, ") as ", hazard_type, " hazard")

func clear_hazard(row: int, col: int):
	"""Remove hazard from a cell"""
	var key = str(row) + "," + str(col)
	if cell_hazards.has(key):
		cell_hazards.erase(key)
		var cell = get_cell_at_position(row, col)
		if cell:
			cell.hide_highlight()

func get_hazard_at_cell(row: int, col: int) -> Dictionary:
	"""Get hazard data at a specific cell, or empty dict if none"""
	var key = str(row) + "," + str(col)
	if cell_hazards.has(key):
		return cell_hazards[key]
	return {}

func get_hazard_color(hazard_type: String) -> Color:
	"""Get visual color for hazard type"""
	match hazard_type:
		"fire":
			return Color(1, 0.3, 0, 0.4)  # Orange-red
		"poison":
			return Color(0.3, 1, 0.3, 0.4)  # Green
		"ice":
			return Color(0.3, 0.7, 1, 0.4)  # Light blue
		"spike":
			return Color(0.7, 0.7, 0.7, 0.4)  # Gray
		_:
			return Color(1, 0, 0, 0.4)  # Red default

# ===== CARD TARGETING =====

func get_valid_target_cells(card_type: String) -> Array:
	"""Get array of valid target cells for a card type
	Returns array of Vector2i(row, col)
	"""
	var valid_cells = []

	match card_type:
		"melee_attack":
			# Adjacent to player only
			var player_entities = get_player_entities()
			if player_entities.size() > 0:
				var player = player_entities[0]
				var player_cell = Vector2i(player.grid_row, player.grid_col)

				# Check all 8 surrounding cells
				for dr in [-1, 0, 1]:
					for dc in [-1, 0, 1]:
						if dr == 0 and dc == 0:
							continue
						var target_row = player_cell.x + dr
						var target_col = player_cell.y + dc
						if target_row >= 0 and target_row < GridConfig.GRID_ROWS and target_col >= 0 and target_col < GridConfig.GRID_COLS:
							valid_cells.append(Vector2i(target_row, target_col))

		"ranged_attack":
			# Any cell with an enemy
			for entity in entity_data_list:
				if entity.is_enemy and entity.is_alive():
					valid_cells.append(Vector2i(entity.grid_row, entity.grid_col))

		"area_attack":
			# All cells
			for row in range(GridConfig.GRID_ROWS):
				for col in range(GridConfig.GRID_COLS):
					valid_cells.append(Vector2i(row, col))

		"placement":
			# Empty cells only
			for row in range(GridConfig.GRID_ROWS):
				for col in range(GridConfig.GRID_COLS):
					if not is_cell_occupied(row, col):
						valid_cells.append(Vector2i(row, col))

		_:
			# Default: all cells
			for row in range(GridConfig.GRID_ROWS):
				for col in range(GridConfig.GRID_COLS):
					valid_cells.append(Vector2i(row, col))

	return valid_cells

func highlight_valid_targets(card_type: String):
	"""Highlight all valid target cells for a card"""
	clear_all_highlights()
	var valid_cells = get_valid_target_cells(card_type)
	for cell_coord in valid_cells:
		highlight_cell(cell_coord.x, cell_coord.y, Color(0, 1, 0, 0.3))  # Green highlight

# =============================================================================
# INTEGRATION DOCUMENTATION
# =============================================================================
#
# This timeline_panel script now uses EntityData models for clean state management.
#
# NEW ENTITY DATA MODEL:
# - entity_data_list: Array[EntityData] - Source of truth for all entities
# - cell_entities: Array[Array] - 2D grid [row][col] -> EntityData or null
# - entity_nodes: Array - Visual Node2D representations (display only)
#
# ENTITY MANAGEMENT (NEW):
# - add_entity(entity, row, col) -> bool - Add entity to timeline
# - remove_entity(entity) - Remove entity from timeline
# - get_entity_at(row, col) -> EntityData - Get entity at position
# - move_entity(entity, new_row, new_col) -> bool - Move entity
# - get_player_entities() -> Array[EntityData] - Get all players
# - get_enemy_entities() -> Array[EntityData] - Get all enemies
# - clear_all_entities() - Remove all entity data
#
# BACKWARDS COMPATIBILITY (TEMPORARY):
# - get_state_dict() -> Dictionary - Convert EntityData to old format
# - load_from_state_dict(state) - Load from old Dictionary format
#
# ENTITY POSITIONING (game_manager.gd):
# - Use get_grid_position_for_entity(index, is_player, total_enemies) for layout
# - Use get_cell_center_position(row, col) to convert grid coords to world pos
# - Player is always at (3, 2), enemies positioned based on count
# - get_leftmost_enemy() returns EntityData (not Node2D)
#
# HAZARD SYSTEM (future card effects):
# - mark_cell_as_hazard(row, col, type, data) to create hazards
# - get_hazard_at_cell(row, col) to check for hazards
# - clear_hazard(row, col) to remove hazards
# - Hazards auto-display with type-specific colors
#
# CARD TARGETING:
# - get_valid_target_cells(card_type) returns array of valid cells
# - highlight_valid_targets(card_type) shows green highlights
# - is_cell_occupied(row, col) now uses EntityData model
# - Supports: "melee_attack", "ranged_attack", "area_attack", "placement"
#
# SETTINGS (game_manager.gd):
# - show_grid_lines(bool) - toggle grid cell borders
# - show_debug_info(bool) - toggle (row,col) labels
# - start_hover_animation() / stop_hover_animation() - floating effect
# - set_grid_interactive(bool) - enable/disable cell mouse input
#
# Z-INDEX LAYERING:
# - Grid cells: z=0 (base layer)
# - Arrows: z=50 (above grid, below entities)
# - Entities: z=100 (top layer)
# - All z_as_relative=true within panel
#
# =============================================================================
