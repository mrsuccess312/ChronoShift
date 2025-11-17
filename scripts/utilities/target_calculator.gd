extends Node
class_name TargetCalculator
## Static utility class for calculating combat targets using leftmost-enemy rule
## with damage prediction optimization

# Algorithm: Assign targets for all entities
# Rule: Attack leftmost entity with opposite is_enemy flag
# Optimization: If accumulated damage >= target HP, move to next target

# ===== MAIN TARGET CALCULATION =====

static func calculate_targets(timeline_panel: Panel):
	"""Calculate attack_target_id for all entities in timeline"""
	print("\n🎯 Calculating targets for ", timeline_panel.timeline_type, " timeline...")

	# Clear all existing targets
	for entity in timeline_panel.entity_data_list:
		entity.attack_target_id = ""

	# Calculate targets for player team (is_enemy = false)
	_assign_targets_for_team(timeline_panel, false)

	# Calculate targets for enemy team (is_enemy = true)
	_assign_targets_for_team(timeline_panel, true)

	print("  ✅ Targets calculated")


# ===== CORE TARGET ASSIGNMENT =====

static func _assign_targets_for_team(timeline_panel: Panel, attacking_team_is_enemy: bool):
	"""Assign targets for one team"""
	# Get attackers (this team)
	var attackers = []
	for entity in timeline_panel.entity_data_list:
		if entity.is_enemy == attacking_team_is_enemy and entity.is_alive():
			attackers.append(entity)

	if attackers.size() == 0:
		return  # No attackers

	# Get potential targets (opposite team)
	var targets = []
	for entity in timeline_panel.entity_data_list:
		if entity.is_enemy != attacking_team_is_enemy and entity.is_alive():
			targets.append(entity)

	if targets.size() == 0:
		return  # No targets

	# Sort targets by grid position (leftmost = lowest col, then lowest row)
	targets.sort_custom(func(a, b):
		if a.grid_col != b.grid_col:
			return a.grid_col < b.grid_col
		return a.grid_row < b.grid_row
	)

	# Assign targets with damage prediction
	var target_index = 0
	var accumulated_damage = 0

	for attacker in attackers:
		# Check if attacker will miss
		if attacker.will_miss:
			attacker.attack_target_id = ""  # No target if missing
			continue

		# Check if current target is dead from accumulated damage
		while target_index < targets.size():
			var current_target = targets[target_index]

			if accumulated_damage >= current_target.hp:
				# Current target will die, move to next
				accumulated_damage = 0
				target_index += 1
			else:
				# This target still has HP left
				break

		# Assign target (or none if all targets dead)
		if target_index < targets.size():
			attacker.attack_target_id = targets[target_index].unique_id
			accumulated_damage += attacker.damage

			var team_name = "Player" if not attacking_team_is_enemy else "Enemy"
			print("  ", team_name, " '", attacker.entity_name, "' → '", targets[target_index].entity_name, "' (predicted kill: ", accumulated_damage >= targets[target_index].hp, ")")
		else:
			attacker.attack_target_id = ""  # All targets dead


# ===== UTILITY METHODS =====

static func get_target_entity(timeline_panel: Panel, attacker: EntityData) -> EntityData:
	"""Get the EntityData that this attacker is targeting (or null)"""
	if attacker.attack_target_id == "":
		return null

	for entity in timeline_panel.entity_data_list:
		if entity.unique_id == attacker.attack_target_id:
			return entity

	return null


static func has_valid_targets(timeline_panel: Panel, is_enemy: bool) -> bool:
	"""Check if a team has any valid targets"""
	var opposite_team_alive = false
	for entity in timeline_panel.entity_data_list:
		if entity.is_enemy != is_enemy and entity.is_alive():
			opposite_team_alive = true
			break
	return opposite_team_alive


static func clear_all_targets(timeline_panel: Panel):
	"""Clear attack_target_id for all entities"""
	for entity in timeline_panel.entity_data_list:
		entity.attack_target_id = ""
		entity.will_miss = false


# ===== DEBUG UTILITIES =====

static func print_target_summary(timeline_panel: Panel):
	"""Print all entity targets for debugging"""
	print("\n📋 Target Summary (", timeline_panel.timeline_type, "):")

	for entity in timeline_panel.entity_data_list:
		var target_name = "NONE"
		if entity.attack_target_id != "":
			var target = get_target_entity(timeline_panel, entity)
			if target:
				target_name = target.entity_name

		var team = "PLAYER" if not entity.is_enemy else "ENEMY"
		var miss = " (MISS)" if entity.will_miss else ""
		print("  [", team, "] ", entity.entity_name, " → ", target_name, miss)


# =============================================================================
# USAGE DOCUMENTATION
# =============================================================================
#
# BASIC USAGE:
# After any card effect or state change:
#   TargetCalculator.calculate_targets(present_panel)
#   TargetCalculator.calculate_targets(future_panel)
#
# In combat:
#   var target = TargetCalculator.get_target_entity(present_panel, attacker_entity)
#   if target:
#       target.take_damage(attacker_entity.damage)
#
# DEBUG:
#   TargetCalculator.print_target_summary(present_panel)
#
# ALGORITHM:
# 1. Targets sorted by grid position (leftmost = lowest col, then lowest row)
# 2. Damage prediction: If accumulated damage >= target HP, skip to next target
# 3. Respects will_miss flag (no target assigned if attacker will miss)
# 4. Efficient overkill prevention
#
# =============================================================================
