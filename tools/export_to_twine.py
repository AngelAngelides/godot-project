#!/usr/bin/env python3
"""Export the game's story JSON files to a Twine-importable Twee file.

Usage:
    python3 tools/export_to_twine.py

Output:
    exports/story.twee

The output uses plain Twee notation. It is designed for visualizing the story
structure in Twine: every choice becomes a visible connection between passages.

Stat checks, item requirements, pickups, and usage are preserved as text
annotations inside links and passages, but they are not enforced automatically.
"""

import json
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
STORY_DIR = PROJECT_ROOT / "data" / "story"
OUTPUT_DIR = PROJECT_ROOT / "exports"
OUTPUT_FILE = OUTPUT_DIR / "story.twee"


def load_story_nodes() -> dict:
    """Load all story JSON files and return node_key -> {source, data}."""
    nodes = {}
    for path in sorted(STORY_DIR.glob("*.json")):
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        if not isinstance(data, dict):
            raise ValueError(f"Expected a JSON object in {path}")
        area = path.stem
        for key, value in data.items():
            if key in nodes:
                print(f"Warning: duplicate node key '{key}' in {path}")
            nodes[key] = {"source": area, "data": value}
    return nodes


def passage_name(node_key: str) -> str:
    """Map the game's start node to Twine's default start passage name."""
    if node_key.lower() == "start":
        return "Start"
    return node_key


def escape_twee_text(text: str) -> str:
    """Escape characters that have special meaning in Twee passages."""
    return text.replace("\\", "\\\\")


def format_link(display: str, target: str) -> str:
    """Return a plain Twee arrow-formatted link.

    Avoids the pipe character in the display text so Twine never confuses it
    with the legacy `[[target|text]]` separator.
    """
    return f"[[{display}->{target}]]"


def format_choice_lines(choice: dict) -> list[str]:
    """Convert a single Godot choice into plain Twine link lines.

    Conditional/stat information is appended to the link display text so that
    Twine's passage map still draws a connection between the passages.
    """
    label = choice.get("text", "")
    lines: list[str] = []

    # Stat check: show both possible destinations as separate visible links.
    if "stat_check" in choice:
        check = choice["stat_check"]
        stat = check.get("stat", "?")
        value = check.get("value", "?")
        pass_node = passage_name(check.get("pass", ""))
        fail_node = passage_name(check.get("fail", ""))
        lines.append(format_link(f"{label} (pass {stat} >= {value})", pass_node))
        lines.append(format_link(f"{label} (fail {stat} < {value})", fail_node))
        return lines

    next_node = passage_name(choice.get("next", ""))
    suffix_parts: list[str] = []

    if "require_stat" in choice and "require_value" in choice:
        suffix_parts.append(f"requires {choice['require_stat']} {choice['require_value']}+")

    if "require_item" in choice:
        suffix_parts.append(f"requires {choice['require_item']}")

    if suffix_parts:
        display = f"{label} ({'; '.join(suffix_parts)})"
    else:
        display = label

    lines.append(format_link(display, next_node))
    return lines


def format_passage(node_key: str, node: dict, area: str) -> str:
    """Format one story node as a Twee passage with annotated links and tags."""
    name = passage_name(node_key)
    text = node.get("text", "")
    text = text.replace("{player_name}", "$playerName")

    tags: list[str] = [f"area:{area}"]
    if "gives_item" in node:
        tags.append(f"gives_item:{node['gives_item']}")
    if "uses_item" in node:
        tags.append(f"uses_item:{node['uses_item']}")

    body_lines = [escape_twee_text(text)]

    choice_lines: list[str] = []
    for choice in node.get("choices", []):
        choice_lines.extend(format_choice_lines(choice))

    if choice_lines:
        body_lines.append("")
        body_lines.extend(choice_lines)

    tag_str = " ".join(tags)
    return f":: {name} [{tag_str}]\n" + "\n".join(body_lines) + "\n"


def build_twee(nodes: dict) -> str:
    """Build the full Twee document from the merged story nodes."""
    passages = []

    # Twine 2 story title.
    passages.append(":: StoryTitle\nChrono Fallout\n")

    # Ensure the start passage is emitted first.
    start_key = next((k for k in nodes if k.lower() == "start"), None)
    if start_key is None:
        raise ValueError("No 'start' node found in story data")

    passages.append(format_passage(start_key, nodes[start_key]["data"], nodes[start_key]["source"]))

    for key, node in nodes.items():
        if key.lower() == "start":
            continue
        passages.append(format_passage(key, node["data"], node["source"]))

    return "\n".join(passages)


def main() -> None:
    if not STORY_DIR.exists():
        raise FileNotFoundError(f"Story directory not found: {STORY_DIR}")

    nodes = load_story_nodes()
    print(f"Loaded {len(nodes)} story node(s) from {STORY_DIR}")

    twee = build_twee(nodes)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        f.write(twee)

    print(f"Exported Twee file: {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
