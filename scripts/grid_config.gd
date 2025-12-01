extends Node
class_name GridConfig

## GridConfig
##
## Centralized configuration for panel grid system.
## Provides configurable grid dimensions with automatic cell size calculation.
##
## Usage:
##   - Change GRID_ROWS and GRID_COLS to adjust cell count
##   - Change PANEL_WIDTH and PANEL_HEIGHT to adjust panel size
##   - Cell sizes are automatically calculated based on these values

# ==============================================================================
# CONFIGURABLE SETTINGS
# ==============================================================================

## Number of rows in the grid
## Change this value to increase/decrease vertical cell count
static var GRID_ROWS: int = 5

## Number of columns in the grid
## Change this value to increase/decrease horizontal cell count
static var GRID_COLS: int = 5

## Panel width in pixels
## Change this value to resize the panel horizontally
static var PANEL_WIDTH: float = 600.0

## Panel height in pixels
## Change this value to resize the panel vertically
static var PANEL_HEIGHT: float = 750.0

## Cell size in pixels (always square)
## Change this value to resize individual cells
## Spacing between cells will be calculated automatically
static var CELL_SIZE: float = 100.0

# ==============================================================================
# CALCULATED PROPERTIES
# ==============================================================================

## Get the width of a single cell (always square, same as CELL_SIZE)
static func get_cell_width() -> float:
	return CELL_SIZE

## Get the height of a single cell (always square, same as CELL_SIZE)
static func get_cell_height() -> float:
	return CELL_SIZE

## Get cell size as Vector2 (always square)
static func get_cell_size() -> Vector2:
	return Vector2(CELL_SIZE, CELL_SIZE)

## Get horizontal spacing between cells
## Formula: (PANEL_WIDTH - (GRID_COLS * CELL_SIZE)) / (GRID_COLS + 1)
static func get_horizontal_spacing() -> float:
	return (PANEL_WIDTH - (GRID_COLS * CELL_SIZE)) / float(GRID_COLS + 1)

## Get vertical spacing between cells
## Formula: (PANEL_HEIGHT - (GRID_ROWS * CELL_SIZE)) / (GRID_ROWS + 1)
static func get_vertical_spacing() -> float:
	return (PANEL_HEIGHT - (GRID_ROWS * CELL_SIZE)) / float(GRID_ROWS + 1)

## Get panel size as Vector2
static func get_panel_size() -> Vector2:
	return Vector2(PANEL_WIDTH, PANEL_HEIGHT)

## Get cell position for given row and column (includes spacing)
static func get_cell_position(row: int, col: int) -> Vector2:
	var h_spacing = get_horizontal_spacing()
	var v_spacing = get_vertical_spacing()
	return Vector2(
		h_spacing + col * (CELL_SIZE + h_spacing),
		v_spacing + row * (CELL_SIZE + v_spacing)
	)

## Get cell center position for given row and column
static func get_cell_center_position(row: int, col: int) -> Vector2:
	var cell_pos = get_cell_position(row, col)
	return Vector2(
		cell_pos.x + CELL_SIZE / 2.0,
		cell_pos.y + CELL_SIZE / 2.0
	)

## Validate that a row index is within bounds
static func is_valid_row(row: int) -> bool:
	return row >= 0 and row < GRID_ROWS

## Validate that a column index is within bounds
static func is_valid_col(col: int) -> bool:
	return col >= 0 and col < GRID_COLS

## Validate that a grid position is within bounds
static func is_valid_position(row: int, col: int) -> bool:
	return is_valid_row(row) and is_valid_col(col)

# ==============================================================================
# PRESET CONFIGURATIONS
# ==============================================================================

## Apply a preset configuration
## Available presets: "default", "small", "medium", "large", "wide", "tall"
static func apply_preset(preset_name: String) -> void:
	match preset_name.to_lower():
		"default":
			GRID_ROWS = 5
			GRID_COLS = 5
			PANEL_WIDTH = 600.0
			PANEL_HEIGHT = 750.0
			CELL_SIZE = 100.0
		"small":
			GRID_ROWS = 3
			GRID_COLS = 3
			PANEL_WIDTH = 450.0
			PANEL_HEIGHT = 450.0
			CELL_SIZE = 120.0
		"medium":
			GRID_ROWS = 4
			GRID_COLS = 4
			PANEL_WIDTH = 600.0
			PANEL_HEIGHT = 600.0
			CELL_SIZE = 120.0
		"large":
			GRID_ROWS = 6
			GRID_COLS = 6
			PANEL_WIDTH = 720.0
			PANEL_HEIGHT = 900.0
			CELL_SIZE = 100.0
		"wide":
			GRID_ROWS = 4
			GRID_COLS = 8
			PANEL_WIDTH = 960.0
			PANEL_HEIGHT = 600.0
			CELL_SIZE = 100.0
		"tall":
			GRID_ROWS = 8
			GRID_COLS = 4
			PANEL_WIDTH = 480.0
			PANEL_HEIGHT = 1200.0
			CELL_SIZE = 100.0
		_:
			push_warning("Unknown preset: " + preset_name + ". Using current configuration.")

## Get information about current configuration
static func get_config_info() -> String:
	return "Grid: %dx%d | Panel: %.0fx%.0f | Cell: %.0fpx | Spacing: %.1fx%.1f" % [
		GRID_COLS, GRID_ROWS,
		PANEL_WIDTH, PANEL_HEIGHT,
		CELL_SIZE,
		get_horizontal_spacing(), get_vertical_spacing()
	]
