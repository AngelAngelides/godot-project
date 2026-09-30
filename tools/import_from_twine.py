#!/usr/bin/env python3
"""Import a Twine Twee file back into the game's per-area JSON story files.

Usage:
    python3 tools/import_from_twine.py [path/to/file.twee] [--output-dir data/story]

Defaults:
    Input:  exports/story.twee
    Output: data/story/

The input must follow the annotation convention produced by export_to_twine.py:
- Passages may have tags:
    [area:control_room]             -> writes to data/story/control_room.json
    [gives_item:Keycard]            -> JSON "gives_item": "Keycard"
    [uses_item:Gun]                  -> JSON "uses_item": "Gun"
- Links may be annotated:
    [[Choice text->target]]
    [[Choice text (requires Strength 3+)->target]]
    [[Choice text (requires Keycard)->target]]
    [[Choice text (pass Strength >= 3)->target_pass]]
    [[Choice text (fail Strength < 3)->target_fail]]

Pass/fail pairs with the same base text are merged into one JSON stat_check.
"""

import argparse
import json
import re
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_INPUT = PROJECT_ROOT / "exports" / "story.twee"
DEFAULT_OUTPUT_DIR = PROJECT_ROOT / "data" / "story"

KNOWN_STATS = {"Strength", "Perception", "Intelligence", "Agility", "Endurance"}

PASS_RE = re.compile(r"\(pass\s+(\w+)\s*(>=|<=|>|<|=)\s*(\d+)\)\s*$")
FAIL_RE = re.compile(r"\(fail\s+(\w+)\s*(>=|<=|>|<|=)\s*(\d+)\)\s*$")
REQUIRE_STAT_RE = re.compile(r"\(requires\s+(\w+)\s+(\d+)\+\)\s*$")
REQUIRE_ITEM_RE = re.compile(r"\(requires\s+(.+?)\)\s*$")
LINK_RE = re.compile(r"\[\[(.*?)\]\]", re.DOTALL)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Import a Twee file into story JSON")
    parser.add_argument("input", nargs="?", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    return parser.parse_args()


def parse_passages(text: str) -> list[dict]:
    """Split a Twee file into passages with name, tags, and body."""
    header_re = re.compile(r"^::\s+(.+?)(?:\s+\[(.*?)\])?\s*$", re.MULTILINE)
    matches = list(header_re.finditer(text))
    passages = []
    for i, m in enumerate(matches):
        name = m.group(1).strip()
        tags = [t.strip() for t in (m.group(2) or "").split() if t.strip()]
        start = m.end()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        body = text[start:end].strip("\n")
        passages.append({"name": name, "tags": tags, "body": body})
    return passages


def node_key_from_passage_name(name: str) -> str:
    return "start" if name.lower() == "start" else name


def parse_tags(tags: list[str]) -> dict:
    """Extract area, gives_item, and uses_item from passage tags."""
    meta = {"area": "imported"}
    for tag in tags:
        if ":" not in tag:
            continue
        key, value = tag.split(":", 1)
        if key == "area":
            meta["area"] = value.strip()
        elif key == "gives_item":
            meta["gives_item"] = value.strip()
        elif key == "uses_item":
            meta["uses_item"] = value.strip()
    return meta


def parse_link(display: str, target: str) -> dict:
    """Parse a single Twee link into a structured choice dict."""
    display = display.strip()
    target = node_key_from_passage_name(target.strip())

    for pattern, kind in [
        (PASS_RE, "pass"),
        (FAIL_RE, "fail"),
    ]:
        m = pattern.search(display)
        if m:
            stat, op, value = m.group(1), m.group(2), int(m.group(3))
            base = display[: m.start()].strip()
            return {
                "kind": kind,
                "base_text": base,
                "target": target,
                "stat": stat,
                "op": op,
                "value": value,
            }

    m = REQUIRE_STAT_RE.search(display)
    if m:
        stat, value = m.group(1), int(m.group(2))
        base = display[: m.start()].strip()
        return {
            "kind": "require_stat",
            "base_text": base,
            "target": target,
            "stat": stat,
            "value": value,
        }

    m = REQUIRE_ITEM_RE.search(display)
    if m:
        item = m.group(1).strip()
        # Avoid mistaking a stat requirement for an item requirement.
        if item not in KNOWN_STATS:
            base = display[: m.start()].strip()
            return {
                "kind": "require_item",
                "base_text": base,
                "target": target,
                "item": item,
            }

    return {"kind": "plain", "base_text": display, "target": target}


def extract_links(body: str) -> list[dict]:
    """Extract all links from a passage body."""
    links = []
    for m in LINK_RE.finditer(body):
        content = m.group(1)
        if "->" in content:
            display, target = content.rsplit("->", 1)
        else:
            display, target = content, content
        links.append(parse_link(display, target))
    return links


def build_choices(links: list[dict]) -> list[dict]:
    """Build JSON choice objects from parsed links, merging pass/fail pairs.

    Preserves the original link order by inserting the merged stat_check choice
    at the position of its first branch.
    """
    choices: list[dict] = []
    used: set[int] = set()

    for i, link in enumerate(links):
        if i in used:
            continue

        if link["kind"] in ("pass", "fail"):
            key = (link["base_text"], link["stat"], link["value"])
            pair_index = None
            for j in range(i + 1, len(links)):
                other = links[j]
                if j in used:
                    continue
                if (
                    other["kind"] in ("pass", "fail")
                    and other["base_text"] == link["base_text"]
                    and other["stat"] == link["stat"]
                    and other["value"] == link["value"]
                ):
                    pair_index = j
                    break

            if pair_index is not None:
                other = links[pair_index]
                pass_target = link["target"] if link["kind"] == "pass" else other["target"]
                fail_target = other["target"] if link["kind"] == "pass" else link["target"]
                choices.append({
                    "text": link["base_text"],
                    "stat_check": {
                        "stat": link["stat"],
                        "value": link["value"],
                        "pass": pass_target,
                        "fail": fail_target,
                    },
                })
                used.add(i)
                used.add(pair_index)
                continue

            # No matching branch found; treat it as a plain link.
            choices.append({"text": link["base_text"], "next": link["target"]})
            used.add(i)
        elif link["kind"] == "require_stat":
            choices.append({
                "text": link["base_text"],
                "next": link["target"],
                "require_stat": link["stat"],
                "require_value": link["value"],
            })
            used.add(i)
        elif link["kind"] == "require_item":
            choices.append({
                "text": link["base_text"],
                "next": link["target"],
                "require_item": link["item"],
            })
            used.add(i)
        else:
            choices.append({"text": link["base_text"], "next": link["target"]})
            used.add(i)

    return choices


def passage_to_node(passage: dict) -> tuple[str, str, dict]:
    """Convert a parsed passage into (area, node_key, node_data)."""
    meta = parse_tags(passage["tags"])
    key = node_key_from_passage_name(passage["name"])

    body = passage["body"]
    body = body.replace("\\\\", "\\")  # Twee escape -> literal backslash
    body = body.replace("$playerName", "{player_name}")

    # Remove link lines from body; they belong in choices.
    text = LINK_RE.sub("", body).strip()

    node = {"text": text}
    if "gives_item" in meta:
        node["gives_item"] = meta["gives_item"]
    if "uses_item" in meta:
        node["uses_item"] = meta["uses_item"]

    links = extract_links(body)
    choices = build_choices(links)
    if choices:
        node["choices"] = choices

    return meta["area"], key, node


def load_twee(path: Path) -> list[dict]:
    with open(path, "r", encoding="utf-8") as f:
        return parse_passages(f.read())


def validate(nodes: dict[str, dict], links: list[dict]) -> None:
    """Warn about any links that point to missing passages."""
    targets = {link["target"] for link in links}
    missing = [t for t in targets if t not in nodes]
    if missing:
        print("Warning: the following link targets have no matching passage:")
        for t in missing:
            print(f"  - {t}")


def write_area_files(nodes_by_area: dict[str, dict], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for area, nodes in nodes_by_area.items():
        path = output_dir / f"{area}.json"
        with open(path, "w", encoding="utf-8") as f:
            json.dump(nodes, f, indent="\t", ensure_ascii=False)
            f.write("\n")
        print(f"Wrote {len(nodes)} node(s) to {path}")


def main() -> None:
    args = parse_args()

    if not args.input.exists():
        raise FileNotFoundError(f"Input file not found: {args.input}")

    passages = load_twee(args.input)
    nodes_by_area: dict[str, dict[str, dict]] = {}
    all_nodes: dict[str, dict] = {}
    all_links: list[dict] = []

    for passage in passages:
        # StoryTitle and other metadata passages are skipped.
        if passage["name"].lower() in ("storytitle",):
            continue
        area, key, node = passage_to_node(passage)
        nodes_by_area.setdefault(area, {})[key] = node
        all_nodes[key] = node
        all_links.extend(extract_links(passage["body"]))

    validate(all_nodes, all_links)
    write_area_files(nodes_by_area, args.output_dir)


if __name__ == "__main__":
    main()
