extends Panel
class_name GridCell

# ===== FLUENT DESIGN GRID CELL =====
# A reusable UI component for Fluent Design grid systems
# Features: hover effects, click detection, shadow styling, visual states

# Cell visual states
enum CellState {
	NORMAL,    # Default light gray
	HOVERED,   # Slightly brighter
	SELECTED,  # Blue tint
	OCCUPIED,  # Yellow tint
	TARGETED   # Red border
}

# Signal emitted when this cell is clicked
signal cell_clicked(grid_x: int, grid_y: int)

# Grid coordinates for this cell
@export var grid_x: int = 0
@export var grid_y: int = 0

# Current visual state
var current_state: CellState = CellState.NORMAL

# State colors
var state_colors = {
	CellState.NORMAL: Color(0.925, 0.925, 0.925),    # #ECECEC
	CellState.HOVERED: Color(0.961, 0.961, 0.961),   # #F5F5F5
	CellState.SELECTED: Color(0.816, 0.910, 1.0),    # #D0E8FF
	CellState.OCCUPIED: Color(1.0, 0.957, 0.816),    # #FFF4D0
	CellState.TARGETED: Color(0.925, 0.925, 0.925)   # #ECECEC (border will be red)
}

# Reference to the StyleBoxFlat (will be set in _ready)
var style_box: StyleBoxFlat = null

func _ready():
	# Create StyleBoxFlat for the panel
	style_box = StyleBoxFlat.new()

	# Set custom minimum size
	custom_minimum_size = Vector2(80, 80)

	# Connect mouse signals for hover effects
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	# Initialize to NORMAL state
	set_state(CellState.NORMAL)

func set_state(new_state: CellState) -> void:
	"""Set the visual state of the cell

	Args:
		new_state: The CellState to apply
	"""
	current_state = new_state

	if not style_box:
		return

	# Get the color for this state
	var bg_color = state_colors.get(new_state, state_colors[CellState.NORMAL])

	# Update background color
	style_box.bg_color = bg_color

	# Set corner radius for all corners (Fluent Design rounded corners)
	style_box.corner_radius_top_left = 10
	style_box.corner_radius_top_right = 10
	style_box.corner_radius_bottom_left = 10
	style_box.corner_radius_bottom_right = 10

	# Enable shadow
	style_box.shadow_size = 5
	style_box.shadow_offset = Vector2(0, 3)
	style_box.shadow_color = Color(0, 0, 0, 0.15)

	# Handle TARGETED state - add red border
	if new_state == CellState.TARGETED:
		style_box.border_width_left = 2
		style_box.border_width_top = 2
		style_box.border_width_right = 2
		style_box.border_width_bottom = 2
		style_box.border_color = Color(1.0, 0.267, 0.267)  # #FF4444
	else:
		# Remove border for other states
		style_box.border_width_left = 0
		style_box.border_width_top = 0
		style_box.border_width_right = 0
		style_box.border_width_bottom = 0

	# Apply the updated style
	add_theme_stylebox_override("panel", style_box)

func reset_state() -> void:
	"""Reset the cell to NORMAL state"""
	set_state(CellState.NORMAL)

func _gui_input(event: InputEvent) -> void:
	"""Handle mouse input events on this cell"""
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Emit signal with grid coordinates when clicked
			cell_clicked.emit(grid_x, grid_y)
			# Optional: Add a subtle click animation
			_play_click_animation()

func set_grid_position(x: int, y: int) -> void:
	"""Set the grid coordinates for this cell

	Args:
		x: The horizontal grid position
		y: The vertical grid position
	"""
	grid_x = x
	grid_y = y

func _on_mouse_entered() -> void:
	"""Brighten the cell slightly when mouse hovers over it"""
	# Only apply hover effect if in NORMAL state
	# (don't override SELECTED, OCCUPIED, or TARGETED states)
	if current_state == CellState.NORMAL:
		set_state(CellState.HOVERED)

func _on_mouse_exited() -> void:
	"""Restore original state when mouse leaves"""
	# Only restore to NORMAL if currently HOVERED
	# (preserve other states)
	if current_state == CellState.HOVERED:
		set_state(CellState.NORMAL)

func _play_click_animation() -> void:
	"""Play a subtle scale animation when clicked"""
	var tween = create_tween()
	# Scale up slightly
	tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Scale back to normal
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
