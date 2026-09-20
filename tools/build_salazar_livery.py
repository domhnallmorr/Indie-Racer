"""Eliseo Salazar #14 Harrah's: reference-inspired UV paint, no mesh changes."""
from livery_baker import *
from PIL import ImageDraw
import math

PURPLE=(60,12,157)
WHITE=(238,240,235)
YELLOW=(246,219,0)
INK=(17,20,24)

def star_image():
    im=Image.new('RGBA',(220,220))
    pts=[]
    for i in range(10):
        angle=-math.pi/2+i*math.pi/5
        radius=105 if i%2==0 else 43
        pts.append((110+radius*math.cos(angle),110+radius*math.sin(angle)))
    ImageDraw.Draw(im).polygon(pts,fill=WHITE)
    return np.asarray(im)

star=star_image()
def harrahs(colour):
    raw=Image.fromarray(lettering("Harrah's",colour,True))
    im=Image.new('RGBA',(raw.width+15,raw.height+40))
    im.alpha_composite(raw,(0,40))
    badge=Image.fromarray(star).resize((55,55),Image.Resampling.LANCZOS)
    if colour!=WHITE:
        tinted=Image.new('RGBA',badge.size,(*colour,255));tinted.putalpha(badge.getchannel('A'));badge=tinted
    im.alpha_composite(badge,(raw.width-90,0))
    return np.asarray(im)

def panel(text,colour,bg,family='Arial',bold=False):
    raw=Image.fromarray(lettering(text,colour,bold,family))
    im=Image.new('RGBA',(raw.width+18,raw.height+14),(*bg,255));im.alpha_composite(raw,(9,7))
    return np.asarray(im)

logo=harrahs(WHITE)
purple_logo=harrahs(PURPLE)
cristal=panel('CRISTAL',INK,YELLOW,'Georgia')
number=panel('14',INK,WHITE,'Arial',True)
side=[(logo,.38,.295,1.22,.235),(purple_logo,.82,.745,.62,.13),
      (cristal,1.05,.57,.42,.093),(number,.28,.565,.29,.17),
      (lettering('FIREHAWK',WHITE,True),1.23,.47,.28,.045),
      (lettering('SIMPSON',WHITE,True),1.39,.23,.27,.046)]

def overlay(c,art,u,v):
    hit=(u>=0)&(u<1)&(v>=0)&(v<1)
    rgba=art[(v[hit]*art.shape[0]).astype(int),(u[hit]*art.shape[1]).astype(int)]
    a=rgba[:,3:4]/255
    c[hit]=(rgba[:,:3]*a+c[hit]*(1-a)).astype(np.uint8)

def paint(p,normal,name):
    x,y,z=p.T
    c=np.tile(WHITE,(len(p),1)).astype(np.uint8)
    if 'Wing' in name or 'Endplate' in name:
        c[:]=PURPLE
        if name=='RearWing': c[z<2.26]=YELLOW
        if name=='FrontWing': c[z>-2.00]=YELLOW
    else:
        c[y<.49]=PURPLE
        # The nose stays white; purple shoulder decks carry the star field.
        c[z<-.75]=WHITE
        c[(abs(x)>.30)&(z>-.72)&(y>.46)&(y<.63)]=PURPLE
        c[(z>.25)&(y>.93-.225*(z-.3))]=YELLOW
        c[(z< -2.05)]=YELLOW
        if name=='RollHoopFairing' or 'Mirror' in name: c[:]=YELLOW
    if abs(normal[0])>.65 and 'Wing' not in name:
        if 'Endplate' in name:
            cz=2.30 if 'Rear' in name else -2.035
            cy=.79 if 'Rear' in name else .19
            decals=[(logo,cz,cy,.31,.09),(cristal,cz,cy-.085,.22,.045)]
        else: decals=side
        for art,cz,cy,w,h in decals:
            overlay(c,art,(z-cz)/w*(-1 if normal[0]>0 else 1)+.5,.5-(y-cy)/h)
    if normal[1]>.40:
        if name=='Nose':
            overlay(c,number,x/.24+.5,(z+1.58)/.29+.5)
            overlay(c,purple_logo,x/.27+.5,(z+.98)/.27+.5)
            for cz,cx,size in [(-.45,.45,.14),(-.22,.51,.16),(.06,.55,.20),(.36,.58,.13),(.66,.59,.12),(.9,.57,.085)]:
                overlay(c,star,(abs(x)-cx)/size+.5,(z-cz)/size+.5)
        if name=='RearWing': overlay(c,purple_logo,x/.84+.5,(z-2.20)/.12+.5)
        if name=='FrontWing': overlay(c,logo,(abs(x)-.53)/.43+.5,(z+2.08)/.15+.5)
    return c

bake(paint,'eliseo_salazar_2001.png')
