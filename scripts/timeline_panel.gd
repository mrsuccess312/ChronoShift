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

func initialize(type: String, slot: int):
	"""Initialize the timeline panel with type and slot index"""
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

			grid_container.add_child(cell)
			grid_cells[row][col] = cell

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
