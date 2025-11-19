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
		var top_card = source_deck.get_top_card()
		Events.card_targeting_started.emit(card_data, top_card, source_deck)
		return  # Don't apply effect yet - wait for target selection

	# INSTANT EFFECT CARDS (no targeting required)
	_execute_instant_card(card_data, source_deck)


## Apply instant card effects (no targeting)
func apply_card_effect_instant(card_data: Dictionary) -> void:
	var future_tp = _get_timeline_panel("future")
	var present_tp = _get_timeline_panel("present")
	var past_tp = _get_timeline_panel("past")
	var effect_type = card_data.get("effect_type")
	var effect_value = card_data.get("effect_value", 0)

	match effect_type:
		# ===== PRESENT EFFECTS =====
		CardDatabase.EffectType.HEAL_PLAYER:
			# Only heal if real player is in PRESENT timeline
			var player_entity = null
			for entity in present_tp.entity_data_list:
				if entity.unique_id == GameState.player_unique_id:
					player_entity = entity
					break

			if player_entity:
				player_entity.heal(effect_value)
				print("Healed ", effect_value, " HP")
				Events.hp_updated.emit(null, player_entity.hp)
				# Update visual display
				_update_entity_visuals(present_tp, player_entity)
				# Sync to backwards-compatible state
				present_tp.state = present_tp.get_state_dict()
			else:
				print("Cannot heal - player not in PRESENT timeline (possibly conscripted to PAST)")
			
			Events.future_recalculation_requested.emit()
			GameState.ensure_real_future_initialized(future_tp)

		CardDatabase.EffectType.DAMAGE_ALL_ENEMIES:
			var enemies = _get_enemy_entities_data(present_tp)
			var defeated = []
			for enemy in enemies:
				var died = enemy.take_damage(effect_value)
				if died:
					defeated.append(enemy)
				else:
					# Update visual display for living enemies
					_update_entity_visuals(present_tp, enemy)
					_update_entity_visuals(future_tp, enemy)
			for enemy in defeated:
				present_tp.entity_data_list.erase(enemy)
				future_tp.entity_data_list.erase(enemy)
				_update_entity_visuals(present_tp, enemy)
				_update_entity_visuals(future_tp, enemy)
			print("Dealt ", effect_value, " damage to all enemies")
			# Sync to backwards-compatible state
			present_tp.state = present_tp.get_state_dict()

			Events.future_recalculation_requested.emit()
			GameState.ensure_real_future_initialized(future_tp)

		CardDatabase.EffectType.BOOST_DAMAGE:
			var player_entity = _get_player_entity_data(present_tp)
			if player_entity:
				# Store original damage before boost
				var original_damage = player_entity.damage
				player_entity.damage += effect_value
				print("Boosted damage by ", effect_value, " (temporarily: ", original_damage, " → ", player_entity.damage, ")")
				Events.damage_display_updated.emit(player_entity.damage)
				# Update visual display
				_update_entity_visuals(present_tp, player_entity)
				# Sync to backwards-compatible state
				present_tp.state = present_tp.get_state_dict()

				# Request future recalculation to show boosted future FIRST
				Events.future_recalculation_requested.emit()

				# Initialize or update REAL_FUTURE from FUTURE panel (after recalculation)
				GameState.ensure_real_future_initialized(future_tp)
				# Revert damage boost for player in REAL_FUTURE
				var modified = GameState.modify_real_future_entity(player_entity.unique_id, func(e):
					e.damage = original_damage
				)
				if modified:
					print("  📍 REAL_FUTURE updated (damage will revert to ", original_damage, " after combat)")

		# ===== PAST EFFECTS =====
		CardDatabase.EffectType.HP_SWAP_FROM_PAST:
			var player_entity = null
			for entity in present_tp.entity_data_list:
				if entity.unique_id == GameState.player_unique_id:
					player_entity = entity
					break

			if player_entity and past_tp and past_tp.entity_data_list.size() > 0:
				var past_player = _get_player_entity_data(past_tp)
				var present_player = _get_player_entity_data(present_tp)
				if past_player and present_player:
					if present_player.hp >= past_player.hp:
						present_player.hp = past_player.hp
					else:
						present_player.hp = present_player.max_hp
					print("HP swapped from Past: now at ", present_player.hp, " HP")
					Events.hp_updated.emit(null, present_player.hp)
					# Update visual display
					_update_entity_visuals(present_tp, present_player)
					Events.future_recalculation_requested.emit()
					GameState.ensure_real_future_initialized(future_tp)
					# Sync to backwards-compatible state
					present_tp.state = present_tp.get_state_dict()
			else:
				print("Cannot heal - player not in PRESENT timeline (possibly conscripted to PAST)")

		CardDatabase.EffectType.SUMMON_PAST_TWIN:
			if past_tp and past_tp.entity_data_list.size() > 0:
				var past_player = _get_player_entity_data(past_tp)
				if past_player:
					print("\n🔄 Summoning Past Twin")

					# Create twin using EntityData
					var twin = EntityData.create_twin(past_player)

					# Find smart position for twin
					var present_player = _get_player_entity_data(present_tp)
					if present_player:
						var twin_pos = _find_smart_position_for_twin(present_tp, present_player)
						twin.grid_row = twin_pos.x
						twin.grid_col = twin_pos.y

					# Add twin to Present panel
					present_tp.entity_data_list.append(twin)
					# Update cell_entities grid
					if twin.grid_row >= 0 and twin.grid_col >= 0:
						present_tp.cell_entities[twin.grid_row][twin.grid_col] = twin

					print("  Twin stats: HP=", twin.hp, " DMG=", twin.damage)
					print("  Twin positioned at (", twin.grid_row, ", ", twin.grid_col, ")")
					print("  ✅ Past Twin summoned to fight alongside you!")

					# Sync to backwards-compatible state
					present_tp.state = present_tp.get_state_dict()

					# Recalculate targets so twin can attack during combat
					TargetCalculator.calculate_targets(present_tp)

					# Request future recalculation to show twin in predicted future FIRST
					Events.future_recalculation_requested.emit()

					# Initialize or update REAL_FUTURE from FUTURE panel (after recalculation)
					GameState.ensure_real_future_initialized(future_tp)

		CardDatabase.EffectType.WOUND_TRANSFER:
			var past_enemies = _get_enemy_entities_data(past_tp) if past_tp else []
			var present_enemies = _get_enemy_entities_data(present_tp)
			if past_enemies.size() > 0 and present_enemies.size() > 0:
				var past_enemy = past_enemies[0]
				var present_enemy = present_enemies[0]
				# Calculate wounds (damage taken) in PAST and PRESENT
				var past_wounds = past_enemy.max_hp - past_enemy.hp
				var present_wounds = present_enemy.max_hp - present_enemy.hp
				# Transfer the difference from PAST to PRESENT
				var damage_to_transfer = past_wounds - present_wounds
				if damage_to_transfer > 0:
					var died = present_enemy.take_damage(damage_to_transfer)
					print("Transferred ", damage_to_transfer, " wound damage from PAST (", past_wounds, " wounds) to PRESENT (", present_wounds, " wounds)")
					if died:
						present_tp.entity_data_list.erase(present_enemy)
						# Clear from grid
						if present_enemy.grid_row >= 0 and present_enemy.grid_col >= 0:
							present_tp.cell_entities[present_enemy.grid_row][present_enemy.grid_col] = null
					else:
						# Update visual display for damaged enemy
						_update_entity_visuals(present_tp, present_enemy)
				else:
					print("No wounds to transfer (PAST: ", past_wounds, " wounds, PRESENT: ", present_wounds, " wounds)")
				# Sync to backwards-compatible state
				present_tp.state = present_tp.get_state_dict()
				# Recalculate future since enemy HP changed
				Events.future_recalculation_requested.emit()
				GameState.ensure_real_future_initialized(future_tp)

		# ===== FUTURE EFFECTS =====
		CardDatabase.EffectType.CHAOS_INJECTION:
			var enemies = _get_enemy_entities_data(present_tp)
			var enemy_count = enemies.size()
			if enemy_count > 0:
				var num_to_miss = min(effect_value, enemy_count)
				# Shuffle enemy array to select random enemies
				var shuffled_enemies = enemies.duplicate()
				shuffled_enemies.shuffle()

				# Track which enemies will miss
				var missing_enemy_ids = []

				# Set will_miss on random enemies
				for i in range(num_to_miss):
					shuffled_enemies[i].will_miss = true
					missing_enemy_ids.append(shuffled_enemies[i].unique_id)
					print("Chaos Injection: ", shuffled_enemies[i].entity_name, " will miss next turn")

				# Sync to backwards-compatible state
				present_tp.state = present_tp.get_state_dict()

				# Request future recalculation to apply miss flags in FUTURE FIRST
				Events.future_recalculation_requested.emit()

				# Initialize or update REAL_FUTURE from FUTURE panel (after recalculation)
				GameState.ensure_real_future_initialized(future_tp)
				# Clear will_miss for affected enemies in REAL_FUTURE (they only miss one turn)
				for enemy_id in missing_enemy_ids:
					GameState.modify_real_future_entity(enemy_id, func(e):
						e.will_miss = false
					)
				print("  📍 REAL_FUTURE updated (enemies will only miss one turn)")

		CardDatabase.EffectType.FUTURE_SELF_AID:
			var player_entity = _get_player_entity_data(present_tp)
			if player_entity:
				if player_entity.hp <= 25:
					player_entity.heal(effect_value)
					print("Borrowed ", effect_value, " HP from Future")
					Events.hp_updated.emit(null, player_entity.hp)
					# Update visual display
					_update_entity_visuals(present_tp, player_entity)
					# Sync to backwards-compatible state
					present_tp.state = present_tp.get_state_dict()
				else:
					print("Cannot use Future Self Aid - HP too high (must be ≤ 25)")

		CardDatabase.EffectType.TIMELINE_SCRAMBLE:
			# Apply randomization to ALL entities (enemies and player)
			var miss_count = 0
			var missing_entity_ids = []
			for entity in present_tp.entity_data_list:
				if randf() < effect_value:
					entity.will_miss = true
					missing_entity_ids.append(entity.unique_id)
					miss_count += 1
					print("Timeline Scramble: ", entity.entity_name, " will miss")
			print("Timeline Scramble: ", miss_count, " entities will miss in Future!")
			# Sync to backwards-compatible state
			present_tp.state = present_tp.get_state_dict()

			# Request future recalculation to apply miss flags in FUTURE FIRST
			Events.future_recalculation_requested.emit()

			# Initialize or update REAL_FUTURE from FUTURE panel (after recalculation)
			GameState.ensure_real_future_initialized(future_tp)
			# Clear will_miss for affected entities in REAL_FUTURE (they only miss one turn)
			for entity_id in missing_entity_ids:
				GameState.modify_real_future_entity(entity_id, func(e):
					e.will_miss = false
				)
			print("  📍 REAL_FUTURE updated (entities will only miss one turn)")


## Apply targeted card effects
func apply_card_effect_targeted(card_data: Dictionary, targets: Array) -> void:
	var future_tp = _get_timeline_panel("future")
	var present_tp = _get_timeline_panel("present")
	var past_tp = _get_timeline_panel("past")
	var effect_type = card_data.get("effect_type")
	var effect_value = card_data.get("effect_value", 0)

	match effect_type:
		CardDatabase.EffectType.DAMAGE_ENEMY:
			if targets.size() > 0 and is_instance_valid(targets[0]):
				var target_visual = targets[0]
				var target_unique_id = target_visual.entity_data.get("unique_id", "")

				# Find EntityData by unique_id
				for entity in present_tp.entity_data_list:
					if entity.unique_id == target_unique_id:
						var died = entity.take_damage(effect_value)
						print("Dealt ", effect_value, " damage to ", entity.entity_name)
						Events.damage_dealt.emit(target_visual, effect_value)
						if died:
							present_tp.entity_data_list.erase(entity)
							print("  Enemy defeated!")
						else:
							# Update visual display for living enemies
							_update_entity_visuals(present_tp, entity)
						# Sync to backwards-compatible state
						present_tp.state = present_tp.get_state_dict()
						break
				
				Events.future_recalculation_requested.emit()
				GameState.ensure_real_future_initialized(future_tp)

		CardDatabase.EffectType.ENEMY_SWAP:
			if targets.size() >= 2 and is_instance_valid(targets[0]) and is_instance_valid(targets[1]):
				var enemy1_id = targets[0].entity_data.get("unique_id", "")
				var enemy2_id = targets[1].entity_data.get("unique_id", "")
				var entity1 = null
				var entity2 = null

				# Find EntityData objects by unique_id
				for entity in present_tp.entity_data_list:
					if entity.unique_id == enemy1_id:
						entity1 = entity
					elif entity.unique_id == enemy2_id:
						entity2 = entity

				if entity1 and entity2:
					# Swap grid positions
					var temp_row = entity1.grid_row
					var temp_col = entity1.grid_col
					entity1.grid_row = entity2.grid_row
					entity1.grid_col = entity2.grid_col
					entity2.grid_row = temp_row
					entity2.grid_col = temp_col
					print("Swapped ", entity1.entity_name, " and ", entity2.entity_name)

					# Sync to backwards-compatible state
					present_tp.state = present_tp.get_state_dict()

					# Recalculate targets since positions changed
					TargetCalculator.calculate_targets(present_tp)

					# Request future recalculation to reflect new positions
					Events.future_recalculation_requested.emit()
					GameState.ensure_real_future_initialized(future_tp)

		CardDatabase.EffectType.REDIRECT_FUTURE_ATTACK:
			if targets.size() >= 2:
				var source_enemy_id = targets[0].entity_data.get("unique_id", "")
				var target_enemy_id = targets[1].entity_data.get("unique_id", "")

				# Find target entity name for logging
				var target_name = ""
				for entity in future_tp.entity_data_list:
					if entity.unique_id == target_enemy_id:
						target_name = entity.entity_name
						break

				# Set attack_target_id in PRESENT
				for entity in future_tp.entity_data_list:
					if entity.unique_id == source_enemy_id and entity.is_enemy:
						entity.attack_target_id = target_enemy_id
						_update_entity_visuals(future_tp, entity)
						print("Redirected ", entity.entity_name, " to attack ", target_name)
						break
				
				# Sync to backwards-compatible state
				future_tp.state = future_tp.get_state_dict()

				TargetCalculator.calculate_targets(future_tp)

				# Request future recalculation to show redirect in FUTURE
				Events.future_recalculation_requested.emit()
				GameState.ensure_real_future_initialized(future_tp)

		CardDatabase.EffectType.WOUND_TRANSFER:
			if targets.size() > 0 and past_tp and past_tp.entity_data_list.size() > 0:
				var past_target_visual = targets[0]  # This is the Past entity visual
				var target_unique_id = past_target_visual.entity_data.get("unique_id", "")

				# Find EntityData in Past and Present by unique_id
				var past_entity = null
				var present_entity = null

				for entity in past_tp.entity_data_list:
					if entity.unique_id == target_unique_id and entity.is_enemy:
						past_entity = entity
						break

				for entity in present_tp.entity_data_list:
					if entity.unique_id == target_unique_id and entity.is_enemy:
						present_entity = entity
						break

				if past_entity and present_entity:
					# Calculate wounds (damage taken) in PAST and PRESENT
					var past_wounds = past_entity.max_hp - past_entity.hp
					var present_wounds = present_entity.max_hp - present_entity.hp
					# Transfer the difference from PAST to PRESENT
					var damage_to_transfer = present_wounds - past_wounds
					if damage_to_transfer > 0:
						var died = present_entity.take_damage(damage_to_transfer)
						print("Transferred ", damage_to_transfer, " wound damage to ", present_entity.entity_name, " (PAST: ", past_wounds, " wounds, PRESENT: ", present_wounds, " wounds)")

						# Emit damage event for visual feedback
						var present_visual = _find_entity_by_unique_id_visual(present_tp, target_unique_id)
						if present_visual:
							Events.damage_dealt.emit(present_visual, damage_to_transfer)

						if died:
							present_tp.entity_data_list.erase(present_entity)
							# Clear from grid
							if present_entity.grid_row >= 0 and present_entity.grid_col >= 0:
								present_tp.cell_entities[present_entity.grid_row][present_entity.grid_col] = null
						else:
							# Update visual display for living enemies
							_update_entity_visuals(present_tp, present_entity)
						# Sync to backwards-compatible state
						present_tp.state = present_tp.get_state_dict()
						# Recalculate future since enemy HP changed
						Events.future_recalculation_requested.emit()
					else:
						print("No wounds to transfer to ", present_entity.entity_name, " (PAST: ", past_wounds, " wounds, PRESENT: ", present_wounds, " wounds)")

		CardDatabase.EffectType.CONSCRIPT_PAST_ENEMY:
			if targets.size() > 0 and past_tp and past_tp.entity_data_list.size() > 0:
				var target_visual = targets[0]
				var target_unique_id = target_visual.entity_data.get("unique_id", "")
				
				# Find the enemy in PAST by unique_id
				var past_enemy = null
				for entity in past_tp.entity_data_list:
					if entity.unique_id == target_unique_id and entity.is_enemy:
						past_enemy = entity
						break

				if not past_enemy:
					print("  ERROR: Could not find enemy in PAST timeline")
					return

				print("🔄 Conscripting ", past_enemy.entity_name, " from PAST")

				# Find player entity in PRESENT
				var player_entity = _get_player_entity_data(present_tp)
				if player_entity:
					# 1. Store positions
					var player_row = player_entity.grid_row
					var player_col = player_entity.grid_col
					var past_enemy_row = past_enemy.grid_row
					var past_enemy_col = past_enemy.grid_col

					# 2. Duplicate the enemy for PRESENT (don't modify the original in PAST!)
					var conscripted_enemy = past_enemy.duplicate_entity()
					# Generate new unique_id to avoid conflicts with original enemy
					conscripted_enemy.unique_id = EntityData._generate_uuid()
					conscripted_enemy.grid_row = player_row
					conscripted_enemy.grid_col = player_col
					conscripted_enemy.is_enemy = false
					conscripted_enemy.is_conscripted = true

					# 3. Update player position to enemy's PAST position
					player_entity.grid_row = past_enemy_row
					player_entity.grid_col = past_enemy_col

					# 4. Remove player entity from PRESENT entity_data_list
					present_tp.entity_data_list.erase(player_entity)

					# 5. Remove enemy entity from PAST entity_data_list
					past_tp.entity_data_list.erase(past_enemy)

					# 6. Add conscripted enemy to PRESENT entity_data_list
					present_tp.entity_data_list.append(conscripted_enemy)

					# 7. Add player to PAST entity_data_list
					past_tp.entity_data_list.append(player_entity)

					# 8. Update PRESENT grid - only conscripted enemy at player's old position
					present_tp.cell_entities[player_row][player_col] = conscripted_enemy
					present_tp.cell_entities[past_enemy_row][past_enemy_col] = null

					# 9. Update PAST grid - player at enemy's old position, enemy cell is now empty
					past_tp.cell_entities[past_enemy_row][past_enemy_col] = player_entity

					print("  ✅ Player removed from PRESENT, added to PAST at (", player_entity.grid_row, ", ", player_entity.grid_col, ")")
					print("  ✅ Enemy removed from PAST, conscripted copy added to PRESENT at (", conscripted_enemy.grid_row, ", ", conscripted_enemy.grid_col, ")")
					print("  ", conscripted_enemy.entity_name, " now fights for you!")

					# Sync to backwards-compatible state
					present_tp.state = present_tp.get_state_dict()
					past_tp.state = past_tp.get_state_dict()

					# Recalculate targets so conscripted enemy attacks enemies
					TargetCalculator.calculate_targets(present_tp)

					# Request future recalculation FIRST
					Events.future_recalculation_requested.emit()

					# Initialize or update REAL_FUTURE from FUTURE panel (after recalculation)
					GameState.ensure_real_future_initialized(future_tp)
					# Remove conscripted enemy from REAL_FUTURE (temporary entity)
					GameState.remove_from_real_future(conscripted_enemy.unique_id)
					# Add player back to REAL_FUTURE at original position (player is currently in PAST)
					var future_player = player_entity.duplicate_entity()
					future_player.grid_row = player_row
					future_player.grid_col = player_col
					GameState.add_to_real_future(future_player)
					print("  📍 REAL_FUTURE updated (player will return, conscripted enemy removed)")
					print("  ✅ Conscription complete")


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
			return ["future"]
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


## Find entity by name in a panel
func _find_entity_by_name(panel, entity_name: String):
	if not panel or not is_instance_valid(panel):
		return null

	for entity in panel.entities:
		if entity.entity_data.get("name", "") == entity_name:
			return entity
	return null


## Find player entity in a panel
func _find_player_entity(panel):
	if not panel or not is_instance_valid(panel):
		return null

	for entity in panel.entities:
		if entity.is_player and not entity.entity_data.get("is_twin", false):
			return entity
	return null


## Get player EntityData from a panel (legacy - finds first non-enemy, non-twin)
func _get_player_entity_data(panel) -> EntityData:
	if not panel or not is_instance_valid(panel):
		return null

	for entity in panel.entity_data_list:
		if not entity.is_enemy and not entity.is_twin:
			return entity
	return null


## Get player EntityData by unique_id (searches across all timelines)
func _get_player_by_id() -> Array:
	"""Find the real player entity by GameState.player_unique_id
	Searches PRESENT first, then PAST, then FUTURE
	This handles cases where player has been moved to other timelines (e.g., CONSCRIPT_PAST_ENEMY)
	Returns: [player_entity: EntityData, panel: Panel] or [null, null] if not found
	"""
	var player_id = GameState.player_unique_id
	if player_id == "":
		return [null, null]

	# Search PRESENT first (most common case)
	var present_tp = _get_timeline_panel("present")
	if present_tp:
		for entity in present_tp.entity_data_list:
			if entity.unique_id == player_id:
				return [entity, present_tp]

	# Search PAST (e.g., during CONSCRIPT_PAST_ENEMY)
	var past_tp = _get_timeline_panel("past")
	if past_tp:
		for entity in past_tp.entity_data_list:
			if entity.unique_id == player_id:
				return [entity, past_tp]

	# Search FUTURE (edge case)
	var future_tp = _get_timeline_panel("future")
	if future_tp:
		for entity in future_tp.entity_data_list:
			if entity.unique_id == player_id:
				return [entity, future_tp]

	return [null, null]


## Get all enemy EntityData from a panel
func _get_enemy_entities_data(panel) -> Array:
	var enemies = []
	if not panel or not is_instance_valid(panel):
		return enemies

	for entity in panel.entity_data_list:
		if entity.is_enemy:
			enemies.append(entity)
	return enemies


## Find visual entity node by unique_id
func _find_entity_by_unique_id_visual(panel, unique_id: String):
	if not panel or not is_instance_valid(panel):
		return null

	for entity in panel.entity_nodes:
		if entity and is_instance_valid(entity) and entity.entity_data.get("unique_id") == unique_id:
			return entity
	return null


## Update visual entity node display from EntityData
func _update_entity_visuals(panel, entity_data: EntityData):
	"""Find visual node for EntityData and update its display"""
	if not panel or not entity_data:
		return

	var visual_node = _find_entity_by_unique_id_visual(panel, entity_data.unique_id)
	if visual_node and is_instance_valid(visual_node):
		# Update the visual node's entity_data dictionary
		visual_node.entity_data["hp"] = entity_data.hp
		visual_node.entity_data["max_hp"] = entity_data.max_hp
		visual_node.entity_data["damage"] = entity_data.damage

		# Call update_display to refresh visual
		if visual_node.has_method("update_display"):
			visual_node.update_display()
			print("  🔄 Updated visual display for ", entity_data.entity_name)


## Find smart position for summoned twin
func _find_smart_position_for_twin(panel, player: EntityData) -> Vector2i:
	"""
	Find the best position for a summoned twin:
	1. Find the furthest ally from player's team (not enemy)
	2. Try to place on same row as that ally
	3. Prefer left cell, otherwise right (but not back)
	"""
	# Get all allies (non-enemy entities)
	var allies = []
	for entity in panel.entity_data_list:
		if not entity.is_enemy:
			allies.append(entity)

	# Find furthest ally from player
	var furthest_ally = null
	var max_distance = -1.0
	for ally in allies:
		var distance = sqrt(pow(ally.grid_row - player.grid_row, 2) + pow(ally.grid_col - player.grid_col, 2))
		if distance > max_distance:
			max_distance = distance
			furthest_ally = ally

	# If no allies found, use player position
	var target_row = player.grid_row
	if furthest_ally:
		target_row = furthest_ally.grid_row

	# Try to find empty cell on same row
	# Priority: left of furthest ally, then right
	var positions_to_try = []

	# Left cells (col 0 to furthest_ally.col - 1)
	if furthest_ally:
		for col in range(furthest_ally.grid_col - 1, -1, -1):
			positions_to_try.append(Vector2i(target_row, col))
		# Right cells (col furthest_ally.col + 1 to end)
		for col in range(furthest_ally.grid_col + 1, panel.GRID_COLS):
			positions_to_try.append(Vector2i(target_row, col))
	else:
		# If no furthest ally, try around player
		for col in range(player.grid_col - 1, -1, -1):
			positions_to_try.append(Vector2i(target_row, col))
		for col in range(player.grid_col + 1, panel.GRID_COLS):
			positions_to_try.append(Vector2i(target_row, col))

	# Try positions in order
	for pos in positions_to_try:
		if pos.x >= 0 and pos.x < panel.GRID_ROWS and pos.y >= 0 and pos.y < panel.GRID_COLS:
			if panel.cell_entities[pos.x][pos.y] == null:
				return pos

	# If same row is full, try next row
	for row_offset in [1, -1, 2, -2]:
		var new_row = target_row + row_offset
		if new_row < 0 or new_row >= panel.GRID_ROWS:
			continue

		# Try left cells first, then right
		for col in range(panel.GRID_COLS):
			if panel.cell_entities[new_row][col] == null:
				return Vector2i(new_row, col)

	# Fallback: find any empty cell
	for row in range(panel.GRID_ROWS):
		for col in range(panel.GRID_COLS):
			if panel.cell_entities[row][col] == null:
				return Vector2i(row, col)

	# No empty cells found - return player position (will fail, but at least we tried)
	return Vector2i(player.grid_row, player.grid_col)
