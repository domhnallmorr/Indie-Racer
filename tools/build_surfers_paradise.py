"""Build the Surfers Paradise experiment from a local ICR2 track folder.

Uses the matching DAT/TRK for the plan and four supplied LP files for paths/speeds.
Does not copy the original archive, textures or scenery into the project.
Road shoulders, pits, flat elevation and scenery are provisional authored geometry.
Supports the stock AUSTRAL and the user-supplied scratch-built Surfers package.
Usage: python tools/build_surfers_paradise.py PATH_TO_TRACK_FOLDER
"""
import argparse
import hashlib
import json
import math
import random
import struct
from pathlib import Path

from icr2_track import Track, UNIT, dat_member

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / 'content/tracks/surfers_paradise'


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t*t*t*(t*(t*6-15)+10)


def build(source):
    archives = [p for p in source.iterdir() if p.suffix.lower()=='.dat']
    if len(archives)!=1 or archives[0].stem.lower() not in ['austral','surfers']:
        raise ValueError('Expected one AUSTRAL.DAT or Surfers.dat in source folder')
    archive = archives[0]
    member = archive.stem.lower()+'.trk'
    custom = archive.stem.lower()=='surfers'
    track = Track(dat_member(archive.read_bytes(), member))
    lap = track.length*UNIT
    lines = {}
    for name in ['RACE', 'MINRACE', 'MAXRACE', 'PIT']:
        raw = (source/(name+'.LP')).read_bytes()
        count, = struct.unpack_from('<i', raw)
        if count < 2 or len(raw) != 4+12*count:
            raise ValueError('Invalid LP: '+name)
        lines[name] = list(struct.iter_unpack('<iii', raw[4:]))
        if not 0 <= (count-1)*65536*UNIT-lap <= 65536*UNIT:
            raise ValueError('LP sample coverage does not match TRK length: '+name)
    count = math.ceil(lap/2)
    ss = [lap*i/count for i in range(count)]
    xy = [track.xy(s/UNIT) for s in ss]
    center = [(min(p[k] for p in xy)+max(p[k] for p in xy))/2 for k in range(2)]

    def point(s, d=0, y=0):
        x, z = track.xy((s % lap)/UNIT, d/UNIT)
        return [round(-(x-center[0])*UNIT, 5), round(y, 5), round((z-center[1])*UNIT, 5)]

    def lp(name, s, field=2):
        at = (s % lap)/(65536*UNIT)
        i = min(int(at), len(lines[name])-2)
        f = min(1, at-i)
        return (lines[name][i][field]*(1-f)+lines[name][i+1][field]*f)*UNIT*(15 if field == 0 else 1)

    def lateral(name, s):
        return sum(lp(name, s+d)*w for d, w in [(-4,1),(-2,2),(0,3),(2,2),(4,1)])/9

    def edges(s):
        # LP MIN/MAX are car-centre limits, not physical road boundaries.
        low, high = sorted([lateral('MINRACE', s), lateral('MAXRACE', s)])
        return min(-6.8, low-1.9, lateral('RACE',s)-1.9), max(6.8, high+1.9, lateral('RACE',s)+1.9)

    def tangent(s, d=0):
        a,b = point(s-.2,d),point(s+.2,d)
        length = math.dist(a,b)
        return [(b[k]-a[k])/length for k in range(3)]

    def pose(s,d):
        t = tangent(s,d)
        return {'position':point(s,d,.025),'heading_deg':math.degrees(math.atan2(-t[0],-t[2]))}

    def closed(fn):
        values = [fn(s) for s in ss]
        return values+[values[0]]

    def write(name,data):
        dest = PACKAGE/name
        dest.parent.mkdir(parents=True,exist_ok=True)
        dest.write_text(json.dumps(data,separators=(',',':'))+'\n',encoding='utf-8')

    race = closed(lambda s:point(s,lateral('RACE',s)))
    corridor = {'schema_version':1,'units':'metres','physical_corridor_width':True,'reference_points':race}
    for name, side, inset in [('inner',1,1.5),('outer',0,1.5),('inside',1,2.7),('outside',0,2.7)]:
        corridor[name] = closed(lambda s,side=side,inset=inset:point(s,edges(s)[side]+(-inset if side else inset)))
    # Constrain all tactical paths, including the tighter side of each chicane.
    # Preserve the untouched imported speeds alongside this conservative envelope.
    imported = [lp('RACE',s,0) for s in ss]
    speeds = imported.copy()
    for path in [race, corridor['inside'], corridor['outside']]:
        for i in range(count):
            a,b,c = path[(i-2)%count],path[i],path[(i+2)%count]
            ab,bc = math.dist(a,b),math.dist(b,c)
            u = [(b[k]-a[k])/ab for k in range(3)]
            v = [(c[k]-b[k])/bc for k in range(3)]
            bend = math.dist(u,v)/((ab+bc)*.5)
            speeds[i] = min(speeds[i],math.sqrt(19/max(.00001,bend)),1.1/max(.00001,bend))
    distances = [math.dist(race[i],race[i+1]) for i in range(count)]
    for _ in range(3):
        for i in reversed(range(count)):
            speeds[i] = min(speeds[i],math.sqrt(speeds[(i+1)%count]**2+2*12*distances[i]))
        for i in range(count):
            speeds[(i+1)%count] = min(speeds[(i+1)%count],math.sqrt(speeds[i]**2+2*5*distances[i]))
    lap_time = sum(distances[i]/((speeds[i]+speeds[(i+1)%count])*.5) for i in range(count))
    write('ai/race_line.json',{'schema_version':1,'units':'metres','points':race})
    write('ai/racing_corridor.json',corridor)
    write('ai/race.lp.json',{'schema_version':1,'method':'ICR2','reference_points':race,
          'speed_mps':speeds,'imported_speed_mps':imported,'reference_lap_s':lap_time,
          'roster_reference_lap_s':21.097133,'driver_pace_spread':.35,'driver_speed_weighting':'profile_range',
          'steering_lookahead_base_m':2.5,'steering_lookahead_time_s':.13,'steering_lookahead_max_m':12,
          'source':archive.stem+' RACE.LP with multi-lane curvature, 12 m/s2 braking and 5 m/s2 acceleration envelope; experimental pace, not calibrated to 1995 results.'})
    write('ai/profiles.json',json.loads((ROOT/'content/tracks/mile_oval/ai/profiles.json').read_text()))
    write('ai/racecraft.json',{'schema_version':1,'overrides':{'passing_speed_factor':1,'lane_blend_distance_m':90}})
    write('ai/pit_out.lp.json',{'schema_version':1,'departure_kph':40,'cruise_kph':100,'merge_acceleration_m':100})
    # Distances belong to their source TRK; stock indices cannot describe the
    # scratch-built chicanes, especially the extended beach-side complex.
    corners = ([(390,530),(620,760),(1290,1555),(2220,2340),(2810,3080),(3320,3405),(3445,3675),(3810,4020)]
               if custom else [(465,610),(680,815),(1340,1580),(2180,2270),(2770,2940),(3270,3480),(3520,3700),(3860,4040)])
    regions = []
    for j,(a,b) in enumerate(corners):
        ia,ib = round(a/lap*count),round(b/lap*count)
        regions.append({'id':'complex_%02d'%(j+1),'entry_index':ia,'exit_index':ib,'entry_point':race[ia],'exit_point':race[ib]})
    write('ai/corner_regions.json',{'schema_version':1,'units':'metres','reference_point_count':count,'regions':regions})

    # PIT.LP contains a whole lap. Keep only the pit-straight portion, with an
    # inset service lane and stalls outside the racing road. Retain its small
    # lateral changes and taper the authored offset at entry/exit.
    pit_start,pit_end = 4080.0,lap+180
    pit_ss = [pit_start+(pit_end-pit_start)*i/350 for i in range(351)]
    def pit_d(s):
        return lateral('PIT',s)+12*smooth((s-4050)/80)*(1-smooth((s-lap-70)/160))
    pit = [point(s,pit_d(s),.008) for s in pit_ss]
    box_ss = [4150+i*9 for i in range(26)]
    boxes = [dict(id='player_pit_01' if i==0 else 'ai_pit_%02d'%(i+1),**pose(s,pit_d(s)+6)) for i,s in enumerate(box_ss)]
    pace_s = 4400
    def polygon(samples,lo,hi):
        pts = [point(s,pit_d(s)+lo) for s in samples]+[point(s,pit_d(s)+hi) for s in reversed(samples)]
        return [[p[0],p[2]] for p in pts]
    limiter = pose(lap+80,pit_d(lap+80))
    write('session.json',{'schema_version':1,'units':'metres','path_based_pits':True,
          'race':{'laps':10,'pace_speed_kph':65,'grid':{'origin':point(4290,0,.025),
          'heading_deg':pose(4290,0)['heading_deg'],'row_spacing_m':9,'lane_spacing_m':4},
          'green_point':point(lap-80),'green_normal':tangent(lap-80)},
          'pit_boxes':boxes,'pace_car_box':dict(id='pace_car_pit',**pose(pace_s,pit_d(pace_s)+6)),
          'pit_lane':{'path_file':'ai/reference_paths.json','half_width_m':3.4,'min_height_m':-.5,'max_height_m':2,
          'pit_box_area_xz':polygon([4120+i*2 for i in range(151)],-3.4,9)},
          'pit_speed_zone':{'limit_kph':80,'polygon_xz':polygon([4120+(lap+80-4120)*i/250 for i in range(251)],-3.4,9),
          'exit_line_x':limiter['position'][0],'exit_pose':limiter}})
    write('ai/reference_paths.json',{'units':'metres','reference_length_m':lap,'straight_length_m':680,
          'reference_path':closed(lambda s:point(s)),'pit_path':pit,
          'start_finish_position':point(0),'max_banking_deg':0})
    write('ai/imported_pit_path.json',{'units':'metres','note':'Unmodified lateral PIT.LP, entire lap; service road is authored separately.',
          'points':closed(lambda s:point(s,lp('PIT',s))),'speed_mps':[lp('PIT',s,0) for s in ss]})
    write('ai/timing_gates.json',{'schema_version':1,'units':'metres','gates':[
          {'name':name,'point':point(s),'normal':tangent(s),'half_width_m':13,'min_height_m':-1,'max_height_m':4}
          for name,s in [('StartFinish',0),('NorthEnd',1600),('BeachStraight',2650),('SouthEnd',3790)]]})
    write('manifest.json',{'schema_version':1,'type':'track','id':'surfers_paradise','display_name':'Surfers Paradise — CART 1995',
          'description':('Scratch-built Surfers source layout' if custom else 'Stock AUSTRAL source layout')+': chicanes, coastal straight and 26 pit boxes.',
          'scene':'scenes/track.tscn','units':'metres','length_m':lap,'layout_type':'street','direction':'clockwise',
          'pit_boxes':26,'pace_car_boxes':1})
    strips = []
    patches = []
    # Photo-guided first-chicane street envelope. Barrier control points are
    # world-space street boundaries, independent of the LP/racing-road bends.
    t1_start,t1_end = 350.0,570.0
    back_start,back_end = 2790.0,3100.0
    wall_controls = {}
    for side in [0,1]:
        start = point(t1_start,edges(t1_start)[side]+(-.6 if side==0 else .15))
        end = point(t1_end,edges(t1_end)[side]+(-.6 if side==0 else .15))
        middle = [(5,85),(-50,84),(-100,106)] if side==0 else [(30,117),(0,134),(-35,148),(-75,147)]
        wall_controls[side] = [(start[0],start[2])]+middle+[(end[0],end[2])]

    back_controls = {}
    for side in [0,1]:
        start = point(back_start,edges(back_start)[side]+(-.6 if side==0 else .15))
        end = point(back_end,edges(back_end)[side]+(-.6 if side==0 else .15))
        middle = [(400,270),(480,275),(555,257)] if side==0 else [(400,225),(490,212),(560,206)]
        back_controls[side] = [(start[0],start[2])]+middle+[(end[0],end[2])]

    landscapes = [
        {'name':'T1','start':t1_start,'end':t1_end,'controls':wall_controls,'z_direction':1,
         'islands':[(1,405,513),(0,432,549)],'lane_marks':[(350,400),(540,570)]},
        {'name':'Backstraight','start':back_start,'end':back_end,'controls':back_controls,'z_direction':-1,
         'islands':[(1,2820,3075),(0,2820,3075)],'lane_marks':[(2790,2830),(3060,3100)]},
    ]

    def landscape_at(s):
        return next((region for region in landscapes if region['start']<=s<=region['end']),None) if custom else None

    def wall_z(x,side,region):
        controls = region['controls'][side]
        for (ax,az),(bx,bz) in zip(controls,controls[1:]):
            if (x-bx)*(ax-bx)>=0:
                f = max(0,min(1,(x-ax)/(bx-ax)))
                return az+(bz-az)*f
        return controls[-1][1]

    def barrier_point(s,side,y=0):
        p = point(s,edges(s)[side]+(-.6 if side==0 else .15),y)
        region = landscape_at(s)
        if region:
            p[2] = round(wall_z(p[0],side,region),5)
        return p

    def strip(name,svalues,ds,color,collision=True,y=0):
        strips.append({'name':name,'rows':[[point(s,d(s) if callable(d) else d,y) for d in ds] for s in svalues],
                       'colour':color,'collision':collision})
    loop = ss+[lap]
    strip('RacingSurface',loop,[lambda s,f=j/4:edges(s)[0]*(1-f)+edges(s)[1]*f for j in range(5)],'#42474c')
    for side in [0,1]:
        sign = -1 if side==0 else 1
        strip('RoadEdge',loop,[lambda s,side=side:edges(s)[side],lambda s,side=side,sign=sign:edges(s)[side]-sign*.14],'#eee8d1',False,.012)
    def wall(name,svalues,d,side=None):
        rows = []
        for s in svalues:
            lateral = d(s) if callable(d) else d
            a,b = point(s,lateral),point(s,lateral+.45)
            region = landscape_at(s)
            if side is not None and region:
                a = barrier_point(s,side)
                b = [a[0],0,a[2]+(-.45 if side==0 else .45)*region['z_direction']]
            rows.append([a,b,[b[0],1.15,b[2]],[a[0],1.15,a[2]],a])
        strips.append({'name':name,'rows':rows,'colour':'#ddd9c9','collision':True,'double_sided':True})
    wall('BeachWall',loop,lambda s:edges(s)[0]-.6,0)
    # Leave genuine openings at pit entry and exit, including driver Hermite joins.
    wall('CityWall',[s for s in loop if 330<=s<=4030],lambda s:edges(s)[1]+.15,1)
    wall('PitDivider',[4140+i*2 for i in range(int((lap+45-4140)/2)+1)],lambda s:edges(s)[1]+.15)
    wall('PitBackWall',[4120+i*2 for i in range(int((lap+100-4120)/2)+1)],lambda s:pit_d(s)+10)
    paving = [4005+(lap+330-4005)*i/450 for i in range(451)]
    strip('PitRoad',paving,[lambda s:edges(s)[1],lambda s:max(edges(s)[1],pit_d(s)+10)],'#505457')
    strip('PitGuide',pit_ss,[lambda s:pit_d(s)-.07,lambda s:pit_d(s)+.07],'#e1bc56',False,.015)
    for s in box_ss+[pace_s]:
        strip('PitBoxMark',[s-3.8,s-3.65],[pit_d(s)+3.8,pit_d(s)+8.8],'#efc958',False,.018)
    # Flush striped kerbs: visual apex references without artificial tyre steps.
    for a,b in corners:
        for s in range(a,b,3):
            if landscape_at(s):
                continue
            i,_ = track.section_at(s/UNIT)
            if track.sections[i][0]!=2 or abs(track.centers[i][0]*UNIT)>80:
                continue
            side = 1 if track.centers[i][0]>0 else 0
            sign = -1 if side else 1
            strip('Kerb',[s,s+3],[lambda s,side=side:edges(s)[side],lambda s,side=side,sign=sign:edges(s)[side]+sign*.75],
                  '#d75645' if (s//3)%2 else '#f3eedc',False,.018)
    for region in landscapes if custom else []:
        # Continuous asphalt shoulders under the grass patches leave a paved
        # recovery margin beside the walls. Grass has its own higher collider.
        prefix = region['name']
        stations = [region['start']+i for i in range(int(region['end']-region['start'])+1)]
        for side in [0,1]:
            rows = []
            for s in stations:
                road = point(s,edges(s)[side],-.002)
                wallp = barrier_point(s,side,-.002)
                rows.append([wallp,road] if side==0 else [road,wallp])
            strips.append({'name':prefix+'PavedMargin','rows':rows,'colour':'#45494a','collision':True,'drivable':True})
        for side,a,b in region['islands']:
            sign = -1 if side==0 else 1
            sign_z = sign*region['z_direction']
            front,back = [],[]
            for s in range(a,b+1):
                inner = point(s,edges(s)[side]+sign*1.05,.025)
                taper = smooth((s-a)/16)*smooth((b-s)/16)
                outside_z = wall_z(inner[0],side,region)-sign_z*1.4
                # Keep a narrow rounded tip; do not produce duplicate polygon vertices.
                depth = max(.03,sign_z*(outside_z-inner[2]))*max(.002,taper)
                outer = [inner[0],.025,round(inner[2]+sign_z*depth,5)]
                front.append(inner)
                back.append(outer)
            patches.append({'name':'Ground'+prefix+'GrassIsland','points':front+list(reversed(back)),
                            'colour':'#39713c','collision':True})
            # Broad red/cream kerb with a shallow ramp, 6 cm crown, and no
            # vertical collision face. Its inner 40 cm overlap the road edge.
            for s in range(a,b,2):
                rows = []
                for at in [s,min(s+2,b)]:
                    profile = [(-.4,.008),(.15,.060),(.65,.060),(1.05,.025)]
                    values = [point(at,edges(at)[side]+sign*d,y) for d,y in profile]
                    rows.append(list(reversed(values)) if side==0 else values)
                strips.append({'name':prefix+'Kerb','rows':rows,'colour':'#c45d44' if (s//2)%2 else '#eee4c8',
                               'collision':True,'drivable':True})
        for a,b in region['lane_marks']:
            for s in range(a,b,9):
                for d in [-3.2,3.2]:
                    strip(prefix+'StreetLaneMark',[s,s+4],[d-.055,d+.055],'#c2c2b4',False,.013)
    for row in range(2):
        for col in range(20):
            strip('Finish',[-.8+row*.8,row*.8],[lambda s,f=col/20:edges(s)[0]*(1-f)+edges(s)[1]*f,
                  lambda s,f=(col+1)/20:edges(s)[0]*(1-f)+edges(s)[1]*f],
                  '#f1ead6' if (row+col)%2 else '#202a30',False,.022)

    # Procedural period-inspired coastal city. Reject footprints near either road.
    rng = random.Random(1995)
    clearance = [point(s) for s in ss[::4]]+pit[::3]
    buildings = []
    for x in range(-1040,1100,63):
        for z in range(-480,310,62):
            xj,zj = x+rng.uniform(-12,12),z+rng.uniform(-10,10)
            w,d = rng.uniform(20,38),rng.uniform(18,32)
            if min(math.hypot(p[0]-xj,p[2]-zj) for p in clearance)<max(w,d)*.65+24:
                continue
            height = rng.choice([12,18,26,38,48,65,82])+rng.uniform(0,8)
            buildings.append({'position':[xj,0,zj],'size':[w,height,d],
                              'colour':rng.choice(['#dbcdb4','#cbd4d2','#d9c3aa','#afc4c4','#e1dcca']),
                              'accent':rng.choice(['#49717c','#6b8b92','#b78772'])})
    if custom:
        # Remove scenery inside or immediately behind the enlarged street envelope.
        wall_samples = [barrier_point(s,side) for region in landscapes for side in [0,1]
                        for s in range(int(region['start']),int(region['end'])+1,5)]
        buildings = [b for b in buildings if min(math.dist([b['position'][0],b['position'][2]],[p[0],p[2]])
                     for p in wall_samples)>max(b['size'][0],b['size'][2])*.7+10]
    palms = []
    for s in range(50,4450,28):
        for d in [-14,18]:
            if s>3990 and d>0: continue
            if custom and any(region['start']-20<=s<=region['end']+25 for region in landscapes): continue
            p = point(s,d)
            if min(math.hypot(p[0]-q[0],p[2]-q[2]) for q in clearance)>11:
                palms.append({'position':p,'height':rng.uniform(7,12),'angle':rng.uniform(0,math.tau)})
    boards = []
    for a,_ in corners:
        for distance in [150,100,50]:
            s = a-distance
            p = pose(s,edges(s)[0]-1.25)
            region = landscape_at(s)
            if region:
                p['position'] = barrier_point(s,0,.025)
                p['position'][2] -= 1.25*region['z_direction']
            boards.append(dict(p,text=str(distance)))
    write('geometry.json',{'strips':strips,'patches':patches,'cameras':[point(s,-22,16) for s in range(100,4450,220)],
          'bank_focus':point(460 if custom else 535),'pit_focus':point(4250,pit_d(4250)),'overview_distance':1550,
          'buildings':buildings,'palms':palms,'brake_boards':boards,
          'pit_building':pose(4250,pit_d(4250)+21),'finish_gantry':pose(0,0),
          'fences':[[barrier_point(s,0,1.15),barrier_point(s,0,3.7)] for s in range(0,int(lap),8)],
          'extra_fences':[[[barrier_point(s,1,1.15),barrier_point(s,1,3.7)]
              for s in range(int(region['start']),int(region['end'])+1,4)] for region in landscapes] if custom else [],
          'first_chicane':{'start_m':t1_start,'end_m':t1_end,'camera_position':point(520,-26,11),
              'camera_target':point(445,0,1),'reference':'User-supplied 1995 race still; approximate grass islands, kerbs and independent street barriers.'} if custom else {},
          'backstraight_chicane':{'start_m':back_start,'end_m':back_end,'camera_position':point(3070,85,165),
              'camera_target':point(2950,0,0),'reference':'Backstraight complex identified in the user screenshot; authored verges and barriers using the first-chicane treatment.'} if custom else {},
          'grandstands':[pose(s,-22) for s in [80,1700,1900,2410,3100]]+([pose(420,52),pose(525,43)] if custom else [])})
    write('source.json',{'files':{name:hashlib.sha256((source/name).read_bytes()).hexdigest()
          for name in [archive.name,'RACE.LP','MINRACE.LP','MAXRACE.LP','PIT.LP']},
          'source_variant':'user-supplied scratch-built Surfers' if custom else 'stock AUSTRAL',
          'track_member':member,'track_sections':len(track.sections),
          'visual_reference':'User-supplied 1995 first-chicane race screenshot; approximate 350–570 m street envelope, grass islands, 1.45 m wide low kerbs and paved wall margins. Same treatment extended to the 2790–3100 m backstraight chicane identified in the user game screenshot; authored approximation.' if custom else '',
          'source_reference_length_m':lap,'scale':1,'lp_samples':len(lines['RACE']),'reference_lap_s':lap_time,
          'changes':'Original TRK XY plan at native scale, flat elevation. Smoothed LP lateral groove. Road edges inferred from MIN/MAX plus 1.9 m clearance and 13.6 m minimum width. Original speeds retained alongside conservative all-lane curvature/braking/acceleration envelope. PIT.LP-derived service lane shifted inwards for 26 stalls. Newly authored barriers, kerbs and stylised coastal scenery; scratch-built variant has a photo-guided first-chicane street envelope, grass islands, paved margins and low ramped kerbs, with the same treatment applied to the long backstraight chicane. No original art imported.',
          'format_reference':'https://github.com/skchow03/icr2tools'})
    print('Built Surfers Paradise:',round(lap,3),'m;',count,'samples; conservative reference',round(lap_time,2),'s;',len(buildings),'buildings')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=Path)
    build(parser.parse_args().source)
