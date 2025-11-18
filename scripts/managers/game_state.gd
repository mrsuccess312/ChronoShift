extends Node

## GameState Singleton - Centralized State Management
## This autoload stores all game state data without logic
## Other systems read/write this state via direct access or Events
## Pure data container - complex logic belongs in other systems

# ============================================================================
# WAVE/TURN STATE
# ============================================================================

## Current wave number in the game
var current_wave: int = 1

## Current turn number (increments each turn)
var turn_number: int = 0

## Flag to track if this is the first turn of the game
var is_first_turn: bool = true

## Flag indicating if the game has ended
var game_over: bool = false

# ============================================================================
# TIMER STATE
# ============================================================================

## Whether the countdown timer is currently running
var timer_active: bool = true

## Current time remaining on the turn timer
var time_remaining: float = 360.0

## Maximum time allowed per turn
var max_time: float = 360.0

# ============================================================================
# PLAYER STATS
# ============================================================================

## Unique ID of the player entity (set at game start, used to track player across timelines)
var player_unique_id: String = ""

## Base damage value for player attacks
var base_player_damage: int = 15

## Flag for temporary damage boost effects
var damage_boost_active: bool = false

## Stores original damage before boost (for future_sight restoration)
var original_damage_before_boost: int = 0

# ============================================================================
# CONSCRIPTION STATE (Card Effect)
# ============================================================================

## Flag indicating if conscription card effect is active
var conscription_active: bool = false

## Stores original player data before conscription
var original_player_data: Dictionary = {}

## Stores data of the enemy being conscripted
var conscripted_enemy_data: Dictionary = {}

# ============================================================================
# FUTURE MANIPULATION FLAGS (Card Effects)
# ============================================================================

## Dictionary of enemies that will miss their attacks
## Format: {enemy_index: true}
var future_miss_flags: Dictionary = {}

## Redirect information for enemy attacks
## Format: {from_enemy: int, to_enemy: int} or null
var future_redirect_flag = null

# ============================================================================
# TIMELINE STATES
# ============================================================================

## References to timeline panel states (past, present, future)
## Format: {"past": {}, "present": {}, "future": {}}
var timeline_states: Dictionary = {
	"past": {},
	"present": {},
	"future": {}
}

# ============================================================================
# REAL_FUTURE TIMELINE TRACKING (NEW)
# ============================================================================
#
# CONCEPT: Separate PREDICTED_FUTURE from REAL_FUTURE
#
# PROBLEM: Temporary effects (conscription, twins, damage boosts) are tracked
# with scattered flags that are easy to forget to reset.
#
# SOLUTION: When cards with temporary effects are played:
# 1. PREDICTED_FUTURE - Shows player the immediate effect (with temporary boost)
# 2. REAL_FUTURE - What actually happens after temporary effects expire
#
# After combat: PRESENT → PREDICTED_FUTURE → REAL_FUTURE
#
# This eliminates need for:
# - conscription_active flag
# - original_player_data storage
# - damage_boost_active flag
# - Manual temporary entity cleanup
# ============================================================================

## Real future entity state (after temporary effects expire)
var real_future_entities: Array[EntityData] = []

## Whether REAL_FUTURE differs from PREDICTED_FUTURE
var has_real_future: bool = false

# ============================================================================
# TEMPORARY ENTITIES
# ============================================================================

## Array of entities created by card effects (cleared each turn)
var temporary_entities: Array = []

# ============================================================================
# UI SETTINGS
# ============================================================================

## Enable/disable panel hover effects
var enable_panel_hover: bool = true

## Show/hide grid lines on the battlefield
var show_grid_lines: bool = false

## Show/hide debug grid visualization
var show_debug_grid: bool = false

# ============================================================================
# SCREEN EFFECTS STATE
# ============================================================================

## Current screen shake intensity
var shake_strength: float = 0.0

## Rate at which screen shake decays
var shake_decay: float = 5.0

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

## Reset temporary turn-based effects
## Called at the end of each turn to clear temporary states
func reset_turn_effects() -> void:
	damage_boost_active = false
	future_miss_flags.clear()
	future_redirect_flag = null
	temporary_entities.clear()

	# NEW: Clear REAL_FUTURE tracking
	clear_real_future()


## Clear conscription state
## Called when conscription effect ends
func reset_conscription() -> void:
	conscription_active = false
	original_player_data = {}
	conscripted_enemy_data = {}


## Move to the next wave
## Increments wave counter and emits signal
func increment_wave() -> void:
	current_wave += 1
	Events.wave_changed.emit(current_wave)


## Move to the next turn
## Increments turn counter, clears first turn flag, and emits signal
func increment_turn() -> void:
	turn_number += 1
	is_first_turn = false
	Events.turn_started.emit(turn_number)


## Mark the game as over
## Stops timer and emits game over event
func set_game_over() -> void:
	game_over = true
	timer_active = false
	Events.game_over.emit()


## Reset timer to maximum time
## Called at the start of each new turn
func reset_timer() -> void:
	time_remaining = max_time
	timer_active = true


## Add a temporary entity that will be cleared at turn end
## Used by card effects that summon entities
func add_temporary_entity(entity: Node2D) -> void:
	if entity and not entity in temporary_entities:
		temporary_entities.append(entity)


## Check if a specific enemy will miss due to future manipulation
## Returns true if the enemy at the given index has a miss flag
func will_enemy_miss(enemy_index: int) -> bool:
	return future_miss_flags.get(enemy_index, false)


## Set a future miss flag for an enemy
## Used by cards that manipulate the future timeline
func set_enemy_miss(enemy_index: int, will_miss: bool = true) -> void:
	if will_miss:
		future_miss_flags[enemy_index] = true
	else:
		future_miss_flags.erase(enemy_index)

# ============================================================================
# REAL_FUTURE TIMELINE METHODS (NEW)
# ============================================================================

## Store the REAL future state (after temporary effects expire)
## Called when a card with temporary effects is played
func set_real_future(entities: Array[EntityData]) -> void:
	real_future_entities.clear()
	for entity in entities:
		real_future_entities.append(entity.duplicate_entity())
	has_real_future = true
	print("📍 REAL_FUTURE stored (", real_future_entities.size(), " entities)")


## Get REAL future entity state
## Returns the entity data for what happens after temporary effects expire
func get_real_future() -> Array[EntityData]:
	return real_future_entities


## Clear REAL future state
## Called at end of turn or when REAL_FUTURE is applied
func clear_real_future() -> void:
	real_future_entities.clear()
	has_real_future = false


## Check if REAL_FUTURE should be applied after combat
## Returns true if there's a real future that differs from predicted
func should_apply_real_future() -> bool:
	return has_real_future

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	print("GameState singleton initialized")


# =============================================================================
# REAL_FUTURE USAGE DOCUMENTATION
# =============================================================================
#
# USAGE PATTERN:
#
# When card with temporary effect is played:
# 1. Apply temporary effect to PRESENT timeline
# 2. Calculate PREDICTED_FUTURE (includes temporary effect)
# 3. Calculate REAL_FUTURE (without temporary effect)
# 4. GameState.set_real_future(real_future_entities)
#
# After combat ends:
# 1. Carousel slides (PRESENT → PAST, FUTURE → PRESENT)
# 2. Check GameState.should_apply_real_future()
# 3. If true: Replace new PRESENT with REAL_FUTURE entities
# 4. Call GameState.clear_real_future()
#
# EXAMPLE: Conscript Past Enemy card
# - PRESENT: Conscripted enemy fights as player (temporary)
# - PREDICTED_FUTURE: Shows combat result with conscripted enemy
# - REAL_FUTURE: Shows real player returning after combat
# - After combat: Real player entity replaces conscripted enemy (REAL_FUTURE applied)
#
# EXAMPLE: Damage Boost card
# - PRESENT: Player has +10 damage (temporary)
# - PREDICTED_FUTURE: Shows combat with boosted damage
# - REAL_FUTURE: Shows player with normal damage
# - After combat: Player damage returns to normal (REAL_FUTURE applied)
#
# EXAMPLE: Summon Twin card
# - PRESENT: Twin entity appears (is_temporary = true)
# - PREDICTED_FUTURE: Shows combat with twin fighting
# - REAL_FUTURE: Shows timeline without twin (expired)
# - After combat: Twin disappears (REAL_FUTURE applied)
#
# BENEFITS:
# - Eliminates scattered temporary effect flags
# - Single source of truth for post-combat state
# - Impossible to forget to reset temporary effects
# - Clean separation of concerns
# - Works with EntityData model naturally
#
# =============================================================================
