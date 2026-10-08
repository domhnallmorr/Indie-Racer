"""Rebuild the wheel-free metric interior with Blender --background --python tools/build_cockpit.py.
Blender +Y maps to Godot -Z. IR-05 dash fit is authored here, not scaled at runtime.
All procedural texture maps are packed into the Blend and embedded in the GLB.
"""
from pathlib import Path
import math
import bpy
import numpy as np
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system = 'METRIC'
bpy.context.scene.unit_settings.scale_length = 1
bpy.context.preferences.filepaths.save_version = 0


def material(name, color, roughness=.7, metallic=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    shader = m.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Roughness'].default_value = roughness
    shader.inputs['Metallic'].default_value = metallic
    return m


def image(name, rgb, data=False):
    h, w, _ = rgb.shape
    img = bpy.data.images.new(name, width=w, height=h)
    if data:
        img.colorspace_settings.name = 'Non-Color'
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[:, :, :3] = rgb
    img.pixels.foreach_set(rgba.ravel())
    img.pack()
    return img


carbon = material('CockpitCarbon', (.06, .065, .07), .6)
# Seamless 2/2 twill. UVs use metres / .064: each tow is 2 mm wide.
yy, xx = np.mgrid[0:512, 0:512]
x, y = xx / 16, yy / 16
horizontal = ((np.floor(x) + np.floor(y)) % 4) < 2
cross = np.where(horizontal, y % 1, x % 1)
roundness = np.sin(np.pi * cross) ** .6
fibres = .5 + .5 * np.cos(cross * math.tau * 6)
value = .065 + .030 * roundness + .006 * fibres + .008 * horizontal
shader = carbon.node_tree.nodes.get('Principled BSDF')
tex = carbon.node_tree.nodes.new('ShaderNodeTexImage')
tex.image = image('CarbonTwill_Albedo', np.stack((value*.94,value*.98,value),axis=-1))
carbon.node_tree.links.new(tex.outputs['Color'], shader.inputs['Base Color'])
height = .22 * roundness + .02 * fibres
dx = (np.roll(height,-1,axis=1)-np.roll(height,1,axis=1))*.6
dy = (np.roll(height,-1,axis=0)-np.roll(height,1,axis=0))*.6
normals = np.stack((-dx,-dy,np.ones_like(dx)),axis=-1)
normals /= np.linalg.norm(normals,axis=-1,keepdims=True)
tex = carbon.node_tree.nodes.new('ShaderNodeTexImage')
tex.image = image('CarbonTwill_Normal',normals*.5+.5,True)
normal = carbon.node_tree.nodes.new('ShaderNodeNormalMap')
carbon.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color'])
carbon.node_tree.links.new(normal.outputs['Normal'],shader.inputs['Normal'])
tex = carbon.node_tree.nodes.new('ShaderNodeTexImage')
tex.image = image('CarbonTwill_Roughness',np.repeat((.59+.10*(1-roundness))[:,:,None],3,axis=2),True)
carbon.node_tree.links.new(tex.outputs['Color'],shader.inputs['Roughness'])
paint = material('CockpitRed',(.52,.018,.022),.34)
rubber = material('CockpitRubber',(.011,.014,.016),.88)
metal = material('SatinAluminium',(.31,.33,.34),.39,.75)
dark_metal = material('BlackAnodised',(.035,.043,.049),.48,.45)
ink = material('PanelLettering',(.58,.61,.55),.85)
red = material('KillSwitchRed',(.35,.025,.015),.52)


def finish(obj, mat, bevel=0):
    obj.data.materials.append(mat)
    if bevel:
        bpy.context.view_layer.objects.active = obj
        mod = obj.modifiers.new('Manufactured edge','BEVEL')
        mod.width, mod.segments = bevel, 3
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod = obj.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if mat == carbon:
        uv = obj.data.uv_layers.new(name='CarbonMetres') if not obj.data.uv_layers else obj.data.uv_layers.active
        for poly in obj.data.polygons:
            axis = max(range(3),key=lambda a: abs(poly.normal[a]))
            axes = [a for a in range(3) if a != axis]
            for loop in poly.loop_indices:
                co = obj.matrix_world @ obj.data.vertices[obj.data.loops[loop].vertex_index].co
                uv.data[loop].uv = (co[axes[0]]/.064,co[axes[1]]/.064)
    return obj


def mesh(name, vertices, faces, mat, bevel=0):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices,[],faces)
    data.update()
    obj = bpy.data.objects.new(name,data)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    return finish(obj,mat,bevel)


def box(name, location, dimensions, mat, bevel=.002):
    bpy.ops.mesh.primitive_cube_add(size=1,location=location)
    obj = bpy.context.object
    obj.name, obj.dimensions = name, dimensions
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(obj,mat,bevel)


def rod(name, start, end, radius, mat, vertices=16):
    a,b = Vector(start),Vector(end)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=(b-a).length,location=(a+b)/2)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = (b-a).to_track_quat('Z','Y').to_euler()
    finish(obj,mat,.0007)
    for poly in obj.data.polygons:
        poly.use_smooth = len(poly.vertices) == 4
    return obj


def sweep(name, points, radius, mat):
    curve = bpy.data.curves.new(name,'CURVE')
    curve.dimensions, curve.bevel_depth, curve.bevel_resolution = '3D',radius,3
    spline = curve.splines.new('BEZIER')
    spline.bezier_points.add(len(points)-1)
    for bp,co in zip(spline.bezier_points,points):
        bp.co = co
        bp.handle_left_type = bp.handle_right_type = 'AUTO'
    obj = bpy.data.objects.new(name,curve)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target='MESH')
    return finish(obj,mat)


def profile(width, height, chamfer, center=.58):
    w,h,c = width/2,height/2,chamfer
    return [(-w,center-h),(w,center-h),(w,center+h-c),(w-c,center+h),(-w+c,center+h),(-w,center+h-c)]


def ring(name, outer, inner, front, back, mat, bevel=.001):
    vertices = [(x,y,z) for y in (front,back) for outline in (outer,inner) for x,z in outline]
    n,faces = len(outer),[]
    for i in range(n):
        j = (i+1)%n
        faces += [(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),(i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)]
    return mesh(name,vertices,faces,mat,bevel)


def screw(x,y,z):
    rod('PanelFastener',(x,y+.001,z),(x,y-.0015,z),.0034,metal,12)
    box('FastenerSlot',(x,y-.0023,z),(.004,.0006,.0007),rubber,0)


def label(text,location,size=.008):
    curve = bpy.data.curves.new('Label '+text,'FONT')
    curve.body,curve.size,curve.align_x = text,size,'CENTER'
    obj = bpy.data.objects.new('Label_'+text,curve)
    bpy.context.collection.objects.link(obj)
    obj.location, obj.rotation_euler.x = location, math.pi/2
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target='MESH')
    return finish(obj,ink)


# Shoulder-wide tub tapering towards a curved forward bulkhead.
stations = [(-.46,.260,.645),(-.27,.234,.673),(-.06,.207,.685),(.12,.208,.688),(.28,.214,.681),(.39,.140,.678)]
for side in (-1,1):
    vertices = []
    for y,x,z in stations:
        vertices += [(side*x,y,z),(side*(x-.010),y,z-.04),(side*(x-.020),y,.335),(side*(x+.080),y,z-.008)]
    faces = [(4*i+j,4*i+(j+1)%4,4*(i+1)+(j+1)%4,4*(i+1)+j) for i in range(len(stations)-1) for j in range(4)]
    faces += [(3,2,1,0),tuple(range(len(vertices)-4,len(vertices)))]
    mesh('CarbonTub',vertices,faces,carbon,.003)
rim = [(-x,y,z+.006) for y,x,z in stations]+[(0,.425,.680)]+[(x,y,z+.006) for y,x,z in reversed(stations)]
sweep('PaintedCockpitLip',rim,.009,paint)
sweep('TubEdgeSeal',[(x,y,z-.014) for x,y,z in rim],.004,rubber)
mesh('ForwardCowl',[(-.214,.25,.680),(.214,.25,.680),(.14,.39,.678),(0,.425,.680),(-.14,.39,.678),
     (-.214,.25,.654),(.214,.25,.654),(.14,.39,.652),(0,.425,.654),(-.14,.39,.652)],
     [(0,1,2,3,4),(9,8,7,6,5),(0,5,6,1),(1,6,7,2),(2,7,8,3),(3,8,9,4),(4,9,5,0)],carbon,.002)
box('FootwellShadow',(0,.27,.32),(.40,.40,.025),rubber)
mesh('LowerDashLining',[(-.215,.173,.462),(.215,.173,.462),(.178,-.06,.31),(-.178,-.06,.31),
     (-.215,.195,.462),(.215,.195,.462),(.178,-.038,.31),(-.178,-.038,.31)],
     [(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],carbon,.002)
for side in (-1,1):
    mesh('DashShoulder',[(side*.204,.17,.478),(side*.283,-.055,.50),(side*.272,-.04,.65),(side*.221,.18,.697),
         (side*.204,.215,.478),(side*.283,-.005,.50),(side*.272,.01,.65),(side*.221,.225,.697)],
         [(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],carbon,.002)
# Live screen fits the open aperture; no hidden face behind the LCD.
ring('InstrumentHousing',profile(.450,.244,.052),profile(.392,.190,.035),.185,.239,carbon,.003)
ring('InstrumentSatinBezel',profile(.397,.195,.036),profile(.381,.179,.030),.178,.188,dark_metal)
ring('InstrumentScreenSeal',profile(.382,.180,.030),profile(.374,.172,.027),.176,.181,rubber,.0006)
box('InstrumentSunHood',(0,.193,.706),(.344,.084,.010),carbon,.003)
for x,z in [(-.211,.49),(.211,.49),(-.170,.690),(.170,.690)]:
    screw(x,.181,z)
label('OVAL  /  COMPETITION',(0,.177,.477),.007)
# Discreet auxiliary controls.
before_switches = set(bpy.context.scene.objects)
box('SwitchPanel',(.253,.060,.557),(.057,.026,.128),dark_metal,.004)
for z,caption in [(.59,'IGN')]:
    rod('SwitchWasher',(.253,.043,z),(.253,.040,z),.008,metal)
    rod('ToggleSwitch',(.253,.039,z),(.253,.024,z+.012),.0025,metal)
    label(caption,(.253,.043,z-.016),.006)
rod('RotaryBezel',(.253,.044,.545),(.253,.039,.545),.012,metal,24)
rod('RotaryGrip',(.253,.038,.545),(.253,.025,.545),.0095,rubber,16)
box('RotaryIndex',(.253,.024,.550),(.0015,.001,.006),ink,.0003)
label('BIAS',(.253,.043,.527),.006)
rod('KillSwitch',(.253,.041,.515),(.253,.032,.515),.008,red)
for x in (.232,.274):
    for z in (.505,.611): screw(x,.044,z)
for obj in set(bpy.context.scene.objects)-before_switches:
    obj.location += Vector((-.070,-.025,.063))
# Lever on the left. Shaft/knob share a pivot; gaiter and mount stay fixed.
box('ShiftConsole',(-.248,-.040,.486),(.078,.143,.075),carbon,.006)
box('ShiftMount',(-.248,-.040,.527),(.068,.099,.009),dark_metal,.004)
for x in (-.274,-.222):
    for y in (-.076,-.004): rod('ShiftMountBolt',(x,y,.531),(x,y,.534),.003,metal,12)
for i in range(5):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=8,radius=1,location=(-.248,-.04,.536+i*.007))
    boot = bpy.context.object
    boot.name,boot.scale = 'ShiftBoot',(.026-i*.003,.035-i*.004,.008)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    finish(boot,rubber)
    for poly in boot.data.polygons: poly.use_smooth = True
pivot = bpy.data.objects.new('GearLeverPivot',None)
bpy.context.collection.objects.link(pivot)
pivot.location = (-.248,-.04,.554)
shaft = rod('GearLeverShaft',(-.248,-.04,.554),(-.236,-.055,.608),.004,metal,20)
bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=1,location=(-.236,-.055,.617))
knob = bpy.context.object
knob.name,knob.scale = 'GearLeverKnob',(.014,.015,.016)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
finish(knob,rubber)
for poly in knob.data.polygons: poly.use_smooth = True
bpy.context.view_layer.update()
for obj in (shaft,knob):
    world = obj.matrix_world.copy()
    obj.parent = pivot
    obj.matrix_world = world
# The lever sits inside the exterior body's opening, clear of the coaming.
for obj in list(bpy.context.scene.objects):
    if obj.name.startswith(('Shift','GearLeverPivot')):
        obj.location += Vector((.053,.070,.044))
# Batch static meshes by material, keeping the lever animated and livery paint isolated.
for mat in (carbon,paint,rubber,metal,dark_metal,ink,red):
    group = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.parent != pivot and o.data.materials[0] == mat]
    if not group: continue
    bpy.ops.object.select_all(action='DESELECT')
    for obj in group: obj.select_set(True)
    bpy.context.view_layer.objects.active = group[0]
    if len(group) > 1:
        bpy.ops.object.join()
    group[0].name = mat.name+'Assembly'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'source_art/vehicles/open_wheel/cockpit.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'content/vehicles/open_wheel/models/cockpit.glb'),export_format='GLB',use_selection=True)
print('COCKPIT BUILT: wheel-free tub, chamfered instruments, carbon maps and lever pivot.')
