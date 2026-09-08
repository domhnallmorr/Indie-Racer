"""Run with Blender --background --python tools/build_mile_oval.py.
Regenerates the source .blend, runtime .glb, reference paths and overview.
All dimensions are metres. Generated files are overwritten; save hand edits separately.
"""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / 'content/tracks/mile_oval'
SOURCE = ROOT / 'source_art/tracks/mile_oval'
LAP = 1609.344
RADIUS = 125.0
STRAIGHT = (LAP - 2 * math.pi * RADIUS) / 2
ARC = math.pi * RADIUS
STEP = 2.0
BANK_TRANSITION = 100.0


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def corner_bank(u):
    # Zero first and second derivatives at the flat and fully banked ends.
    # The longer ramp reduces the crest/dip felt at racing speeds.
    t = max(0.0, min(1.0, min(u, ARC-u) / BANK_TRANSITION))
    return 9 * t**3 * (10 - 15*t + 6*t*t)


def frame(s):
    s %= LAP
    if s < STRAIGHT:
        return (-STRAIGHT / 2 + s, -RADIUS), (0, -1), 0.0
    if s < STRAIGHT + ARC:
        u = s - STRAIGHT
        angle = -math.pi / 2 + u / RADIUS
        normal = (math.cos(angle), math.sin(angle))
        return (STRAIGHT / 2 + RADIUS * normal[0], RADIUS * normal[1]), normal, corner_bank(u)
    if s < 2 * STRAIGHT + ARC:
        return (STRAIGHT / 2 - (s - STRAIGHT - ARC), RADIUS), (0, 1), 0.0
    u = s - 2 * STRAIGHT - ARC
    angle = math.pi / 2 + u / RADIUS
    normal = (math.cos(angle), math.sin(angle))
    return (-STRAIGHT / 2 + RADIUS * normal[0], RADIUS * normal[1]), normal, corner_bank(u)


def point(s, offset, lift=0):
    center, normal, bank = frame(s)
    return (center[0] + offset * normal[0], center[1] + offset * normal[1],
            max(0, offset + 10) * math.tan(math.radians(bank)) + lift)


def material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Roughness'].default_value = 0.9
    return mat


def mesh(name, vertices, faces, mat):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def ribbon(name, start, end, low, high, mat, lift=0):
    count = max(1, math.ceil((end-start)/STEP))
    across = 20 if name == 'RacingSurface-col' else 1
    verts = []
    for i in range(count+1):
        s = start + (end-start)*i/count
        a = low(s) if callable(low) else low
        b = high(s) if callable(high) else high
        verts.extend(point(s, a+(b-a)*j/across, lift) for j in range(across+1))
    # Inner to outer points, CCW travel: face normals point up.
    stride = across+1
    return mesh(name, verts, [(stride*i+j, stride*i+j+1, stride*(i+1)+j+1, stride*(i+1)+j)
                             for i in range(count) for j in range(across)], mat)


def wall(name, start, end, offset, mat, height=1.15, width=0.5):
    count = math.ceil((end-start)/STEP)
    verts = []
    for i in range(count+1):
        s = start+(end-start)*i/count
        verts.extend([point(s, offset-width/2), point(s, offset+width/2),
                      point(s, offset+width/2, height), point(s, offset-width/2, height)])
    faces = [(3,2,1,0)]
    for i in range(count):
        for j in range(4):
            faces.append((4*i+j,4*i+(j+1)%4,4*(i+1)+(j+1)%4,4*(i+1)+j))
    faces.append(tuple(4*count+j for j in range(4)))
    return mesh(name+'-col', verts, faces, mat)


def box(name, location, dimensions, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return obj


def label(text, location, size=8):
    curve = bpy.data.curves.new(text, 'FONT')
    curve.body = text
    curve.size = size
    curve.align_x = 'CENTER'
    obj = bpy.data.objects.new(text, curve)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.data.materials.append(WHITE)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target='MESH')
    obj.select_set(False)


bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
scene.unit_settings.length_unit = 'METERS'
ASPHALT = material('Racing asphalt', (0.105, 0.12, 0.14))
APRON = material('Apron asphalt', (0.20, 0.22, 0.24))
PIT = material('Pit asphalt', (0.15, 0.17, 0.19))
GRASS = material('Infield grass', (0.20, 0.29, 0.115))
WHITE = material('Warm white', (0.86, 0.85, 0.78))
YELLOW = material('Safety yellow', (0.95, 0.65, 0.07))
BLUE = material('Grandstand blue', (0.15, 0.28, 0.40))
CONCRETE = material('Concrete', (0.56, 0.57, 0.55))
box('Ground-col', (0, 0, -0.3), (920, 530, 0.4), GRASS)
ribbon('RacingSurface-col', 0, LAP, -10, 10, ASPHALT)
ribbon('Apron-col', 0, LAP, -16, -10, APRON)
wall('OuterWall', 0, LAP, 10.5, WHITE)
wall('InnerWall', 0, LAP, -38, CONCRETE)

# Pit entry after T4; parallel front-straight lane and full T1/T2 bypass.
PIT_START = 18.0
PIT_END = STRAIGHT + ARC + 145


def pit_center(s):
    if s < 115:
        return -12 - 12*smooth((s-PIT_START)/(115-PIT_START))
    if s > STRAIGHT + ARC + 20:
        return -24 + 12*smooth((s-STRAIGHT-ARC-20)/125)
    return -24.0


def pit_halfwidth(s):
    return 5 * min(smooth((s-PIT_START)/55), smooth((PIT_END-s)/55))


ribbon('PitLane-col', PIT_START, PIT_END,
       lambda s: pit_center(s)-pit_halfwidth(s), lambda s: pit_center(s)+pit_halfwidth(s), PIT, 0.008)
ribbon('PitBoxesConcrete-col', 115, STRAIGHT-15, -35.5, -29, CONCRETE)
wall('PitSeparator', 125, STRAIGHT+ARC+15, -17, WHITE, 1.0)
for offset in [-9.9, 9.6]:
    ribbon('TrackEdge', 0, LAP, offset-.075, offset+.075, WHITE, .022)
ribbon('PitGuide', PIT_START+5, PIT_END-5,
       lambda s: pit_center(s)-.065, lambda s: pit_center(s)+.065, YELLOW, .035)
for i in range(28):
    s = 120 + i*(STRAIGHT-145)/27
    ribbon('PitBoxLine', s, s+.12, -35.3, -29.15, YELLOW, .025)
    if i < 27:
        p = point(s+3, -33, .03)
        label(str(i+1), p, 1.5)

FINISH = STRAIGHT * .65
for row in range(2):
    for col in range(20):
        ribbon('FinishChecker', FINISH+row*.7, FINISH+(row+1)*.7,
               -10+col, -9+col, WHITE if (row+col)%2 == 0 else ASPHALT, .03)
for i in range(27):
    s = FINISH - 15 - (i//2)*12
    d = -4 if i%2 == 0 else 4
    ribbon('GridSlot', s, s+.12, d-1.2, d+1.2, WHITE, .025)
    for edge in [d-1.2, d+1.2]:
        ribbon('GridSlotSide', s, s+4.5, edge, edge+.1, WHITE, .025)
for i in range(7):
    box('Grandstand', (FINISH-STRAIGHT/2, -RADIUS-24-i*3, 1.2+i*.9), (260, 3, .5), BLUE if i%2 else CONCRETE)
box('PitBuilding-col', (20, -58, 4), (160, 18, 8), CONCRETE)
label('MILE OVAL', (0, 15, .05), 17)
label('1609.344 m  /  9 deg', (0, -7, .05), 7)
for text, s in [('T1',STRAIGHT+ARC*.22),('T2',STRAIGHT+ARC*.78),
                ('T3',2*STRAIGHT+ARC*1.22),('T4',2*STRAIGHT+ARC*1.78)]:
    label(text, point(s, -55, .05), 10)

# Export reference geometry in Godot coordinates (Blender X,Y,Z -> X,Z,-Y).
def godot(v):
    return [round(v[0],5),round(v[2],5),round(-v[1],5)]


reference = {
    'units': 'metres', 'reference_length_m': LAP, 'straight_length_m': STRAIGHT,
    'reference_radius_m': RADIUS, 'max_banking_deg': 9,
    'bank_transition_m': BANK_TRANSITION,
    'track_width_m': 20, 'apron_width_m': 6,
    'reference_path': [godot(point(i*LAP/804, 0)) for i in range(805)],
    'pit_path': [godot(point(PIT_START+(PIT_END-PIT_START)*i/500, pit_center(PIT_START+(PIT_END-PIT_START)*i/500), .008)) for i in range(501)],
    'start_finish_position': godot(point(FINISH, 0, .1)),
    'note': 'Reference geometry only; not yet a tuned AI racing line.'
}
(PACKAGE/'ai/reference_paths.json').write_text(json.dumps(reference, indent=2)+'\n')
assert abs(2*STRAIGHT+2*math.pi*RADIUS-LAP) < 1e-8
assert all(math.dist(point(0,d),point(LAP,d)) < 1e-6 for d in [-16,-10,10])
assert abs(frame(STRAIGHT+ARC/2)[2]-9) < 1e-8
assert all(poly.normal.z > .98 for poly in bpy.data.objects['RacingSurface-col'].data.polygons)

bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(PACKAGE/'models/mile_oval.glb'), export_format='GLB', use_selection=True)

# An orthographic source-file camera provides a repeatable layout review.
bpy.ops.object.camera_add(location=(620,-820,1050))
camera = bpy.context.object
camera.name = 'OverviewCamera'
camera.rotation_euler = (Vector((0,0,0))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.clip_end = 5000
camera.data.ortho_scale = 980
scene.camera = camera
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'MATERIAL'
scene.display.shading.show_shadows = True
scene.display.shading.show_cavity = True
scene.render.resolution_x = 1600
scene.render.resolution_y = 1100
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.filepath = str(SOURCE/'overview.png')
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'mile_oval.blend'))
bpy.ops.render.render(write_still=True)
print('TRACK VALIDATION PASSED: metric dimensions, closed seams, banking, surface normals.')
