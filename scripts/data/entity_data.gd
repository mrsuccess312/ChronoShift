extends Resource
class_name EntityData
## Pure data class representing an entity in any timeline
## This is a structured replacement for Dictionary-based entity data

# ===== CORE IDENTITY =====
var unique_id: String = ""  # UUID for cross-timeline identification
var entity_name: String = ""  # Display name (e.g., "Chrono-Beast A")

# ===== TEAM & TYPE =====
var is_enemy: bool = true  # false = player/ally, true = enemy
var is_temporary: bool = false  # true for twins, conscripted enemies, etc.
var temporary_expires_after_combat: bool = false  # Auto-remove after combat

# ===== STATS =====
var hp: int = 100
var max_hp: int = 100
var damage: int = 10

# ===== COMBAT PROPERTIES =====
var attack_target_id: String = ""  # unique_id of entity to attack
var will_miss: bool = false  # If true, this entity's attack misses

# ===== GRID POSITION =====
var grid_row: int = -1  # Grid position (row)
var grid_col: int = -1  # Grid position (col)

# ===== SPECIAL FLAGS =====
var is_twin: bool = false  # Special case: Past Twin entity
var is_conscripted: bool = false  # Special case: Conscripted enemy
var is_death_forecasted: bool = false  # If true, entity will die in Future timeline (remove when killed)


# ===== HELPER CONSTRUCTORS =====

static func create_player(unique_id: String = "") -> EntityData:
	"""Create a player entity with default stats"""
	var entity = EntityData.new()
	entity.unique_id = unique_id if unique_id else _generate_uuid()
	entity.entity_name = "Chronomancer"
	entity.is_enemy = false
	entity.hp = 100
	entity.max_hp = 100
	entity.damage = 15
	return entity


static func create_enemy(name: String, hp: int, damage: int, unique_id: String = "") -> EntityData:
	"""Create an enemy entity"""
	var entity = EntityData.new()
	entity.unique_id = unique_id if unique_id else _generate_uuid()
	entity.entity_name = name
	entity.is_enemy = true
	entity.hp = hp
	entity.max_hp = hp
	entity.damage = damage
	return entity


static func create_twin(player: EntityData) -> EntityData:
	"""Create a Past Twin from player data"""
	var twin = EntityData.new()
	twin.unique_id = _generate_uuid()
	twin.entity_name = "Past Twin"
	twin.is_enemy = false
	twin.is_twin = true
	twin.is_temporary = true
	twin.temporary_expires_after_combat = true
	twin.hp = int(player.hp * 0.5)
	twin.max_hp = int(player.max_hp * 0.5)
	twin.damage = int(player.damage * 0.5)
	return twin


# ===== HELPER METHODS =====

func duplicate_entity() -> EntityData:
	"""Create a deep copy of this entity"""
	var copy = EntityData.new()
	copy.unique_id = unique_id  # Keep same ID for cross-timeline tracking
	copy.entity_name = entity_name
	copy.is_enemy = is_enemy
	copy.is_temporary = is_temporary
	copy.temporary_expires_after_combat = temporary_expires_after_combat
	copy.hp = hp
	copy.max_hp = max_hp
	copy.damage = damage
	copy.attack_target_id = attack_target_id
	copy.will_miss = will_miss
	copy.grid_row = grid_row
	copy.grid_col = grid_col
	copy.is_twin = is_twin
	copy.is_conscripted = is_conscripted
	copy.is_death_forecasted = is_death_forecasted
	return copy


func is_alive() -> bool:
	"""Check if entity is still alive"""
	return hp > 0


func take_damage(amount: int) -> bool:
	"""Apply damage and return true if entity died"""
	hp -= amount
	if hp < 0:
		hp = 0
	return hp == 0


func heal(amount: int):
	"""Heal entity (capped at max_hp)"""
	hp += amount
	if hp > max_hp:
		hp = max_hp


func clear_combat_state():
	"""Clear combat-specific state (call after combat)"""
	attack_target_id = ""
	will_miss = false


static func _generate_uuid() -> String:
	"""Generate a simple unique ID"""
	return "entity_" + str(Time.get_ticks_msec()) + "_" + str(randi())


# ===== DEBUG & SERIALIZATION =====

func to_dict() -> Dictionary:
	"""Convert to dictionary for debugging/serialization"""
	return {
		"unique_id": unique_id,
		"name": entity_name,
		"is_enemy": is_enemy,
		"hp": hp,
		"max_hp": max_hp,
		"damage": damage,
		"target": attack_target_id,
		"will_miss": will_miss,
		"position": Vector2i(grid_row, grid_col)
	}
