"""Geometry invariants for the ICR2-derived street-course package."""
import json
import math
from pathlib import Path

package = Path(__file__).resolve().parents[1]/'content/tracks/surfers_paradise'
def read(name): return json.loads((package/name).read_text(encoding='utf-8'))

geometry = read('geometry.json')
race = read('ai/race_line.json')['points']
corridor = read('ai/racing_corridor.json')
profile = read('ai/race.lp.json')
source = read('source.json')
length = read('manifest.json')['length_m']
road = next(s['rows'] for s in geometry['strips'] if s['name']=='RacingSurface')
assert road[0] == road[-1] and race[0] == race[-1]
assert len(road) == len(race) == len(profile['speed_mps'])+1
assert profile['reference_points'] == race == corridor['reference_points']
assert 4490 < length < 4520
assert math.isclose(length,source['source_reference_length_m'],abs_tol=1e-6)
assert len(race)-1 == math.ceil(length/2)
assert len(profile['imported_speed_mps']) == len(profile['speed_mps'])
# Main-line pace can be telemetry-derived. The conservative tactical envelope
# remains subject to the original LP ceiling and the authored dynamic limits.
bounded_speeds = profile.get('tactical_speed_mps',profile['speed_mps'])
assert all(math.isfinite(v) and 0 < v < 120 for v in profile['speed_mps'])
assert all(0 < v <= imported+.001 for v,imported in zip(bounded_speeds,profile['imported_speed_mps']))
if source.get('source_variant') == 'user-supplied scratch-built Surfers':
    assert math.isclose(length,4509.5714228,abs_tol=1e-6)
    assert source['lp_samples'] == 1356 and source['track_sections'] == 87
    assert source['track_member'] == 'surfers.trk' and 'Surfers.dat' in source['files']
assert len(read('session.json')['pit_boxes']) == 26
for i,row in enumerate(road):
    width = math.dist(row[0],row[-1])
    station = i*length/(len(road)-1)
    minimum = 13.199 if geometry.get('second_chicane') and 630<=station<=770 else 13.599
    assert minimum < width < 22, (i,width)
    for key in ['inner','outer','inside','outside','reference_points']:
        p = corridor[key][i]
        assert abs(math.dist(row[0],p)+math.dist(p,row[-1])-width)<.001
        assert min(math.dist(row[0],p),math.dist(row[-1],p)) >= 1.499, (key,i)
    if i<len(race)-1:
        ds = math.dist(race[i],race[i+1])
        assert .3<ds<5, (i,ds)
        v,w = bounded_speeds[i],bounded_speeds[(i+1)%(len(race)-1)]
        assert v*v <= w*w+24*ds+.001, ('braking',i)
        assert w*w <= v*v+10*ds+.001, ('acceleration',i)
turns = []
for i in range(1,len(race)-1):
    a,b,c = race[i-1],race[i],race[i+1]
    turns.append((b[0]-a[0])*(c[2]-b[2])-(b[2]-a[2])*(c[0]-b[0]))
assert min(turns)<-.1 and max(turns)>.1, 'Must include left and right turns'
assert all(s['collision'] and s['double_sided'] for s in geometry['strips'] if 'Wall' in s['name'] or s['name']=='PitDivider')
corners = read('ai/corner_regions.json')
assert corners['reference_point_count'] == len(race)-1
for corner in corners['regions']:
    assert 0 <= corner['entry_index'] < corner['exit_index'] < len(race)-1
    assert race[corner['entry_index']] == corner['entry_point']
    assert race[corner['exit_index']] == corner['exit_point']
pit = read('ai/reference_paths.json')['pit_path']
assert all(.1 < math.dist(a,b) < 5 for a,b in zip(pit,pit[1:])), 'Continuous pit route'
print(f'SURFERS GEOMETRY PASS: closed {length/1000:.3f} km layout, source provenance, left/right turns, 26 stalls, road clearance, bounded speeds, walls, pit route and corner alignment')
