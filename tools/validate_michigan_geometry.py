"""Verify authored Michigan dimensions, seams, AI clearance and smooth banking."""
import json
import math
from pathlib import Path

PACKAGE = Path(__file__).resolve().parents[1]/'content/tracks/michigan'
def read(name): return json.loads((PACKAGE/name).read_text())
strips = read('geometry.json')['strips']
road = next(s['rows'] for s in strips if s['name']=='RacingSurface')
apron = next(s['rows'] for s in strips if s['name']=='Apron')
race = read('ai/race_line.json')['points']
corridor = read('ai/racing_corridor.json')
def horizontal(a,b): return math.hypot(a[0]-b[0],a[2]-b[2])
widths = [horizontal(r[0],r[-1]) for r in road]
aprons = [horizontal(r[0],r[-1]) for r in apron]
banks = [math.degrees(math.atan2(r[0][1]-r[-1][1],horizontal(r[0],r[-1]))) for r in road]
assert road[0] == road[-1] and apron[0] == apron[-1] and race[0] == race[-1]
for measured, expected in [(min(widths),45*.3048),(max(widths),73*.3048),
                           (min(aprons),10*.3048),(max(aprons),12*.3048),
                           (min(banks),5),(max(banks),18),(banks[0],12)]:
    assert abs(measured-expected) < .001, (measured,expected)
max_gradient = max(abs(b-a)/(3218.688/(len(road)-1)) for a,b in zip(banks,banks[1:]))
assert max_gradient < .068, max_gradient
for i,(r,p) in enumerate(zip(road,race)):
    assert horizontal(p,r[0]) >= 1.699 and horizontal(p,r[-1]) >= 1.699
    assert abs(p[1]-(horizontal(p,r[-1])*math.tan(math.radians(banks[i])))) < .001
    for key in ['inside','outside','inner','outer']:
        p = corridor[key][i]
        assert horizontal(p,r[0]) >= 1.699 and horizontal(p,r[-1]) >= 1.699
    assert math.dist(corridor['inside'][i],corridor['outside'][i]) >= 5
    assert math.dist(corridor['inner'][i],corridor['outer'][i]) >= 10
assert read('ai/race.lp.json')['reference_points'] == race
assert len(read('ai/race.lp.json')['speed_mps']) == len(race)-1
print('Michigan geometry PASS: exact widths/aprons, 5/12/18 degree banks, closed seams, AI edge clearance; max bank gradient',round(max_gradient,5),'deg/m')
