"""Build the generic 2001-style oval car, its shared livery UVs and source previews.
Blender +Y forward -> Godot -Z forward. Metric, ground-level origin.
Rebuilds generated .blend/.glb outputs; preserve manual edits before rebuilding.
"""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'source_art/vehicles/open_wheel'
PACKAGE = ROOT / 'content/vehicles/open_wheel'
LIVERY = PACKAGE / 'liveries'
LIVERY.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1
scene.unit_settings.length_unit = 'METERS'
painted = []


def material(name, rgb, metallic=0, roughness=.32):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*rgb, 1)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic
    return mat


# Keep the primary material name: the existing AI roster uses it to tint paint.
PAINT = material('Livery_RacingRed', (.018, .26, .62), .12, .26)
WHITE = material('Livery_Ivory', (.91, .94, .96), .05, .28)
SUIT = material('DriverSuit', (.84, .86, .88), 0, .7)
CARBON = material('Carbon', (.022, .026, .031), .12, .48)
RUBBER = material('SlickRubber', (.018, .021, .025), 0, .68)
METAL = material('SuspensionMetal', (.28, .31, .34), .78, .3)
RIM = material('WheelMagnesium', (.065, .07, .077), .72, .28)
DARK = material('IntakeShadow', (.003, .005, .008), 0, .9)
VISOR = material('Visor', (.022, .05, .075), .68, .12)
HELMET = material('HelmetBlue', (.015, .31, .7), .2, .23)
RED = material('RearLight', (.7, .015, .008), .1, .25)


def finish(obj, mat, smooth=False):
    obj.data.materials.append(mat)
    if smooth:
        for p in obj.data.polygons:
            p.use_smooth = True
    if mat in (PAINT, WHITE):
        painted.append(obj)
    return obj


def mesh(name, verts, faces, mat, smooth=False):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    finish(obj, mat, smooth)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    return obj


def box(name, pos, size, mat, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    finish(obj, mat)
    if bevel:
        mod = obj.modifiers.new('Soft manufactured edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 3
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod = obj.modifiers.new('Weighted normals', 'WEIGHTED_NORMAL')
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def rod(name, a, b, radius, mat=CARBON, vertices=10):
    a, b = Vector(a), Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=(b-a).length, location=(a+b)/2)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = (b-a).to_track_quat('Z', 'Y').to_euler()
    return finish(obj, mat, True)


def sphere(name, pos, scale, mat, segments=24, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, mat, True)


def loft(name, sections, mat, x=0, end_cap=True, exponent=.62):
    """Rounded-box sections (Y, half-width, bottom, top); smooth axial sampling."""
    samples = []
    for i in range(len(sections)-1):
        a, b = sections[max(i-1, 0)], sections[i]
        c, d = sections[i+1], sections[min(i+2, len(sections)-1)]
        for step in range(4):
            t = step / 4
            # Monotonic Y; interpolate the silhouette without subdivision shrinkage.
            values = [b[0] + (c[0]-b[0])*t]
            for k in range(1, 4):
                value = .5*((2*b[k])+(-a[k]+c[k])*t+(2*a[k]-5*b[k]+4*c[k]-d[k])*t*t+(-a[k]+3*b[k]-3*c[k]+d[k])*t*t*t)
                values.append(max(.009, value) if k == 1 else value)
            samples.append(values)
    samples.append(sections[-1])
    n = 24
    verts = []
    for y, width, bottom, top in samples:
        for j in range(n):
            angle = 2*math.pi*j/n
            cs, sn = math.cos(angle), math.sin(angle)
            verts.append((x+width*math.copysign(abs(cs)**exponent, cs), y,
                          (bottom+top)/2+(top-bottom)/2*math.copysign(abs(sn)**exponent, sn)))
    faces = [tuple(reversed(range(n)))]
    for i in range(len(samples)-1):
        for j in range(n):
            faces.append((i*n+j, i*n+(j+1)%n, (i+1)*n+(j+1)%n, (i+1)*n+j))
    if end_cap:
        faces.append(tuple((len(samples)-1)*n+j for j in range(n)))
    return mesh(name, verts, faces, mat, True)


# A narrow low nose runs back into a hollow tub; no filled block through the driver.
loft('Nose', [(.30,.285,.20,.635),(.70,.255,.205,.60),(1.17,.205,.18,.49),
             (1.65,.155,.17,.365),(2.10,.10,.165,.26),(2.42,.045,.175,.215),(2.50,.012,.185,.205)], PAINT)
loft('LowerMonocoque', [(-.80,.235,.105,.26),(-.40,.29,.105,.27),(.30,.285,.13,.32),(.64,.24,.17,.48)], PAINT)
loft('Floor', [(-2.10,.37,.075,.105),(-1.5,.58,.065,.095),(-.9,.805,.065,.095),
              (.50,.78,.065,.095),(.80,.25,.085,.11)], CARBON, exponent=.3)
for side, label in [(-1,'Left'),(1,'Right')]:
    loft('Sidepod'+label, [(-1.50,.115,.125,.32),(-1.20,.205,.115,.46),(-.65,.285,.115,.58),
                         (.05,.285,.14,.61),(.43,.27,.185,.59),(.66,.23,.225,.525)], PAINT, side*.505, end_cap=False)
    # Recessed radiator opening, with a thick painted leading edge and a dark duct.
    loft('RadiatorDuct'+label, [(.39,.205,.245,.485),(.64,.215,.24,.51)], DARK, side*.505)
    for z in [.285,.335,.385,.435]:
        box('RadiatorVane'+label,(side*.505,.651,z),(.37,.012,.009),CARBON)
    loft('CockpitRim'+label,[(-.75,.083,.31,.675),(-.49,.065,.33,.69),(-.10,.056,.31,.65),(.32,.062,.28,.635)],PAINT,side*.267)
    # Narrow dark cockpit inner padding leaves a clearly open seat cavity.
    loft('CockpitPadding'+label,[(-.62,.022,.38,.65),(-.25,.019,.38,.615),(.22,.02,.38,.60)],CARBON,side*.208)
    rod('MirrorStem'+label,(side*.265,.34,.58),(side*.41,.42,.67),.013)
    sphere('Mirror'+label,(side*.425,.43,.682),(.095,.065,.043),PAINT,16,8)
    box('MirrorGlass'+label,(side*.425,.374,.682),(.14,.008,.053),VISOR,.008)

box('CockpitWell',(0,-.20,.31),(.40,.85,.07),DARK,.025)
box('SeatBack',(0,-.64,.49),(.35,.085,.32),CARBON,.025)
loft('EngineCover',[(-2.05,.09,.22,.36),(-1.65,.15,.22,.49),(-1.24,.215,.23,.65),
                    (-.95,.24,.25,.79),(-.70,.215,.29,.87),(-.57,.185,.32,.84)],PAINT)
# Tall period airbox: an oval lip and visibly recessed hollow throat, no modern fin.
loft('AirboxSpine',[(-1.40,.075,.49,.64),(-1.04,.10,.59,.85),(-.80,.145,.67,1.005),
                    (-.61,.155,.72,1.075),(-.51,.14,.755,1.045)],PAINT, end_cap=False, exponent=1)
verts, faces = [], []
for y, rx, rz in [(-.495,.145,.155),(-.48,.122,.133),(-.62,.103,.112)]:
    for i in range(32):
        a=2*math.pi*i/32
        verts.append((rx*math.cos(a),y,.905+rz*math.sin(a)))
for ring in range(2):
    for i in range(32):
        faces.append((ring*32+i,ring*32+(i+1)%32,(ring+1)*32+(i+1)%32,(ring+1)*32+i))
intake=mesh('AirIntakeLip',verts,faces,PAINT,True)
mesh('AirIntakeDepth',[(.103*math.cos(i*math.tau/32),-.635,.905+.112*math.sin(i*math.tau/32)) for i in range(32)], [tuple(range(32))], DARK)
loft('RollHoopFairing',[(-.77,.026,.97,1.105),(-.65,.035,1.0,1.13),(-.57,.025,1.01,1.09)],PAINT)

# Driver proportions and rounded full-face helmet. Keep hideable node prefixes.
sphere('DriverShoulders',(0,-.32,.545),(.185,.14,.14),SUIT)
for side in [-1,1]:
    rod('DriverUpperArm',(side*.16,-.24,.54),(side*.17,-.02,.44),.047,SUIT,12)
    rod('DriverForearm',(side*.17,-.02,.44),(side*.12,.09,.52),.04,SUIT,12)
    sphere('DriverGlove',(side*.115,.10,.52),(.041,.04,.045),CARBON,12,8)
sphere('DriverHelmet',(0,-.285,.796),(.143,.167,.169),HELMET,32,16)
# Curved visor patch on the front hemisphere.
verts=[]
for v in range(5):
    latitude=-.06+v*.105
    for u in range(17):
        a=-1.18+u*2.36/16
        verts.append((.146*math.sin(a)*math.cos(latitude),-.285+.171*math.cos(a)*math.cos(latitude),.79+.17*math.sin(latitude)))
mesh('HelmetVisor',verts,[(v*17+u,v*17+u+1,(v+1)*17+u+1,(v+1)*17+u) for v in range(4) for u in range(16)],VISOR,True)
rod('HelmetVisorSeal',(-.12,-.185,.86),(.12,-.185,.86),.008,CARBON,8)
rod('SteeringWheel',(-.13,.10,.52),(.13,.10,.52),.025,CARBON,12)


def wing(name, span, y, z, chord, mat):
    # Thin cambered airfoil; broad planform, slender edge-on oval-racing profile.
    profile=[(0,0),(.08,.014),(.28,.019),(.55,.009),(1,-.025),(.97,-.037),(.5,-.009),(.12,-.01)]
    verts=[(x,y+chord*(.5-t),z+h) for x in [-span/2,span/2] for t,h in profile]
    return mesh(name,verts,[tuple(reversed(range(8))),tuple(range(8,16))]+[(j,(j+1)%8,(j+1)%8+8,j+8) for j in range(8)],mat)

wing('FrontWing',1.84,2.205,.158,.47,WHITE)
wing('RearWing',1.08,-2.265,.905,.47,WHITE)
for side,label in [(-1,'Left'),(1,'Right')]:
    box('FrontEndplate'+label,(side*.917,2.20,.198),(.018,.49,.255),PAINT,.009)
    box('RearEndplate'+label,(side*.546,-2.265,.84),(.018,.47,.37),PAINT,.009)
    box('FrontWingMount'+label,(side*.065,2.15,.202),(.028,.16,.12),CARBON,.007)
    box('RearWingStay'+label,(side*.20,-2.19,.60),(.032,.14,.58),CARBON,.008)
    rod('RearWingBrace'+label,(side*.20,-2.20,.49),(side*.40,-2.25,.87),.012,METAL)

# Exposed gearbox, driveshafts, shallow upward rear floor and small strakes.
loft('Gearbox',[(-2.29,.105,.235,.34),(-1.95,.13,.18,.41),(-1.46,.17,.19,.43)],METAL)
box('RearCrashBox',(0,-2.33,.29),(.225,.32,.17),PAINT,.028)
box('RearRainLight',(0,-2.497,.30),(.11,.005,.055),RED,.004)
for side in [-1,1]:
    rod('ExhaustOutlet',(side*.24,-1.65,.40),(side*.28,-1.89,.43),.036,METAL,16)
    rod('ExhaustBore',(side*.28,-1.889,.43),(side*.281,-1.897,.431),.028,DARK,16)
    # Only 90 mm rise over the final 650 mm, not a tall modern diffuser.
    mesh('ShallowDiffuser',[(side*.13,-1.55,.079),(side*.59,-1.55,.079),(side*.58,-2.20,.169),(side*.13,-2.20,.169)],[(0,1,2,3)],CARBON)
    for x in [.15,.37,.57]:
        mesh('DiffuserStrake',[(side*x,-1.55,.075),(side*x,-2.20,.075),(side*x,-2.20,.167)],[(0,1,2),(2,1,0)],CARBON)

# Rounded slick shoulder profile, recessed twelve-spoke magnesium rims and brakes.
for axle,y,radius,width,hub in [('Front',1.5,.325,.30,.845),('Rear',-1.5,.35,.39,.805)]:
    for side,label in [(-1,'Left'),(1,'Right')]:
        cx=side*hub
        verts=[]
        rings=[(-width/2,.63),(-width/2,.85),(-width/2+.018,.95),(-width/2+.045,.995),
               (-width*.23,1),(width*.23,1),(width/2-.045,.995),(width/2-.018,.95),(width/2,.85),(width/2,.63)]
        for dx,factor in rings:
            for i in range(48):
                a=math.tau*i/48
                verts.append((dx,math.sin(a)*radius*factor,math.cos(a)*radius*factor))
        faces=[]
        for ring in range(len(rings)-1):
            for i in range(48):
                faces.append((ring*48+i,ring*48+(i+1)%48,(ring+1)*48+(i+1)%48,(ring+1)*48+i))
        tire=mesh('Wheel'+axle+label,verts,faces,RUBBER,True)
        tire.location=(cx,y,radius)
        parts=[]
        outer=cx+side*(width/2-.018)
        # Rim barrel, rings and spokes are all parented to their hub-origin wheel.
        for x in [outer,cx-side*(width/2-.02)]:
            bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=8,major_radius=radius*.60,minor_radius=.012,
                location=(x,y,radius),rotation=(0,math.pi/2,0))
            part=bpy.context.object
            part.name='RimLip'+axle+label
            parts.append(finish(part,RIM,True))
        parts.append(rod('BrakeDisc'+axle+label,(outer-side*.05,y,radius),(outer-side*.04,y,radius),radius*.49,METAL,32))
        parts.append(rod('Hub'+axle+label,(outer-side*.025,y,radius),(outer+side*.005,y,radius),.055,RIM,16))
        for i in range(12):
            a=i*math.tau/12
            parts.append(rod('Spoke'+axle+label,(outer,y+math.sin(a)*.045,radius+math.cos(a)*.045),
                (outer-side*.018,y+math.sin(a)*radius*.58,radius+math.cos(a)*radius*.58),.012,RIM,6))
        parts.append(rod('WheelNut'+axle+label,(outer,y,radius),(outer+side*.016,y,radius),.026,METAL,6))
        # Subtle moulded concentric sidewall rings; no invented tyre sponsor text.
        for factor in [.76,.86]:
            bpy.ops.mesh.primitive_torus_add(major_segments=48,minor_segments=4,major_radius=radius*factor,minor_radius=.0018,
                location=(cx+side*(width/2+.0003),y,radius),rotation=(0,math.pi/2,0))
            part=bpy.context.object
            part.name='SidewallRing'+axle+label
            parts.append(finish(part,RUBBER,True))
        bpy.context.view_layer.update()
        for part in parts:
            world=part.matrix_world.copy()
            part.parent=tire
            part.matrix_world=world
        for height in ([.20,.31] if axle=='Front' else [.20,.40]):
            for attach_y in [y-.30,y+.29]:
                rod('Wishbone'+axle+label,(side*.11,attach_y,height),(cx-side*width*.45,y,radius),.014)
        pushrod_mount=(side*.14,1.10,.45) if axle=='Front' else (side*.13,y+.15,.50)
        rod('Pushrod'+axle+label,(cx-side*.16,y,.23),pushrod_mount,.012,METAL)
        rod('TrackRod'+axle+label,(side*.11,y+.11,.29),(cx-side*.12,y+.10,radius),.011,METAL)
        if axle=='Rear':
            rod('Driveshaft'+label,(side*.12,y,.30),(cx,y,radius),.022,METAL)

# One globally packed UV atlas for ALL paint. Opposite sides occupy unique islands.
# Keep paint meshes separate so current cockpit visibility and roster overrides work.
bpy.ops.object.select_all(action='DESELECT')
for obj in painted:
    obj.select_set(True)
bpy.context.view_layer.objects.active=painted[0]
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(65),island_margin=.015,area_weight=.4)
bpy.ops.uv.pack_islands(rotate=True,margin=.006)
bpy.ops.object.mode_set(mode='OBJECT')
for obj in painted:
    obj.data.uv_layers.active.name='LiveryUV'

# A neutral atlas is wired into both paint slots. Future full-colour skins use
# the same image in both slots, with each base colour set to white (avoid tinting).
image=bpy.data.images.new('LiveryBase',width=2048,height=2048,alpha=True)
image.generated_color=(1,1,1,1)
image.filepath_raw=str(LIVERY/'base_white.png')
image.file_format='PNG'
image.save()
image.pack()
for mat in [PAINT,WHITE]:
    texture=mat.node_tree.nodes.new('ShaderNodeTexImage')
    texture.name='LiveryTexture'
    texture.label='Shared 2048px livery atlas — tint white for full-colour artwork'
    texture.image=image
    mat.node_tree.links.new(texture.outputs['Color'],mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
    # Multiply the neutral atlas by the existing material colour for default paint.
    tint=mat.node_tree.nodes.new('ShaderNodeMixRGB')
    tint.blend_type='MULTIPLY'
    tint.inputs[0].default_value=1
    tint.inputs[2].default_value=mat.diffuse_color
    mat.node_tree.links.new(texture.outputs['Color'],tint.inputs[1])
    mat.node_tree.links.new(tint.outputs[0],mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'])

# glTF only supports a texture and a base-colour factor, not arbitrary shader graphs.
# Restore supported graph; set export material factors after export below.
for mat in [PAINT,WHITE]:
    mat.node_tree.links.new(mat.node_tree.nodes['LiveryTexture'].outputs['Color'],mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'])

# Layered SVG UV wire template: separate named group per part, exact exported UVs.
svg=['<svg xmlns="http://www.w3.org/2000/svg" xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape" width="2048" height="2048" viewBox="0 0 2048 2048">',
     '<rect width="2048" height="2048" fill="white"/>']
layout={}
for index,obj in enumerate(painted):
    uv=obj.data.uv_layers.active.data
    color=f'hsl({index*137%360},55%,45%)'
    svg.append(f'<g id="{escape(obj.name)}" stroke="{color}" fill="none" stroke-width="0.6"><title>{escape(obj.name)}</title>')
    edges=set()
    points=[]
    for polygon in obj.data.polygons:
        coords=[(float(uv[i].uv.x),float(uv[i].uv.y)) for i in polygon.loop_indices]
        points.extend(coords)
        for i,a in enumerate(coords):
            b=coords[(i+1)%len(coords)]
            edge=tuple(sorted((a,b)))
            if edge not in edges:
                edges.add(edge)
                svg.append(f'<path d="M {a[0]*2048:.3f},{(1-a[1])*2048:.3f} L {b[0]*2048:.3f},{(1-b[1])*2048:.3f}"/>')
    svg.append('</g>')
    layout[obj.name]={'material':obj.data.materials[0].name,'uv_bounds':[min(p[0] for p in points),min(p[1] for p in points),max(p[0] for p in points),max(p[1] for p in points)]}
svg.append('</svg>')
(LIVERY/'template.svg').write_text('\n'.join(svg),encoding='utf-8')
(LIVERY/'layout.json').write_text(json.dumps(layout,indent=2)+'\n')

# Merge mechanical details by material to keep a full grid practical to render.
# Wheel children stay with their respective wheel; painted and hideable parts stay named.
mechanical=[o for o in scene.objects if o.type=='MESH' and o not in painted and o.parent is None
            and not o.name.startswith(('Wheel','Driver','Helmet','Mirror','SteeringWheel','Cockpit'))]
groups={mat:[o for o in mechanical if o.data.materials[0]==mat] for mat in [CARBON,METAL,RIM,RUBBER,DARK,RED]}
for mat,group in groups.items():
    if len(group)<2:
        continue
    bpy.ops.object.select_all(action='DESELECT')
    for obj in group:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=group[0]
    bpy.ops.object.join()
    bpy.context.object.name='ChassisDetails_'+mat.name
for wheel in [o for o in scene.objects if o.name.startswith('Wheel') and o.parent is None]:
    children=list(wheel.children)
    if not children:
        continue
    bpy.ops.object.select_all(action='DESELECT')
    for obj in children:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=children[0]
    bpy.ops.object.join()
    bpy.context.object.name='RimAssembly'+wheel.name[5:]

bpy.context.view_layer.update()
runtime=list(scene.objects)
triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in runtime if o.type=='MESH')
assert triangles<65000,triangles
coords=[o.matrix_world@v.co for o in runtime if o.type=='MESH' for v in o.data.vertices]
dims=[max(v[i] for v in coords)-min(v[i] for v in coords) for i in range(3)]
assert abs(dims[1]-5.0)<.015,dims
assert abs(dims[0]-2.0)<.015,dims
assert abs(bpy.data.objects['WheelFrontLeft'].location.y-bpy.data.objects['WheelRearLeft'].location.y-3.0)<1e-6
bpy.ops.object.select_all(action='SELECT')
glb_path=PACKAGE/'models/open_wheel.glb'
bpy.ops.export_scene.gltf(filepath=str(glb_path),export_format='GLB',use_selection=True,export_yup=True)
# Set standard glTF baseColorFactors explicitly; keeps runtime roster recolouring.
import struct
raw=glb_path.read_bytes()
json_size=struct.unpack_from('<I',raw,12)[0]
gltf=json.loads(raw[20:20+json_size])
for mat in gltf['materials']:
    if mat['name'] in [PAINT.name,WHITE.name]:
        source=bpy.data.materials[mat['name']]
        mat['pbrMetallicRoughness']['baseColorFactor']=list(source.diffuse_color)
packed=json.dumps(gltf,separators=(',',':')).encode()
packed+=b' '*((-len(packed))%4)
rest=raw[20+json_size:]
glb_path.write_bytes(struct.pack('<4sII',b'glTF',2,20+len(packed)+len(rest))+struct.pack('<I4s',len(packed),b'JSON')+packed+rest)
# Source preview uses the same colour multiplication as the runtime glTF factor.
for mat in [PAINT,WHITE]:
    mix=next(n for n in mat.node_tree.nodes if n.type=='MIX_RGB')
    mat.node_tree.links.new(mix.outputs[0],mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'])

# Studio preview rig: source-only, excluded from the runtime selection.
groundmat=material('PreviewGround',(.105,.13,.16),0,.8)
box('PreviewGround',(0,0,-.035),(200,200,.05),groundmat)
bpy.ops.object.camera_add(location=(6.2,8.5,4.6))
camera=bpy.context.object
camera.name='PreviewCamera'
camera.data.type='ORTHO'
camera.data.ortho_scale=6.6
scene.camera=camera
scene.render.engine='CYCLES'
scene.cycles.samples=24
scene.cycles.use_denoising=True
scene.world.color=(.25,.25,.25)
for name,pos,power,size in [('Key',(3,4,7),1600,5),('Fill',(-4,1,4),1000,4),('Rim',(1,-5,5),1800,3)]:
    bpy.ops.object.light_add(type='AREA',location=pos)
    light=bpy.context.object
    light.name='Preview'+name
    light.data.energy=power
    light.data.shape='DISK'
    light.data.size=size
    light.rotation_euler=(Vector((0,0,.3))-light.location).to_track_quat('-Z','Y').to_euler()
scene.view_settings.view_transform='AgX'
scene.render.resolution_x=1500
scene.render.resolution_y=1000
scene.render.resolution_percentage=100

def preview(name,pos,target=(0,0,.42),scale=6.6):
    camera.location=pos
    camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.ortho_scale=scale
    scene.render.filepath=str(SOURCE/name)
    bpy.ops.render.render(write_still=True)

bpy.ops.object.select_all(action='DESELECT')
for obj in runtime:
    obj.select_set(True)
bpy.context.view_layer.objects.active=runtime[0]
camera.rotation_euler=(Vector((0,0,.42))-camera.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'open_wheel.blend'))
(SOURCE/'model_stats.json').write_text(json.dumps({'triangles':triangles,'mesh_objects':sum(o.type=='MESH' for o in runtime),
    'length_m':dims[1],'width_m':dims[0],'height_m':dims[2],'wheelbase_m':3.0,'units':'metres',
    'paint_uv':'LiveryUV','livery_resolution':2048,'paint_parts':len(painted),'diffuser_rise_m':.09},indent=2)+'\n')
preview('overview.png',(6.2,8.5,4.6))
preview('rear.png',(5,-8,3.2))
preview('side.png',(8,0,1.8),scale=6.1)
print('CAR BUILD PASSED: %d triangles; dimensions %s; 3 m wheelbase; %d UV-mapped paint parts.'%(triangles,dims,len(painted)))
