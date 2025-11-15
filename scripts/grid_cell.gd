extends Area2D

# ===== GRID CELL SCRIPT =====
# Represents a single cell in the 5x5 grid

signal cell_clicked(row: int, col: int)
signal cell_hovered(row: int, col: int)
signal cell_exited(row: int, col: int)

var row: int = -1
var col: int = -1
var is_hovered: bool = false

@onready var highlight: ColorRect = $Highlight
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	# Connect mouse signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)

	# Hide highlight by default
	if highlight:
		highlight.visible = false

func initialize(grid_row: int, grid_col: int):
	"""Initialize cell with grid coordinates"""
	row = grid_row
	col = grid_col

func _on_mouse_entered():
	"""Handle mouse entering cell"""
	is_hovered = true
	cell_hovered.emit(row, col)

func _on_mouse_exited():
	"""Handle mouse exiting cell"""
	is_hovered = false
	cell_exited.emit(row, col)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int):
	"""Handle mouse click on cell"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		cell_clicked.emit(row, col)

func show_highlight(color: Color = Color(1, 1, 1, 0.3)):
	"""Show cell highlight with optional color"""
	if highlight:
		highlight.color = color
		highlight.visible = true

func hide_highlight():
	"""Hide cell highlight"""
	if highlight:
		highlight.visible = false
