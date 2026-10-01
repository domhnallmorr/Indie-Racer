"""Build Michigan from the user's ICR2 directory; standard library only.

Usage: python tools/build_michigan.py PATH_TO_MICHIGAN
LP files contain lateral offsets, not an XY layout: MICHIGAN.DAT supplies TRK.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct

from icr2_track import Track, UNIT, dat_member

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / 'content/tracks/michigan'
LAP = 3218.688
INNER = 7.2136
FT = .3048
RAMP = 360.0
EXTENSION = 40.0


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t*t*t*(t*(t*6-15)+10)


def build(source):
    raw = (source/'MICHIGAN.DAT').read_bytes()
    track = Track(dat_member(raw, 'michigan.trk'))
    lines = {}
    for name in ['RACE', 'MINRACE', 'MAXRACE']:
        data = (source/(name+'.LP')).read_bytes()
        count, = struct.unpack_from('<i', data)
        if len(data) != 4+12*count or count < 2:
            raise ValueError('Invalid LP: '+name)
        lines[name] = list(struct.iter_unpack('<iii', data[4:]))
    scale = LAP/(track.length*UNIT)
    starts = [s[1]/track.length*LAP for s in track.sections]
    # The shallow frontstretch arcs are deliberately excluded from the turns.
    turns = [(starts[3], starts[9]), (starts[12], starts[18])]

    def turn_weight(s):
        s %= LAP
        return max(smooth((s-a+EXTENSION)/RAMP)*smooth((b+EXTENSION-s)/RAMP)
                   for a, b in turns)

    def bank(s):
        s %= LAP
        a, b = turns[0]
        c, d = turns[1]
        if a-EXTENSION <= s <= b+EXTENSION:
            return 12+6*smooth((s-a+EXTENSION)/RAMP)-13*smooth((s-b-EXTENSION+RAMP)/RAMP)
        if c-EXTENSION <= s <= d+EXTENSION:
            return 5+13*smooth((s-c+EXTENSION)/RAMP)-6*smooth((s-d-EXTENSION+RAMP)/RAMP)
        return 5.0 if b < s < c else 12.0

    def width(s): return (45+28*turn_weight(s))*FT
    def apron(s): return (12-2*turn_weight(s))*FT
    count = 1610
    ss = [LAP*i/count for i in range(count)]
    raw_points = [track.xy(s/LAP*track.length) for s in ss]
    center = [(min(p[k] for p in raw_points)+max(p[k] for p in raw_points))/2 for k in range(2)]

    def point(s, lateral, lift=0):
        x, y = track.xy((s % LAP)/LAP*track.length, lateral/(UNIT*scale))
        return [round(-(x-center[0])*UNIT*scale, 5),
                round(max(0, INNER-lateral)*math.tan(math.radians(bank(s)))+lift, 5),
                round((y-center[1])*UNIT*scale, 5)]

    def lp(name, s, field=2):
        at = (s % LAP)/LAP*track.length/65536
        i = min(int(at), len(lines[name])-2)
        f = min(1, at-i)
        return (lines[name][i][field]*(1-f)+lines[name][i+1][field]*f)*UNIT*(scale if field == 2 else 15)

    def lateral(name, s):
        return sum(lp(name, s+d)*w for d, w in [(-6,1),(-3,2),(0,3),(3,2),(6,1)])/9

    def race_d(s):
        # Map the supplied MIN/MAX car-centre corridor to the requested road.
        # This preserves the groove's relative position as the road narrows.
        low, high = lateral('MINRACE',s), lateral('MAXRACE',s)
        fraction = max(0, min(1, (lateral('RACE',s)-low)/(high-low)))
        return INNER-width(s)+1.7+fraction*(width(s)-3.4)

    def tangent(s, d):
        a, b = point(s-.25,d), point(s+.25,d)
        length = math.hypot(b[0]-a[0],b[2]-a[2])
        return [(b[0]-a[0])/length,0,(b[2]-a[2])/length]

    def pose(s,d):
        t = tangent(s,d)
        return {'position':point(s,d,.025),'heading_deg':math.degrees(math.atan2(-t[0],-t[2]))}

    def write(name,data):
        path = PACKAGE/name
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(json.dumps(data,separators=(',',':'))+'\n')

    def closed(fn):
        values = [fn(s) for s in ss]
        return values+[values[0]]

    race = closed(lambda s: point(s,race_d(s)))
    corridor = {'schema_version':1,'units':'metres','reference_points':race}
    for name, fraction in [('inner',1),('outer',0),('inside',.78),('outside',.22)]:
        corridor[name] = closed(lambda s: point(s,INNER-width(s)+1.7+fraction*(width(s)-3.4)))
    speeds = [lp('RACE',s,0) for s in ss]
    lap_time = sum(math.dist(race[i],race[i+1])/((speeds[i]+speeds[(i+1)%count])/2) for i in range(count))
    write('ai/race_line.json',{'schema_version':1,'units':'metres','points':race})
    write('ai/racing_corridor.json',corridor)
    write('ai/race.lp.json',{'schema_version':1,'method':'ICR2','reference_points':race,
          'speed_mps':speeds,'imported_speed_mps':speeds,'reference_lap_s':lap_time,
          'roster_reference_lap_s':21.097133,'driver_pace_spread':.45,'driver_speed_weighting':'profile_range',
          'source':'Michigan RACE.LP speeds; lateral groove remapped between MINRACE/MAXRACE to authored widths. Player pace not yet calibrated.'})
    write('ai/profiles.json',json.loads((ROOT/'content/tracks/mile_oval/ai/profiles.json').read_text()))
    write('ai/racecraft.json',{'schema_version':1,'overrides':{'passing_speed_factor':1.0,'lane_blend_distance_m':90}})
    write('ai/pit_out.lp.json',{'schema_version':1,'departure_kph':55,'cruise_kph':140,'merge_acceleration_m':600})

    # Authored inset pit lane, continuing through turns 1/2 to a backstretch merge.
    pit_start, pit_end = 2750.0, LAP+1530.0
    pit_ss = [pit_start+(pit_end-pit_start)*i/1000 for i in range(1001)]
    def pit_d(s):
        return INNER+9+15*smooth((s-2750)/200)*(1-smooth((s-LAP-330)/350))
    pit = [point(s,pit_d(s),.008) for s in pit_ss]
    box_ss = [LAP-145+i*10 for i in range(27)]
    boxes = [dict(id='player_pit_01' if i == 0 else 'ai_pit_%02d'%(i+1),**pose(s,pit_d(s)+8)) for i,s in enumerate(box_ss)]
    def polygon(samples,lo,hi):
        return [[p[0],p[2]] for p in [point(s,pit_d(s)+lo) for s in samples]+[point(s,pit_d(s)+hi) for s in reversed(samples)]]
    limiter = pose(LAP+210,pit_d(LAP+210))
    write('session.json',{'schema_version':1,'units':'metres','path_based_pits':True,
          'race':{'laps':10,'pace_speed_kph':100,'grid':{'origin':point(1680,INNER-width(1680)/2,.025),
          'heading_deg':pose(1680,0)['heading_deg'],'row_spacing_m':9,'lane_spacing_m':5},
          'green_point':point(LAP-230,INNER-width(LAP-230)/2),'green_normal':tangent(LAP-230,0)},
          'pit_boxes':boxes[:26],'pace_car_box':dict(boxes[26],id='pace_car_pit'),
          'pit_lane':{'path_file':'ai/reference_paths.json','half_width_m':5,'min_height_m':-.5,'max_height_m':10,
          'pit_box_area_xz':polygon([LAP-170+i*3 for i in range(111)],-5,12)},
          'pit_speed_zone':{'limit_kph':80,'polygon_xz':polygon([LAP-240+i*3 for i in range(151)],-5,12),
          'exit_line_x':limiter['position'][0],'exit_pose':limiter}})
    write('ai/reference_paths.json',{'units':'metres','reference_length_m':LAP,'straight_length_m':starts[12]-starts[9],
          'reference_path':closed(lambda s:point(s,INNER-width(s)/2)),'pit_path':pit,
          'start_finish_position':point(0,INNER-width(0)/2),'max_banking_deg':18,
          'frontstretch_banking_deg':12,'backstretch_banking_deg':5,'bank_transition_m':RAMP,
          'bank_transition_on_straight_m':EXTENSION,'bank_turn_sections':[[a,b,18] for a,b in turns]})
    write('ai/timing_gates.json',{'schema_version':1,'units':'metres','gates':[
          {'name':name,'point':point(s,INNER-width(s)/2),'normal':tangent(s,0),'half_width_m':20,'min_height_m':-1,'max_height_m':12}
          for name,s in [('StartFinish',0),('Turns12',820),('Backstraight',1620),('Turns34',2400)]]})
    write('manifest.json',{'schema_version':1,'type':'track','id':'michigan','display_name':'Michigan International Speedway',
          'description':'Two-mile ICR2-derived oval; 18 degree turns, 12 degree frontstretch, 5 degree backstretch.',
          'scene':'scenes/track.tscn','units':'metres','length_m':LAP,'direction':'counterclockwise',
          'racing_width_m':45*FT,'turn_width_m':73*FT,'straight_width_m':45*FT,
          'turn_apron_width_m':10*FT,'straight_apron_width_m':12*FT,'pit_boxes':26,'pace_car_boxes':1})
    strips = []
    def strip(name,svalues,ds,color,collision=True,lift=0):
        strips.append({'name':name,'rows':[[point(s,d(s) if callable(d) else d,lift) for d in ds] for s in svalues],
                       'colour':color,'collision':collision})
    loop = ss+[LAP]
    strip('RacingSurface',loop,[lambda s,j=j:INNER-width(s)*(1-j/8) for j in range(9)],'#393d40')
    strip('Apron',loop,[INNER,lambda s:INNER+apron(s)],'#555653')
    strip('TrackInnerEdge',loop,[INNER-.08,INNER+.08],'#e9e4d5',False,.025)
    strip('TrackOuterEdge',loop,[lambda s:INNER-width(s)+.4,lambda s:INNER-width(s)+.55],'#e9e4d5',False,.025)
    strip('PitRoad',pit_ss,[lambda s:pit_d(s)-5,lambda s:pit_d(s)+12],'#4b4c4b')
    # Paved access wedges connect the dedicated lane to the apron at both ends.
    # Include the driver's 70 m entry blend and 120 m exit merge. Otherwise
    # the route can dip onto the lower grass and meet a raised paving edge.
    for name,a,b,edge in [('PitEntryApproach',2630,pit_start,12),
                          ('PitEntryAccess',pit_start,2950,-5),
                          ('PitExitAccess',LAP+1370,pit_end,-5),
                          ('PitExitMerge',pit_end,pit_end+180,12)]:
        strip(name,[a+(b-a)*i/160 for i in range(161)],
              [lambda s:INNER+apron(s),lambda s,edge=edge:pit_d(s)+edge],'#4b4c4b')
    strip('PitGuide',pit_ss,[lambda s:pit_d(s)-.08,lambda s:pit_d(s)+.08],'#d7b344',False,.03)
    wall = []
    for s in loop:
        a,b = point(s,INNER-width(s)-.5),point(s,INNER-width(s))
        wall.append([a,b,[b[0],b[1]+1.25,b[2]],[a[0],a[1]+1.25,a[2]],a])
    strips.append({'name':'OuterWall','rows':wall,'colour':'#ddd9cf','collision':True,'double_sided':True})
    for row in range(2):
        for col in range(20):
            if (row+col)%2 == 0:
                strip('Finish',[-.7+row*.7,row*.7],[lambda s,col=col:INNER-width(s)+col*width(s)/20,
                      lambda s,col=col:INNER-width(s)+(col+1)*width(s)/20],'#efede2',False,.04)
    for s in box_ss:
        strip('PitBoxMark',[s-4,s-3.85],[pit_d(s)+5,pit_d(s)+11],'#d7b344',False,.04)
    write('geometry.json',{'strips':strips,'cameras':[point(s,65,30) for s in range(0,3200,400)],
          'bank_focus':point(820,0),'pit_focus':point(0,pit_d(LAP)),'overview_distance':1750})
    write('source.json',{'files':{name:hashlib.sha256((source/name).read_bytes()).hexdigest()
          for name in ['MICHIGAN.DAT','RACE.LP','MINRACE.LP','MAXRACE.LP']},
          'source_reference_length_m':track.length*UNIT,'scale':scale,'lp_samples':len(lines['RACE']),
          'reference_lap_s':lap_time,'bank_transition_m':RAMP,
          'changes':'TRK plan scaled to 2 miles. Requested widths are horizontal road widths, excluding the flat apron. 360 m quintic banking ramps begin 40 m before turns. MIN/MAX LP bounds map to 1.7 m edge clearances; RACE retains relative lateral position and imported speeds. Pit road and passing lanes newly authored; no Michigan scenery imported.'})
    print('Built Michigan:',LAP,'m; reference lap',round(lap_time,3),'s; banks',sorted(set(round(bank(s),2) for s in [0,820,1620,2400])))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path)
    build(parser.parse_args().source)
