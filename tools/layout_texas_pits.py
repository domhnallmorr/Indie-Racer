"""Author Texas's straight, inset pit road from the imported package.

Can run without the source archive; build_texas also calls apply_layout().
"""
import json
import math
from pathlib import Path

LAP = 2414.016
START, IMPORTED_END = 2120.0, LAP + 860.0
# Stay on the left apron until the middle of the backstretch. The driver
# appends its tangent-matched 120 m merge after this point.
END = LAP + 1200.0
EXIT_INSET = 8.0
STRAIGHT_START, STRAIGHT_END = 2220.0, LAP + 170.0
LANE_Z = 205.0


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t*t*t*(t*(t*6-15)+10)


def apply_layout(package):
    def read(name):
        return json.loads((package / name).read_text())
    def write(name, data):
        (package / name).write_text(json.dumps(data, separators=(',', ':')) + '\n')
    geometry = read('geometry.json')
    reference = read('ai/reference_paths.json')
    session = read('session.json')
    source = package / 'ai/imported_pit_path.json'
    if not source.exists():
        write('ai/imported_pit_path.json', reference['pit_path'])
    imported = read('ai/imported_pit_path.json')
    road = next(s for s in geometry['strips'] if s['name']=='RacingSurface')['rows']

    def road_inner(s):
        at = (s%LAP)/LAP*(len(road)-1)
        i,f = int(at),at-int(at)
        return [road[i][-1][k]*(1-f)+road[i+1][-1][k]*f for k in range(3)]

    def exit_point(s):
        p = road_inner(s)
        a,b = road_inner(s-.2),road_inner(s+.2)
        length = math.hypot(b[0]-a[0],b[2]-a[2])
        return [p[0]+(b[2]-a[2])/length*EXIT_INSET,.008,
                p[2]-(b[0]-a[0])/length*EXIT_INSET]

    def blend(s):
        return smooth((s-START)/(STRAIGHT_START-START))*smooth((2800-s)/(2800-STRAIGHT_END))
    def pit_point(s):
        at = max(0, min(len(imported)-1, (s-START)/(IMPORTED_END-START)*(len(imported)-1)))
        i = min(int(at), len(imported)-2)
        f = at-i
        p = [imported[i][k]*(1-f)+imported[i+1][k]*f for k in range(3)]
        p[2] += (LANE_Z-p[2])*blend(s)
        # Leave the straight pit road gently, then hold an independent lane
        # through turns 1/2 instead of following the imported early merge.
        weight = smooth((s-STRAIGHT_END)/(LAP+500-STRAIGHT_END))
        target = exit_point(s)
        p = [p[k]+(target[k]-p[k])*weight for k in range(3)]
        return p
    def offset(p, normal, d, height):
        return [round(p[0]+normal[0]*d,5), height, round(p[2]+normal[2]*d,5)]
    def pit_normal(s):
        a,b = pit_point(s-.2),pit_point(s+.2)
        length = math.hypot(b[0]-a[0],b[2]-a[2])
        return [(b[2]-a[2])/length,0,-(b[0]-a[0])/length]

    count = math.ceil((END-START)/2)+1
    pit = [pit_point(START+(END-START)*i/(count-1)) for i in range(count)]
    reference['pit_path'] = pit
    write('ai/reference_paths.json',reference)
    profile = read('ai/pit_out.lp.json')
    profile['merge_acceleration_m'] = 600
    write('ai/pit_out.lp.json',profile)
    boxes = session['pit_boxes']+[session['pace_car_box']]
    for i,box in enumerate(boxes):
        box['position'] = [-117.0+9*i,.025,LANE_Z-8]
        box['heading_deg'] = -90.0
    def rectangle(x0,x1):
        return [[x0,LANE_Z+5],[x1,LANE_Z+5],[x1,LANE_Z-12],[x0,LANE_Z-12]]
    session['pit_lane']['pit_box_area_xz'] = rectangle(-130,130)
    speed = session['pit_speed_zone']
    speed['polygon_xz'] = rectangle(-155,150)
    speed['exit_line_x'] = 150.0
    speed['exit_pose'] = {'position':[150,.025,LANE_Z],'heading_deg':-90.0}
    write('session.json',session)

    # Reconstruct apron from the unchanged road, so rerunning is idempotent.
    apron = []
    for i,row in enumerate(road):
        s = i/(len(road)-1)*LAP
        unwrapped = s+LAP if s < 900 else s
        front = row[-1]
        direction = [front[k]-row[0][k] for k in range(3)]
        length = math.hypot(direction[0],direction[2])
        direction = [direction[0]/length,0,direction[2]/length]
        back = offset(front,direction,33.5,0)
        # Wall sits 4 m behind stall centres, 1 m behind the painted stall edge.
        back[2] += (min(back[2],LANE_Z-12)-back[2])*blend(unwrapped)
        apron.append([[round(front[k]+(back[k]-front[k])*f,5) for k in range(3)] for f in [0,.25,.6,1]])
    def strip(name,rows,color,collision=False):
        return dict(name=name,rows=rows,colour=color,collision=collision)
    strips = [s for s in geometry['strips'] if s['name'] not in ['Apron','PitGuide','PitBoxMark','PitSeparationGrass']]
    strips.append(strip('Apron',apron,'#4b4c4b',True))
    guide = []
    for i,p in enumerate(pit):
        s = START+(END-START)*i/(len(pit)-1)
        normal = pit_normal(s)
        guide.append([offset(p,normal,-.08,.03),offset(p,normal,.08,.03)])
    strips.append(strip('PitGuide',guide,'#d7b344'))
    grass = []
    for i in range(201):
        s = STRAIGHT_START+(STRAIGHT_END-STRAIGHT_START)*i/200
        edge = offset(pit_point(s),pit_normal(s),-6,.04)
        inner = road_inner(s)
        inner[2] -= 1
        taper = smooth((s-STRAIGHT_START)/20)*smooth((STRAIGHT_END-s)/20)
        front = [edge[k]+(inner[k]-edge[k])*taper for k in range(3)]
        front[1] = .04
        grass.append([front,edge])
    strips.append(strip('PitSeparationGrass',grass,'#50643a'))
    for box in boxes:
        x,_,z = box['position']
        strips.append(strip('PitBoxMark',[[[x-4,.04,z+3],[x-4,.04,z-3]],[[x-3.85,.04,z+3],[x-3.85,.04,z-3]]],'#d7b344'))
    geometry['strips'] = strips
    geometry['pit_focus'] = [0,0,LANE_Z]
    geometry['pit_wall_z'] = LANE_Z-12
    write('geometry.json',geometry)
    print('Texas pit road: straight stalls x=-117..117, lane z=205, boxes z=197, inner wall z=193.')


if __name__ == '__main__':
    apply_layout(Path(__file__).resolve().parents[1]/'content/tracks/texas')

