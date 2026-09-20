"""Donnie Beechler #84 Harrah's reference study on the shared UV atlas."""
from livery_baker import *
from PIL import ImageDraw

PURPLE=(32,18,91)
PEARL=(226,232,233)
GOLD=(240,194,20)
INK=(20,23,29)

def plate(text,fg,bg,family='Arial'):
    raw=Image.fromarray(lettering(text,fg,True,family))
    im=Image.new('RGBA',(raw.width+14,raw.height+12),(*bg,255));im.alpha_composite(raw,(7,6))
    return np.asarray(im)

def harrahs(colour):
    raw=Image.fromarray(lettering("Harrah's",colour,True))
    im=Image.new('RGBA',(raw.width+12,raw.height+30));im.alpha_composite(raw,(0,30))
    d=ImageDraw.Draw(im);x=raw.width-55
    d.polygon([(x,0),(x+6,13),(x+21,13),(x+9,22),(x+14,36),(x,27),(x-14,36),(x-9,22),(x-21,13),(x-6,13)],fill=colour)
    return np.asarray(im)

def badge():
    im=Image.new('RGBA',(190,150));d=ImageDraw.Draw(im)
    d.ellipse((6,6,184,144),fill=GOLD,outline=PEARL,width=5)
    im.alpha_composite(Image.fromarray(lettering('IRL',INK,True)).resize((100,50),Image.Resampling.LANCZOS),(45,50))
    return np.asarray(im)

logo=harrahs(PEARL);dark_logo=harrahs(PURPLE)
number=plate('84',INK,PEARL,'Impact')
# The red rectangular sponsor block is reconstructed from the small reference.
red_panel=plate('TRW',PEARL,(177,27,20),'Impact')
side=[(logo,.38,.30,1.18,.25),(dark_logo,.70,.755,.55,.095),
      (number,.39,.84,.23,.16),(red_panel,.97,.595,.29,.14),
      (badge(),-1.57,.255,.14,.085),
      (lettering('BOSCH',PEARL,True),1.38,.25,.20,.035)]

def overlay(c,art,u,v):
    hit=(u>=0)&(u<1)&(v>=0)&(v<1)
    rgba=art[(v[hit]*art.shape[0]).astype(int),(u[hit]*art.shape[1]).astype(int)]
    a=rgba[:,3:4]/255
    c[hit]=(rgba[:,:3]*a+c[hit]*(1-a)).astype(np.uint8)

def paint(p,normal,name):
    x,y,z=p.T
    c=np.tile(PURPLE,(len(p),1)).astype(np.uint8)
    if name=='RearWing': c[z<2.29]=PEARL
    elif 'Wing' not in name and 'Endplate' not in name:
        edge=.49+.035*np.clip(z,0,1.4)
        c[y>edge]=PEARL
        c[(z>.24)&(y>.86-.16*(z-.35))]=GOLD
        nose=z<-.72
        line=.14+.19*np.clip((z+2.275)/1.55,0,1)
        c[nose&(y>line)]=PEARL
        if name=='RollHoopFairing': c[:]=GOLD
    if abs(normal[0])>.65 and 'Wing' not in name:
        if 'RearEndplate' in name: decals=[(logo,2.30,.77,.32,.10)]
        elif 'FrontEndplate' in name: decals=[(logo,-2.035,.16,.26,.07)]
        else: decals=side
        for art,cz,cy,w,h in decals:
            overlay(c,art,(z-cz)/w*(-1 if normal[0]>0 else 1)+.5,.5-(y-cy)/h)
    if normal[1]>.45 and name=='Nose':
        overlay(c,number,x/.23+.5,(z+1.65)/.28+.5)
        overlay(c,dark_logo,x/.27+.5,(z+1.09)/.33+.5)
    return c

bake(paint,'donnie_beechler_2001.png')
