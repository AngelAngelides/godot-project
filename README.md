# chono-fallout

Text-based choice game built with Godot 4. Create a character, make decisions, pass stat checks, and collect or consume items as you navigate the story.

## Getting Started

1. Open Godot 4 (latest stable) and select this folder as the project.
2. The entry scene is `scenes/CharacterCreation.tscn`.
3. Press Play to run.

## How to Play

1. Enter a name and distribute 10 bonus points across five stats:
   - Strength
   - Perception
   - Intelligence
   - Agility
   - Endurance
2. Click **Start Game** to enter the main story scene (`scenes/Main.tscn`).
3. Read each story node and choose from the available actions.
4. Some choices require a minimum stat, a specific item, or a stat check that routes to different outcomes.

## Project Structure

- `project.godot` – Project settings and autoloads
- `scenes/`
  - `CharacterCreation.tscn` – Character creation screen (entry point)
  - `Main.tscn` – Main story/gameplay screen
- `scripts/`
  - `character_creation.gd` – Character creation UI logic
  - `game_manager.gd` – Story display and choice button handling
  - `story_data.gd` – Loads story nodes from JSON
  - `player_data.gd` – Player stats and inventory (autoload)
  - `item_database.gd` – Loads item definitions from JSON (autoload)
- `data/`
  - `story/*.json` – Story node definitions
  - `items/items.json` – Item definitions (display name, consumable flag, max uses)
- `themes/game_theme.tres` – UI theme

## Story Data Format

Each JSON file in `data/story/` contains a flat map of node IDs to node data:

```json
{
  "node_id": {
    "text": "Story passage text...",
    "gives_item": "ItemID",
    "uses_item": "ItemID",
    "choices": [
      {"text": "Choice text", "next": "another_node"},
      {"text": "Stat-gated choice", "next": "node", "require_stat": "Strength", "require_value": 3},
      {"text": "Item-gated choice", "next": "node", "require_item": "Keycard"},
      {"text": "Skill check", "stat_check": {"stat": "Perception", "value": 3, "pass": "pass_node", "fail": "fail_node"}}
    ]
  }
}
```

## Items

Items are defined in `data/items/items.json`. Each item has an ID, display name, and usage settings:

```json
{
  "Gun": {
    "display_name": "Pistol",
    "consumable": true,
    "max_uses": 6
  }
}
```

- `consumable: true` with `max_uses > 0` means the item has a limited number of uses.
- `consumable: false` with `max_uses: -1` means the item is unlimited (e.g. keycards, flashlight).

## Twine round-trip workflow

You can export the story to Twine for editing/visualizing, then import it back into the game's JSON files.

### Export to Twine

```bash
python3 tools/export_to_twine.py
```

This produces `exports/story.twee`. Import it into Twine 2 via **Library > Import > Import From File** (or **File > Import From File**).

### Import from Twine

```bash
python3 tools/import_from_twine.py path/to/your_story.twee
```

This writes per-area JSON files back into `data/story/`. The default input is `exports/story.twee`.

### Annotation convention

The exporter writes the following annotations so the importer can reconstruct the JSON structure. If you edit the story in Twine, keep using the same annotations.

**Passage tags (used for item effects and output file):**

- `area:control_room` — writes this passage to `data/story/control_room.json`
- `gives_item:Keycard` — maps to JSON `"gives_item": "Keycard"`
- `uses_item:Gun` — maps to JSON `"uses_item": "Gun"`

**Link annotations (used for choices):**

```twee
[[Choice text->target]]
[[Choice text (requires Strength 3+)->target]]
[[Choice text (requires Keycard)->target]]
[[Choice text (pass Strength >= 3)->target_pass]]
[[Choice text (fail Strength < 3)->target_fail]]
```

A `pass`/`fail` pair with the same base text is merged into one JSON `stat_check` choice. The story is exported for **visualization**, not for playing inside Twine — the annotations are plain text, not macros.
