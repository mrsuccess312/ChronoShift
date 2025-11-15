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

@onready var grid_container: Control = $GridContainer

func _ready():
	"""Setup grid when panel is added to scene"""
	setup_grid()
	# Update hover colors after grid is set up
	update_cell_hover_colors()

func initialize(type: String, slot: int):
	"""Initialize the timeline panel with type and slot index"""
	timeline_type = type
	slot_index = slot
	update_cell_hover_colors()

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
	if not grid_container:
		return

	# Initialize 2D array for grid cells
	grid_cells = []
	for row in range(GRID_ROWS):
		var row_array = []
		for col in range(GRID_COLS):
			row_array.append(null)
		grid_cells.append(row_array)

	# Create grid cells
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var cell = GRID_CELL_SCENE.instantiate()
			cell.initialize(row, col)

			# Connect cell signals
			cell.cell_clicked.connect(_on_cell_clicked)
			cell.cell_hovered.connect(_on_cell_hovered)
			cell.cell_exited.connect(_on_cell_exited)

			# Position cell (100px wide, 126px tall per cell)
			cell.position = Vector2(col * 100, row * 126)

			# Set timeline-appropriate hover color
			cell.set_hover_color(get_timeline_hover_color())

			grid_container.add_child(cell)
			grid_cells[row][col] = cell

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
	# Grid starts at (50, 60) in panel coordinates
	# Each cell is 100x126 px
	var grid_offset = Vector2(50, 60)
	var cell_size = Vector2(100, 126)
	var cell_center = grid_offset + Vector2(col * cell_size.x + cell_size.x / 2, row * cell_size.y + cell_size.y / 2)

	entity.position = cell_center
	print("Placed entity at cell (", row, ", ", col, ") -> position ", cell_center)

func get_cell_from_entity_position(entity: Node2D) -> Vector2i:
	"""Get the grid cell coordinates from an entity's position"""
	var grid_offset = Vector2(50, 60)
	var cell_size = Vector2(100, 126)

	var relative_pos = entity.position - grid_offset
	var col = int(relative_pos.x / cell_size.x)
	var row = int(relative_pos.y / cell_size.y)

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
