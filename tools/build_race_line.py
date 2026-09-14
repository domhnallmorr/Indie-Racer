"""Generate a wide-entry, low-apex oval groove with progressive transitions."""
import ast
import json
import math
from pathlib import Path

root = Path(__file__).resolve().parents[1]
# Reuse track geometry functions without importing Blender or executing its build.
tree = ast.parse((root / 'tools/build_mile_oval.py').read_text())
names = {'LAP', 'RADIUS', 'STRAIGHT', 'ARC', 'BANK_TRANSITION'}
nodes = [n for n in tree.body if
         isinstance(n, ast.FunctionDef) and n.name in {'corner_bank', 'frame', 'point'} or
         isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id in names for t in n.targets)]
scope = {'math': math}
exec(compile(ast.Module(body=nodes, type_ignores=[]), '<track geometry>', 'exec'), scope)
path = root / 'content/tracks/mile_oval/ai/race_line.json'
data = json.loads(path.read_text())
points = []
count = math.ceil(scope['LAP'] / 2)
def raw_point(s):
    # Spread the lateral transition onto the straights. Confine it to the
    # corner itself and its extra curvature produces two separate slowdowns.
    transition = 100.0
    half_lap = scope['STRAIGHT'] + scope['ARC']
    phase = (s - scope['STRAIGHT'] + transition) % half_lap
    span = scope['ARC'] + 2 * transition
    offset = 6.0
    if phase < span:
        offset -= 6.0 * math.sin(math.pi * phase / span)**2
    return scope['point'](s, offset)


for i in range(count + 1):
    s = scope['LAP'] * i / count
    # Blend the horizontal path over +/-120 metres. This begins turning on the
    # straight and removes the abrupt curvature change at the circular joins.
    samples = [(raw_point(s + d), 1 + math.cos(math.pi * d / 120))
               for d in range(-120, 121)]
    weight = sum(w for _, w in samples)
    x = sum(p[0] * w for p, w in samples) / weight
    y = sum(p[1] * w for p, w in samples) / weight
    # Reproject height onto the actual banking rather than averaging road height.
    half = scope['STRAIGHT'] / 2
    if -half <= x <= half:
        z = 0.0
    else:
        cx = half if x > half else -half
        radius = math.hypot(x - cx, y)
        angle = math.atan2(y, x - cx)
        u = ((angle + math.pi / 2) if x > half else
             (angle - math.pi / 2) % (2 * math.pi)) * scope['RADIUS']
        z = max(0, radius - scope['RADIUS'] + 10) * math.tan(
            math.radians(scope['corner_bank'](u)))
    points.append([round(x, 5), round(z, 5), round(-y, 5)])
data['description'] = 'Wide straights, low apex; raw offsets +6 to 0 m, transitions extending 100 m onto each straight, 120 m cosine smoothing and road-projected height.'
data['points'] = points
path.write_text(json.dumps(data, indent=2) + '\n')
