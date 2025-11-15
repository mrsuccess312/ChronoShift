extends Area2D

# ===== GRID CELL SCRIPT =====
# Represents a single cell in the 5x5 grid

signal cell_clicked(row: int, col: int)
signal cell_hovered(row: int, col: int)
signal cell_exited(row: int, col: int)

var row: int = -1
var col: int = -1
var is_hovered: bool = false
var hover_color: Color = Color(1, 1, 1, 0.3)  # Default hover color

@onready var highlight: ColorRect = $Highlight
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var grid_lines: Control = $GridLines
@onready var debug_label: Label = $DebugLabel

func _ready():
	# Connect mouse signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)

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

func initialize(grid_row: int, grid_col: int):
	"""Initialize cell with grid coordinates"""
	row = grid_row
	col = grid_col

	# Update debug label
	if debug_label:
		debug_label.text = "(%d,%d)" % [row, col]

func set_hover_color(color: Color):
	"""Set the hover color for this cell based on timeline type"""
	hover_color = color

func _on_mouse_entered():
	"""Handle mouse entering cell with smooth fade-in"""
	is_hovered = true
	print("DEBUG: Mouse entered cell (", row, ", ", col, ")")

	# Fade in highlight
	if highlight:
		highlight.color = hover_color
		highlight.visible = true
		print("DEBUG: Highlight visible, color = ", hover_color)

		var tween = create_tween()
		tween.tween_property(highlight, "modulate:a", 0.3, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	cell_hovered.emit(row, col)

func _on_mouse_exited():
	"""Handle mouse exiting cell with smooth fade-out"""
	is_hovered = false

	# Fade out highlight
	if highlight:
		var tween = create_tween()
		tween.tween_property(highlight, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		await tween.finished
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
		highlight.color = color
		highlight.visible = true
		highlight.modulate.a = 0.3

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
