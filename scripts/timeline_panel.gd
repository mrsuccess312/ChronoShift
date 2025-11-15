extends Panel

# ===== TIMELINE PANEL SCRIPT =====
# Self-contained panel with all its data and entities
# Refactored from game_manager.gd TimelinePanel class

var timeline_type: String = "decorative"  # "past", "present", "future", "decorative"
var state: Dictionary = {}  # Game state: { player: {...}, enemies: [...] }
var entities: Array = []  # Entity visual nodes
var arrows: Array = []  # Arrow visual nodes
var slot_index: int = -1  # Current carousel slot position

func initialize(type: String, slot: int):
	"""Initialize the timeline panel with type and slot index"""
	timeline_type = type
	slot_index = slot

func clear_entities():
	"""Remove all entity nodes from panel"""
	for entity in entities:
		if entity and is_instance_valid(entity):
			entity.queue_free()
	entities.clear()

func clear_arrows():
	"""Remove all arrow nodes from panel"""
	for arrow in arrows:
		if arrow and is_instance_valid(arrow):
			arrow.queue_free()
	arrows.clear()

func clear_all():
	"""Clear both entities and arrows"""
	clear_entities()
	clear_arrows()
