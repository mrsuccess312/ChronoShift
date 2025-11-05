extends Node2D

# References
@onready var arrow_line = $ArrowLine
@onready var arrowhead = $ArrowHead
@onready var hover_area = $HoverArea

# Arrow properties
var start_pos = Vector2.ZERO
var end_pos = Vector2.ZERO
var curve_height = 50.0  # How much the arrow curves
var is_hovered = false

# Visual state
var default_alpha = 0.3  # Faded by default
var hover_alpha = 1.0    # Fully visible on hover

# Entity offset distance (how far from entity center to start/end arrow)
var entity_offset = 100.0  # Entities are 72x72, so 36 radius + 9 pixels gap

func setup(from: Vector2, to: Vector2, curve: float = 50.0):
	"""Initialize arrow from start to end position"""
	# Calculate direction from start to end
	var direction = (to - from).normalized()
	
	# Offset start and end positions to be near entities, not at center
	start_pos = from + direction * entity_offset
	end_pos = to - direction * entity_offset
	
	curve_height = curve
	
	# Draw the arrow
	draw_arrow()
	
	# Set default faded state
	modulate = Color(1.0, 1.0, 1.0, default_alpha)

func draw_arrow():
	"""Draw curved line from start to end with arrowhead"""
	# Calculate curve points (simple quadratic bezier)
	var mid_point = (start_pos + end_pos) / 2.0
	var direction = (end_pos - start_pos).normalized()
	var perpendicular = Vector2(-direction.y, direction.x)
	var control_point = mid_point + perpendicular * curve_height
	
	# Generate smooth curve points
	var points = []
	var num_points = 20
	for i in range(num_points + 1):
		var t = float(i) / num_points
		var point = quadratic_bezier(start_pos, control_point, end_pos, t)
		points.append(point)
	
	# Set line points
	arrow_line.points = PackedVector2Array(points)
	
	# Position arrowhead at end
	arrowhead.position = end_pos
	arrowhead.rotation = direction.angle()

func quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	"""Calculate point on quadratic bezier curve"""
	var q0 = p0.lerp(p1, t)
	var q1 = p1.lerp(p2, t)
	return q0.lerp(q1, t)

func _ready():
	"""Setup hover detection (using _process like entities)"""
	pass

func _process(_delta):
	"""Check for mouse hover over arrow"""
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Simple check: is mouse near any point on the arrow line?
	var was_hovered = is_hovered
	is_hovered = false
	
	for point in arrow_line.points:
		var global_point = arrow_line.global_position + point
		if mouse_pos.distance_to(global_point) < 20:  # 20 pixel hover radius
			is_hovered = true
			break
	
	# Update visibility on state change
	if is_hovered and not was_hovered:
		# Mouse entered
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, hover_alpha), 0.15)
	elif not is_hovered and was_hovered:
		# Mouse exited
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, default_alpha), 0.15)

func hide_arrow():
	"""Hide the arrow (called before animations)"""
	visible = false

func show_arrow():
	"""Show the arrow"""
	visible = true
