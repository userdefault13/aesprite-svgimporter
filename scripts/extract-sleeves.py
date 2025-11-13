#!/usr/bin/env python3
import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Dict


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Extract individual sleeve SVGs for a wearable item."
    )
    parser.add_argument(
        "--json",
        required=True,
        help="Path to the wearables JSON file (e.g. wearables-1-20.json).",
    )
    parser.add_argument(
        "--item",
        required=True,
        type=int,
        help="Wearable item id to extract sleeves for.",
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Directory to write the extracted SVG files.",
    )
    return parser


SLEEVE_CLASSES = {
    "left-up": "gotchi-sleeves gotchi-sleeves-left gotchi-sleeves-up",
    "left-down": "gotchi-sleeves gotchi-sleeves-left gotchi-sleeves-down",
    "right-up": "gotchi-sleeves gotchi-sleeves-right gotchi-sleeves-up",
    "right-down": "gotchi-sleeves gotchi-sleeves-right gotchi-sleeves-down",
}


def load_wearable(json_path: Path, item_id: int) -> dict:
    try:
        data = json.loads(json_path.read_text())
    except Exception as exc:
        sys.exit(f"Failed to read {json_path}: {exc}")

    wearables = data.get("wearables") or {}
    wearable = wearables.get(str(item_id))
    if wearable is None:
        sys.exit(f"Item id {item_id} not found in {json_path}")
    return wearable


def extract_g_fragments(svg_text: str) -> Dict[str, str]:
    """
    Collect all <g ...>...</g> fragments keyed by their class attribute.
    """
    fragments: dict[str, str] = {}
    for match in re.finditer(r'(<g[^>]*class="([^"]+)"[^>]*>.*?</g>)', svg_text, re.DOTALL):
        fragment_html, class_attr = match.groups()
        fragments[class_attr] = fragment_html
    return fragments


def gather_sleeve_fragments(wearable: dict) -> Dict[str, str]:
    fragments: Dict[str, str] = {}
    for sleeve_svg in wearable.get("sleeves", []):
        for class_name, fragment in extract_g_fragments(sleeve_svg).items():
            fragments.setdefault(class_name, fragment)
    return fragments


def wrap_svg(fragment: str) -> str:
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">'
        f"{fragment}"
        "</svg>\n"
    )


def main() -> None:
    parser = build_arg_parser()
    args = parser.parse_args()

    json_path = Path(args.json).expanduser()
    output_dir = Path(args.output).expanduser()
    wearable = load_wearable(json_path, args.item)
    fragments_by_class = gather_sleeve_fragments(wearable)

    if not fragments_by_class:
        sys.exit(f"No sleeves found for item {args.item}")

    output_dir.mkdir(parents=True, exist_ok=True)

    for slug, class_name in SLEEVE_CLASSES.items():
        fragment = fragments_by_class.get(class_name)
        if not fragment:
            print(f"Skipping {slug}: class '{class_name}' not present", file=sys.stderr)
            continue
        dest_path = output_dir / f"{args.item}_front_sleeve_{slug}.svg"
        dest_path.write_text(wrap_svg(fragment))
        print(f"Wrote {dest_path}")


if __name__ == "__main__":
    main()

