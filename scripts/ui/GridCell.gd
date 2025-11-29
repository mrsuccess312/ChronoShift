extends Panel
class_name GridCell

# ===== FLUENT DESIGN GRID CELL =====
# A reusable UI component for Fluent Design grid systems
# Features: hover effects, click detection, shadow styling

# Signal emitted when this cell is clicked
signal cell_clicked(grid_x: int, grid_y: int)

# Grid coordinates for this cell
@export var grid_x: int = 0
@export var grid_y: int = 0

# Styling properties
var default_bg_color: Color = Color(0.925, 0.925, 0.925)  # #ECECEC
var hover_bg_color: Color = Color(0.95, 0.95, 0.95)  # Slightly brighter on hover

# Reference to the StyleBoxFlat (will be set in _ready)
var style_box: StyleBoxFlat = null

func _ready():
	# Create StyleBoxFlat for the panel
	style_box = StyleBoxFlat.new()

	# Set background color
	style_box.bg_color = default_bg_color

	# Set corner radius for all corners (Fluent Design rounded corners)
	style_box.corner_radius_top_left = 10
	style_box.corner_radius_top_right = 10
	style_box.corner_radius_bottom_left = 10
	style_box.corner_radius_bottom_right = 10

	# Enable shadow
	style_box.shadow_size = 5
	style_box.shadow_offset = Vector2(0, 3)
	style_box.shadow_color = Color(0, 0, 0, 0.15)  # Semi-transparent black

	# Apply the style to the panel
	add_theme_stylebox_override("panel", style_box)

	# Set custom minimum size
	custom_minimum_size = Vector2(80, 80)

	# Connect mouse signals for hover effects
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

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
	if style_box:
		# Create a smooth transition to hover color
		var tween = create_tween()
		tween.tween_property(style_box, "bg_color", hover_bg_color, 0.15)

func _on_mouse_exited() -> void:
	"""Restore original color when mouse leaves"""
	if style_box:
		# Smooth transition back to default color
		var tween = create_tween()
		tween.tween_property(style_box, "bg_color", default_bg_color, 0.15)

func _play_click_animation() -> void:
	"""Play a subtle scale animation when clicked"""
	var tween = create_tween()
	# Scale up slightly
	tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Scale back to normal
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
