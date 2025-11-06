extends Node2D

# Entity data
var entity_data = {}
var is_player = false
var timeline_type = "present"

# References to child nodes
@onready var sprite = $Sprite
@onready var hp_label = $HPLabel
@onready var damage_label = $DamageLabel
@onready var attack_sound = $AttackSound

# Mouse hover state tracking
var is_mouse_over = false

func setup(data: Dictionary, player: bool = false, timeline: String = "present"):
	"""Initialize entity with data from game manager"""
	entity_data = data
	is_player = player
	timeline_type = timeline

func _ready():
	"""Called when node enters scene tree"""
	# Update visuals
	update_display()

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
	if is_player:
		sprite.color = Color(1.0, 0.5, 0.2)  # Orange
	else:
		sprite.color = Color(0.3, 0.8, 0.3)  # Green
	
	# Visual feedback for low HP
	if current_hp <= 0:
		modulate = Color(0.4, 0.4, 0.4, 0.5)
	elif current_hp < max_hp * 0.3:
		var tween = create_tween().set_loops()
		tween.tween_property(sprite, "modulate", Color(1.5, 0.8, 0.8), 0.5)
		tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0), 0.5)
	else:
		sprite.modulate = Color(1.0, 1.0, 1.0)

func play_attack_sound():
	"""Play this entity's attack sound"""
	if attack_sound and attack_sound.stream:
		attack_sound.play()
		print(entity_data.get("name", "Entity"), " playing attack sound")
	else:
		print(entity_data.get("name", "Entity"), " has no attack sound assigned")
