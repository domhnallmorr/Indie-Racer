"""Build Mile Oval racecraft paths from the current, unmodified racing line."""
import ast
import json
import math
from pathlib import Path

root = Path(__file__).resolve().parents[1]
tree = ast.parse((root / 'tools/build_mile_oval.py').read_text())
names = {'LAP', 'RADIUS', 'STRAIGHT', 'ARC', 'BANK_TRANSITION'}
nodes = [n for n in tree.body if
         isinstance(n, ast.FunctionDef) and n.name == 'corner_bank' or
         isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id in names for t in n.targets)]
scope = {'math': math}
exec(compile(ast.Module(body=nodes, type_ignores=[]), '<track geometry>', 'exec'), scope)
folder = root / 'content/tracks/mile_oval/ai'
race = json.loads((folder / 'race_line.json').read_text())['points']
half, radius = scope['STRAIGHT'] / 2, scope['RADIUS']
paths = {key: [] for key in ('inner', 'outer', 'inside', 'outside')}
for x, height, z in race:
    if -half <= x <= half:
        cx, cz = x, math.copysign(radius, z)
        nx, nz, bank = 0, math.copysign(1, z), 0
    else:
        ox = math.copysign(half, x)
        distance = math.hypot(x - ox, z)
        nx, nz = (x - ox) / distance, z / distance
        cx, cz = ox + nx * radius, nz * radius
        angle = math.atan2(-z, x - ox)
        u = (angle + math.pi / 2 if x > half else
             (angle - math.pi / 2) % (2 * math.pi)) * radius
        bank = math.radians(scope['corner_bank'](u))
    offset = (x - cx) * nx + (z - cz) * nz
    for key, lateral in [('inner', -8), ('outer', 8),
                         ('inside', -4 + .35 * offset), ('outside', 3.5 + .35 * offset)]:
        paths[key].append([round(cx + lateral * nx, 5),
                           round((lateral + 10) * math.tan(bank), 5),
                           round(cz + lateral * nz, 5)])
data = {'schema_version': 1, 'units': 'metres',
        'description': 'Car-centre bounds +/-8 m; two separated PASS1/PASS2 grooves aligned to race_line points. Regenerate after editing the race line.',
        'passing_speed_factor': .985,
        'reference_points': race, **paths}
(folder / 'racing_corridor.json').write_text(json.dumps(data, separators=(',', ':')) + '\n')
