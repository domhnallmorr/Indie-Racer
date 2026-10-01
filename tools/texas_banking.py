"""Shared Texas banking profile and archive-free rebanking of the current package."""
import json
import math
from pathlib import Path

LAP = 2414.016
BANK_TRANSITION = 360.0
STRAIGHT_TRANSITION = 40.0
STRAIGHT_BANK = 5.0


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t*t*t*(t*(t*6-15)+10)


def bank_angle(s, turns):
    s %= LAP
    for entry, exit, degrees in turns:
        begin, end = entry-STRAIGHT_TRANSITION, exit+STRAIGHT_TRANSITION
        if begin <= s <= end:
            return STRAIGHT_BANK+(degrees-STRAIGHT_BANK)*smooth((s-begin)/BANK_TRANSITION)*smooth((end-s)/BANK_TRANSITION)
    return STRAIGHT_BANK


def apply_banking(package):
    def read(name): return json.loads((package/name).read_text())
    def write(name,data): (package/name).write_text(json.dumps(data,separators=(',',':'))+'\n')
    geometry = read('geometry.json')
    refs = read('ai/reference_paths.json')
    road = next(s['rows'] for s in geometry['strips'] if s['name']=='RacingSurface')
    count = len(road)-1
    turns = refs.get('bank_turn_sections')
    if turns is None:
        # Recover geometric turn boundaries from the original symmetric ramps:
        # the half-angle crossings lie exactly at turn entry and exit.
        angles = [math.degrees(math.atan2(r[0][1]-r[-1][1],math.hypot(r[0][0]-r[-1][0],r[0][2]-r[-1][2]))) for r in road]
        def crossing(target,lo,hi):
            for i in range(count):
                s=i*LAP/count
                if lo<s<hi and (angles[i]-target)*(angles[i+1]-target)<0:
                    return s+LAP/count*(target-angles[i])/(angles[i+1]-angles[i])
            raise ValueError('Cannot recover original turn boundary')
        turns = [[crossing(10,0,600),crossing(10,800,1200),20],
                 [crossing(12,1200,1700),crossing(12,1900,2300),24]]
    def height(p,i):
        row=road[i%count]
        inner,outer=row[-1],row[0]
        dx,dz=outer[0]-inner[0],outer[2]-inner[2]
        depth=max(0,((p[0]-inner[0])*dx+(p[2]-inner[2])*dz)/math.hypot(dx,dz))
        return round(depth*math.tan(math.radians(bank_angle(i*LAP/count,turns))),5)
    for strip in geometry['strips']:
        name=strip['name']
        if name not in ['RacingSurface','OuterWall','TrackInnerEdge','TrackOuterEdge']:
            continue
        for i,row in enumerate(strip['rows']):
            for j,p in enumerate(row):
                lift = 1.25 if name=='OuterWall' and j in [2,3] else (.025 if name in ['TrackInnerEdge','TrackOuterEdge'] else 0)
                p[1]=round(height(p,i)+lift,5)
    # Finish tiles have their own sampling around the lap seam. Project onto
    # the start/finish cross-section instead of treating their row as a lap index.
    for strip in geometry['strips']:
        if strip['name']=='Finish':
            for row in strip['rows']:
                for p in row:
                    p[1]=round(height(p,0)+.04,5)
    geometry['bank_focus'][1]=round(9.5*math.tan(math.radians(bank_angle(600,turns))),5)
    write('geometry.json',geometry)
    for name,keys in [('ai/reference_paths.json',['reference_path']),('ai/race_line.json',['points']),
                      ('ai/race.lp.json',['reference_points']),('ai/racing_corridor.json',['reference_points','inner','outer','inside','outside'])]:
        data=read(name)
        for key in keys:
            for i,p in enumerate(data[key]): p[1]=height(p,i)
        if name=='ai/reference_paths.json':
            data['bank_transition_m']=BANK_TRANSITION
            data['bank_transition_on_straight_m']=STRAIGHT_TRANSITION
            data['bank_turn_sections']=turns
            data['straight_banking_deg']=STRAIGHT_BANK
            data['start_finish_position'][1]=height(data['start_finish_position'],0)
        if name=='ai/race.lp.json':
            points,speeds=data['reference_points'],data['speed_mps']
            data['reference_lap_s']=sum(math.dist(points[i],points[i+1])/((speeds[i]+speeds[(i+1)%count])*.5) for i in range(count))
        write(name,data)
    gates=read('ai/timing_gates.json')
    for gate,s in zip(gates['gates'],[0,600,1200,1800]):
        gate['point'][1]=round(9.5*math.tan(math.radians(bank_angle(s,turns))),5)
    write('ai/timing_gates.json',gates)
    session=read('session.json')
    session['race']['green_point'][1]=round(9.5*math.tan(math.radians(bank_angle(2200,turns))),5)
    write('session.json',session)
    source=read('source.json')
    source['changes']=source['changes'].replace('280 m quintic ramps extending 140 m','360 m quintic ramps extending 40 m')
    source['changes']=source['changes'].replace('20/24 degree turns with', '5 degree straights and 20/24 degree turns with') if '5 degree straights' not in source['changes'] else source['changes']
    source['reference_lap_s']=read('ai/race.lp.json')['reference_lap_s']
    write('source.json',source)
    print('Applied 5 degree straights, 360 m banking ramps / 40 m straight extensions; constant-bank backstraight length:',round(turns[1][0]-turns[0][1]-80,2))


if __name__=='__main__':
    apply_banking(Path(__file__).resolve().parents[1]/'content/tracks/texas')
