# Grid Configuration System

## Overview

The ChronoShift grid system is now fully configurable! You can easily change the number of cells and panel size without modifying multiple files throughout the codebase.

All grid-related settings are centralized in `scripts/grid_config.gd`.

## How to Change Grid Settings

### Method 1: Direct Configuration

Edit `scripts/grid_config.gd` and modify these variables:

```gdscript
# Number of rows in the grid
static var GRID_ROWS: int = 5

# Number of columns in the grid
static var GRID_COLS: int = 5

# Panel width in pixels
static var PANEL_WIDTH: float = 600.0

# Panel height in pixels
static var PANEL_HEIGHT: float = 750.0
```

**Example: Create a 4x4 grid**
```gdscript
static var GRID_ROWS: int = 4
static var GRID_COLS: int = 4
static var PANEL_WIDTH: float = 600.0
static var PANEL_HEIGHT: float = 600.0
```

**Example: Create a 6x8 wide grid**
```gdscript
static var GRID_ROWS: int = 6
static var GRID_COLS: int = 8
static var PANEL_WIDTH: float = 960.0
static var PANEL_HEIGHT: float = 720.0
```

### Method 2: Use Presets

The GridConfig includes several preset configurations. To apply a preset, call:

```gdscript
GridConfig.apply_preset("preset_name")
```

**Available Presets:**

- `"default"` - 5x5 grid, 600x750 panel (original ChronoShift layout)
- `"small"` - 3x3 grid, 450x450 panel
- `"medium"` - 4x4 grid, 600x600 panel
- `"large"` - 6x6 grid, 720x900 panel
- `"wide"` - 4x8 grid, 960x600 panel
- `"tall"` - 8x4 grid, 480x1200 panel

**Example usage in code:**
```gdscript
# In your game initialization or settings menu
GridConfig.apply_preset("large")
```

## How It Works

### Automatic Calculation

Cell sizes are **automatically calculated** based on panel size and grid dimensions:

```gdscript
cell_width = PANEL_WIDTH / GRID_COLS
cell_height = PANEL_HEIGHT / GRID_ROWS
```

For the default 5x5 grid on a 600x750 panel:
- Cell width: 600 / 5 = 120 pixels
- Cell height: 750 / 5 = 150 pixels

### Dynamic Resizing

All components automatically resize when the configuration changes:

- **Grid cells** - Collision shapes, highlights, borders, and labels
- **Panel** - Main panel, shadow, and container
- **Entity positioning** - Entities are placed at calculated cell centers
- **Targeting** - Valid target calculations adapt to grid size

## API Reference

### GridConfig Static Methods

#### Size Calculations

```gdscript
# Get cell width in pixels
GridConfig.get_cell_width() -> float

# Get cell height in pixels
GridConfig.get_cell_height() -> float

# Get cell size as Vector2
GridConfig.get_cell_size() -> Vector2

# Get panel size as Vector2
GridConfig.get_panel_size() -> Vector2
```

#### Position Calculations

```gdscript
# Get cell position (top-left corner)
GridConfig.get_cell_position(row: int, col: int) -> Vector2

# Get cell center position
GridConfig.get_cell_center_position(row: int, col: int) -> Vector2
```

#### Validation

```gdscript
# Check if row index is valid
GridConfig.is_valid_row(row: int) -> bool

# Check if column index is valid
GridConfig.is_valid_col(col: int) -> bool

# Check if grid position is valid
GridConfig.is_valid_position(row: int, col: int) -> bool
```

#### Info

```gdscript
# Get configuration summary string
GridConfig.get_config_info() -> String
# Returns: "Grid: 5x5 | Panel: 600x750 | Cell: 120.0x150.0"
```

## Examples

### Example 1: Create a Small Arena (3x3)

```gdscript
# In game_manager.gd or similar
func _ready():
    GridConfig.apply_preset("small")
    setup_game()
```

### Example 2: Custom Configuration

```gdscript
# Create a wide rectangular grid
GridConfig.GRID_ROWS = 3
GridConfig.GRID_COLS = 10
GridConfig.PANEL_WIDTH = 1000.0
GridConfig.PANEL_HEIGHT = 450.0

print(GridConfig.get_config_info())
# Output: "Grid: 10x3 | Panel: 1000x450 | Cell: 100.0x150.0"
```

### Example 3: Settings Menu

```gdscript
# In your settings UI
func _on_grid_size_changed(size: String):
    match size:
        "Small (3x3)":
            GridConfig.apply_preset("small")
        "Medium (4x4)":
            GridConfig.apply_preset("medium")
        "Large (6x6)":
            GridConfig.apply_preset("large")

    # Reload the game scene to apply changes
    get_tree().reload_current_scene()
```

## Important Notes

### When Changes Take Effect

Configuration changes are applied when scenes are loaded. To see changes:

1. Modify GridConfig settings
2. Reload the scene: `get_tree().reload_current_scene()`

### Entity Positioning

The `get_grid_position_for_entity()` function in `timeline_panel.gd` still uses hardcoded positioning logic for player and enemies. This was designed for a 5x5 grid.

If you change the grid size significantly, you may need to update these positioning rules:

```gdscript
# In timeline_panel.gd
func get_grid_position_for_entity(entity_index: int, is_player: bool, total_enemies: int) -> Vector2i:
    # Currently assumes 5x5 grid
    # Customize for your grid size
```

### Visual Considerations

- Very small cells (< 80x80 pixels) may make entity sprites difficult to see
- Very large grids (> 10x10) may affect performance
- Maintain reasonable aspect ratios for best visual results

## Troubleshooting

### Issue: Changes not visible

**Solution:** Reload the scene to apply configuration changes:
```gdscript
get_tree().reload_current_scene()
```

### Issue: Entities positioned incorrectly

**Solution:** Check `get_grid_position_for_entity()` in `timeline_panel.gd` and adjust positioning logic for your grid size.

### Issue: Grid lines not showing correctly

**Solution:** Toggle grid lines after resize:
```gdscript
panel.show_grid_lines(true)
```

## Migration from Hardcoded Values

All hardcoded references to grid dimensions have been replaced:

- `GRID_ROWS` → `GridConfig.GRID_ROWS`
- `GRID_COLS` → `GridConfig.GRID_COLS`
- `120` (cell width) → `GridConfig.get_cell_width()`
- `150` (cell height) → `GridConfig.get_cell_height()`
- `Vector2(120, 150)` → `GridConfig.get_cell_size()`
- `600` (panel width) → `GridConfig.PANEL_WIDTH`
- `750` (panel height) → `GridConfig.PANEL_HEIGHT`

## Future Enhancements

Potential improvements for the configuration system:

- [ ] Save/load grid configurations from files
- [ ] Runtime grid resizing without scene reload
- [ ] Adaptive entity positioning for any grid size
- [ ] Grid size presets selectable from main menu
- [ ] Validation to prevent unreasonable grid sizes
