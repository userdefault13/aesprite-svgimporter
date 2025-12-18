#!/usr/bin/env python3
"""Copy Eyes folder for amaave from AavegotchiQuerey to output directory"""

import shutil
import os
from pathlib import Path

source_dir = Path("/Users/juliuswong/Dev/AavegotchiQuerey/cli/exports/Eyes/amaave")
target_dir = Path("/Users/juliuswong/Dev/aesprite-svgimporter/output/amaave/Eyes")

# Check if source exists
if not source_dir.exists():
    print(f"ERROR: Source directory not found: {source_dir}")
    exit(1)

# Check if target parent exists
if not target_dir.parent.exists():
    print(f"ERROR: Target parent directory not found: {target_dir.parent}")
    exit(1)

# Create target directory
target_dir.mkdir(parents=True, exist_ok=True)

# Copy the entire Eyes/amaave structure
print(f"Copying Eyes folder for amaave...")
print(f"  From: {source_dir}")
print(f"  To: {target_dir}")

try:
    # Copy all contents from source to target
    for item in source_dir.iterdir():
        dest = target_dir / item.name
        if item.is_dir():
            shutil.copytree(item, dest, dirs_exist_ok=True)
        else:
            shutil.copy2(item, dest)
    
    print("✓ Successfully copied Eyes folder structure")
    print(f"\nStructure in {target_dir}:")
    for item in sorted(target_dir.iterdir()):
        if item.is_dir():
            count = len(list(item.rglob("*.json")))
            print(f"  {item.name}/ ({count} JSON files)")
    
except Exception as e:
    print(f"✗ Error copying files: {e}")
    exit(1)

