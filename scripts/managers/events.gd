extends Node

## Events Singleton - Global Event Bus
## This autoload provides a centralized event system for the game
## Usage: Events.signal_name.emit(parameters)
## Connect with: Events.signal_name.connect(callback_function)

# ============================================================================
# GAME STATE SIGNALS
# ============================================================================

## Emitted when the game starts
signal game_started()

## Emitted when the game is over
signal game_over()

## Emitted when the wave number changes
signal wave_changed(new_wave: int)

## Emitted at the start of each turn
signal turn_started(turn_number: int)

## Emitted at the end of each turn
signal turn_ended(turn_number: int)

# ============================================================================
# COMBAT SIGNALS
# ============================================================================

## Emitted when combat phase begins
signal combat_started()

## Emitted when combat phase ends
signal combat_ended()

## Emitted when damage is dealt to a target
signal damage_dealt(target: Node2D, damage: int)

## Emitted when an entity dies
signal entity_died(entity: Node2D)

## Emitted when the player attacks a target
signal player_attacked(target: Node2D)

## Emitted when an enemy attacks
signal enemy_attacked(attacker: Node2D, target: Node2D)

# ============================================================================
# CARD SIGNALS
# ============================================================================

## Emitted when a card is played
signal card_played(card_data: Dictionary)

## Emitted when a card is recycled
signal card_recycled(card_data: Dictionary)

## Emitted when card targeting begins (includes card node and source deck for system communication)
signal card_targeting_started(card_data: Dictionary, card_node: Node, source_deck)

## Emitted when card targeting is completed with targets
signal card_targeting_completed(card_data: Dictionary, targets: Array)

## Emitted when card targeting is cancelled
signal card_targeting_cancelled(card_data: Dictionary)

# ============================================================================
# TIMELINE SIGNALS
# ============================================================================

## Emitted when timeline is updated (player/enemy)
signal timeline_updated(timeline_type: String)

## Emitted when future state is calculated
signal future_calculated(future_state: Dictionary)

## Emitted when a card effect requests future recalculation (e.g., enemy_swap)
signal future_recalculation_requested()

## Emitted when carousel slide animation starts
signal carousel_slide_started()

## Emitted when carousel slide animation completes
signal carousel_slide_completed()

# ============================================================================
# UI SIGNALS
# ============================================================================

## Emitted when timer value changes
signal timer_updated(time_remaining: float)

## Emitted when entity HP changes
signal hp_updated(entity: Node2D, new_hp: int)

## Emitted when damage display value changes
signal damage_display_updated(new_damage: int)

# ============================================================================
# TARGETING SIGNALS
# ============================================================================

## Emitted when a target is selected
signal target_selected(target: Node2D)

## Emitted when valid targets are highlighted
signal valid_targets_highlighted(targets: Array)

## Emitted when targeting mode is entered
signal targeting_mode_entered(card_data: Dictionary)

## Emitted when targeting mode is exited
signal targeting_mode_exited()

# ============================================================================
# VFX SIGNALS
# ============================================================================

## Emitted to request screen shake effect
signal screen_shake_requested(strength: float)

## Emitted to request hit reaction on an entity
signal hit_reaction_requested(entity: Node2D, direction: Vector2)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	print("Events singleton initialized")
