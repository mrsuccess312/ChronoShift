extends Panel
class_name BattleGrid

# ===== FLUENT DESIGN BATTLE GRID =====
# A grid container that uses FIXED cell sizes (80x80) with DYNAMIC spacing
# Unlike the old system where cell size varied, spacing now adapts to available space

# Signal re-emitted when any cell is clicked
signal grid_cell_clicked(x: int, y: int)

# Constants for fixed cell sizing
const CELL_SIZE: float = 80.0  # Fixed cell size (both width and height)
const PANEL_MARGIN: float = 20.0  # Margin from panel edges to grid
const MIN_SPACING: float = 8.0  # Minimum spacing between cells

# Reference to the GridCell scene
const GRID_CELL_SCENE = preload("res://scenes/ui/GridCell.tscn")

# Child nodes
@onready var cell_container: GridContainer = $CellContainer

# Grid data
var cells: Array[GridCell] = []  # Flat array of all cells
var grid_width: int = 0
var grid_height: int = 0

func _ready():
	setup_grid()

func setup_grid() -> void:
	"""Initialize the grid based on grid_config dimensions"""
	# Clear any existing cells
	clear_grid()

	# Get grid dimensions from config
	grid_width = GridConfig.GRID_COLS
	grid_height = GridConfig.GRID_ROWS

	# Configure the GridContainer
	if cell_container:
		cell_container.columns = grid_width

		# Calculate and apply spacing
		calculate_spacing()

		# Create cells
		create_cells()

func calculate_spacing() -> void:
	"""Calculate dynamic spacing based on panel size and fixed cell dimensions

	KEY CHANGE: In the old system, cell size was calculated from panel size.
	In the new system, cell size is FIXED at 80x80, and spacing is CALCULATED.

	Formula:
	- available_space = panel_dimension - (margins * 2)
	- total_cell_space = num_cells * CELL_SIZE
	- remaining_space = available_space - total_cell_space
	- spacing = remaining_space / (num_cells - 1)
	"""

	# Calculate required panel size based on fixed cells and minimum spacing
	var required_width = (grid_width * CELL_SIZE) + ((grid_width - 1) * MIN_SPACING) + (PANEL_MARGIN * 2)
	var required_height = (grid_height * CELL_SIZE) + ((grid_height - 1) * MIN_SPACING) + (PANEL_MARGIN * 2)

	# Set panel minimum size to accommodate all cells
	custom_minimum_size = Vector2(required_width, required_height)

	# If panel is larger than minimum, calculate spacing
	var panel_size = size
	if panel_size.x < required_width:
		panel_size.x = required_width
	if panel_size.y < required_height:
		panel_size.y = required_height

	# Calculate available space (subtract margins)
	var available_width = panel_size.x - (PANEL_MARGIN * 2)
	var available_height = panel_size.y - (PANEL_MARGIN * 2)

	# Calculate total space used by cells
	var total_cell_width = grid_width * CELL_SIZE
	var total_cell_height = grid_height * CELL_SIZE

	# Calculate remaining space for gaps
	var remaining_width = available_width - total_cell_width
	var remaining_height = available_height - total_cell_height

	# Calculate spacing (distribute remaining space evenly between cells)
	var h_spacing = MIN_SPACING
	var v_spacing = MIN_SPACING

	if grid_width > 1:
		h_spacing = max(MIN_SPACING, remaining_width / (grid_width - 1))
	if grid_height > 1:
		v_spacing = max(MIN_SPACING, remaining_height / (grid_height - 1))

	# Apply spacing to GridContainer
	if cell_container:
		cell_container.add_theme_constant_override("h_separation", int(h_spacing))
		cell_container.add_theme_constant_override("v_separation", int(v_spacing))

		# Position the container with margins
		cell_container.position = Vector2(PANEL_MARGIN, PANEL_MARGIN)
		cell_container.size = Vector2(available_width, available_height)

	print("BattleGrid: Grid %dx%d | Cell size: %.0f | H-Spacing: %.1f | V-Spacing: %.1f" % [
		grid_width, grid_height, CELL_SIZE, h_spacing, v_spacing
	])

func create_cells() -> void:
	"""Create and populate the grid with GridCell instances"""
	cells.clear()

	for y in range(grid_height):
		for x in range(grid_width):
			# Instantiate a new cell
			var cell = GRID_CELL_SCENE.instantiate() as GridCell

			# Set grid position
			cell.set_grid_position(x, y)

			# Name it systematically for debugging
			cell.name = "Cell_%d_%d" % [x, y]

			# Connect the cell's clicked signal
			cell.cell_clicked.connect(_on_cell_clicked)

			# Add to container
			cell_container.add_child(cell)

			# Store reference
			cells.append(cell)

	print("BattleGrid: Created %d cells (%dx%d grid)" % [cells.size(), grid_width, grid_height])

func clear_grid() -> void:
	"""Remove all existing cells from the grid"""
	if cell_container:
		for child in cell_container.get_children():
			child.queue_free()
	cells.clear()

func get_cell(x: int, y: int) -> GridCell:
	"""Get a specific cell by grid coordinates

	Args:
		x: Column index (0 to grid_width-1)
		y: Row index (0 to grid_height-1)

	Returns:
		The GridCell at the specified position, or null if out of bounds
	"""
	if x < 0 or x >= grid_width or y < 0 or y >= grid_height:
		push_warning("BattleGrid: Invalid cell coordinates (%d, %d)" % [x, y])
		return null

	# Convert 2D coordinates to 1D array index
	var index = y * grid_width + x

	if index >= 0 and index < cells.size():
		return cells[index]

	return null

func highlight_cell(x: int, y: int, color: Color) -> void:
	"""Change a cell's background color

	Args:
		x: Column index
		y: Row index
		color: The color to set
	"""
	var cell = get_cell(x, y)
	if cell and cell.style_box:
		cell.style_box.bg_color = color

func clear_highlights() -> void:
	"""Reset all cells to their default background color"""
	for cell in cells:
		if cell and cell.style_box:
			cell.style_box.bg_color = cell.default_bg_color

func _on_cell_clicked(x: int, y: int) -> void:
	"""Handle cell click events and re-emit as grid signal"""
	print("BattleGrid: Cell clicked at (%d, %d)" % [x, y])
	grid_cell_clicked.emit(x, y)

# Optional: Handle resizing to recalculate spacing
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if is_inside_tree() and cell_container:
			calculate_spacing()
