extends Node
class_name CardManager

## CardManager - Handles all card deck management and card effects
## Extracted from game_manager.gd to create a dedicated card system
## Uses Events for communication and GameState for data access

# ============================================================================
# CARD DECK CLASS
# ============================================================================

class CardDeck:
	"""Manages a deck of cards for one timeline type"""
	var timeline_type: int  # CardDatabase.TimelineType enum
	var container: Control  # UI container for this deck
	var cards: Array = []   # Card data array (all cards in deck)
	var card_nodes: Array = []  # Visual card nodes (stacked)

	func _init(type: int, cont: Control):
		timeline_type = type
		container = cont

	func get_top_card() -> Node:
		"""Get the top (visible) card node"""
		if card_nodes.size() > 0:
			return card_nodes[card_nodes.size() - 1]
		return null

	func get_top_card_data() -> Dictionary:
		"""Get the top card's data"""
		if cards.size() > 0:
			return cards[cards.size() - 1]
		return {}

# ============================================================================
# REFERENCES (Set by GameController)
# ============================================================================

var past_deck_container: Control
var present_deck_container: Control
var future_deck_container: Control

# Timeline panel references (for applying effects)
var timeline_panels: Array = []  # [past, present, future] panels

# ============================================================================
# CARD DECK OBJECTS
# ============================================================================

var past_deck: CardDeck
var present_deck: CardDeck
var future_deck: CardDeck

# ============================================================================
# CONSTANTS
# ============================================================================

const CARD_SCENE = preload("res://scenes/card.tscn")

# ============================================================================
# PUBLIC API
# ============================================================================

## Initialize three card decks from database
func initialize_decks() -> void:
	print("\n=== Setting up card decks ===")

	# Create deck objects
	past_deck = CardDeck.new(CardDatabase.TimelineType.PAST, past_deck_container)
	present_deck = CardDeck.new(CardDatabase.TimelineType.PRESENT, present_deck_container)
	future_deck = CardDeck.new(CardDatabase.TimelineType.FUTURE, future_deck_container)

	# Get all cards from database
	var all_cards = CardDatabase.get_all_cards()

	# Organize cards by timeline type
	for card_data in all_cards:
		var timeline_type = card_data.get("timeline_type")

		match timeline_type:
			CardDatabase.TimelineType.PAST:
				past_deck.cards.append(card_data)
			CardDatabase.TimelineType.PRESENT:
				present_deck.cards.append(card_data)
			CardDatabase.TimelineType.FUTURE:
				future_deck.cards.append(card_data)

	# Shuffle each deck
	past_deck.cards.shuffle()
	present_deck.cards.shuffle()
	future_deck.cards.shuffle()

	# Create visual cards for each deck
	create_deck_visuals(past_deck)
	create_deck_visuals(present_deck)
	create_deck_visuals(future_deck)

	# Initialize card affordability based on timer
	update_affordability(GameState.time_remaining)

	print("✅ Decks created:")
	print("  Past: ", past_deck.cards.size(), " cards")
	print("  Present: ", present_deck.cards.size(), " cards")
	print("  Future: ", future_deck.cards.size(), " cards")


## Handle card click event
func on_card_played(card_data: Dictionary) -> void:
	var time_cost = card_data.get("time_cost", 0)

	# Check if player has enough time
	if GameState.time_remaining < time_cost:
		print("Not enough time for card: ", card_data.get("name", "Unknown"))
		return

	print("Playing card: ", card_data.get("name", "Unknown"), " (Cost: ", time_cost, "s)")

	# Find which deck this card belongs to
	var source_deck: CardDeck = null
	if card_data.get("timeline_type") == CardDatabase.TimelineType.PAST:
		source_deck = past_deck
	elif card_data.get("timeline_type") == CardDatabase.TimelineType.PRESENT:
		source_deck = present_deck
	elif card_data.get("timeline_type") == CardDatabase.TimelineType.FUTURE:
		source_deck = future_deck

	if not source_deck:
		print("ERROR: Could not find source deck for card!")
		return

	# CHECK IF CARD REQUIRES TARGETING
	if card_requires_targeting(card_data):
		print("  🎯 Card requires targeting - entering targeting mode")
		Events.card_targeting_started.emit(card_data)
		return  # Don't apply effect yet - wait for target selection

	# INSTANT EFFECT CARDS (no targeting required)
	_execute_instant_card(card_data, source_deck)


## Apply instant card effects (no targeting)
func apply_card_effect_instant(card_data: Dictionary) -> void:
	var present_tp = _get_timeline_panel("present")
	var past_tp = _get_timeline_panel("past")
	var effect_type = card_data.get("effect_type")
	var effect_value = card_data.get("effect_value", 0)

	match effect_type:
		# ===== PRESENT EFFECTS =====
		CardDatabase.EffectType.HEAL_PLAYER:
			var current_hp = present_tp.state["player"]["hp"]
			var max_hp = present_tp.state["player"]["max_hp"]
			present_tp.state["player"]["hp"] = min(current_hp + effect_value, max_hp)
			print("Healed ", effect_value, " HP")
			Events.hp_updated.emit(null, present_tp.state["player"]["hp"])

		CardDatabase.EffectType.DAMAGE_ENEMY:
			if present_tp.state["enemies"].size() > 0:
				present_tp.state["enemies"][0]["hp"] -= effect_value
				if present_tp.state["enemies"][0]["hp"] <= 0:
					present_tp.state["enemies"].remove_at(0)
				print("Dealt ", effect_value, " damage")

		CardDatabase.EffectType.DAMAGE_ALL_ENEMIES:
			var defeated = []
			for enemy in present_tp.state["enemies"]:
				enemy["hp"] -= effect_value
				if enemy["hp"] <= 0:
					defeated.append(enemy)
			for enemy in defeated:
				present_tp.state["enemies"].erase(enemy)
			print("Dealt ", effect_value, " damage to all")

		CardDatabase.EffectType.BOOST_DAMAGE:
			present_tp.state["player"]["damage"] += effect_value
			GameState.damage_boost_active = true  # Mark for reset next turn
			print("Boosted damage by ", effect_value, " (will reset next turn)")
			Events.damage_display_updated.emit(present_tp.state["player"]["damage"])

		CardDatabase.EffectType.ENEMY_SWAP:
			if present_tp.state["enemies"].size() >= 2:
				# Swap first two enemies
				var temp = present_tp.state["enemies"][0]
				present_tp.state["enemies"][0] = present_tp.state["enemies"][1]
				present_tp.state["enemies"][1] = temp
				print("Swapped enemy positions")

		# ===== PAST EFFECTS =====
		CardDatabase.EffectType.HP_SWAP_FROM_PAST:
			if past_tp and not past_tp.state.is_empty():
				var past_hp = past_tp.state["player"]["hp"]
				present_tp.state["player"]["hp"] = past_hp
				print("HP swapped from Past: now at ", past_hp, " HP")
				Events.hp_updated.emit(null, past_hp)
			else:
				print("No Past state available - card has no effect")

		CardDatabase.EffectType.SUMMON_PAST_TWIN:
			if past_tp and not past_tp.state.is_empty():
				print("\n🔄 Summoning Past Twin")

				# Create twin entity data based on PAST player stats
				var twin_data = {
					"name": "Past Twin",
					"hp": int(past_tp.state["player"]["hp"] * 0.5),
					"max_hp": int(past_tp.state["player"]["max_hp"] * 0.5),
					"damage": int(past_tp.state["player"]["damage"] * 0.5),
					"is_twin": true
				}

				print("  Twin stats: HP=", twin_data["hp"], " DMG=", twin_data["damage"])
				present_tp.state["twin"] = twin_data
				print("  ✅ Past Twin summoned to fight alongside you!")

		CardDatabase.EffectType.CONSCRIPT_PAST_ENEMY:
			if past_tp and not past_tp.state.is_empty() and past_tp.state["enemies"].size() > 0:
				var conscripted = past_tp.state["enemies"][0].duplicate()
				conscripted["name"] = "Conscripted " + conscripted["name"]
				print("Conscripted ", conscripted["name"], " to fight for you")
				if present_tp.state["enemies"].size() > 0:
					present_tp.state["enemies"][0]["hp"] -= conscripted["damage"]
					if present_tp.state["enemies"][0]["hp"] <= 0:
						present_tp.state["enemies"].remove_at(0)

		CardDatabase.EffectType.WOUND_TRANSFER:
			if past_tp and not past_tp.state.is_empty():
				if present_tp.state["enemies"].size() > 0 and past_tp.state["enemies"].size() > 0:
					var present_enemy = present_tp.state["enemies"][0]
					var past_enemy = past_tp.state["enemies"][0]
					var damage_taken = past_enemy["hp"] - present_enemy["hp"]
					if damage_taken > 0:
						present_enemy["hp"] -= damage_taken
						print("Transferred ", damage_taken, " wound damage")
						if present_enemy["hp"] <= 0:
							present_tp.state["enemies"].remove_at(0)

		# ===== FUTURE EFFECTS =====
		CardDatabase.EffectType.REDIRECT_FUTURE_ATTACK:
			if present_tp.state["enemies"].size() >= 2:
				GameState.future_redirect_flag = {
					"from_enemy": 0,
					"to_enemy": 1
				}
				print("Future: Enemy 0 will attack Enemy 1")

		CardDatabase.EffectType.CHAOS_INJECTION:
			var enemy_count = present_tp.state["enemies"].size()
			if enemy_count > 0:
				var num_to_miss = min(effect_value, enemy_count)
				var indices = range(enemy_count)
				indices.shuffle()

				GameState.future_miss_flags.clear()
				for i in range(num_to_miss):
					GameState.future_miss_flags[indices[i]] = true
				print("Chaos Injection: ", num_to_miss, " enemies will miss")

		CardDatabase.EffectType.FUTURE_SELF_AID:
			if present_tp.state["player"]["hp"] <= 25:
				present_tp.state["player"]["hp"] += effect_value
				print("Borrowed ", effect_value, " HP from Future")
				Events.hp_updated.emit(null, present_tp.state["player"]["hp"])
			else:
				print("Cannot use Future Self Aid - HP too high (must be ≤ 25)")

		CardDatabase.EffectType.TIMELINE_SCRAMBLE:
			var enemy_count = present_tp.state["enemies"].size()
			if enemy_count > 0:
				for i in range(enemy_count):
					if randf() < effect_value:
						GameState.future_miss_flags[i] = true
			print("Timeline Scramble: All attacks randomized in Future!")


## Apply targeted card effects
func apply_card_effect_targeted(card_data: Dictionary, targets: Array) -> void:
	var present_tp = _get_timeline_panel("present")
	var past_tp = _get_timeline_panel("past")
	var effect_type = card_data.get("effect_type")
	var effect_value = card_data.get("effect_value", 0)

	match effect_type:
		CardDatabase.EffectType.DAMAGE_ENEMY:
			if targets.size() > 0 and is_instance_valid(targets[0]):
				var target_entity = targets[0]
				for i in range(present_tp.state["enemies"].size()):
					if present_tp.state["enemies"][i]["name"] == target_entity.entity_data["name"]:
						present_tp.state["enemies"][i]["hp"] -= effect_value
						print("Dealt ", effect_value, " damage to ", present_tp.state["enemies"][i]["name"])
						Events.damage_dealt.emit(target_entity, effect_value)
						if present_tp.state["enemies"][i]["hp"] <= 0:
							present_tp.state["enemies"].remove_at(i)
							print("  Enemy defeated!")
						break

		CardDatabase.EffectType.ENEMY_SWAP:
			if targets.size() >= 2 and is_instance_valid(targets[0]) and is_instance_valid(targets[1]):
				var enemy1_name = targets[0].entity_data["name"]
				var enemy2_name = targets[1].entity_data["name"]
				var idx1 = -1
				var idx2 = -1

				for i in range(present_tp.state["enemies"].size()):
					if present_tp.state["enemies"][i]["name"] == enemy1_name:
						idx1 = i
					if present_tp.state["enemies"][i]["name"] == enemy2_name:
						idx2 = i

				if idx1 >= 0 and idx2 >= 0:
					var temp = present_tp.state["enemies"][idx1]
					present_tp.state["enemies"][idx1] = present_tp.state["enemies"][idx2]
					present_tp.state["enemies"][idx2] = temp
					print("Swapped ", enemy1_name, " and ", enemy2_name)

		CardDatabase.EffectType.REDIRECT_FUTURE_ATTACK:
			if targets.size() >= 2:
				var source_enemy = targets[0]
				var target_enemy = targets[1]
				var source_idx = -1
				var target_idx = -1

				for i in range(present_tp.state["enemies"].size()):
					if present_tp.state["enemies"][i]["name"] == source_enemy.entity_data["name"]:
						source_idx = i
					if present_tp.state["enemies"][i]["name"] == target_enemy.entity_data["name"]:
						target_idx = i

				if source_idx >= 0 and target_idx >= 0:
					GameState.future_redirect_flag = {
						"from_enemy": source_idx,
						"to_enemy": target_idx
					}
					print("Future: Enemy ", source_idx, " will attack Enemy ", target_idx)

		CardDatabase.EffectType.WOUND_TRANSFER:
			if targets.size() > 0 and past_tp and not past_tp.state.is_empty():
				var target_entity = targets[0]
				var target_name = target_entity.entity_data["name"]

				for i in range(present_tp.state["enemies"].size()):
					if present_tp.state["enemies"][i]["name"] == target_name:
						for past_enemy in past_tp.state.get("enemies", []):
							if past_enemy["name"] == target_name:
								var damage_taken = past_enemy["hp"] - present_tp.state["enemies"][i]["hp"]
								if damage_taken > 0:
									present_tp.state["enemies"][i]["hp"] -= damage_taken
									print("Transferred ", damage_taken, " wound damage to ", target_name)
									if present_tp.state["enemies"][i]["hp"] <= 0:
										present_tp.state["enemies"].remove_at(i)
								break
						break

		CardDatabase.EffectType.CONSCRIPT_PAST_ENEMY:
			if targets.size() > 0 and past_tp and not past_tp.state.is_empty():
				var target_entity = targets[0]
				var conscripted_data = target_entity.entity_data.duplicate()

				print("🔄 Conscripting ", conscripted_data["name"], " to fight in player's place")
				GameState.original_player_data = present_tp.state["player"].duplicate(true)
				print("  Stored original player: HP=", GameState.original_player_data["hp"])


## Recycle used card back to deck
func recycle_used_card(deck: CardDeck) -> void:
	print("♻️ Recycling card from deck (simple mode)...")

	var played_card_data = deck.get_top_card_data()

	if played_card_data.is_empty():
		print("  ERROR: No card data to recycle")
		return

	print("  Playing card: ", played_card_data.get("name", "Unknown"))

	# Remove card from end (it was the top)
	deck.cards.remove_at(deck.cards.size() - 1)

	# Add card to front (index 0)
	deck.cards.insert(0, played_card_data)

	# Recreate all card visuals
	create_deck_visuals(deck)

	Events.card_recycled.emit(played_card_data)
	print("  ✅ Card recycled")


## Update which cards are affordable based on time remaining
func update_affordability(time_remaining: float) -> void:
	for deck in [past_deck, present_deck, future_deck]:
		if not deck:
			continue
		var top_card = deck.get_top_card()
		if top_card and is_instance_valid(top_card):
			top_card.update_affordability(time_remaining)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

## Check if card needs target selection
func card_requires_targeting(card_data: Dictionary) -> bool:
	var effect_type = card_data.get("effect_type")

	match effect_type:
		CardDatabase.EffectType.DAMAGE_ENEMY:
			return true
		CardDatabase.EffectType.ENEMY_SWAP:
			return true
		CardDatabase.EffectType.REDIRECT_FUTURE_ATTACK:
			return true
		CardDatabase.EffectType.WOUND_TRANSFER:
			return true
		CardDatabase.EffectType.CONSCRIPT_PAST_ENEMY:
			return true
		_:
			return false


## Get number of targets required
func get_required_target_count(card_data: Dictionary) -> int:
	var effect_type = card_data.get("effect_type")

	match effect_type:
		CardDatabase.EffectType.DAMAGE_ENEMY:
			return 1
		CardDatabase.EffectType.ENEMY_SWAP:
			return 2
		CardDatabase.EffectType.REDIRECT_FUTURE_ATTACK:
			return 2
		CardDatabase.EffectType.WOUND_TRANSFER:
			return 1
		CardDatabase.EffectType.CONSCRIPT_PAST_ENEMY:
			return 1
		_:
			return 0


## Get which timelines can be targeted
func get_valid_target_timelines(card_data: Dictionary) -> Array:
	var effect_type = card_data.get("effect_type")

	match effect_type:
		CardDatabase.EffectType.DAMAGE_ENEMY:
			return ["present"]
		CardDatabase.EffectType.ENEMY_SWAP:
			return ["present"]
		CardDatabase.EffectType.REDIRECT_FUTURE_ATTACK:
			return ["present"]
		CardDatabase.EffectType.WOUND_TRANSFER:
			return ["past"]
		CardDatabase.EffectType.CONSCRIPT_PAST_ENEMY:
			return ["past"]
		_:
			return []


## Create stacked card visuals for a deck
func create_deck_visuals(deck: CardDeck) -> void:
	# Clear old nodes
	for node in deck.card_nodes:
		if node and is_instance_valid(node):
			node.queue_free()
	deck.card_nodes.clear()

	# Create cards in stack (bottom to top)
	for i in range(deck.cards.size()):
		var card_data = deck.cards[i]
		var card_node = CARD_SCENE.instantiate()

		# Position cards in stack (small vertical offset)
		card_node.position = Vector2(0, 40 + i * 3)

		deck.container.add_child(card_node)
		card_node.setup(card_data)

		# Only top card is interactive
		var is_top_card = (i == deck.cards.size() - 1)
		if is_top_card:
			card_node.card_clicked.connect(on_card_played)
			card_node.mouse_filter = Control.MOUSE_FILTER_STOP
			card_node.modulate = Color(0.4, 0.4, 0.4, 0.8)
		else:
			card_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_node.modulate = Color(0.2, 0.2, 0.2, 0.6)
			card_node.z_index = -1 - i

		deck.card_nodes.append(card_node)

	print("  Created ", deck.card_nodes.size(), " visual cards for deck")

# ============================================================================
# PRIVATE HELPERS
# ============================================================================

## Execute instant card (no targeting)
func _execute_instant_card(card_data: Dictionary, source_deck: CardDeck) -> void:
	var time_cost = card_data.get("time_cost", 0)

	# Mark card as used
	var card_node = source_deck.get_top_card()
	if card_node and is_instance_valid(card_node):
		card_node.mark_as_used()

	# Deduct time cost
	GameState.time_remaining -= time_cost
	if GameState.time_remaining < 0:
		GameState.time_remaining = 0
	Events.timer_updated.emit(GameState.time_remaining)

	# Update affordability
	update_affordability(GameState.time_remaining)

	# Apply card effect
	apply_card_effect_instant(card_data)

	# Recycle card
	recycle_used_card(source_deck)

	# Emit event
	Events.card_played.emit(card_data)

	print("  ✅ Card effect applied")


## Get timeline panel by type
func _get_timeline_panel(timeline_type: String):
	if timeline_panels.size() == 0:
		return null

	for panel in timeline_panels:
		if panel.timeline_type == timeline_type:
			return panel
	return null
