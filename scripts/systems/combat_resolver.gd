extends Node
class_name CombatResolver

## CombatResolver - Handles all combat animations and damage resolution
## Extracted from game_manager.gd to create a dedicated combat system
## Uses Events for communication and GameState for data access

# ============================================================================
# REFERENCES (Set by GameController)
# ============================================================================

var timeline_panels: Array = []

# ============================================================================
# CONSTANTS
# ============================================================================

const ATTACK_DASH_TIME = 0.3
const ATTACK_PAUSE_TIME = 0.1
const RETREAT_TIME = 0.25
const ATTACK_OFFSET = 50.0

# ============================================================================
# PUBLIC API
# ============================================================================

## Main entry point for combat resolution
## Orchestrates the full combat sequence on the Present panel
func execute_combat(present_panel: Panel) -> void:
	Events.combat_started.emit()

	# Check state
	print("  Present state before combat:")
	print("    Player HP: ", present_panel.state.get("player", {}).get("hp", 0))
	print("    Enemies: ", present_panel.state.get("enemies", []).size())

	if present_panel.state.get("enemies", []).size() == 0:
		print("  No enemies - skipping combat")
		Events.combat_ended.emit()
		return

	# Track if any enemy died during combat
	var enemies_before = present_panel.state.get("enemies", []).size()

	# Twin attacks first (leftmost entity)
	if present_panel.state.has("twin"):
		print("  ⚔️ Twin attacking...")
		await _animate_twin_attack(present_panel)
		await get_tree().create_timer(0.2).timeout

	# Player attacks
	print("  ⚔️ Player attacking...")
	await _animate_player_attack(present_panel)
	await get_tree().create_timer(0.2).timeout

	# Check if enemy died
	var enemies_after_player = present_panel.state.get("enemies", []).size()
	var enemy_died_during_player_attack = enemies_after_player < enemies_before

	# Enemies attack (if any left)
	if present_panel.state.get("enemies", []).size() > 0:
		print("  ⚔️ Enemies attacking...")
		await _animate_enemy_attacks(present_panel)

	print("  ✅ Combat complete!")
	print("    Player HP after: ", present_panel.state.get("player", {}).get("hp", 0))

	# Reposition enemies if any died during combat
	if enemy_died_during_player_attack:
		print("  ↔️ Enemy died during combat - repositioning remaining enemies...")
		await _animate_enemy_repositioning(present_panel)

	Events.combat_ended.emit()

# ============================================================================
# PRIVATE COMBAT ANIMATIONS
# ============================================================================

## Animate player attacking leftmost enemy in Present
func _animate_player_attack(present_panel: Panel) -> void:
	# Find player and target enemy
	var player_entity = _get_player_entity(present_panel)
	var target_enemy = _get_target_enemy(present_panel)

	if not player_entity or not target_enemy:
		print("  Cannot animate - missing player or enemy")
		return

	# Store original position
	var original_pos = player_entity.position
	var target_pos = target_enemy.position

	# Calculate attack position
	var direction = (target_pos - original_pos).normalized()
	var attack_pos = target_pos - direction * ATTACK_OFFSET

	print("  Player attack animation starting...")

	# Dash to enemy
	var tween = create_tween()
	tween.tween_property(player_entity, "position", attack_pos, ATTACK_DASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

	# APPLY DAMAGE AT IMPACT
	if present_panel.state["enemies"].size() > 0:
		var target_enemy_data = present_panel.state["enemies"][0]
		var damage = present_panel.state["player"]["damage"]
		target_enemy_data["hp"] -= damage
		print("  Player dealt ", damage, " damage! Enemy HP: ", target_enemy_data["hp"])

		# Emit damage event
		Events.damage_dealt.emit(target_enemy, damage)

		# Play attack sound
		player_entity.play_attack_sound()

		# Screen shake via event
		Events.screen_shake_requested.emit(damage * 0.5)

		# Hit reaction
		var hit_direction = (target_enemy.position - player_entity.position).normalized()
		Events.hit_reaction_requested.emit(target_enemy, hit_direction)
		target_enemy.play_hit_reaction(hit_direction)

		# Update visual
		target_enemy.entity_data = target_enemy_data
		target_enemy.update_display()

		# Remove enemy if dead
		if target_enemy_data["hp"] <= 0:
			print("  ", target_enemy_data["name"], " defeated!")
			Events.entity_died.emit(target_enemy)
			present_panel.state["enemies"].remove_at(0)
			present_panel.entities.erase(target_enemy)
			target_enemy.visible = false

			# Queue for deletion (don't delete immediately - let combat finish)
			get_tree().create_timer(1.5).timeout.connect(func():
				if is_instance_valid(target_enemy):
					target_enemy.queue_free()
			)

	# Pause at enemy
	await get_tree().create_timer(ATTACK_PAUSE_TIME).timeout

	# Dash back
	var tween2 = create_tween()
	tween2.tween_property(player_entity, "position", original_pos, RETREAT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween2.finished

	print("  Player attack complete!")


## Animate twin attacking leftmost enemy in Present
func _animate_twin_attack(present_panel: Panel) -> void:
	# Find twin and target enemy
	var twin_entity = _get_twin_entity(present_panel)
	var target_enemy = _get_target_enemy(present_panel)

	if not twin_entity or not target_enemy:
		print("  Cannot animate - missing twin or enemy")
		return

	# Store original position
	var original_pos = twin_entity.position
	var target_pos = target_enemy.position

	# Calculate attack position
	var direction = (target_pos - original_pos).normalized()
	var attack_pos = target_pos - direction * ATTACK_OFFSET

	print("  Twin attack animation starting...")

	# Dash to enemy
	var tween = create_tween()
	tween.tween_property(twin_entity, "position", attack_pos, ATTACK_DASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

	# APPLY DAMAGE AT IMPACT
	if present_panel.state["enemies"].size() > 0 and present_panel.state.has("twin"):
		var target_enemy_data = present_panel.state["enemies"][0]
		var damage = present_panel.state["twin"]["damage"]
		target_enemy_data["hp"] -= damage
		print("  Twin dealt ", damage, " damage! Enemy HP: ", target_enemy_data["hp"])

		# Emit damage event
		Events.damage_dealt.emit(target_enemy, damage)

		# Play attack sound
		twin_entity.play_attack_sound()

		# Screen shake via event
		Events.screen_shake_requested.emit(damage * 0.5)

		# Hit reaction
		var hit_direction = (target_enemy.position - twin_entity.position).normalized()
		Events.hit_reaction_requested.emit(target_enemy, hit_direction)
		target_enemy.play_hit_reaction(hit_direction)

		# Update visual
		target_enemy.entity_data = target_enemy_data
		target_enemy.update_display()

		# Remove enemy if dead
		if target_enemy_data["hp"] <= 0:
			print("  ", target_enemy_data["name"], " defeated by twin!")
			Events.entity_died.emit(target_enemy)
			present_panel.state["enemies"].remove_at(0)
			present_panel.entities.erase(target_enemy)
			target_enemy.visible = false

			# Queue for deletion
			get_tree().create_timer(1.5).timeout.connect(func():
				if is_instance_valid(target_enemy):
					target_enemy.queue_free()
			)

	# Pause at enemy
	await get_tree().create_timer(ATTACK_PAUSE_TIME).timeout

	# Dash back
	var tween2 = create_tween()
	tween2.tween_property(twin_entity, "position", original_pos, RETREAT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween2.finished

	print("  Twin attack complete!")


## Animate all enemies attacking twin/player sequentially
func _animate_enemy_attacks(present_panel: Panel) -> void:
	# Find player and twin
	var player_entity = _get_player_entity(present_panel)
	var twin_entity = _get_twin_entity(present_panel)

	if not player_entity:
		print("  Cannot animate - missing player")
		return

	# Get all enemies with data
	var enemy_list = []
	for i in range(present_panel.state["enemies"].size()):
		var enemy_data = present_panel.state["enemies"][i]
		for entity in present_panel.entities:
			if not entity.is_player and entity.entity_data["name"] == enemy_data["name"]:
				enemy_list.append({"node": entity, "data": enemy_data, "index": i})
				break

	if enemy_list.size() == 0:
		return

	print("  Enemy attacks starting...")

	# Animate each enemy sequentially
	for enemy_info in enemy_list:
		var enemy_index = enemy_info["index"]

		# CHECK MISS FLAGS from GameState
		if GameState.will_enemy_miss(enemy_index):
			print("  Enemy ", enemy_index, " misses (Chaos Injection effect)")
			continue

		# Determine target: leftmost ally (twin or player)
		var target = null
		var target_is_twin = false

		# CHECK REDIRECT from GameState
		if GameState.future_redirect_flag != null and GameState.future_redirect_flag.get("from_enemy", -1) == enemy_index:
			var to_index = GameState.future_redirect_flag.get("to_enemy", -1)
			if to_index >= 0 and to_index < enemy_list.size():
				target = enemy_list[to_index]["node"]
				print("  Enemy ", enemy_index, " attacks enemy ", to_index, " (Redirect effect)")
		else:
			# Find leftmost ally (by x-position) to attack
			var leftmost_ally = null
			var leftmost_x = INF
			var leftmost_is_twin = false

			# Check player
			if player_entity and is_instance_valid(player_entity):
				if player_entity.position.x < leftmost_x:
					leftmost_x = player_entity.position.x
					leftmost_ally = player_entity
					leftmost_is_twin = false

			# Check twin (if alive)
			if twin_entity and is_instance_valid(twin_entity) and present_panel.state.has("twin"):
				if present_panel.state["twin"]["hp"] > 0:  # Twin still alive
					if twin_entity.position.x < leftmost_x:
						leftmost_x = twin_entity.position.x
						leftmost_ally = twin_entity
						leftmost_is_twin = true

			target = leftmost_ally
			target_is_twin = leftmost_is_twin

		await _animate_single_enemy_attack(enemy_info["node"], target, enemy_info["data"], target_is_twin, present_panel)

		# Check if twin died from this attack
		if target_is_twin and present_panel.state.has("twin"):
			if present_panel.state["twin"]["hp"] <= 0:
				print("  Twin defeated! Remaining enemies will attack player.")
				# Remove twin from entities
				if twin_entity and is_instance_valid(twin_entity):
					Events.entity_died.emit(twin_entity)
					present_panel.entities.erase(twin_entity)
					twin_entity.visible = false
					get_tree().create_timer(1.0).timeout.connect(func():
						if is_instance_valid(twin_entity):
							twin_entity.queue_free()
					)
				twin_entity = null

	print("  All enemy attacks complete!")


## Animate single enemy attacking target (player, twin, or another enemy)
func _animate_single_enemy_attack(enemy: Node2D, target: Node2D, enemy_data: Dictionary, target_is_twin: bool, present_panel: Panel) -> void:
	var original_pos = enemy.position
	var target_pos = target.position
	var direction = (target_pos - original_pos).normalized()
	var attack_pos = target_pos - direction * ATTACK_OFFSET

	# Dash to target
	var tween = create_tween()
	tween.tween_property(enemy, "position", attack_pos, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

	# APPLY DAMAGE AT IMPACT
	var damage = enemy_data["damage"]

	# Check if target is player, twin, or enemy
	if target.is_player:
		if target_is_twin:
			# Attacking twin
			present_panel.state["twin"]["hp"] -= damage
			print("  ", enemy_data["name"], " dealt ", damage, " damage to twin! Twin HP: ", present_panel.state["twin"]["hp"])

			# Emit events
			Events.enemy_attacked.emit(enemy, target)
			Events.damage_dealt.emit(target, damage)
			Events.hp_updated.emit(target, present_panel.state["twin"]["hp"])

			# Update twin visual
			target.entity_data = present_panel.state["twin"]
			target.update_display()
		else:
			# Attacking player
			present_panel.state["player"]["hp"] -= damage
			print("  ", enemy_data["name"], " dealt ", damage, " damage! Player HP: ", present_panel.state["player"]["hp"])

			# Emit events
			Events.enemy_attacked.emit(enemy, target)
			Events.damage_dealt.emit(target, damage)
			Events.hp_updated.emit(target, present_panel.state["player"]["hp"])

			# Update player visual
			target.entity_data = present_panel.state["player"]
			target.update_display()
	else:
		# Attacking another enemy (redirect)
		for enemy_state in present_panel.state["enemies"]:
			if enemy_state["name"] == target.entity_data["name"]:
				enemy_state["hp"] -= damage
				print("  ", enemy_data["name"], " dealt ", damage, " damage to ", enemy_state["name"], "! Enemy HP: ", enemy_state["hp"])

				# Emit events
				Events.enemy_attacked.emit(enemy, target)
				Events.damage_dealt.emit(target, damage)

				# Update enemy visual
				target.entity_data = enemy_state
				target.update_display()

				# Remove if dead
				if enemy_state["hp"] <= 0:
					print("  ", enemy_state["name"], " defeated by redirect!")
					Events.entity_died.emit(target)
					present_panel.state["enemies"].erase(enemy_state)
					present_panel.entities.erase(target)
					target.visible = false
					get_tree().create_timer(1.5).timeout.connect(func():
						if is_instance_valid(target):
							target.queue_free()
					)
				break

	# Play attack sound
	enemy.play_attack_sound()

	# Screen shake via event
	Events.screen_shake_requested.emit(damage * 0.5)

	# Hit reaction
	var hit_direction = (target.position - enemy.position).normalized()
	Events.hit_reaction_requested.emit(target, hit_direction)
	target.play_hit_reaction(hit_direction)

	# Pause
	await get_tree().create_timer(0.08).timeout

	# Dash back
	var tween2 = create_tween()
	tween2.tween_property(enemy, "position", original_pos, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween2.finished


## Animate remaining enemies repositioning after one dies using grid-based layout
func _animate_enemy_repositioning(present_panel: Panel) -> void:
	var enemy_entities = []
	for entity in present_panel.entities:
		if not entity.is_player and is_instance_valid(entity) and entity.visible:
			enemy_entities.append(entity)

	var enemy_count = enemy_entities.size()
	if enemy_count == 0:
		return  # No repositioning needed for 0 enemies

	print("  ↔️ Repositioning ", enemy_count, " remaining enemies to grid cells...")

	var tween = create_tween()
	tween.set_parallel(true)

	# Calculate and animate to new grid-based positions
	for i in range(enemy_count):
		var entity = enemy_entities[i]

		# Get grid position for this enemy based on new count
		var grid_pos = present_panel.get_grid_position_for_entity(i, false, enemy_count)
		var new_pos = present_panel.get_cell_center_position(grid_pos.x, grid_pos.y)

		print("    Enemy ", i, " → grid (", grid_pos.x, ", ", grid_pos.y, ") at ", new_pos)
		tween.tween_property(entity, "position", new_pos, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await tween.finished
	print("  ✅ Enemy repositioning complete")

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

## Find player entity in panel (excludes twin)
func _get_player_entity(present_panel: Panel) -> Node2D:
	for entity in present_panel.entities:
		if entity.is_player and not entity.entity_data.get("is_twin", false):
			return entity
	return null


## Find twin entity in panel
func _get_twin_entity(present_panel: Panel) -> Node2D:
	for entity in present_panel.entities:
		if entity.is_player and entity.entity_data.get("is_twin", false):
			return entity
	return null


## Get first enemy as target (leftmost)
func _get_target_enemy(present_panel: Panel) -> Node2D:
	for entity in present_panel.entities:
		if not entity.is_player:
			return entity
	return null
