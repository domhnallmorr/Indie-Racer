"""Build our JSON LP from a clean F11 lap: --telemetry PATH.
Spatially maps measured speeds onto the existing line, without lap-time scaling.
"""
import argparse
import bisect
import csv
import hashlib
import json
import math
from pathlib import Path


def build(path):
    root = Path(__file__).resolve().parents[1]
    folder = root / 'content/tracks/mile_oval/ai'
    line = json.loads((folder / 'race_line.json').read_text())
    points = line['points'][:-1]
    gates = json.loads((folder / 'timing_gates.json').read_text())['gates']
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
                if abs(lateral) <= gate['half_width_m'] and -1 < cross[1] < 6:
                    time = float(a['time_s'])+f*(float(b['time_s'])-float(a['time_s']))
                    events.append((i, time, g))
    laps = []
    starts = [j for j,e in enumerate(events) if e[2] == 0]
    for first, last in zip(starts, starts[1:]):
        if [e[2] for e in events[first:last+1]] != [0,1,2,3,0]:
            continue
        i,t,_ = events[first]
        j,u,_ = events[last]
        lap = rows[i:j+1]
        if any(r['surface'] != 'tarmac' or int(r['pit_limit']) or not int(r['grounded']) for r in lap):
            continue
        laps.append((u-t, i, j))
    if not laps:
        raise ValueError('No complete grounded, tarmac-only lap through ordered gates')
    seconds, start, end = min(laps)
    n = len(points)
    lengths = [math.dist(points[i], points[(i+1)%n]) for i in range(n)]
    distances = [0.0]
    for length in lengths:
        distances.append(distances[-1]+length)
    projected = []
    for row in rows[start:end+1]:
        x,z = float(row['track_x_m']), float(row['track_z_m'])
        best = (math.inf, 0)
        for i,a in enumerate(points):
            b = points[(i+1)%n]
            dx,dz = b[0]-a[0], b[2]-a[2]
            f = max(0,min(1,((x-a[0])*dx+(z-a[2])*dz)/(dx*dx+dz*dz)))
            error = (x-a[0]-f*dx)**2+(z-a[2]-f*dz)**2
            if error < best[0]:
                best = error, (distances[i]+f*lengths[i]) % distances[-1]
        if best[0] > 100:
            raise ValueError('Player lap lies too far from reference line')
        projected.append((best[1],float(row['speed_kph'])/3.6))
    projected.sort()
    samples = [(projected[-1][0]-distances[-1],projected[-1][1])]+projected+[(projected[0][0]+distances[-1],projected[0][1])]
    keys = [s for s,v in samples]
    if max(b-a for a,b in zip(keys,keys[1:])) > 10:
        raise ValueError('Reference lap has a gap exceeding 10 metres')
    speeds = []
    for s in distances[:-1]:
        j = bisect.bisect_right(keys,s)
        a,va = samples[j-1]
        b,vb = samples[j]
        speeds.append(va+(vb-va)*(s-a)/max(b-a,1e-9))
    # Approximately six metres of smoothing preserves braking locations.
    speeds = [sum(speeds[(i+d)%n] for d in (-1,0,1))/3 for i in range(n)]
    lap = sum(2*d/(speeds[i]+speeds[(i+1)%n]) for i,d in enumerate(lengths))
    profile = dict(schema_version=1, method='ICR2', units='metres, seconds',
                   source=f'Player telemetry {path.name}; fastest complete clean lap, spatially projected onto current line. Measured speeds, no lap-time normalization.',
                   source_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                   source_lap_s=seconds, source_rows=[start+2,end+2],
                   clean_laps_s=[s for s,_,_ in laps],
                   reference_lap_s=lap, reference_points=line['points'],
                   speed_mps=[round(s,5) for s in speeds])
    (folder/'race.lp.json').write_text(json.dumps(profile,indent=2)+'\n')
    print(json.dumps({k:profile[k] for k in ('clean_laps_s','source_lap_s','reference_lap_s','source_rows')},indent=2))
    print(f'Wrote {n} samples: {min(speeds)*3.6:.1f}-{max(speeds)*3.6:.1f} km/h')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--telemetry',type=Path,required=True)
    build(parser.parse_args().telemetry)
