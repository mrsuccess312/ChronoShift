extends Panel

# ===== TIMELINE PANEL SCRIPT =====
# Self-contained panel with all its data and entities
# Refactored from game_manager.gd TimelinePanel class

const GRID_CELL_SCENE = preload("res://scenes/grid_cell.tscn")

var timeline_type: String = "decorative"  # "past", "present", "future", "decorative"
var state: Dictionary = {}  # Game state: { player: {...}, enemies: [...] }
var entities: Array = []  # Entity visual nodes
var arrows: Array = []  # Arrow visual nodes
var slot_index: int = -1  # Current carousel slot position

# Grid system
var grid_cells: Array = []  # 2D array [row][col] of grid cell nodes
const GRID_ROWS: int = 5
const GRID_COLS: int = 5

# Hover animation
var hover_enabled: bool = false
var time_offset: float = 0.0  # Random phase offset for this panel
var hover_amplitude: float = 6.0  # 8-10 pixels
var hover_period: float = 2.5  # 3-4 seconds
var base_position_y: float = 0.0  # Original Y position
var current_hover_offset: float = 0.0

@onready var grid_container: Control = $GridContainer
@onready var shadow: ColorRect = $Shadow

func _ready():
	"""Setup grid when panel is added to scene"""
	print("TimelinePanel _ready() called for ", timeline_type)

	# Store base position for hover animation
	base_position_y = position.y

	# Set random time offset for unique phase (0 to 2*PI)
	time_offset = randf() * TAU

	setup_grid()
	# Update hover colors after grid is set up
	update_cell_hover_colors()
	print("TimelinePanel _ready() complete - grid has ", grid_cells.size(), " rows")

func initialize(type: String, slot: int):
	"""Initialize the timeline panel with type and slot index"""
	timeline_type = type
	slot_index = slot
	update_cell_hover_colors()

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

	# Update shadow position (moves opposite to panel)
	if shadow:
		# Shadow moves down when panel moves up, and vice versa
		shadow.position.y = 10.0 - current_hover_offset

		# Shadow opacity increases when panel is higher (looks more elevated)
		# Map hover offset (-amplitude to +amplitude) to opacity (0.2 to 0.4)
		var normalized_height = (current_hover_offset + hover_amplitude) / (hover_amplitude * 2.0)
		var shadow_opacity = lerp(0.2, 0.4, normalized_height)
		shadow.modulate.a = shadow_opacity

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

	# Reset shadow to default
	if shadow:
		shadow.position.y = 10.0
		shadow.modulate.a = 0.3

	print("  Hover animation stopped for ", timeline_type, " panel")

func update_cell_hover_colors():
	"""Update hover colors for all cells based on current timeline type"""
	# Safety check: only update if grid is set up
	if grid_cells.is_empty():
		return

	var hover_color = get_timeline_hover_color()
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var cell = grid_cells[row][col]
			if cell:
				cell.set_hover_color(hover_color)

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

# ===== GRID SYSTEM =====

func setup_grid():
	"""Create 5x5 grid of cells"""
	print("DEBUG setup_grid: Starting for ", timeline_type)
	print("DEBUG setup_grid: grid_container = ", grid_container)

	if not grid_container:
		print("DEBUG setup_grid: grid_container is null! Aborting.")
		return

	# Initialize 2D array for grid cells
	grid_cells = []
	for row in range(GRID_ROWS):
		var row_array = []
		for col in range(GRID_COLS):
			row_array.append(null)
		grid_cells.append(row_array)

	print("DEBUG setup_grid: Creating ", GRID_ROWS * GRID_COLS, " cells...")

	# Create grid cells
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var cell = GRID_CELL_SCENE.instantiate()
			cell.initialize(row, col)

			# Connect cell signals
			cell.cell_clicked.connect(_on_cell_clicked)
			cell.cell_hovered.connect(_on_cell_hovered)
			cell.cell_exited.connect(_on_cell_exited)

			# Position cell (120px wide, 150px tall per cell)
			cell.position = Vector2(col * 120, row * 150)

			# Set timeline-appropriate hover color
			cell.set_hover_color(get_timeline_hover_color())

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

func get_cell_at_position(row: int, col: int):
	"""Get grid cell at specific row/col coordinates"""
	if row < 0 or row >= GRID_ROWS or col < 0 or col >= GRID_COLS:
		return null
	return grid_cells[row][col]

func highlight_cell(row: int, col: int, color: Color = Color(1, 1, 1, 0.3)):
	"""Highlight a specific grid cell"""
	var cell = get_cell_at_position(row, col)
	if cell:
		cell.show_highlight(color)

func clear_all_highlights():
	"""Clear all grid cell highlights"""
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var cell = grid_cells[row][col]
			if cell:
				cell.hide_highlight()

func show_grid_lines(visible: bool):
	"""Toggle grid lines visibility for all cells"""
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var cell = grid_cells[row][col]
			if cell:
				cell.show_grid_lines(visible)

func show_debug_info(visible: bool):
	"""Toggle debug coordinate labels for all cells"""
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var cell = grid_cells[row][col]
			if cell:
				cell.show_debug_info(visible)

func place_entity_at_cell(entity: Node2D, row: int, col: int):
	"""Place an entity at the center of a specific grid cell"""
	if row < 0 or row >= GRID_ROWS or col < 0 or col >= GRID_COLS:
		print("Warning: Invalid cell position (", row, ", ", col, ")")
		return

	# Calculate cell center position
	# Grid now covers full panel (600x750)
	# Each cell is 120x150 px
	var cell_size = Vector2(120, 150)
	var cell_center = Vector2(col * cell_size.x + cell_size.x / 2, row * cell_size.y + cell_size.y / 2)

	entity.position = cell_center
	print("Placed entity at cell (", row, ", ", col, ") -> position ", cell_center)

func get_cell_from_entity_position(entity: Node2D) -> Vector2i:
	"""Get the grid cell coordinates from an entity's position"""
	var cell_size = Vector2(120, 150)

	var col = int(entity.position.x / cell_size.x)
	var row = int(entity.position.y / cell_size.y)

	# Clamp to valid range
	col = clamp(col, 0, GRID_COLS - 1)
	row = clamp(row, 0, GRID_ROWS - 1)

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
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
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
		return Vector2i(1, 2)  # row=1, col=2

	# Enemy positioning based on count
	match total_enemies:
		1:
			# 1 enemy: cell (2, 3)
			return Vector2i(3, 2)
		2:
			# 2 enemies: cells (1, 3) and (3, 3)
			if entity_index == 0:
				return Vector2i(3, 1)
			else:
				return Vector2i(3, 3)
		3:
			# 3 enemies: cells (1, 3), (2, 4), and (3, 3)
			if entity_index == 0:
				return Vector2i(3, 1)
			elif entity_index == 1:
				return Vector2i(4, 2)
			else:
				return Vector2i(3, 3)
		4:
			# 4 enemies: cells (1, 3), (2, 4), (3, 3), and (2, 3)
			if entity_index == 0:
				return Vector2i(3, 1)
			elif entity_index == 1:
				return Vector2i(4, 2)
			elif entity_index == 2:
				return Vector2i(3, 3)
			else:
				return Vector2i(3, 2)
		5:
			# 5 enemies: cells (0, 3), (1, 4), (2, 3), (3, 4), and (4, 3)
			if entity_index == 0:
				return Vector2i(3, 0)
			elif entity_index == 1:
				return Vector2i(4, 1)
			elif entity_index == 2:
				return Vector2i(3, 2)
			elif entity_index == 3:
				return Vector2i(4, 3)
			else:
				return Vector2i(3, 4)
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
	var cell_size = Vector2(120, 150)
	return Vector2(col * cell_size.x + cell_size.x / 2, row * cell_size.y + cell_size.y / 2)

func is_cell_occupied(row: int, col: int) -> bool:
	"""Check if a cell is occupied by an entity"""
	for entity in entities:
		if not is_instance_valid(entity):
			continue
		var entity_cell = get_cell_from_entity_position(entity)
		if entity_cell.x == row and entity_cell.y == col:
			return true
	return false

func get_leftmost_enemy() -> Node2D:
	"""Get the leftmost enemy entity (lowest x-coordinate, then lowest y if tied)
	Used for targeting mechanics"""
	var leftmost = null
	var leftmost_cell = Vector2i(999, 999)

	for entity in entities:
		if not is_instance_valid(entity):
			continue
		if entity.is_player:
			continue

		var entity_cell = get_cell_from_entity_position(entity)
		# Check if this is more to the left (lower col), or same col but lower row
		if entity_cell.y < leftmost_cell.y or (entity_cell.y == leftmost_cell.y and entity_cell.x < leftmost_cell.x):
			leftmost = entity
			leftmost_cell = entity_cell

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
			var player_cell = Vector2i(-1, -1)
			for entity in entities:
				if is_instance_valid(entity) and entity.is_player:
					player_cell = get_cell_from_entity_position(entity)
					break

			if player_cell.x >= 0:
				# Check all 8 surrounding cells
				for dr in [-1, 0, 1]:
					for dc in [-1, 0, 1]:
						if dr == 0 and dc == 0:
							continue
						var target_row = player_cell.x + dr
						var target_col = player_cell.y + dc
						if target_row >= 0 and target_row < GRID_ROWS and target_col >= 0 and target_col < GRID_COLS:
							valid_cells.append(Vector2i(target_row, target_col))

		"ranged_attack":
			# Any cell with an enemy
			for entity in entities:
				if is_instance_valid(entity) and not entity.is_player:
					valid_cells.append(get_cell_from_entity_position(entity))

		"area_attack":
			# All cells
			for row in range(GRID_ROWS):
				for col in range(GRID_COLS):
					valid_cells.append(Vector2i(row, col))

		"placement":
			# Empty cells only
			for row in range(GRID_ROWS):
				for col in range(GRID_COLS):
					if not is_cell_occupied(row, col):
						valid_cells.append(Vector2i(row, col))

		_:
			# Default: all cells
			for row in range(GRID_ROWS):
				for col in range(GRID_COLS):
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
# This timeline_panel script provides a complete grid-based positioning system
# for entities, hazards, and card targeting. Key integration points:
#
# ENTITY POSITIONING (game_manager.gd):
# - Use get_grid_position_for_entity(index, is_player, total_enemies) for layout
# - Use get_cell_center_position(row, col) to convert grid coords to world pos
# - Player is always at (2, 1), enemies positioned based on count (see function)
# - get_leftmost_enemy() returns the primary target for player attacks
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
# - is_cell_occupied(row, col) checks for entity presence
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