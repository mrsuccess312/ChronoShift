extends PanelContainer

# Signal emitted when card is clicked
signal card_clicked(card_data)

# References to UI elements
@onready var card_name_label = $Content/CardName
@onready var description_label = $Content/Description
@onready var cost_label = $CostLabel

# Card data
var card_data = {}
var is_used = false  # Track if card has been played this turn
var is_affordable = true  # Track if player has enough time
var is_hovered = false  # Track if mouse is currently hovering

func setup(data: Dictionary):
	"""Initialize card with data from CardDatabase"""
	card_data = data
	is_used = false
	update_display()

func _ready():
	"""Connect mouse hover signals"""
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
func update_display():
	"""Update visual elements based on card_data"""
	if card_data.is_empty():
		return

	card_name_label.text = card_data.get("name", "Unknown")
	description_label.text = card_data.get("description", "")

	# Display cost
	var time_cost = card_data.get("time_cost", 0)
	cost_label.text = "⏱%ds" % time_cost

	# Update visual state
	update_affordability_visual()

func _gui_input(event: InputEvent):
	"""Handle mouse clicks on the card"""
	if is_used:
		return  # Can't click used cards

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_card_clicked()

func _on_card_clicked():
	"""Called when player clicks this card"""
	if is_used:
		return

	# Check if card is affordable
	if not is_affordable:
		play_shake_animation()
		print("Card too expensive: ", card_data.get("name", "Unknown"))
		return

	print("Card clicked: ", card_data.get("name", "Unknown"))
	emit_signal("card_clicked", card_data)

	# Mark as used FIRST
	is_used = true

	# Kill all tweens immediately
	_kill_active_tweens()

	# Force to used state
	scale = Vector2(1.0, 1.0)
	modulate = Color(0.2, 0.2, 0.2, 0.5)

	# Small shrink feedback
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

func _on_mouse_entered():
	"""Called when mouse hovers over card"""
	if is_used:
		return  # Don't respond to hover if used

	is_hovered = true

	# Stop any existing tweens first
	_kill_active_tweens()

	# Brighten to full visibility
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)
	# Scale up slightly instead of moving
	tween.parallel().tween_property(self, "scale", Vector2(1.05, 1.05), 0.15)

func _on_mouse_exited():
	"""Called when mouse leaves card"""
	if is_used:
		return  # Don't respond if used

	is_hovered = false

	# Stop any existing tweens first
	_kill_active_tweens()

	# Return to appropriate state based on affordability
	update_affordability_visual()

func mark_as_used():
	"""Externally mark card as used"""
	is_used = true
	is_hovered = false

	# Stop any running tweens (CRITICAL FIX)
	_kill_active_tweens()

	# Force consistent state
	scale = Vector2(1.0, 1.0)
	modulate = Color(0.2, 0.2, 0.2, 0.5)  # Dark gray for used cards

	mouse_filter = Control.MOUSE_FILTER_IGNORE

func reset():
	"""Reset card for new turn"""
	is_used = false
	is_hovered = false
	scale = Vector2(1.0, 1.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	update_display()

func update_affordability(time_remaining: float):
	"""Update whether card is affordable based on remaining time"""
	var time_cost = card_data.get("time_cost", 0)
	is_affordable = time_remaining >= time_cost
	update_affordability_visual()

func update_affordability_visual():
	"""Update visual appearance based on affordability"""
	# Don't update visuals if card is currently being hovered
	if is_hovered and not is_used:
		return

	if is_used:
		modulate = Color(0.2, 0.2, 0.2, 0.5)  # Used: dark gray
		scale = Vector2(1.0, 1.0)
	elif not is_affordable:
		modulate = Color(0.6, 0.2, 0.2, 0.6)  # Too expensive: reddish
		scale = Vector2(1.0, 1.0)
	else:
		modulate = Color(0.4, 0.4, 0.4, 0.8)  # Normal: grayed out
		scale = Vector2(1.0, 1.0)

func play_shake_animation():
	"""Play shake animation when card can't be used"""
	_kill_active_tweens()

	var original_pos = position
	var shake_amount = 5.0

	var tween = create_tween()
	tween.tween_property(self, "position", original_pos + Vector2(-shake_amount, 0), 0.05)
	tween.tween_property(self, "position", original_pos + Vector2(shake_amount, 0), 0.05)
	tween.tween_property(self, "position", original_pos + Vector2(-shake_amount, 0), 0.05)
	tween.tween_property(self, "position", original_pos + Vector2(shake_amount, 0), 0.05)
	tween.tween_property(self, "position", original_pos, 0.05)

func _kill_active_tweens():
	"""Stop all active tweens on this node"""
	var active_tweens = get_tree().get_processed_tweens()
	for tween in active_tweens:
		if tween.is_valid():
			tween.kill()
