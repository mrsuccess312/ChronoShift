extends Node
class_name CombatResolver

## CombatResolver - Simplified target-based combat system
## Uses EntityData models and attack_target_id for clean combat resolution
## Replaces complex entity-finding logic with simple iteration

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
func execute_combat(present_panel: Panel, attacking_team_is_enemy: bool) -> void:
	"""Main combat orchestrator - simplified target-based version"""
	print("CombatResolver: Starting combat...")
	Events.combat_started.emit()

	# Get entity data list
	var entities = present_panel.entity_data_list

	if entities.size() == 0:
		print("  No entities - ending combat")
		Events.combat_ended.emit()
		return

	# Check if any enemies exist
	var has_enemies = false
	for entity in entities:
		if entity.is_enemy and entity.is_alive():
			has_enemies = true
			break

	if not has_enemies:
		print("  No enemies - ending combat")
		Events.combat_ended.emit()
		return

	# Phase 1: Player team attacks (is_enemy = false)
	await _execute_team_attacks(present_panel, attacking_team_is_enemy)
	await get_tree().create_timer(0.2).timeout

	# Phase 2: Enemy team attacks (is_enemy = true)
	# await _execute_team_attacks(present_panel, true)

	Events.combat_ended.emit()
	print("CombatResolver: Combat complete")


# ============================================================================
# SIMPLIFIED TEAM ATTACK LOGIC
# ============================================================================

## Execute attacks for one team using target properties
func _execute_team_attacks(present_panel: Panel, attacking_team_is_enemy: bool) -> void:
	"""Execute attacks for one team using target properties"""
	var team_name = "Enemy team" if attacking_team_is_enemy else "Player team"
	print("  ⚔️ ", team_name, " attacking...")

	# Get all attackers from this team
	var attackers = []
	for entity in present_panel.entity_data_list:
		if entity.is_enemy == attacking_team_is_enemy and entity.is_alive():
			attackers.append(entity)

	if attackers.size() == 0:
		print("    No attackers in ", team_name)
		return

	# Sort attackers by grid position (left to right, top to bottom)
	# This ensures attacks execute in visual order regardless of entity_data_list order
	attackers.sort_custom(func(a, b):
		if a.grid_col != b.grid_col:
			return a.grid_col < b.grid_col  # Left to right
		return a.grid_row < b.grid_row  # Top to bottom (tiebreaker)
	)

	# Each attacker attacks their target sequentially (now in grid order)
	for attacker in attackers:
		# Skip if no target assigned or will miss
		if attacker.attack_target_id == "" or attacker.will_miss:
			if attacker.will_miss:
				print("    ", attacker.entity_name, " misses (will_miss = true)")
			continue

		# Find target entity
		var target = _find_entity_by_id(present_panel, attacker.attack_target_id)
		if not target or not target.is_alive():
			print("    ", attacker.entity_name, " has no valid target")
			continue

		# Find visual nodes for animation
		var attacker_node = _find_entity_node(present_panel, attacker.unique_id)
		var target_node = _find_entity_node(present_panel, target.unique_id)

		if not attacker_node or not target_node:
			print("    Warning: Could not find visual nodes for combat")
			continue

		# Execute attack animation
		await _animate_attack(attacker, target, attacker_node, target_node, present_panel)
		await get_tree().create_timer(0.1).timeout


# ============================================================================
# SIMPLIFIED ATTACK ANIMATION
# ============================================================================

## Animate single attack with damage application
func _animate_attack(attacker: EntityData, target: EntityData, attacker_node: Node2D, target_node: Node2D, present_panel: Panel) -> void:
	"""Animate single attack with damage application"""
	var original_pos = attacker_node.position
	var target_pos = target_node.position
	var direction = (target_pos - original_pos).normalized()
	var attack_pos = target_pos - direction * ATTACK_OFFSET

	# Dash to target
	var tween = create_tween()
	tween.tween_property(attacker_node, "position", attack_pos, ATTACK_DASH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

	# Apply damage to data model
	var damage = attacker.damage
	var target_died = target.take_damage(damage)

	print("    ", attacker.entity_name, " dealt ", damage, " damage to ", target.entity_name, " (HP: ", target.hp, "/", target.max_hp, ")")

	# Visual feedback
	if attacker_node.has_method("play_attack_sound"):
		attacker_node.play_attack_sound()

	Events.damage_dealt.emit(target_node, damage)
	Events.screen_shake_requested.emit(damage * 0.5)

	var hit_direction = (target_node.position - attacker_node.position).normalized()
	if target_node.has_method("play_hit_reaction"):
		target_node.play_hit_reaction(hit_direction)

	# Update visual display
	if target_node.has_method("update_display"):
		# Update the entity_data dictionary on the visual node
		target_node.entity_data["hp"] = target.hp
		target_node.update_display()

	# Handle death
	if target_died:
		print("    💀 ", target.entity_name, " defeated!")
		Events.entity_died.emit(target_node)

		# Remove entity from PRESENT immediately
		print("      Removing entity from PRESENT panel")
		target_node.visible = false
		target_node.queue_free()

		# Remove from panel arrays immediately to prevent accessing freed node
		if present_panel.entity_nodes.has(target_node):
			present_panel.entity_nodes.erase(target_node)
		if present_panel.entities.has(target_node):
			present_panel.entities.erase(target_node)
		if present_panel.entity_data_list.has(target):
			present_panel.entity_data_list.erase(target)

	# Pause
	await get_tree().create_timer(ATTACK_PAUSE_TIME).timeout

	# Dash back
	var tween2 = create_tween()
	tween2.tween_property(attacker_node, "position", original_pos, RETREAT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween2.finished


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

## Find EntityData by unique_id
func _find_entity_by_id(present_panel: Panel, unique_id: String) -> EntityData:
	"""Find EntityData by unique_id"""
	for entity in present_panel.entity_data_list:
		if entity.unique_id == unique_id:
			return entity
	return null


## Find visual entity node by unique_id
func _find_entity_node(present_panel: Panel, unique_id: String) -> Node2D:
	"""Find visual entity node by unique_id"""
	for node in present_panel.entity_nodes:
		# Check if node is valid before accessing properties (prevents crash when entity dies)
		if node and is_instance_valid(node) and node.entity_data.get("unique_id") == unique_id:
			return node
	return null


# =============================================================================
# COMBAT SYSTEM DOCUMENTATION
# =============================================================================
#
# SIMPLIFIED COMBAT FLOW:
#
# 1. Get all entities with is_enemy = false (player team)
# 2. For each: attack their attack_target_id
# 3. Get all entities with is_enemy = true (enemy team)
# 4. For each: attack their attack_target_id
#
# BENEFITS:
# - No special cases for twins/conscription
# - Target assignment handles all complexity
# - Easy to add new entity types
# - Deterministic and predictable
# - Combat logic reduced from ~400 lines to ~150 lines
#
# INTEGRATION:
# - TargetCalculator.calculate_targets() must be called before combat
# - EntityData.attack_target_id determines who attacks whom
# - EntityData.will_miss flag automatically skips attacks
# - Visual nodes are found by matching unique_id
#
# USAGE:
#   # Before combat:
#   TargetCalculator.calculate_targets(present_panel)
#
#   # Execute combat:
#   combat_resolver.execute_combat(present_panel)
#
# =============================================================================
