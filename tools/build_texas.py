"""Build the Texas package from ntexas(1).zip using only Python's standard library.

Usage: python tools/build_texas.py PATH_TO_ZIP
The TRK plan and LP grooves are retained; banking is re-authored at 20/24 degrees.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
from icr2_track import UNIT, read_archive
from layout_texas_pits import apply_layout
from texas_banking import BANK_TRANSITION, STRAIGHT_TRANSITION, STRAIGHT_BANK, bank_angle
from texas_pace import calibrate

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / 'content/tracks/texas'
LAP = 2414.016
INNER, OUTER = 14.5, -4.5


def smooth(t):
    t = max(0, min(1, t))
    return t*t*t*(t*(t*6-15)+10)


def build(archive):
    track, lines = read_archive(archive)
    scale = LAP / (track.length * UNIT)
    starts = [s[1] / track.length * LAP for s in track.sections]
    bank_turns = [(starts[8],starts[13],20),(starts[14],starts[19],24)]
    samples = 1208
    # Centre the source footprint, rotate it so front-stretch travel is +X.
    raw = [track.xy(track.length*i/samples) for i in range(samples)]
    center = [(min(p[k] for p in raw)+max(p[k] for p in raw))*.5 for k in range(2)]

    def bank(s):
        return bank_angle(s,bank_turns)

    def point(s, lateral=5.0, lift=0):
        x, y = track.xy((s % LAP)/LAP*track.length, lateral/(UNIT*scale))
        h = max(0, INNER-lateral)*math.tan(math.radians(bank(s)))
        return [round(-(x-center[0])*UNIT*scale,5),round(h+lift,5),round((y-center[1])*UNIT*scale,5)]

    def lp(name, s, field=2):
        at = (s % LAP)/LAP*track.length/65536
        i = min(int(at),len(lines[name])-2)
        f = min(1,at-i)
        return (lines[name][i][field]*(1-f)+lines[name][i+1][field]*f)*UNIT*(scale if field == 2 else 15)

    def lateral(name,s):
        # Remove quantisation chatter while preserving the imported groove.
        return sum(lp(name,s+offset)*weight for offset,weight in [(-6,1),(-3,2),(0,3),(3,2),(6,1)])/9

    def tangent(s,d=5):
        a,b = point(s-.5,d),point(s+.5,d)
        length = math.hypot(b[0]-a[0],b[2]-a[2])
        return [(b[0]-a[0])/length,0,(b[2]-a[2])/length]

    def pose(s,d):
        t = tangent(s,d)
        return {'position':point(s,d,.025),'heading_deg':math.degrees(math.atan2(-t[0],-t[2]))}

    def write(name,data):
        path = PACKAGE/name
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_text(json.dumps(data,separators=(',',':'))+'\n')

    ss = [i*LAP/samples for i in range(samples)]
    race_d = [max(-2.5,min(12.5,lateral('race',s))) for s in ss]
    race = [point(s,d) for s,d in zip(ss,race_d)]
    race.append(race[0])
    corridor = {'schema_version':1,'units':'metres','reference_points':race}
    # Leave >3.2 m to RACE on at least one side, not just between PASS lanes.
    # Keep the imported shared shape within the 16 m car-centre corridor.
    for name in ['inner','outer','inside','outside']:
        points = []
        for s in ss:
            mid = max(.8,min(8.5,(lateral('pass1',s)+lateral('pass2',s))*.5))
            d = {'inner':13.0,'outer':-3.0,'inside':mid+3.8,'outside':mid-3.8}[name]
            points.append(point(s,d))
        points.append(points[0])
        corridor[name] = points
    speeds = [lp('race',s,0) for s in ss]
    reference_lap = sum(math.dist(race[i],race[i+1])/((speeds[i]+speeds[(i+1)%samples])*.5) for i in range(samples))
    write('ai/race_line.json',{'schema_version':1,'units':'metres','points':race})
    write('ai/racing_corridor.json',corridor)
    pace_profile = calibrate({'schema_version':1,'method':'ICR2','reference_points':race,
          'speed_mps':speeds,'reference_lap_s':reference_lap,
          'roster_reference_lap_s':22.05232549885755,
          'source':'Supplied Texas RACE.LP, resampled onto TRK plan; imported speeds retained separately; active speeds calibrated for the player.'})
    reference_lap = pace_profile['reference_lap_s']
    write('ai/race.lp.json',pace_profile)
    write('ai/pit_out.lp.json',{'schema_version':1,'departure_kph':55,'cruise_kph':140,'merge_acceleration_m':250})
    write('ai/profiles.json',json.loads((ROOT/'content/tracks/mile_oval/ai/profiles.json').read_text()))
    write('ai/racecraft.json',{'schema_version':1,'overrides':{'passing_speed_factor':1.0,'lane_blend_distance_m':70}})

    pit_start, pit_end = 2120.0, LAP+860.0
    pit_ss = [pit_start+(pit_end-pit_start)*i/650 for i in range(651)]
    pit_ds = [max(16.5,lateral('pit',s)) for s in pit_ss]
    pit = [point(s,d,.008) for s,d in zip(pit_ss,pit_ds)]
    write('ai/imported_pit_path.json',pit)
    box_ss = [2265+i*9 for i in range(27)]
    boxes = [dict(id='player_pit_01' if i == 0 else 'ai_pit_%02d'%(i+1),
                  **pose(s,lateral('pit',s)+8.0)) for i,s in enumerate(box_ss)]
    green_s = 2200.0
    grid_s = 1260.0 # Keep the grid on the flat middle of the backstretch.
    end_s = LAP+155
    speed_ss = [2220+(end_s-2220)*i/100 for i in range(101)]
    def poly(svalues,lo,hi):
        return [[p[0],p[2]] for p in ([point(s,lateral('pit',s)+lo) for s in svalues]+
                   [point(s,lateral('pit',s)+hi) for s in reversed(svalues)])]
    limiter = pose(end_s,lateral('pit',end_s))
    write('session.json',{'schema_version':1,'units':'metres','path_based_pits':True,
          'race':{'laps':10,'pace_speed_kph':100,'grid':{'origin':point(grid_s,5,.025),
          'heading_deg':pose(grid_s,5)['heading_deg'],'row_spacing_m':9,'lane_spacing_m':6},
          'green_point':point(green_s,5),'green_normal':tangent(green_s)},
          'pit_boxes':boxes[:26],'pace_car_box':dict(boxes[26],id='pace_car_pit'),
          'pit_lane':{'path_file':'ai/reference_paths.json','half_width_m':5,'min_height_m':-.5,'max_height_m':10,
          'pit_box_area_xz':poly([2240+i*3 for i in range(95)],-5,12)},
          'pit_speed_zone':{'limit_kph':80,'polygon_xz':poly(speed_ss,-5,12),'exit_line_x':limiter['position'][0],
          'exit_pose':limiter}})
    reference = [point(s,5) for s in ss]
    reference.append(reference[0])
    write('ai/reference_paths.json',{'units':'metres','reference_length_m':LAP,'straight_length_m':405,
          'reference_path':reference,'pit_path':pit,'start_finish_position':point(0,5),
          'straight_banking_deg':STRAIGHT_BANK,'max_banking_deg':24,'turns_12_banking_deg':20,'turns_34_banking_deg':24,
          'bank_transition_m':BANK_TRANSITION,'bank_transition_on_straight_m':STRAIGHT_TRANSITION,
          'bank_turn_sections':bank_turns})
    gates = []
    for name,s in [('StartFinish',0),('Turns12',600),('Backstraight',1200),('Turns34',1800)]:
        gates.append({'name':name,'point':point(s,5),'normal':tangent(s),'half_width_m':20,
                      'min_height_m':-1,'max_height_m':12})
    write('ai/timing_gates.json',{'schema_version':1,'units':'metres','gates':gates})
    write('manifest.json',{'schema_version':1,'type':'track','id':'texas','display_name':'Texas Tri-Oval',
          'description':'Texas ICR2-derived layout, 1.5 miles, re-authored 20/24 degree banking.',
          'scene':'scenes/track.tscn','units':'metres','length_m':LAP,'direction':'counterclockwise',
          'racing_width_m':INNER-OUTER,'pit_boxes':26,'pace_car_boxes':1})

    strips = []
    def strip(name,svalues,ds,color,collision=True,lift=0):
        rows = [[point(s,d(s) if callable(d) else d,lift) for d in ds] for s in svalues]
        strips.append({'name':name,'rows':rows,'colour':color,'collision':collision})
    loop = ss+[LAP]
    strip('RacingSurface',loop,[OUTER+(INNER-OUTER)*j/8 for j in range(9)],'#363b40')
    strip('Apron',loop,[INNER,23,35,48],'#4b4c4b')
    strip('TrackInnerEdge',loop,[INNER-.12,INNER+.12],'#dddccf',False,.025)
    strip('TrackOuterEdge',loop,[OUTER+.45,OUTER+.65],'#dddccf',False,.025)
    strip('PitGuide',pit_ss,[lambda s:lateral('pit',s)-.08,lambda s:lateral('pit',s)+.08],'#d7b344',False,.03)
    # The outer wall is a vertical strip with closed top, thickness and end seam.
    wall = []
    for s in loop:
        a,b = point(s,OUTER-.5),point(s,OUTER)
        wall.append([a,b,[b[0],b[1]+1.25,b[2]],[a[0],a[1]+1.25,a[2]],a])
    strips.append({'name':'OuterWall','rows':wall,'colour':'#d9d5c7','collision':True,'double_sided':True})
    # Open grass separation on the track side of pit road, with paved access
    # at either end. The flat apron underneath supplies ground collision.
    grass_start, grass_end = 2220.0, LAP+155.0
    grass_ss = [grass_start+(grass_end-grass_start)*i/180 for i in range(181)]
    def grass_inner(s):
        edge = lateral('pit',s)-6
        taper = smooth((s-grass_start)/20)*smooth((grass_end-s)/20)
        return edge-max(0,edge-(INNER+1))*taper
    strip('PitSeparationGrass',grass_ss,[grass_inner,lambda s:lateral('pit',s)-6],
          '#50643a',False,.015)
    for row in range(2):
        for col in range(19):
            if (row+col)%2 == 0:
                strip('Finish',[-.7+row*.7,row*.7],[OUTER+col,OUTER+col+1],'#f1efe1',False,.04)
    for s in box_ss:
        d = lateral('pit',s)
        strip('PitBoxMark',[s-4,s-3.85],[d+5,d+11],'#d7b344',False,.04)
    cameras = [point(s,60,25) for s in [0,350,650,1100,1350,1650,1950,2200]]
    write('geometry.json',{'strips':strips,'cameras':cameras,'bank_focus':point(600,5),
                         'pit_focus':point(0,35),'overview_distance':1350})
    write('source.json',{'archive':archive.name,'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),
          'credit':'Texas NASCAR 3 to ICR2 conversion by Tom Smith, per supplied README.TXT',
          'source_reference_length_m':track.length*UNIT,'scale':scale,'lp_samples':len(lines['race']),
          'reference_lap_s':reference_lap,'changes':'Plan scaled to 2414.016 m; 19 m road; 5 degree straights and 20/24 degree turns with 360 m quintic ramps extending 40 m onto the adjoining straights. LP lateral positions smoothed over 12 m; passing separation widened to 7.6 m. Pit boxes and scenery newly authored.'})
    apply_layout(PACKAGE)
    print('Texas package generated:',samples,'samples;',round(reference_lap,3),'s calibrated reference lap')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive',type=Path)
    build(parser.parse_args().archive)

