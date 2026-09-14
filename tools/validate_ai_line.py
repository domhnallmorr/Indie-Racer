"""Check the Mile Oval groove against road edges and optional AI CSV captures.

Run after validate_ai.gd -- --capture:
    python tools/validate_ai_line.py ai_validation_AI_Blue.csv ai_validation_AI_Yellow.csv
"""
import csv
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
track = ROOT / 'content/tracks/mile_oval'
manifest = json.loads((track / 'manifest.json').read_text())
radius = 125.0
half_straight = (manifest['length_m'] - 2 * math.pi * radius) / 4
half_width = manifest['racing_width_m'] / 2


def check(label, points):
    offsets = [math.hypot(max(0, abs(x)-half_straight), z)-radius for x, z in points]
    straight = [abs(z)-radius for x, z in points if abs(x) < 40]
    apex = [math.hypot(abs(x)-half_straight, z)-radius
            for x, z in points if abs(x) > half_straight and abs(z) < 10]
    assert straight and apex, f'{label}: incomplete track coverage'
    assert min(offsets) > -half_width+1.5, f'{label}: too close to inner road edge'
    assert max(offsets) < half_width-1.5, f'{label}: too close to outer wall'
    assert min(straight) > 4, f'{label}: not using outside of straights'
    assert max(apex) < -2, f'{label}: apex is too high'
    print(f'{label}: straight offset {min(straight):.2f}..{max(straight):.2f} m; '
          f'apex offset {min(apex):.2f}..{max(apex):.2f} m (positive = outside).')


line = json.loads((track / 'ai/race_line.json').read_text())['points']
check('Target line', [(p[0], p[2]) for p in line])
for filename in sys.argv[1:]:
    with open(filename, newline='') as source:
        rows = list(csv.DictReader(source))
    # Discard the outlap and merge; inspect all subsequent recorded circuits.
    points = [(float(r['x_m']), float(r['z_m'])) for r in rows
              if r['mode'] == '2' and float(r['time_s']) > 80]
    check(Path(filename).name, points)
print('AI LINE PASSED: outside straights, low apex and road-edge clearance.')
