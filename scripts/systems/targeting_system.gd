extends Node
class_name TargetingSystem

## TargetingSystem - Handles all card targeting logic
## Extracted from game_manager.gd to create a dedicated targeting system
## Uses Events for communication and works with CardManager

# ============================================================================
# REFERENCES (Set by GameController)
# ============================================================================

var timeline_panels: Array = []
var ui_root: Control
var card_manager: CardManager

# ============================================================================
# TARGETING STATE
# ============================================================================

var targeting_mode_active: bool = false  # Whether we're in targeting mode
var targeting_card_data: Dictionary = {}  # The card being played
var targeting_card_node = null  # The card node that's targeting
var targeting_source_deck = null  # Which deck the card came from
var selected_targets: Array = []  # Array of selected targets (entities or cells)
var required_target_count: int = 0  # How many targets this card needs
var targeting_click_handled: bool = false  # Flag to track if last click was on valid target
var valid_target_timelines: Array = []  # Array of timeline types that can be targeted

# ============================================================================
# UI ELEMENTS
# ============================================================================

var targeting_status_label: Label = null

# ============================================================================
# PUBLIC API
# ============================================================================

## Setup targeting system
func initialize() -> void:
	_create_targeting_status_label()
	Events.card_targeting_started.connect(_on_card_targeting_started)
	print("TargetingSystem initialized")


## Enter targeting mode for a card
func enter_targeting_mode(card_data: Dictionary, card_node: Node, source_deck) -> void:
	print("\n🎯 ENTERING TARGETING MODE")
	print("  Card: ", card_data.get("name", "Unknown"))

	targeting_mode_active = true
	targeting_card_data = card_data
	targeting_card_node = card_node
	targeting_source_deck = source_deck
	selected_targets = []

	# Get targeting requirements from CardManager
	required_target_count = card_manager.get_required_target_count(card_data)
	valid_target_timelines = card_manager.get_valid_target_timelines(card_data)

	# Set card visual state
	if card_node:
		card_node.enter_targeting_mode()

	# Disable all other cards
	_disable_other_cards()

	# Highlight valid targets
	_highlight_valid_targets()

	# Enable entity targeting
	_enable_entity_targeting()

	# Show targeting status UI
	_show_targeting_status()

	# Emit event
	Events.targeting_mode_entered.emit(card_data)

	print("  Required targets: ", required_target_count)
	print("  ✅ Targeting mode active")


## Exit targeting without applying effect
func cancel_targeting_mode() -> void:
	print("\n❌ CANCELING TARGETING MODE")

	if not targeting_mode_active:
		return

	targeting_mode_active = false
	selected_targets = []

	# Restore card visual states
	_restore_card_states()

	# Clear highlights
	_clear_all_highlights()

	# Disable entity targeting
	_disable_entity_targeting()

	# Hide targeting status UI
	_hide_targeting_status()

	# Clear targeting variables
	targeting_card_data = {}
	targeting_card_node = null
	targeting_source_deck = null
	required_target_count = 0

	# Emit event
	Events.targeting_mode_exited.emit()

	print("  ✅ Targeting mode canceled")


## Handle target selection
func on_target_selected(target) -> void:
	if not targeting_mode_active:
		return

	# Validate that the target is from a valid timeline
	if target is Node2D:  # Entity
		var target_timeline = target.timeline_type
		if target_timeline not in valid_target_timelines:
			print("❌ Invalid target: ", target.entity_data.get("name", "Unknown"), " is in ", target_timeline, " (valid: ", valid_target_timelines, ")")
			# Don't mark click as handled - this will cancel targeting
			return

	# Mark that this click was handled by a valid target
	targeting_click_handled = true

	print("🎯 Target selected: ", target)

	# Add to selected targets
	selected_targets.append(target)

	# Visual feedback for selected target
	if target is Node2D:  # Entity
		target.mark_as_targeted()

	# Update targeting status UI
	_update_targeting_status()

	# Emit event
	Events.target_selected.emit(target)

	print("  Selected ", selected_targets.size(), "/", required_target_count, " targets")

	# Check if we have all required targets
	if selected_targets.size() >= required_target_count:
		_complete_targeting()


## Called after click to check if targeting should cancel
func check_cancel_from_empty_click() -> void:
	if not targeting_mode_active:
		return

	# If the click wasn't handled by a valid target, cancel targeting
	if not targeting_click_handled:
		print("Clicked on empty space - canceling targeting mode")
		cancel_targeting_mode()

	# Reset flag for next click
	targeting_click_handled = false

# ============================================================================
# PRIVATE HELPER FUNCTIONS
# ============================================================================

## All targets selected - apply effect
func _complete_targeting() -> void:
	print("\n✅ TARGETING COMPLETE")
	print("  Applying effect with targets: ", selected_targets)

	# Validate that player still has enough time
	var time_cost = targeting_card_data.get("time_cost", 0)
	if GameState.time_remaining < time_cost:
		print("❌ Not enough time! Card cost: ", time_cost, ", Time remaining: ", GameState.time_remaining)

		# Play shake animation on the card
		if targeting_card_node and is_instance_valid(targeting_card_node):
			targeting_card_node.play_shake_animation()

		# Cancel targeting mode
		cancel_targeting_mode()
		return

	# Deduct time cost
	GameState.time_remaining -= time_cost
	if GameState.time_remaining < 0:
		GameState.time_remaining = 0
	Events.timer_updated.emit(GameState.time_remaining)

	# Update all cards' affordability
	card_manager.update_affordability(GameState.time_remaining)

	# Apply card effect with targets via CardManager
	card_manager.apply_card_effect_targeted(targeting_card_data, selected_targets)

	# Recycle the card via CardManager
	if targeting_source_deck:
		card_manager.recycle_used_card(targeting_source_deck)

	# Emit completion event
	Events.card_targeting_completed.emit(targeting_card_data, selected_targets)

	# Exit targeting mode
	cancel_targeting_mode()

	print("  ✅ Card effect applied and targeting complete")


## Highlight entities that can be targeted
func _highlight_valid_targets() -> void:
	# Iterate through all panels and highlight entities in valid timelines
	for panel in timeline_panels:
		# Check if this panel's timeline is valid for targeting
		if panel.timeline_type in valid_target_timelines:
			for entity in panel.entities:
				if is_instance_valid(entity) and not entity.is_player:
					entity.show_as_valid_target()

	# Emit event
	Events.valid_targets_highlighted.emit(selected_targets)


## Clear all target highlights
func _clear_all_highlights() -> void:
	for panel in timeline_panels:
		for entity in panel.entities:
			if is_instance_valid(entity):
				entity.clear_target_visuals()
		panel.clear_all_highlights()


## Enable click handlers on entities
func _enable_entity_targeting() -> void:
	# Enable targeting on all entities across all timelines
	# (only highlighted ones will be visibly clickable)
	for panel in timeline_panels:
		for entity in panel.entities:
			if is_instance_valid(entity) and not entity.is_player:
				entity.enable_targeting(self)


## Disable click handlers on entities
func _disable_entity_targeting() -> void:
	for panel in timeline_panels:
		for entity in panel.entities:
			if is_instance_valid(entity):
				entity.disable_targeting()


## Disable all cards except the targeting card
func _disable_other_cards() -> void:
	if not card_manager:
		return

	# Access decks from card_manager
	for deck in [card_manager.past_deck, card_manager.present_deck, card_manager.future_deck]:
		if not deck:
			continue
		var top_card = deck.get_top_card()
		if top_card and is_instance_valid(top_card) and top_card != targeting_card_node:
			top_card.disable_for_targeting()


## Restore card visual states after targeting
func _restore_card_states() -> void:
	if not card_manager:
		return

	# Restore card visual states (but keep selected card highlighted until it's used)
	for deck in [card_manager.past_deck, card_manager.present_deck, card_manager.future_deck]:
		if not deck:
			continue
		var top_card = deck.get_top_card()
		if top_card and is_instance_valid(top_card):
			# Keep the selected card highlighted, restore others
			if top_card == targeting_card_node:
				# Keep selected card highlighted but restore normal interaction
				top_card.card_state = top_card.CardState.NORMAL
				top_card.mouse_filter = Control.MOUSE_FILTER_STOP
			else:
				top_card.exit_targeting_mode()


## Create UI label for targeting status
func _create_targeting_status_label() -> void:
	targeting_status_label = Label.new()
	targeting_status_label.name = "TargetingStatusLabel"
	targeting_status_label.visible = false

	# Style the label
	targeting_status_label.add_theme_font_size_override("font_size", 32)
	targeting_status_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	targeting_status_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	targeting_status_label.add_theme_constant_override("outline_size", 3)

	# Position at top center
	targeting_status_label.anchor_left = 0.5
	targeting_status_label.anchor_top = 0.1
	targeting_status_label.anchor_right = 0.5
	targeting_status_label.anchor_bottom = 0.1
	targeting_status_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	targeting_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	ui_root.add_child(targeting_status_label)
	print("Targeting status label created")


## Display targeting status message
func _show_targeting_status() -> void:
	if targeting_status_label:
		var card_name = targeting_card_data.get("name", "Unknown")
		targeting_status_label.text = "%s: Select %d/%d targets" % [card_name, 0, required_target_count]
		targeting_status_label.visible = true


## Update targeting status count
func _update_targeting_status() -> void:
	if targeting_status_label:
		var card_name = targeting_card_data.get("name", "Unknown")
		targeting_status_label.text = "%s: Select %d/%d targets" % [card_name, selected_targets.size(), required_target_count]


## Hide targeting status
func _hide_targeting_status() -> void:
	if targeting_status_label:
		targeting_status_label.visible = false


## Event handler for targeting mode start (connected in initialize)
func _on_card_targeting_started(card_data: Dictionary, card_node: Node, source_deck) -> void:
	"""Handle targeting start event from CardManager"""
	print("🎯 TargetingSystem received targeting_started event for: ", card_data.get("name", "Unknown"))
	enter_targeting_mode(card_data, card_node, source_deck)
