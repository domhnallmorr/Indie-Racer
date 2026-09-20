"""Bake position-projected vector-style paint into the existing GLB UV atlas.
Run with Python + numpy + Pillow. Does not change geometry or other liveries.
"""
from pathlib import Path
import json, struct, subprocess
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'content/vehicles/open_wheel/liveries'
SIZE = 2048
RED, YELLOW, BLACK, WHITE = (207, 20, 34), (255, 211, 0), (17, 20, 24), (245, 245, 237)
blob = (ROOT / 'content/vehicles/open_wheel/models/open_wheel.glb').read_bytes()
length = struct.unpack_from('<I', blob, 12)[0]
gltf = json.loads(blob[20:20+length])
binary = blob[28+length:]

def accessor(index):
    a = gltf['accessors'][index]
    v = gltf['bufferViews'][a['bufferView']]
    dtype = {5126:'<f4', 5125:'<u4', 5123:'<u2'}[a['componentType']]
    width = {'SCALAR':1, 'VEC2':2, 'VEC3':3}[a['type']]
    return np.ndarray((a['count'], width), dtype=dtype, buffer=binary,
                      offset=v.get('byteOffset', 0)+a.get('byteOffset', 0),
                      strides=(v.get('byteStride', np.dtype(dtype).itemsize*width), np.dtype(dtype).itemsize))

def lettering(text, colour=WHITE, bold=False, family='Arial'):
    # Windows GDI avoids a broken FreeType build on the project's Python runtime.
    target = ROOT / 'builds' / ('lettering_'+text.replace("'", '_')+'.png')
    target.parent.mkdir(exist_ok=True)
    script = f"""Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap 1800,240
$graphics = [System.Drawing.Graphics]::FromImage($bmp)
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$font = New-Object System.Drawing.Font '{family}',140,([System.Drawing.FontStyle]::{'Bold' if bold else 'Regular'}),([System.Drawing.GraphicsUnit]::Pixel)
$brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255,{colour[0]},{colour[1]},{colour[2]}))
$graphics.DrawString('{text.replace(chr(39), chr(39)*2)}',$font,$brush,0,0)
$bmp.Save('{str(target).replace(chr(39), chr(39)*2)}',[System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bmp.Dispose()
"""
    subprocess.run(['powershell','-NoProfile','-Command',script],check=True,capture_output=True)
    im=Image.open(target).convert('RGBA')
    return np.asarray(im.crop(im.getbbox()))


def bake(paint, filename):
    atlas = np.zeros((SIZE,SIZE,4), dtype=np.uint8)
    for node in gltf['nodes']:
        if 'mesh' not in node: continue
        for prim in gltf['meshes'][node['mesh']]['primitives']:
            if not gltf['materials'][prim['material']]['name'].startswith('Livery_'): continue
            pos = accessor(prim['attributes']['POSITION']) + np.array(node.get('translation',[0,0,0]))
            uv = accessor(prim['attributes']['TEXCOORD_0'])*SIZE
            indices = accessor(prim['indices']).reshape(-1,3)
            for ids in indices:
                pts, tex = pos[ids], uv[ids]
                lo=np.maximum(np.floor(tex.min(axis=0)).astype(int),0)
                hi=np.minimum(np.ceil(tex.max(axis=0)).astype(int),SIZE-1)
                a,b=tex[1]-tex[0],tex[2]-tex[0]
                det=a[0]*b[1]-a[1]*b[0]
                if abs(det)<1e-8: continue
                xx,yy=np.meshgrid(np.arange(lo[0],hi[0]+1),np.arange(lo[1],hi[1]+1))
                q=np.stack((xx+.5,yy+.5),axis=-1)-tex[0]
                s=(q[:,:,0]*b[1]-q[:,:,1]*b[0])/det
                t=(a[0]*q[:,:,1]-a[1]*q[:,:,0])/det
                mask=(s>=0)&(t>=0)&(s+t<=1)
                p=pts[0]+s[mask,None]*(pts[1]-pts[0])+t[mask,None]*(pts[2]-pts[0])
                n=np.cross(pts[1]-pts[0],pts[2]-pts[0]); n/=max(np.linalg.norm(n),1e-12)
                atlas[yy[mask],xx[mask],:3]=paint(p,n,node.get('name',''))
                atlas[yy[mask],xx[mask],3]=255
    # Extend colour into empty UV gutters for filtering, preserving all island pixels.
    for _ in range(8):
        old=atlas.copy()
        for dy,dx in ((0,1),(0,-1),(1,0),(-1,0)):
            shifted=np.roll(old,(dy,dx),(0,1))
            hit=(atlas[:,:,3]==0)&(shifted[:,:,3]>0)
            atlas[hit]=shifted[hit]
    atlas[atlas[:,:,3]==0]=(*BLACK,255)
    Image.fromarray(atlas).save(OUT/filename)
    print('Baked livery:', OUT/filename)
