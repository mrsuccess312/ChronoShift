extends Object
class_name CardDatabase

# Card effect types
enum EffectType {
	HEAL_PLAYER,           # Restore player HP
	DAMAGE_ENEMY,          # Deal damage to target enemy
	DAMAGE_ALL_ENEMIES,    # Deal damage to all enemies
	BOOST_DAMAGE,          # Increase player damage this turn
	SKIP_ENEMY_TURN,       # Prevent one enemy from attacking
}

# Card definitions
static func get_all_cards() -> Array:
	"""Returns array of all available cards"""
	return [
		{
			"id": "temporal_heal",
			"name": "Temporal Rewind",
			"description": "Restore 20 HP from Past timeline",
			"energy_cost": 0,  # Not using energy yet
			"effect_type": EffectType.HEAL_PLAYER,
			"effect_value": 20
		},
		{
			"id": "chrono_strike",
			"name": "Chrono Strike",
			"description": "Deal 25 damage to leftmost enemy",
			"energy_cost": 0,
			"effect_type": EffectType.DAMAGE_ENEMY,
			"effect_value": 25
		},
		{
			"id": "time_fracture",
			"name": "Time Fracture",
			"description": "Deal 10 damage to all enemies",
			"energy_cost": 0,
			"effect_type": EffectType.DAMAGE_ALL_ENEMIES,
			"effect_value": 10
		},
		{
			"id": "future_sight",
			"name": "Future Sight",
			"description": "Increase damage by 10 this turn",
			"energy_cost": 0,
			"effect_type": EffectType.BOOST_DAMAGE,
			"effect_value": 10
		}
	]

static func get_card_by_id(card_id: String) -> Dictionary:
	"""Get a specific card by its ID"""
	for card in get_all_cards():
		if card["id"] == card_id:
			return card
	return {}
