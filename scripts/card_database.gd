extends Object
class_name CardDatabase

# Card timeline types
enum TimelineType {
	PAST,
	PRESENT,
	FUTURE
}

# Card effect types
enum EffectType {
	# PRESENT EFFECTS (direct actions on Present)
	HEAL_PLAYER,           # Restore player HP
	DAMAGE_ENEMY,          # Deal damage to target enemy
	DAMAGE_ALL_ENEMIES,    # Deal damage to all enemies
	BOOST_DAMAGE,          # Increase player damage this turn
	ENEMY_SWAP,            # Swap positions of two enemies
	
	# PAST EFFECTS (interact with Past timeline)
	HP_SWAP_FROM_PAST,     # Set Present HP to Past HP value
	SUMMON_PAST_TWIN,      # Spawn Past copy that fights alongside you
	CONSCRIPT_PAST_ENEMY,  # Take control of Past enemy for this turn
		WOUND_TRANSFER,        # Deal damage = damage enemy took last turn
	
	# FUTURE EFFECTS (interact with Future predictions)
	REDIRECT_FUTURE_ATTACK,  # Change enemy attack target to another enemy
	CHAOS_INJECTION,         # 2 random enemies miss their attacks
	FUTURE_SELF_AID,         # Borrow 25 HP from Future (risky!)
	TIMELINE_SCRAMBLE        # Random combat - enemies AND player can miss
}

# Card definitions
static func get_all_cards() -> Array:
	"""Returns array of all available cards organized by timeline type"""
	return [
		# ===== PAST CARDS =====
		{
			"id": "hp_swap_past",
			"name": "HP Swap from Past",
			"description": "Set your HP to what it was last turn",
			"timeline_type": TimelineType.PAST,
			"effect_type": EffectType.HP_SWAP_FROM_PAST,
			"effect_value": 0,
			"time_cost": 8
		},
		{
			"id": "conscript_enemy",
			"name": "Conscript Past Enemy",
			"description": "Enemy fights for you this turn",
			"timeline_type": TimelineType.PAST,
			"effect_type": EffectType.CONSCRIPT_PAST_ENEMY,
			"effect_value": 0,
			"time_cost": 12
		},
		{
			"id": "wound_transfer",
			"name": "Wound Transfer",
			"description": "Click enemy in PAST to deal matching damage",
			"timeline_type": TimelineType.PAST,
			"effect_type": EffectType.WOUND_TRANSFER,
			"effect_value": 0,
			"time_cost": 10
		},

		# ===== PRESENT CARDS =====
		{
			"id": "chrono_strike",
			"name": "Chrono Strike",
			"description": "Click enemy in PRESENT to deal 25 damage",
			"timeline_type": TimelineType.PRESENT,
			"effect_type": EffectType.DAMAGE_ENEMY,
			"effect_value": 25,
			"time_cost": 12
		},
		{
			"id": "time_fracture",
			"name": "Time Fracture",
			"description": "Deal 10 damage to all enemies",
			"timeline_type": TimelineType.PRESENT,
			"effect_type": EffectType.DAMAGE_ALL_ENEMIES,
			"effect_value": 10,
			"time_cost": 15
		},
		{
			"id": "future_sight",
			"name": "Future Sight",
			"description": "Increase damage by 10 this turn only",
			"timeline_type": TimelineType.PRESENT,
			"effect_type": EffectType.BOOST_DAMAGE,
			"effect_value": 10,
			"time_cost": 8
		},
		{
			"id": "temporal_heal",
			"name": "Meal Time",
			"description": "Restore 20 HP",
			"timeline_type": TimelineType.PRESENT,
			"effect_type": EffectType.HEAL_PLAYER,
			"effect_value": 20,
			"time_cost": 6
		},
		{
			"id": "enemy_swap",
			"name": "Enemy Swap",
			"description": "Swap positions of two enemies",
			"timeline_type": TimelineType.PRESENT,
			"effect_type": EffectType.ENEMY_SWAP,
			"effect_value": 0,
			"time_cost": 5
		},

		# ===== FUTURE CARDS =====
		{
			"id": "redirect_attack",
			"name": "Redirect Future Attack",
			"description": "Enemy attacks another enemy in Future",
			"timeline_type": TimelineType.FUTURE,
			"effect_type": EffectType.REDIRECT_FUTURE_ATTACK,
			"effect_value": 0,
			"time_cost": 14
		},
		{
			"id": "chaos_injection",
			"name": "Chaos Injection",
			"description": "2 random enemies miss in Future",
			"timeline_type": TimelineType.FUTURE,
			"effect_type": EffectType.CHAOS_INJECTION,
			"effect_value": 2,  # Number of enemies that will miss
			"time_cost": 16
		},
		{
			"id": "future_aid",
			"name": "Future Self Aid",
			"description": "Borrow 25 HP from Future (HP ≤ 25 only)",
			"timeline_type": TimelineType.FUTURE,
			"effect_type": EffectType.FUTURE_SELF_AID,
			"effect_value": 25,
			"time_cost": 10
		},
		{
			"id": "timeline_scramble",
			"name": "Timeline Scramble",
			"description": "Randomize Future combat - all can miss!",
			"timeline_type": TimelineType.FUTURE,
			"effect_type": EffectType.TIMELINE_SCRAMBLE,
			"effect_value": 0.4,  # Miss chance percentage
			"time_cost": 18
		}
	]

static func get_card_by_id(card_id: String) -> Dictionary:
	"""Get a specific card by its ID"""
	for card in get_all_cards():
		if card["id"] == card_id:
			return card
	return {}

static func get_cards_by_timeline(timeline_type: TimelineType) -> Array:
	"""Get all cards for a specific timeline type"""
	var cards = []
	for card in get_all_cards():
		if card["timeline_type"] == timeline_type:
			cards.append(card)
	return cards