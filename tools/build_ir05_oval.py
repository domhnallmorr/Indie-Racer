"""Adapt ccjr's Dallara IR-05 STL to oval trim. See source_art/vehicles/dallara_ir05/ATTRIBUTION.md.
Keeps the source body silhouette; replaces road-course wings and coarse wheels.
Run with Blender --background --python tools/build_ir05_oval.py.
"""
from pathlib import Path
import bpy, math, json, bmesh
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
# Reuse the project's material/mesh primitives, not its rejected generic body.
shared=(ROOT/'tools/build_open_wheel.py').read_text()
exec(compile(shared.split('# A narrow low nose')[0],str(ROOT/'tools/build_open_wheel.py'),'exec'))
SOURCE=ROOT/'source_art/vehicles/dallara_ir05'
PAINT.diffuse_color=(.38,.018,.026,1)
PAINT.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=PAINT.diffuse_color
PAINT.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.4
PAINT.node_tree.nodes['Principled BSDF'].inputs['Metallic'].default_value=.03
bpy.ops.wm.stl_import(filepath=str(SOURCE/'Dallara_IR05_original.stl'))
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.separate(type='LOOSE')
bpy.ops.object.mode_set(mode='OBJECT')
parts=sorted(bpy.context.selected_objects,key=lambda o:len(o.data.vertices),reverse=True)
assert len(parts)==104,'Source STL changed; re-audit part classification'
# Raw source points forwards along -Y. Use wheel centres for the longitudinal scale.
FRONT_RAW=(-62.085-34.682-61.972-34.569)/4
REAR_RAW=(56.176+83.579+56.289+83.692)/4
SY=3/(REAR_RAW-FRONT_RAW)
SX=2/88.23873901367188
SZ=5/198.39999389648438
NOSE_RAW=-97.883

def point(v):
    return Vector((v[0]*SX,2.5-(v[1]-NOSE_RAW)*SY,v[2]*SZ))

front_y=point((0,FRONT_RAW,0)).y
rear_y=point((0,REAR_RAW,0)).y
NOSE_SHORTEN_M=.225
# Explicit mapping is tied to the archived source file, sorted by component size.
road_wings={3,4,11,12,16,21,22,23,24,27,28,29,38,39,66,67}
old_wheels={5,6,7,8,34,35,36,37,41,42,43,44,50,51,52,53,55,56,57,58}
paint_ids={1,15,40,45,46,47,61}
helmet_ids={0,14}
driver_ids={9,10,49}
dash_ids={2,19,20,54,65,69,70,73,74,*range(78,97),98,99,102,103}
mirror_ids={40,46,68,100,101}
body=None
for i,obj in enumerate(parts):
    if i in road_wings or i in old_wheels:
        bpy.data.objects.remove(obj,do_unlink=True)
        continue
    for v in obj.data.vertices:
        v.co=point(v.co)
        # Compress only the body ahead of the front axle; keep chassis and suspension fixed.
        if i==1 and v.co.y>front_y:
            v.co.y-=NOSE_SHORTEN_M*(v.co.y-front_y)/(2.5-front_y)
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.000001)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data);bm.free();obj.data.update()
    mat=PAINT if i in paint_ids else CARBON
    name='SourceDetail_%03d'%i
    if i==1: name='Nose';body=obj
    elif i==15: name='RollHoopFairing'
    elif i in helmet_ids: name='DriverHelmet' if i==0 else 'HelmetVisor';mat=HELMET if i==0 else VISOR
    elif i in driver_ids: name='DriverSuit_%03d'%i;mat=SUIT
    elif i in dash_ids: name='SteeringWheelDashboard_%03d'%i;mat=CARBON
    elif i in mirror_ids: name='Mirror_%03d'%i;mat=VISOR if i in {100,101} else PAINT
    elif i==13: name='CockpitLining';mat=DARK
    elif i==61: name='RearGearboxCover'
    elif i in {45,47}:name='SidepodExit_%03d'%i
    obj.name=name
    finish(obj,mat,True)
    # Split only strong creases; do not subdivide or shrink the source silhouette.
    bpy.context.view_layer.objects.active=obj
    modifier=obj.modifiers.new('Preserve hard creases','EDGE_SPLIT')
    modifier.split_angle=math.radians(48)
    modifier.use_edge_angle=True
    bpy.ops.object.modifier_apply(modifier=modifier.name)

# Carbon floor and underside are distinct from paint, without altering the mesh.
body.data.materials.append(CARBON)
for face in body.data.polygons:
    if face.center.z < .135 and abs(face.center.x) > .27:
        face.material_index=1

# Reuse the existing high-resolution, hub-centred wheels, fitted to the source track.
wheel_code=shared.split('# Rounded slick shoulder profile, recessed twelve-spoke magnesium rims and brakes.')[1].split('# One globally packed UV atlas')[0]
# Each new wheel preserves the source hub position; front track is narrower than rear.
wheel_code=wheel_code.replace("('Front',1.5,.325,.30,.845),('Rear',-1.5,.35,.39,.805)","('Front',front_y,.327,.348,.715),('Rear',rear_y,.327,.348,.823)")
# Suspension already exists in the STL; only generate wheel and rim geometry.
wheel_code=wheel_code.split('        for height in')[0]
exec(compile(wheel_code,'<shared wheel geometry>','exec'))

# Thin low-incidence airfoil with rounded leading edge and sharp trailing edge.
def oval_wing(name,span,center_y,height,chord):
    profile=[(0,0),(.035,.009),(.10,.014),(.25,.015),(.50,.010),(.78,.002),(1,-.008),
             (1,-.012),(.78,-.010),(.50,-.009),(.25,-.006),(.10,-.005),(.035,-.003)]
    n=len(profile)
    verts=[(x,center_y+chord*(.5-t),height+z) for x in [-span/2,span/2] for t,z in profile]
    return mesh(name,verts,[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],WHITE,True)

oval_wing('FrontWing',1.62,2.26-NOSE_SHORTEN_M,.143,.32)
oval_wing('RearWing',1.08,-2.30,.83,.36)
for side,label in [(-1,'Left'),(1,'Right')]:
    box('FrontEndplate'+label,(side*.81,2.26-NOSE_SHORTEN_M,.17),(.014,.36,.16),PAINT,.004)
    box('RearEndplate'+label,(side*.547,-2.30,.79),(.014,.40,.25),PAINT,.005)
    box('FrontWingPylon'+label,(side*.06,2.22-NOSE_SHORTEN_M,.19),(.021,.11,.105),CARBON,.003)
    box('RearWingStay'+label,(side*.16,-2.19,.565),(.025,.105,.53),CARBON,.005)

# Preserve the original body's complete bounds and topology in the build report.
body_vertices=len(body.data.vertices)
body_triangles=len(body.data.polygons)
# Shared livery atlas, export and studio rig. No use of the generic body construction.
tail=shared.split('# One globally packed UV atlas')[1]
tail='# One globally packed UV atlas'+tail
tail=tail.replace("assert abs(dims[1]-5.0)<.015,dims","assert abs(dims[1]-(5.0-NOSE_SHORTEN_M))<.015,dims")
# Imported parts lack a source shader multiply node; this section creates it as usual.
tail=tail.replace("assert abs(dims[0]-2.0)<.015,dims","assert abs(dims[0]-2.0)<.015,dims")
tail=tail.replace("assert abs(bpy.data.objects['WheelFrontLeft'].location.y-bpy.data.objects['WheelRearLeft'].location.y-3.0)<1e-6","assert abs(bpy.data.objects['WheelFrontLeft'].location.y-bpy.data.objects['WheelRearLeft'].location.y-3.0)<1e-6")
# Header helper used to assemble source-based geometry; source archive remains untouched.
tail=tail.replace("'diffuser_rise_m':.09","'source':'ccjr / Dallara IR-05 / Cults3D 346481','body_source_vertices':body_vertices,'body_source_triangles':body_triangles,'front_wing_span_m':1.62,'front_wing_chord_m':.32,'rear_wing_span_m':1.08,'rear_wing_chord_m':.36")
# Save working model separately from the rejected generic model.
tail=tail.replace("SOURCE/'open_wheel.blend'","SOURCE/'ir05_oval.blend'")
tail=tail.replace("'wheelbase_m':3.0","'wheelbase_m':3.0,'nose_shortened_m':NOSE_SHORTEN_M,'nose_overhang_m':2.5-NOSE_SHORTEN_M-front_y")
exec(compile(tail,'<shared UV export and preview>','exec'))
# Neutral review images let the source silhouette and wing changes speak for themselves.
scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.light='STUDIO'
scene.display.shading.color_type='SINGLE'
scene.display.shading.single_color=(.48,.50,.53)
scene.display.shading.show_cavity=True
scene.display.shading.show_shadows=True
scene.display.shading.show_specular_highlight=False
preview('oval_grey.png',(6.2,8.5,4.6))
preview('oval_grey_side.png',(8,0,1.1),scale=6.1)
