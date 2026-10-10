"""Audit ordered Surfers laps before selecting an AI pace reference."""
import csv
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def audit(path):
    gates = json.loads((ROOT / 'content/tracks/surfers_paradise/ai/timing_gates.json').read_text())['gates']
    rows = list(csv.DictReader(path.open()))
    events = []
    for i in range(1, len(rows)):
        a, b = rows[i-1], rows[i]
        pa = [float(a[f'track_{k}_m']) for k in 'xyz']
        pb = [float(b[f'track_{k}_m']) for k in 'xyz']
        for g, gate in enumerate(gates):
            c, n = gate['point'], gate['normal']
            before = sum((pa[k]-c[k])*n[k] for k in range(3))
            after = sum((pb[k]-c[k])*n[k] for k in range(3))
            if before < 0 <= after:
                f = -before/(after-before)
                cross = [pa[k]+f*(pb[k]-pa[k]) for k in range(3)]
                lateral = (cross[0]-c[0])*(-n[2])+(cross[2]-c[2])*n[0]
                if abs(lateral) <= gate['half_width_m'] and -1 < cross[1] < 4:
                    events.append((i, float(a['time_s'])+f*(float(b['time_s'])-float(a['time_s'])), g))
    starts = [j for j, e in enumerate(events) if e[2] == 0]
    laps = []
    for first, last in zip(starts, starts[1:]):
        if [e[2] for e in events[first:last+1]] != [0, 1, 2, 3, 0]:
            continue
        i, t, _ = events[first]
        j, u, _ = events[last]
        lap = rows[i:j+1]
        laps.append(dict(seconds=round(u-t, 3), rows=[i+2, j+2],
                         off_tarmac=sum(r['surface'] != 'tarmac' for r in lap),
                         airborne=sum(not int(r['grounded']) for r in lap),
                         pit=sum(int(r['pit_limit']) != 0 for r in lap),
                         wall_impacts=sum(float(r.get('wall_delta_v_mps', 0)) > 0.1 for r in lap),
                         max_wall_delta_v=max(float(r.get('wall_delta_v_mps', 0)) for r in lap)))
    return dict(file=path.name, laps=laps)


if __name__ == '__main__':
    folder = Path(os.environ['APPDATA']) / 'Godot/app_userdata/Oval Racer/telemetry'
    results = []
    for cfg in sorted(folder.glob('practice_*.cfg')):
        if 'surfers' in cfg.read_text() and cfg.with_suffix('.csv').exists():
            results.append(audit(cfg.with_suffix('.csv')))
    print(json.dumps(results, indent=2))
