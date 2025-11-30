extends Area2D

# ===== GRID CELL SCRIPT =====
# Represents a single cell in the grid (size from GridConfig)

signal cell_clicked(row: int, col: int)
signal cell_hovered(row: int, col: int)
signal cell_exited(row: int, col: int)

var row: int = -1
var col: int = -1
var is_hovered: bool = false
var hover_color: Color = Color(1, 1, 1, 0.3)  # Default hover color

@onready var background: Panel = $Background
@onready var highlight: Panel = $Highlight
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var grid_lines: Control = $GridLines
@onready var debug_label: Label = $DebugLabel

func _ready():
	print("DEBUG GridCell _ready: Cell (", row, ", ", col, ") initializing")

	# Dynamically resize cell based on GridConfig
	_resize_cell_components()

	# Enable monitoring
	monitoring = true
	monitorable = true

	# Connect mouse signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)

	print("DEBUG GridCell _ready: Signals connected for (", row, ", ", col, ")")
	print("DEBUG GridCell _ready: input_pickable = ", input_pickable, ", monitoring = ", monitoring)

	# Hide highlight by default
	if highlight:
		highlight.visible = false
		highlight.modulate.a = 0.0

	# Hide grid lines by default
	if grid_lines:
		grid_lines.visible = false

	# Hide debug label by default
	if debug_label:
		debug_label.visible = false

	print("DEBUG GridCell _ready: Complete for (", row, ", ", col, ")")

func initialize(grid_row: int, grid_col: int):
	"""Initialize cell with grid coordinates"""
	row = grid_row
	col = grid_col

	# Update debug label
	if debug_label:
		debug_label.text = "(%d,%d)" % [row, col]

func _resize_cell_components():
	"""Dynamically resize all cell components based on GridConfig"""
	var cell_size = GridConfig.get_cell_size()
	var cell_width = cell_size.x
	var cell_height = cell_size.y

	# Resize collision shape
	if collision_shape and collision_shape.shape:
		collision_shape.shape.size = cell_size
		collision_shape.position = Vector2(cell_width / 2, cell_height / 2)

	# Resize background Panel
	if background:
		background.size = cell_size
		background.offset_right = cell_width
		background.offset_bottom = cell_height

	# Resize highlight Panel
	if highlight:
		highlight.size = cell_size
		highlight.offset_right = cell_width
		highlight.offset_bottom = cell_height

	# Resize grid lines container
	if grid_lines:
		grid_lines.size = cell_size
		grid_lines.set_size(cell_size)

		# Update right line position
		var right_line = grid_lines.get_node_or_null("RightLine")
		if right_line:
			right_line.offset_left = cell_width - 1
			right_line.offset_right = cell_width
			right_line.offset_bottom = cell_height

		# Update bottom line position
		var bottom_line = grid_lines.get_node_or_null("BottomLine")
		if bottom_line:
			bottom_line.offset_top = cell_height - 1
			bottom_line.offset_right = cell_width
			bottom_line.offset_bottom = cell_height

	# Resize debug label
	if debug_label:
		debug_label.size = cell_size
		debug_label.offset_right = cell_width
		debug_label.offset_bottom = cell_height

func set_hover_color(color: Color):
	"""Set the hover color for this cell based on timeline type"""
	hover_color = color

func _on_mouse_entered():
	"""Handle mouse entering cell with smooth fade-in and lift animation"""
	is_hovered = true
	print("DEBUG: Mouse entered cell (", row, ", ", col, ")")

	# Create parallel tweens for smooth animation
	var tween = create_tween()
	tween.set_parallel(true)

	# Fade in highlight with custom color
	if highlight:
		# Update highlight color via StyleBox
		var style = highlight.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			style.bg_color = hover_color
		highlight.visible = true
		print("DEBUG: Highlight visible, color = ", hover_color)
		tween.tween_property(highlight, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Subtle scale-up for lift effect (1.0 → 1.03)
	tween.tween_property(self, "scale", Vector2(1.03, 1.03), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	cell_hovered.emit(row, col)

func _on_mouse_exited():
	"""Handle mouse exiting cell with smooth fade-out and return to original scale"""
	is_hovered = false

	# Create parallel tweens for smooth animation
	var tween = create_tween()
	tween.set_parallel(true)

	# Fade out highlight
	if highlight:
		tween.tween_property(highlight, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# Return to original scale
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# Hide highlight after animation
	await tween.finished
	if highlight:
		highlight.visible = false

	cell_exited.emit(row, col)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	"""Handle mouse click on cell with pulse animation"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("DEBUG: Cell clicked (", row, ", ", col, ")")
		# Play click pulse animation
		play_click_animation()
		cell_clicked.emit(row, col)

func play_click_animation():
	"""Pulse animation on click (1.0 → 1.05 → 1.0)"""
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func show_highlight(color: Color = Color(1, 1, 1, 0.3)):
	"""Show cell highlight with optional color (for manual highlighting)"""
	if highlight:
		# Update highlight color via StyleBox
		var style = highlight.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			style.bg_color = color
		highlight.visible = true
		highlight.modulate.a = 1.0

func hide_highlight():
	"""Hide cell highlight (for manual highlighting)"""
	if highlight:
		highlight.visible = false
		highlight.modulate.a = 0.0

func show_grid_lines(visible: bool):
	"""Toggle grid line visibility"""
	if grid_lines:
		grid_lines.visible = visible

func show_debug_info(visible: bool):
	"""Toggle debug coordinate label visibility"""
	if debug_label:
		debug_label.visible = visible
