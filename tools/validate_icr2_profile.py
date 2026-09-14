"""Compare current headless ICR2 captures with their recorded player reference.

Run validate_icr2.gd first, then this script with --telemetry PATH.
Checks regional pace independently of total lap time, plus target tracking.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--telemetry', type=Path, required=True)
args = parser.parse_args()
profile = json.loads((root/'content/tracks/mile_oval/ai/race.lp.json').read_text())
assert hashlib.sha256(args.telemetry.read_bytes()).hexdigest() == profile['source_sha256']
source = list(csv.DictReader(args.telemetry.open()))
a,b = profile['source_rows']
source = source[a-2:b-1]
regions = {'straight': lambda x: abs(x)<180, 'corner': lambda x: abs(x)>260}
reference = {}
for name, test in regions.items():
    speeds = [float(r['speed_kph']) for r in source if test(float(r['track_x_m']))]
    reference[name] = sum(speeds)/len(speeds)
results = {'player_mean_kph': reference, 'cars': []}
roster = json.loads((root/'content/rosters/icr2_test/manifest.json').read_text())
for entry in roster['entries']:
    rows = list(csv.DictReader((root/f"builds/icr2_AI_{entry['id']}.csv").open()))
    rows = [r for r in rows if r['mode']=='2' and float(r['time_s'])>65]
    assert rows and all(r['reason']=='clear' for r in rows), 'Need clean-air captures'
    scale = profile['reference_lap_s']/entry['icr2_lap_s']
    item = {'name': entry['driver_name']}
    for name,test in regions.items():
        speeds = [float(r['speed_kph']) for r in rows if test(float(r['x_m']))]
        mean = sum(speeds)/len(speeds)
        item[name+'_mean_kph'] = mean
        assert abs(mean-reference[name]*scale)<5, f'{entry["id"]}: {name} differs from player by >5 km/h'
    assert item['straight_mean_kph'] > item['corner_mean_kph']+40
    error = sum(abs(float(r['speed_kph'])-float(r['target_kph'])) for r in rows)/len(rows)
    item['mean_target_error_kph'] = error
    assert error < 3, 'Movement cannot follow reference speed'
    results['cars'].append(item)
(root/'builds/icr2_profile_comparison.json').write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps(results,indent=2))
print('ICR2 PROFILE PASSED')
