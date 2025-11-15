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
