"""Verify authored Indianapolis dimensions, seams, AI clearance and smooth banking."""
import json
import math
from pathlib import Path

PACKAGE = Path(__file__).resolve().parents[1]/'content/tracks/indianapolis'
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
for measured, expected in [(min(widths),50*.3048),(max(widths),60*.3048),
                           (min(aprons),12*.3048),(max(aprons),12*.3048),
                           (min(banks),0),(max(banks),9.2),(banks[0],0)]:
    assert abs(measured-expected) < .001, (measured,expected)
max_gradient = max(abs(b-a)/(4023.36/(len(road)-1)) for a,b in zip(banks,banks[1:]))
assert max_gradient < .079, max_gradient
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
pit_road = next(s['rows'] for s in strips if s['name']=='PitRoad')
divider = next(s['rows'] for s in strips if s['name']=='PitDividerBase')
for lane, base in zip(pit_road, divider):
    assert base[-1] == lane[0], 'Grass gap beside pit lane'
    assert abs(horizontal(lane[0], lane[-1])-17) < .001
for name in ['PitWall','InnerWall']:
    wall = next(s for s in strips if s['name']==name)
    assert wall['collision'] and wall['double_sided']
    assert abs(wall['rows'][1][2][1]-wall['rows'][1][1][1]-1.05) < .001
inner_wall = next(s['rows'] for s in strips if s['name']=='InnerWall')
assert inner_wall[1] == inner_wall[-2], 'Inner wall seam'
pylon = read('geometry.json')['scoring_pylon']
assert pylon['distance_after_finish_m'] == 75
assert abs(horizontal(pylon['position'],read('ai/reference_paths.json')['start_finish_position'])-75.9) < .2
print('Indianapolis pits PASS: continuous paving, 17 m pit road, collidable walls, closed inner boundary, pylon 75 m after finish')
bricks = next(s for s in strips if s['name']=='YardOfBricks')
assert not any(s['name']=='Finish' for s in strips), 'Old checkered finish still present'
assert not bricks['collision'], 'Brick overlay must not add a physical bump'
assert abs(horizontal(bricks['rows'][0][0],bricks['rows'][1][0])-.9144) < .0001
assert abs(horizontal(bricks['rows'][0][0],bricks['rows'][0][-1])-(15.24+21.5)) < .001
finish = read('ai/reference_paths.json')['start_finish_position']
brick_center = [(bricks['rows'][0][0][i]+bricks['rows'][1][-1][i])/2 for i in range(3)]
assert abs(horizontal(finish,brick_center)-10.75) < .001, 'Bricks misaligned with timing line'
pagoda = read('geometry.json')['pagoda']['position']
assert abs(horizontal(pagoda,finish)-(51+15.24/2)) < .001
print('Indianapolis landmarks PASS: yard-wide brick strip across track and pits; Pagoda aligned with finish')
print('Indianapolis geometry PASS: exact widths/aprons, 0/9.2 degree banks, closed seams, AI edge clearance; max bank gradient',round(max_gradient,5),'deg/m')
