extends Node2D

# Entity data
var entity_data = {}
var is_player = false
var timeline_type = "present"

# References to child nodes
@onready var shadow = $Shadow
@onready var sprite = $Sprite
@onready var animated_sprite = $AnimatedSprite2D
@onready var glow = $Glow
@onready var hp_label = $HPLabel
@onready var damage_label = $DamageLabel
@onready var attack_sound = $AttackSound

# Mouse hover state tracking
var is_mouse_over = false

# Original position (for hit reactions)
var original_position = Vector2.ZERO

# Floating animation
var float_offset = 0.0  # Current vertical offset from floating
var base_y_position = 0.0  # Base Y position before floating

# Targeting system
var is_targetable = false  # Can this entity be targeted right now?
var is_highlighted_as_target = false  # Is this a valid target (green glow)?
var is_selected_as_target = false  # Has this been selected as a target (golden glow)?
var game_manager_ref = null  # Reference to game manager for callbacks

func _process(_delta):
	"""Check for mouse hover (only for enemies in Past/Future)"""
	# Only check for enemies in Past/Future timelines
	if is_player or timeline_type == "present":
		return
	
	# Get mouse position in viewport coordinates
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Get hitbox global rect (72x72, centered on entity)
	var global_pos = global_position
	var hitbox_rect = Rect2(global_pos - Vector2(36, 36), Vector2(72, 72))
	
	# Check if mouse is inside hitbox
	var was_over = is_mouse_over
	is_mouse_over = hitbox_rect.has_point(mouse_pos)
	
	# Trigger events on state change
	if is_mouse_over and not was_over:
		# Mouse just entered
		damage_label.visible = true
	elif not is_mouse_over and was_over:
		# Mouse just exited
		damage_label.visible = false

func setup(data: Dictionary, player: bool = false, timeline: String = "present"):
	"""Initialize entity with data from game manager"""
	entity_data = data
	is_player = player
	timeline_type = timeline

	# Setup sprite type if nodes are ready (otherwise will be called in _ready)
	if animated_sprite != null:
		_setup_sprite_display()

func _ready():
	"""Called when node enters scene tree"""
	# Store original position for hit reactions
	original_position = position

	# Connect sprite input for targeting
	if sprite:
		sprite.gui_input.connect(_on_sprite_gui_input)

	# Setup sprite type based on entity type (in case setup() was called before _ready)
	_setup_sprite_display()

	# Update visuals
	update_display()

	# Start floating animation for 3D hover effect
	_start_floating_animation()

	# Start glow animation for shiny effect
	_start_glow_animation()

func _on_sprite_gui_input(event: InputEvent):
	"""Handle mouse clicks on sprite for targeting"""
	if not is_targetable:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_entity_clicked_for_targeting()

func _setup_sprite_display():
	"""Setup the appropriate sprite type based on whether this is a player or enemy"""
	if is_player:
		# Player uses animated sprite
		animated_sprite.visible = true
		sprite.visible = false

		# Load player animations if not already loaded in scene
		if animated_sprite.sprite_frames == null:
			animated_sprite.sprite_frames = load("res://assets/sprites/player/player_animations.tres")

		# Play idle animation
		animated_sprite.play("idle")
		print("Player sprite setup complete - playing idle animation")
	else:
		# Enemies use ColorRect
		animated_sprite.visible = false
		sprite.visible = true

func _start_floating_animation():
	"""Create a gentle floating/hovering animation with dynamic shadow"""
	if not shadow:
		return

	# Store base position
	base_y_position = position.y

	# Floating parameters
	var float_height = 4.0  # How many pixels to float up/down
	var float_speed = 1.8  # Duration of one bob cycle (seconds)
	var rotation_angle = 2.0  # Degrees of rotation wobble

	# Create looping tween for vertical bobbing
	var bob_tween = create_tween().set_loops()
	bob_tween.set_parallel(true)  # Run all animations in parallel

	# Gentle up movement
	bob_tween.tween_property(self, "float_offset", -float_height, float_speed / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Gentle down movement
	bob_tween.chain().tween_property(self, "float_offset", 0.0, float_speed / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Subtle rotation wobble (left tilt)
	bob_tween.tween_property(self, "rotation_degrees", rotation_angle, float_speed / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Subtle rotation wobble (right tilt)
	bob_tween.chain().tween_property(self, "rotation_degrees", -rotation_angle, float_speed / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	bob_tween.chain().tween_property(self, "rotation_degrees", 0.0, float_speed / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _start_glow_animation():
	"""Create a subtle pulsing glow effect for shine"""
	if not glow:
		return

	# Glow pulsing parameters
	var min_energy = 0.4
	var max_energy = 0.7
	var pulse_speed = 2.5  # Seconds for full pulse cycle

	# Create looping tween for glow pulse
	var glow_tween = create_tween().set_loops()

	# Brighten
	glow_tween.tween_property(glow, "energy", max_energy, pulse_speed / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Dim
	glow_tween.tween_property(glow, "energy", min_energy, pulse_speed / 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _process(_delta):
	"""Update shadow based on float height and check for mouse hover"""
	# Update shadow dynamically based on float height
	if shadow and float_offset != 0:
		# As entity floats up (negative offset), shadow gets smaller and fainter
		var float_ratio = abs(float_offset) / 4.0  # 0.0 to 1.0
		shadow.scale = Vector2(1.0 - float_ratio * 0.3, 1.0)  # Shrink horizontally when higher
		shadow.modulate.a = 0.3 - float_ratio * 0.15  # Fade when higher

	# Apply float offset to position
	if float_offset != 0:
		position.y = base_y_position + float_offset

	# Original mouse hover logic (only for enemies in Past/Future)
	# Only check for enemies in Past/Future timelines
	if is_player or timeline_type == "present":
		return

	# Get mouse position in viewport coordinates
	var mouse_pos = get_viewport().get_mouse_position()

	# Get hitbox global rect (72x72, centered on entity)
	var global_pos = global_position
	var hitbox_rect = Rect2(global_pos - Vector2(36, 36), Vector2(72, 72))

	# Check if mouse is inside hitbox
	var was_over = is_mouse_over
	is_mouse_over = hitbox_rect.has_point(mouse_pos)

	# Trigger events on state change
	if is_mouse_over and not was_over:
		# Mouse just entered
		damage_label.visible = true
	elif not is_mouse_over and was_over:
		# Mouse just exited
		damage_label.visible = false

func update_display():
	"""Update visual elements based on entity data"""
	if entity_data.is_empty():
		return
	
	# Update HP label
	var current_hp = entity_data.get("hp", 0)
	var max_hp = entity_data.get("max_hp", 100)
	hp_label.text = "%d/%d" % [current_hp, max_hp]
	
	# Update damage label
	var damage = entity_data.get("damage", 0)
	if is_player:
		damage_label.visible = false
	else:
		damage_label.text = "DMG: %d" % damage
		if timeline_type == "present":
			damage_label.visible = true
		else:
			damage_label.visible = false
	
	# Set sprite color
	# Check if this is a conscripted enemy (enemy fighting in player's place)
	var is_conscripted = entity_data.get("is_conscripted_enemy", false)
	var is_twin = entity_data.get("is_twin", false)

	if is_twin:
		sprite.color = Color(0.7, 0.35, 0.15, 0.8)  # Lighter/faded orange for twin
	elif is_player and not is_conscripted:
		sprite.color = Color(1.0, 0.5, 0.2)  # Orange (real player)
	else:
		sprite.color = Color(0.3, 0.8, 0.3)  # Green (enemy or conscripted enemy)
	
	# Visual feedback for low HP
	if current_hp <= 0:
		modulate = Color(0.4, 0.4, 0.4, 0.5)
	elif current_hp < max_hp * 0.3:
		# Apply pulse animation to the visible sprite (animated for player, ColorRect for enemies)
		var target_sprite = animated_sprite if is_player else sprite
		var tween = create_tween().set_loops()
		tween.tween_property(target_sprite, "modulate", Color(1.5, 0.8, 0.8), 0.5)
		tween.tween_property(target_sprite, "modulate", Color(1.0, 1.0, 1.0), 0.5)
	else:
		# Reset modulate on the appropriate sprite
		if is_player:
			animated_sprite.modulate = Color(1.0, 1.0, 1.0)
		else:
			sprite.modulate = Color(1.0, 1.0, 1.0)

func play_attack_sound():
	"""Play this entity's attack sound"""
	if attack_sound and attack_sound.stream:
		attack_sound.play()
		print(entity_data.get("name", "Entity"), " playing attack sound")
	else:
		print(entity_data.get("name", "Entity"), " has no attack sound assigned")

func play_hit_reaction(hit_direction: Vector2):
	"""Play a quick recoil animation when hit"""
	# Update original position to current position
	original_position = position

	# Calculate knockback position (20 pixels back)
	var knockback_pos = position + hit_direction * 20.0

	# Create non-blocking tween (runs independently)
	var tween = create_tween()

	# Quick knockback (0.08 seconds)
	tween.tween_property(self, "position", knockback_pos, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Smooth return to original position (0.15 seconds)
	tween.tween_property(self, "position", original_position, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# NOTE: This tween is NOT awaited - it runs in the background
	# This allows attack animations to continue without blocking

# ===== TARGETING SYSTEM METHODS =====

func enable_targeting(game_manager):
	"""Enable this entity as a clickable target"""
	is_targetable = true
	game_manager_ref = game_manager

	# Make sprite clickable (MOUSE_FILTER_STOP = 0)
	if sprite:
		sprite.mouse_filter = Control.MOUSE_FILTER_STOP

	print("Entity ", entity_data.get("name", "Unknown"), " is now targetable")

func disable_targeting():
	"""Disable targeting on this entity"""
	is_targetable = false
	game_manager_ref = null

	# Disable sprite clicking (MOUSE_FILTER_IGNORE = 2)
	if sprite:
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Clear any target visuals
	clear_target_visuals()

func show_as_valid_target():
	"""Show visual feedback that this is a valid target with timeline-specific colors"""
	is_highlighted_as_target = true

	# Timeline-specific highlight colors
	var highlight_color: Color
	match timeline_type:
		"past":
			highlight_color = Color(1.5, 1.3, 0.8, 1.0)  # Warm golden (past)
		"present":
			highlight_color = Color(1.2, 1.5, 1.2, 1.0)  # Bright green (present)
		"future":
			highlight_color = Color(0.8, 1.3, 1.5, 1.0)  # Cool cyan (future)
		_:
			highlight_color = Color(1.2, 1.5, 1.2, 1.0)  # Default green

	modulate = highlight_color

	# Subtle pulse animation
	var tween = create_tween().set_loops()
	tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	print("Entity ", entity_data.get("name", "Unknown"), " highlighted as valid target (", timeline_type, ")")

func mark_as_targeted():
	"""Visual feedback for being selected as a target (golden glow)"""
	is_selected_as_target = true
	is_highlighted_as_target = false

	# Kill any existing tweens
	var active_tweens = get_tree().get_processed_tweens()
	for tween in active_tweens:
		if tween.is_valid():
			tween.kill()

	# Golden glow to show selection
	modulate = Color(1.5, 1.3, 0.6, 1.0)  # Golden
	scale = Vector2(1.1, 1.1)

	print("Entity ", entity_data.get("name", "Unknown"), " marked as targeted")

func clear_target_visuals():
	"""Clear all targeting visual effects"""
	is_highlighted_as_target = false
	is_selected_as_target = false

	# Kill any existing tweens
	var active_tweens = get_tree().get_processed_tweens()
	for tween in active_tweens:
		if tween.is_valid():
			tween.kill()

	# Return to normal appearance
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	scale = Vector2(1.0, 1.0)

func _on_entity_clicked_for_targeting():
	"""Called when entity is clicked during targeting mode"""
	if not is_targetable or not game_manager_ref:
		return

	print("Entity clicked for targeting: ", entity_data.get("name", "Unknown"))

	# Notify game manager
	game_manager_ref.on_target_selected(self)