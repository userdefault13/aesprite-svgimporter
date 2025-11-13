#!/usr/bin/env python3
"""
Generate all 4 views (front, left, right, back) for a wearable item
Usage: python3 generate-item-all-views.py [item_id]
Example: python3 generate-item-all-views.py 11
"""
import json
from pathlib import Path
import xml.etree.ElementTree as ET
from copy import deepcopy
import subprocess
import sys

SVG_NS = 'http://www.w3.org/2000/svg'
ET.register_namespace('', SVG_NS)
ROOT = Path('.')

# Get item ID from command line or default to 8
item_id = sys.argv[1] if len(sys.argv) > 1 else '8'
print(f"Processing item {item_id}...")

# Load JSON data - check multiple possible locations
json_paths = [
    'wearables-1-420.json',
    'wearables-1-20.json',
    '../AavegotchiQuerey/wearables-1-420.json',
    '../AavegotchiQuerey/wearables-1-20.json',
    '/Users/juliuswong/Dev/AavegotchiQuerey/wearables-1-420.json',
    '/Users/juliuswong/Dev/AavegotchiQuerey/wearables-1-20.json'
]

json_path = None
for path in json_paths:
    if Path(path).exists():
        json_path = path
        break

if not json_path:
    print("Error: Could not find wearables-1-20.json")
    print("Searched in:", json_paths)
    sys.exit(1)

with open(json_path, 'r') as f:
    data = json.load(f)
    if item_id not in data['wearables']:
        print(f"Error: Item {item_id} not found in wearables JSON")
        sys.exit(1)
    item = data['wearables'][item_id]
    item_name = item.get('name', f'Item{item_id}')
    print(f"Item name: {item_name}")

# Check if it's a body item by loading aavegotchi_db_wearables.json
db_json_paths = [
    'aavegotchi_db_wearables.json',
    '../AavegotchiQuerey/aavegotchi_db_wearables.json',
    '/Users/juliuswong/Dev/AavegotchiQuerey/aavegotchi_db_wearables.json'
]

db_json_path = None
for path in db_json_paths:
    if Path(path).exists():
        db_json_path = path
        break

is_body_item = False
if db_json_path:
    try:
        with open(db_json_path, 'r') as f:
            db_data = json.load(f)
            # Find item by ID in the wearables array
            for wearable in db_data.get('wearables', []):
                if wearable.get('id') == int(item_id):
                    slot_positions = wearable.get('slotPositions', [])
                    is_body_item = slot_positions[0] if len(slot_positions) > 0 else False
                    break
    except Exception as e:
        print(f"Warning: Could not check body item status: {e}")
        # Default to body item if we can't check
        is_body_item = True

print(f"Is body item: {is_body_item}")

# Sanitize item name for filename
def sanitize_filename(name):
    # Remove or replace characters that cause filesystem issues
    name = name.replace(' ', '').replace("'", "").replace("-", "").replace(".", "")
    name = name.replace("/", "").replace("\\", "").replace(":", "").replace("*", "")
    name = name.replace("?", "").replace("\"", "").replace("<", "").replace(">", "")
    name = name.replace("|", "")
    return name

item_name_safe = sanitize_filename(item_name)

examples = ROOT / 'examples/svgItems'

def extract_groups(svg_text, class_names):
    """Extract groups by class from SVG text"""
    # Strip backticks if present (some JSON entries have them)
    svg_text = svg_text.strip().strip('`')
    root = ET.fromstring(svg_text)
    groups = {}
    for elem in root.findall(f'.//{{{SVG_NS}}}g'):
        cls = elem.get('class', '')
        for name in class_names:
            if name in cls and name not in groups:
                groups[name] = deepcopy(elem)
                break
    return groups

def write_svg_file(path, elements):
    """Write SVG file with given elements"""
    svg = ET.Element(f'{{{SVG_NS}}}svg', {'xmlns': SVG_NS, 'viewBox': '0 0 64 64'})
    for elem in elements:
        if elem is not None:
            svg.append(elem)
    path.write_text(ET.tostring(svg, encoding='unicode'))

if not is_body_item:
    # ===== NON-BODY ITEMS: SIMPLE STRUCTURE =====
    print("\nProcessing non-body item with simple structure...")
    
    # Create single output directory
    output_base = ROOT / f'output/{item_id}_{item_name_safe}'
    output_base.mkdir(parents=True, exist_ok=True)
    
    # Create temp directory for SVGs
    temp_dir = ROOT / f'tmp/{item_id}_{item_name_safe}'
    temp_dir.mkdir(parents=True, exist_ok=True)
    
    # Process each view and create single SVG files
    views_data = [
        ('front', item['sides']['Front']),
        ('back', item['sides']['Back']),
        ('left', item['sides']['Left']),
        ('right', item['sides']['Right']),
    ]
    
    # Process each view separately to avoid duplicates
    print("\nSVG files prepared. Now running batch converter...")
    view_idx_map = {'front': 0, 'back': 3, 'left': 1, 'right': 2}
    view_suffix_map = {'front': 'front', 'back': 'back', 'left': 'left', 'right': 'right'}
    
    for view_name, view_data in views_data:
        print(f"\nProcessing {view_name.upper()} view...")
        view_svg = view_data['svg'].strip().strip('`')
        try:
            view_root = ET.fromstring(view_svg)
        except ET.ParseError as e:
            print(f"✗ Error parsing SVG for {view_name} view: {e}")
            print(f"  Skipping this view...")
            continue
        
        # Extract all wearable groups
        svg_elem = ET.Element(f'{{{SVG_NS}}}svg', {'xmlns': SVG_NS, 'viewBox': '0 0 64 64'})
        for g in view_root.findall(f'.//{{{SVG_NS}}}g'):
            if 'gotchi-wearable' in g.get('class', ''):
                svg_elem.append(deepcopy(g))
        
        # Create separate temp directory for this view
        view_temp_dir = temp_dir / view_name
        view_temp_dir.mkdir(parents=True, exist_ok=True)
        
        # Write SVG file
        svg_file = view_temp_dir / f'{item_id}_{item_name_safe}_{view_name}.svg'
        svg_file.write_text(ET.tostring(svg_elem, encoding='unicode'))
        
        # Convert this view
        view_idx = view_idx_map[view_name]
        print(f"Converting {view_name} view (index {view_idx})...")
        result = subprocess.run(
            ['./batch-process.sh', str(view_temp_dir), str(output_base), str(view_idx)],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            print(f"✓ {view_name} view completed")
            
            # Rename files to remove duplicate view suffix
            view_suffix = view_suffix_map[view_name]
            for aseprite_file in output_base.glob(f'*_{view_name}_{view_suffix}.aseprite'):
                old_name = aseprite_file.name
                base_without_ext = old_name[:-len('.aseprite')]
                # Remove the duplicate suffix (e.g., _front_front -> _front)
                if base_without_ext.endswith(f'_{view_name}_{view_suffix}'):
                    new_name = base_without_ext[:-len(f'_{view_suffix}')] + '.aseprite'
                    new_path = output_base / new_name
                    aseprite_file.rename(new_path)
                    print(f"  Renamed: {old_name} → {new_name}")
        else:
            print(f"✗ {view_name} view failed:")
            print(result.stderr)
            sys.exit(1)
    
    print(f"\n✅ Non-body item generated successfully!")
    print(f"Output location: output/{item_id}_{item_name_safe}/")
    
else:
    # ===== BODY ITEMS: COMPLEX STRUCTURE WITH SLEEVES =====
    print("\nProcessing body item with complex structure...")

    # ===== FRONT VIEW =====
    print("Processing FRONT view...")
    front_svg = item['sides']['Front']['svg']
    front_groups = extract_groups(front_svg, ['gotchi-wearable wearable-body'])

    # Extract sleeves from sleeves array
    sleeves = item.get('sleeves', [])
    def extract_sleeve_group(svg_text, class_pattern):
        # Handle None or empty strings
        if not svg_text or svg_text is None:
            return None
        # Strip backticks if present
        svg_text = svg_text.strip().strip('`')
        if not svg_text:
            return None
        try:
            root = ET.fromstring(svg_text)
            for g in root.findall(f'.//{{{SVG_NS}}}g'):
                cls = g.get('class', '')
                if class_pattern in cls:
                    return deepcopy(g)
        except ET.ParseError:
            return None
        return None

    # Left/right sleeves up/down
    # sleeves[0] has all 4, sleeves[1] has left only, sleeves[2] has right only, sleeves[3] has both up
    left_up = extract_sleeve_group(sleeves[0] if len(sleeves) > 0 and sleeves[0] else None, 'gotchi-sleeves-left gotchi-sleeves-up')
    left_down = extract_sleeve_group(sleeves[0] if len(sleeves) > 0 and sleeves[0] else None, 'gotchi-sleeves-left gotchi-sleeves-down')
    right_up = extract_sleeve_group(sleeves[0] if len(sleeves) > 0 and sleeves[0] else None, 'gotchi-sleeves-right gotchi-sleeves-up')
    right_down = extract_sleeve_group(sleeves[0] if len(sleeves) > 0 and sleeves[0] else None, 'gotchi-sleeves-right gotchi-sleeves-down')

    front_dir = ROOT / f'tmp/{item_id}_{item_name_safe}/Front'
    front_dir.mkdir(parents=True, exist_ok=True)
    write_svg_file(front_dir / f'{item_id}_{item_name_safe}_Front.svg', [front_groups['gotchi-wearable wearable-body']])

    # Separate left and right sleeves
    if left_up is not None:
        left_up_svg = ET.Element(f'{{{SVG_NS}}}svg', {'xmlns': SVG_NS, 'viewBox': '0 0 64 64'})
        left_up_svg.append(left_up)
        (front_dir / f'{item_id}_{item_name_safe}_Front_LeftUp.svg').write_text(ET.tostring(left_up_svg, encoding='unicode'))

    if left_down is not None:
        left_down_svg = ET.Element(f'{{{SVG_NS}}}svg', {'xmlns': SVG_NS, 'viewBox': '0 0 64 64'})
        left_down_svg.append(left_down)
        (front_dir / f'{item_id}_{item_name_safe}_FrontLeft.svg').write_text(ET.tostring(left_down_svg, encoding='unicode'))

    if right_up is not None:
        right_up_svg = ET.Element(f'{{{SVG_NS}}}svg', {'xmlns': SVG_NS, 'viewBox': '0 0 64 64'})
        right_up_svg.append(right_up)
        (front_dir / f'{item_id}_{item_name_safe}_Front_RightUp.svg').write_text(ET.tostring(right_up_svg, encoding='unicode'))

    if right_down is not None:
        right_down_svg = ET.Element(f'{{{SVG_NS}}}svg', {'xmlns': SVG_NS, 'viewBox': '0 0 64 64'})
        right_down_svg.append(right_down)
        (front_dir / f'{item_id}_{item_name_safe}_FrontRight.svg').write_text(ET.tostring(right_down_svg, encoding='unicode'))

    # ===== LEFT VIEW =====
    print("Processing LEFT view...")
    left_svg = item['sides']['Left']['svg']
    left_groups = extract_groups(left_svg, ['gotchi-wearable wearable-body', 'gotchi-wearable gotchi-secondary'])

    left_dir = ROOT / f'tmp/{item_id}_{item_name_safe}/Left'
    left_dir.mkdir(parents=True, exist_ok=True)
    body_elements = [left_groups.get('gotchi-wearable wearable-body')]
    if 'gotchi-wearable gotchi-secondary' in left_groups:
        body_elements.append(left_groups['gotchi-wearable gotchi-secondary'])
    write_svg_file(left_dir / f'{item_id}_{item_name_safe}_SideLeft.svg', body_elements)

    # Left sleeves from examples
    def make_side_sleeve(name, pose):
        src = ET.fromstring((examples / name).read_text())
        top = ET.Element(f'{{{SVG_NS}}}svg', {'xmlns': SVG_NS, 'viewBox': '0 0 64 64'})
        inner = ET.SubElement(top, f'{{{SVG_NS}}}svg', {'x': '20', 'y': '28'})
        group = ET.SubElement(inner, f'{{{SVG_NS}}}g', {'class': f'gotchi-sleeves gotchi-sleeves-left gotchi-sleeves-{pose}'})
        for child in list(src):
            group.append(deepcopy(child))
        return top

    # Find left sleeve files
    left_up_files = list(examples.glob(f'{item_id}_*SideLeftUp.svg'))
    left_down_files = list(examples.glob(f'{item_id}_*SideLeftDown.svg'))
    if left_up_files:
        (left_dir / f'{item_id}_{item_name_safe}_SideLeftUp.svg').write_text(ET.tostring(make_side_sleeve(left_up_files[0].name, 'up'), encoding='unicode'))
    if left_down_files:
        (left_dir / f'{item_id}_{item_name_safe}_SideLeftDown.svg').write_text(ET.tostring(make_side_sleeve(left_down_files[0].name, 'down'), encoding='unicode'))

    # ===== RIGHT VIEW =====
    print("Processing RIGHT view...")
    right_svg = item['sides']['Right']['svg']
    right_groups = extract_groups(right_svg, ['gotchi-wearable wearable-body', 'gotchi-wearable gotchi-secondary'])

    right_dir = ROOT / f'tmp/{item_id}_{item_name_safe}/Right'
    right_dir.mkdir(parents=True, exist_ok=True)
    body_elements = [right_groups.get('gotchi-wearable wearable-body')]
    if 'gotchi-wearable gotchi-secondary' in right_groups:
        body_elements.append(right_groups['gotchi-wearable gotchi-secondary'])
    write_svg_file(right_dir / f'{item_id}_{item_name_safe}_SideRight.svg', body_elements)

    def make_right_sleeve(name, pose):
        src = ET.fromstring((examples / name).read_text())
        top = ET.Element(f'{{{SVG_NS}}}svg', {'xmlns': SVG_NS, 'viewBox': '0 0 64 64'})
        inner = ET.SubElement(top, f'{{{SVG_NS}}}svg', {'x': '20', 'y': '28'})
        group = ET.SubElement(inner, f'{{{SVG_NS}}}g', {'class': f'gotchi-sleeves gotchi-sleeves-right gotchi-sleeves-{pose}'})
        for child in list(src):
            group.append(deepcopy(child))
        return top

    # Find right sleeve files
    right_up_files = list(examples.glob(f'{item_id}_*SideRightUp.svg'))
    right_down_files = list(examples.glob(f'{item_id}_*SideRightDown.svg'))
    if right_up_files:
        (right_dir / f'{item_id}_{item_name_safe}_SideRightUp.svg').write_text(ET.tostring(make_right_sleeve(right_up_files[0].name, 'up'), encoding='unicode'))
    if right_down_files:
        (right_dir / f'{item_id}_{item_name_safe}_SideRightDown.svg').write_text(ET.tostring(make_right_sleeve(right_down_files[0].name, 'down'), encoding='unicode'))

    # ===== BACK VIEW =====
    print("Processing BACK view...")
    back_svg = item['sides']['Back']['svg']
    # Strip backticks if present
    back_svg = back_svg.strip().strip('`')
    back_root = ET.fromstring(back_svg)
    back_body = None
    for elem in back_root.findall(f'.//{{{SVG_NS}}}g'):
        if elem.get('class') == 'gotchi-wearable wearable-body':
            back_body = deepcopy(elem)
            # Remove embedded sleeves
            for child in list(elem):
                if 'gotchi-sleeves' in child.get('class', ''):
                    elem.remove(child)
            break

    back_dir = ROOT / f'tmp/{item_id}_{item_name_safe}/Back'
    back_dir.mkdir(parents=True, exist_ok=True)
    write_svg_file(back_dir / f'{item_id}_{item_name_safe}_Back.svg', [back_body])

    def make_back_sleeve(name, side, pose):
        src = ET.fromstring((examples / name).read_text())
        top = ET.Element(f'{{{SVG_NS}}}svg', {'xmlns': SVG_NS, 'viewBox': '0 0 64 64'})
        wrap = ET.SubElement(top, f'{{{SVG_NS}}}svg', {'x': '12', 'y': '32'})
        group = ET.SubElement(wrap, f'{{{SVG_NS}}}g', {'class': f'gotchi-sleeves gotchi-sleeves-{side} {pose}'})
        for child in list(src):
            group.append(deepcopy(child))
        return top

    # Find back sleeve files
    back_left_up_files = list(examples.glob(f'{item_id}_*BackLeftUp.svg'))
    back_left_down_files = list(examples.glob(f'{item_id}_*BackLeft.svg'))
    back_right_up_files = list(examples.glob(f'{item_id}_*BackRightUp.svg'))
    back_right_down_files = list(examples.glob(f'{item_id}_*BackRight.svg'))

    # Filter out "Up" files from down list
    back_left_down_files = [f for f in back_left_down_files if 'Up' not in f.name]
    back_right_down_files = [f for f in back_right_down_files if 'Up' not in f.name]

    if back_left_up_files:
        (back_dir / f'{item_id}_{item_name_safe}_Back_LeftUp.svg').write_text(ET.tostring(make_back_sleeve(back_left_up_files[0].name, 'left', 'gotchi-sleeves-up'), encoding='unicode'))
    if back_left_down_files:
        (back_dir / f'{item_id}_{item_name_safe}_BackLeft.svg').write_text(ET.tostring(make_back_sleeve(back_left_down_files[0].name, 'left', 'gotchi-sleeves-down'), encoding='unicode'))
    if back_right_up_files:
        (back_dir / f'{item_id}_{item_name_safe}_Back_RightUp.svg').write_text(ET.tostring(make_back_sleeve(back_right_up_files[0].name, 'right', 'gotchi-sleeves-up'), encoding='unicode'))
    if back_right_down_files:
        (back_dir / f'{item_id}_{item_name_safe}_BackRight.svg').write_text(ET.tostring(make_back_sleeve(back_right_down_files[0].name, 'right', 'gotchi-sleeves-down'), encoding='unicode'))

    print("\nSVG files prepared. Now running batch converter...")

    # Run batch converter for each view
    views = [
        ('Front', 0, front_dir),
        ('Left', 1, left_dir),
        ('Right', 2, right_dir),
        ('Back', 3, back_dir),
    ]

    output_base = ROOT / f'output/{item_id}_{item_name_safe}'
    
    # Map view names to their suffix that batch converter adds
    view_suffix_map = {
        'Front': 'front',
        'Left': 'left',
        'Right': 'right',
        'Back': 'back'
    }
    
    for view_name, view_idx, input_dir in views:
        output_dir = output_base / view_name
        print(f"\nConverting {view_name} view (index {view_idx})...")
        result = subprocess.run(
            ['./batch-process.sh', str(input_dir), str(output_dir), str(view_idx)],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            print(f"✓ {view_name} view completed")
            
            # Rename files to remove duplicate view suffix
            view_suffix = view_suffix_map[view_name]
            for aseprite_file in output_dir.glob('*.aseprite'):
                old_name = aseprite_file.name
                base_without_ext = old_name[:-len('.aseprite')]
                # Check if filename ends with _{view_suffix}_{view_suffix} (duplicate)
                # Pattern: {item_id}_{item_name}_{View}_{view_suffix}.aseprite
                # Should become: {item_id}_{item_name}_{View}.aseprite
                if base_without_ext.endswith(f'_{view_suffix}_{view_suffix}'):
                    # Remove the duplicate suffix
                    new_name = base_without_ext[:-len(f'_{view_suffix}')] + '.aseprite'
                    new_path = output_dir / new_name
                    aseprite_file.rename(new_path)
                    print(f"  Renamed: {old_name} → {new_name}")
                elif base_without_ext.endswith(f'_{view_suffix}'):
                    # Remove the view suffix that batch converter added
                    # Pattern examples:
                    # - 8_MarineJacket_FrontLeft_front -> 8_MarineJacket_FrontLeft
                    # - 8_MarineJacket_Front_LeftUp_front -> 8_MarineJacket_Front_LeftUp
                    # - 8_MarineJacket_BackLeft_back -> 8_MarineJacket_BackLeft
                    parts = base_without_ext.split('_')
                    if len(parts) >= 2:
                        # Check if the last part is the view suffix we want to remove
                        if parts[-1] == view_suffix:
                            # Remove the last part (the view suffix)
                            new_name = '_'.join(parts[:-1]) + '.aseprite'
                            new_path = output_dir / new_name
                            aseprite_file.rename(new_path)
                            print(f"  Renamed: {old_name} → {new_name}")
        else:
            print(f"✗ {view_name} view failed:")
            print(result.stderr)
            sys.exit(1)

    print("\n✅ All 4 views generated successfully!")
    print("\nOutput locations:")
    print(f"  - Front: output/{item_id}_{item_name_safe}/Front/")
    print(f"  - Left:  output/{item_id}_{item_name_safe}/Left/")
    print(f"  - Right: output/{item_id}_{item_name_safe}/Right/")
    print(f"  - Back:  output/{item_id}_{item_name_safe}/Back/")

