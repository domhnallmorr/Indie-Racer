"""Blender --background --python tools/build_open_wheel.py.
Generates a visual-only, metric, mid-1990s oval car. Rebuild overwrites outputs.
Blender +Y forward exports to Godot -Z forward; origin is ground level.
"""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'source_art/vehicles/open_wheel'
PACKAGE = ROOT / 'content/vehicles/open_wheel'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1
scene.unit_settings.length_unit = 'METERS'


def material(name, rgb, metallic=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*rgb, 1)
    bsdf.inputs['Roughness'].default_value = .65
    bsdf.inputs['Metallic'].default_value = metallic
    return mat


RED = material('Livery_RacingRed', (.68, .025, .025))
WHITE = material('Livery_Ivory', (.88, .86, .77))
BLACK = material('Carbon', (.025, .03, .038))
RUBBER = material('SlickRubber', (.012, .014, .018))
METAL = material('WheelMagnesium', (.32, .34, .37), .6)
VISOR = material('Visor', (.025, .07, .10), .3)
YELLOW = material('HelmetGold', (.95, .64, .06))


def mesh(name, verts, faces, mat):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    data.materials.append(mat)
    # Recalculate outward normals for custom closed body sections.
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    return obj


def box(name, xyz, dims, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return obj


def loft(name, sections, mat, x=0):
    verts = []
    for y, w, bottom, top in sections:
        verts.extend([(x-w*.8,y,bottom),(x+w*.8,y,bottom),(x+w,y,bottom+.05),
                      (x+w,y,top-.05),(x+w*.72,y,top),(x-w*.72,y,top),
                      (x-w,y,top-.05),(x-w,y,bottom+.05)])
    faces = [tuple(reversed(range(8)))]
    for i in range(len(sections)-1):
        for j in range(8):
            faces.append((8*i+j,8*i+(j+1)%8,8*(i+1)+(j+1)%8,8*(i+1)+j))
    faces.append(tuple(8*(len(sections)-1)+j for j in range(8)))
    return mesh(name, verts, faces, mat)


def rod(name, a, b, radius, mat, vertices=6):
    a, b = Vector(a), Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=(b-a).length, location=(a+b)/2)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = (b-a).to_track_quat('Z','Y').to_euler()
    obj.data.materials.append(mat)
    return obj


# Slim pointed nose, broad low sidepods, open cockpit, low tapered engine cover.
loft('Nose', [(.28,.29,.17,.57),(.75,.24,.17,.51),(1.65,.145,.15,.36),(2.30,.08,.14,.27)], RED)
loft('Floor', [(-2.0,.26,.09,.20),(-1.30,.72,.09,.20),(.40,.66,.09,.20),(.70,.25,.09,.20)], BLACK)
for side in [-1,1]:
    loft('SidepodLeft' if side < 0 else 'SidepodRight',
         [(-1.60,.14,.17,.40),(-1.18,.27,.15,.54),(.08,.27,.15,.55),(.38,.23,.16,.46)], RED, side*.48)
    box('RadiatorIntake', (side*.49,.389,.33), (.35,.015,.16), BLACK)
    box('SidepodStripe', (side*.748,-.50,.37), (.007,1.13,.14), WHITE)
    loft('CockpitRim', [(-.67,.065,.24,.64),(-.27,.065,.24,.62),(.28,.065,.24,.57)], RED, side*.255)
loft('EngineCover', [(-2.04,.13,.19,.35),(-1.37,.24,.18,.58),(-.78,.25,.20,.83),(-.60,.25,.20,.72)], RED)
box('CockpitWell', (0,-.20,.25), (.40,.78,.10), BLACK)
box('SeatBack', (0,-.53,.44), (.34,.09,.35), BLACK)
rod('RollHoopLeft', (-.18,-.64,.64),(-.12,-.65,.94),.035,METAL)
rod('RollHoopTop', (-.12,-.65,.94),(.12,-.65,.94),.035,METAL)
rod('RollHoopRight', (.12,-.65,.94),(.18,-.64,.64),.035,METAL)

# Low-detail driver and helmet give the open cockpit a period silhouette.
box('DriverShoulders', (0,-.27,.53), (.34,.24,.18), WHITE)
bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=1, location=(0,-.25,.76))
helmet = bpy.context.object
helmet.name = 'DriverHelmet'
helmet.scale = (.145,.16,.17)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
helmet.data.materials.append(YELLOW)
box('HelmetVisor', (0,-.102,.78), (.235,.032,.065), VISOR)
rod('SteeringWheel',(-.12,.11,.54),(.12,.11,.54),.035,BLACK,8)

# Oval trim: single shallow-chord blades and small endplates.
box('FrontWing', (0,2.03,.16), (1.78,.27,.045), WHITE)
box('RearWing', (0,-2.05,.79), (1.00,.29,.05), WHITE)
for side in [-1,1]:
    box('FrontEndplate', (side*.89,2.03,.19), (.025,.32,.19), RED)
    box('RearEndplate', (side*.50,-2.05,.80), (.025,.34,.24), RED)
    box('RearWingStay', (side*.17,-2.05,.51), (.035,.10,.51), BLACK)
    rod('MirrorStem',(side*.25,.18,.53),(side*.41,.18,.62),.016,BLACK)
    box('Mirror', (side*.43,.18,.63), (.11,.15,.07), RED)

# Four 16-sided slicks with bevelled shoulders, separate wheel object origins.
for axle, y, radius, width, hub in [('Front',1.34,.315,.25,.86),('Rear',-1.48,.34,.36,.84)]:
    for side, suffix in [(-1,'Left'),(1,'Right')]:
        cx = side*hub
        verts = []
        rings = [(-width/2,.87),(-width/2+.03,1),(width/2-.03,1),(width/2,.87)]
        for dx, factor in rings:
            for i in range(16):
                a = 2*math.pi*i/16
                verts.append((dx,math.sin(a)*radius*factor,math.cos(a)*radius*factor))
        faces = [tuple(reversed(range(16)))]
        for j in range(3):
            for i in range(16):
                faces.append((j*16+i,j*16+(i+1)%16,(j+1)*16+(i+1)%16,(j+1)*16+i))
        faces.append(tuple(48+i for i in range(16)))
        tire = mesh('Wheel'+axle+suffix,verts,faces,RUBBER)
        tire.location = (cx,y,radius)
        outer = cx+side*(width/2+.003)
        rim = rod('Rim'+axle+suffix,(outer-side*.015,y,radius),(outer,y,radius),radius*.53,METAL,12)
        hubcap = rod('Hub'+axle+suffix,(outer,y,radius),(outer+side*.008,y,radius),.065,BLACK,8)
        for part in [rim,hubcap]:
            world = part.matrix_world.copy()
            part.parent = tire
            part.matrix_world = world
        for h in [.22,.39]:
            for attach_y in [y-.32,y+.32]:
                rod('Wishbone'+axle+suffix,(side*.24,attach_y,h),(cx,y,radius),.018,BLACK)

# Race number on the top of the nose, converted to geometry for portable export.
bpy.ops.object.text_add(location=(0,1.1,.447))
number = bpy.context.object
number.name = 'Number27'
number.data.body = '27'
number.data.align_x = 'CENTER'
number.data.size = .22
number.rotation_euler = (0,0,math.pi)
number.data.materials.append(WHITE)
bpy.ops.object.convert(target='MESH')

bpy.context.view_layer.update()
runtime = list(scene.objects)
triangles = sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in runtime if o.type == 'MESH')
assert triangles < 6000, triangles
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(PACKAGE/'models/open_wheel.glb'),export_format='GLB',use_selection=True)

# Source-only presentation ground and overview camera, excluded from runtime export.
groundmat = material('PreviewGround',(.19,.23,.27))
box('PreviewGround',(0,0,-.035),(200,200,.05),groundmat)
bpy.ops.object.camera_add(location=(6,8,4.3))
camera = bpy.context.object
camera.name = 'PreviewCamera'
camera.rotation_euler = (Vector((0,0,.35))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 6.6
scene.camera = camera
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'MATERIAL'
scene.display.shading.show_shadows = True
scene.display.shading.show_cavity = True
scene.render.resolution_x = 1400
scene.render.resolution_y = 950
scene.render.resolution_percentage = 100
scene.render.filepath = str(SOURCE/'overview.png')
# Select only runtime objects to make subsequent manual export straightforward.
bpy.ops.object.select_all(action='DESELECT')
for obj in runtime:
    obj.select_set(True)
bpy.context.view_layer.objects.active = runtime[0]
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'open_wheel.blend'))
bpy.ops.render.render(write_still=True)
(SOURCE/'model_stats.json').write_text(json.dumps({'triangles':triangles,'units':'metres','visual_only':True},indent=2)+'\n')
print('CAR BUILD PASSED: %d triangles; metric, visual-only model.' % triangles)
