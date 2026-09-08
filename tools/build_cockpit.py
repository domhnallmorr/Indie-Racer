"""Blender --background --python tools/build_cockpit.py. Metric interior only."""
import bpy
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system = 'METRIC'
bpy.context.scene.unit_settings.scale_length = 1

def mat(name, color):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color,1)
    m.use_nodes = True
    m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = (*color,1)
    m.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value = .8
    return m

carbon = mat('CockpitCharcoal',(.035,.04,.05))
metal = mat('PanelTrim',(.28,.30,.32))
red = mat('CockpitRed',(.68,.025,.025))
rubber = mat('WheelGrip',(.014,.016,.019))

def box(name, location, dims, material):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    o=bpy.context.object
    o.name=name
    o.dimensions=dims
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(material)

# +Y forward becomes Godot -Z. Recessed console faces driver along -Y.
box('InstrumentHousing',(0,.29,.59),(.49,.065,.265),carbon)
box('InstrumentTrim',(0,.251,.59),(.46,.012,.235),metal)
for side in [-1,1]:
    box('InnerTub',(side*.235,-.13,.39),(.035,.64,.27),carbon)
    box('CockpitLip',(side*.265,-.06,.59),(.035,.73,.035),red)
    box('MirrorHousing',(side*.39,.42,.68),(.255,.055,.125),red)
    box('MirrorBezel',(side*.39,.388,.68),(.238,.014,.108),carbon)
    box('MirrorSupport',(side*.33,.42,.60),(.20,.025,.025),metal)

# Small period steering wheel, below the instrument face.
bpy.ops.mesh.primitive_torus_add(major_segments=16,minor_segments=4,
    location=(0,-.035,.395),rotation=(1.5707963,0,0),major_radius=.145,minor_radius=.022)
bpy.context.object.name='SteeringRim'
bpy.context.object.data.materials.append(rubber)
box('SteeringSpoke',(0,-.034,.395),(.27,.026,.035),metal)
box('SteeringHub',(0,-.05,.395),(.075,.04,.065),carbon)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(ROOT/'content/vehicles/open_wheel/models/cockpit.glb'),export_format='GLB',use_selection=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'source_art/vehicles/open_wheel/cockpit.blend'))
