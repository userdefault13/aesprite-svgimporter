#!/usr/bin/env python3
"""
Analyze why winding number might fail for pixel (2,40) in the CamoHat black path.

The path goes from (0,14) → (1,14) → (1,15) → (2,15) → (2,16)
This creates a staircase pattern.

Point to test: (2.5, 40.5) in canvas coords
After scaling: ~(1.04, 14.26) in SVG coords
"""

print("=== WINDING NUMBER ANALYSIS ===\n")

# Simplified polygon representing the staircase section
# Scaled to canvas coordinates (assuming scale ~1.88, offset ~13.2)
polygon = [
    (0.05, 39.52),   # (0, 14) in SVG → canvas
    (1.93, 39.52),   # (1, 14) in SVG → canvas  
    (1.93, 41.40),   # (1, 15) in SVG → canvas
    (3.81, 41.40),   # (2, 15) in SVG → canvas
    (3.81, 43.28),   # (2, 16) in SVG → canvas
    # ... continues around
    (3.81, 30.0),    # arbitrary closing path
    (0.05, 30.0),    # back to left side
]

test_x, test_y = 2.5, 40.5

print(f"Test point: ({test_x}, {test_y})")
print(f"\nPolygon edges:")

winding = 0
n = len(polygon)

for i in range(n):
    j = (i + 1) % n
    xi, yi = polygon[i]
    xj, yj = polygon[j]
    
    print(f"\nEdge {i+1}: ({xi:.2f},{yi:.2f}) → ({xj:.2f},{yj:.2f})")
    
    if yi <= test_y:
        if yj > test_y:
            # Upward crossing
            cross = (xj - xi) * (test_y - yi) - (test_x - xi) * (yj - yi)
            print(f"  Upward crossing candidate")
            print(f"  Cross product: {cross:.3f}")
            if cross > 0:
                winding += 1
                print(f"  → Winding +1 (total: {winding})")
    else:
        if yj <= test_y:
            # Downward crossing
            cross = (xj - xi) * (test_y - yi) - (test_x - xi) * (yj - yi)
            print(f"  Downward crossing candidate")
            print(f"  Cross product: {cross:.3f}")
            if cross < 0:
                winding -= 1
                print(f"  → Winding -1 (total: {winding})")

print(f"\n=== RESULT ===")
print(f"Final winding number: {winding}")
print(f"Point is {'INSIDE' if winding != 0 else 'OUTSIDE'}")

print(f"\n=== ANALYSIS ===")
if winding != 0:
    print("✓ Winding algorithm says INSIDE")
    print("If pixel still not black, issue is:")
    print("  1. Another element painting over it")
    print("  2. Pixel not being added to render queue")  
    print("  3. drawPixel not being called for this coordinate")
else:
    print("✗ Winding algorithm says OUTSIDE") 
    print("Issue is in the winding algorithm itself:")
    print("  1. Duplicate points breaking edge calculation")
    print("  2. Float precision issues")
    print("  3. Edge case in staircase/zigzag patterns")
