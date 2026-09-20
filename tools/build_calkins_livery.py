"""Buzz Calkins #12 Bradley/Sav-O-Mat livery from the supplied reference."""
from livery_baker import *
from PIL import ImageDraw

SCARLET=(215,16,35)
WHITE=(240,242,237)
INK=(22,20,25)

def plate():
    raw=Image.fromarray(lettering('12',INK,True,'Impact'))
    im=Image.new('RGBA',(raw.width+14,raw.height+10),(*WHITE,255))
    im.alpha_composite(raw,(7,5));return np.asarray(im)

def contingency():
    im=Image.new('RGBA',(200,170));d=ImageDraw.Draw(im)
    d.ellipse((8,8,192,162),fill=(238,204,20),outline=WHITE,width=5)
    art=Image.fromarray(lettering('IRL',INK,True)).resize((105,65),Image.Resampling.LANCZOS)
    im.alpha_composite(art,(48,51));return np.asarray(im)

number=plate()
bradley=lettering('Bradley',WHITE,True,'Arial')
savomat=lettering('Sav-O-Mat',WHITE,True,'Segoe Script')
sinclair=lettering('Sinclair',WHITE,True,'Arial')
firestone=lettering('Firestone',WHITE,True)
side=[(bradley,.37,.325,1.05,.255),
      (savomat,.82,.665,.82,.115),(sinclair,.80,.80,.44,.085),
      (number,.40,.82,.20,.16),
      (lettering('Oldsmobile',WHITE),.54,.915,.26,.035),
      (firestone,.36,.733,.21,.029),
      (contingency(),1.23,.46,.12,.095),
      (lettering('BOSCH',WHITE,True),1.30,.29,.17,.032),
      (lettering('BUZZ CALKINS',WHITE,True),-.36,.52,.27,.027)]

def overlay(c,art,u,v):
    hit=(u>=0)&(u<1)&(v>=0)&(v<1)
    rgba=art[(v[hit]*art.shape[0]).astype(int),(u[hit]*art.shape[1]).astype(int)]
    a=rgba[:,3:4]/255
    c[hit]=(rgba[:,:3]*a+c[hit]*(1-a)).astype(np.uint8)

def paint(p,normal,name):
    x,y,z=p.T
    c=np.tile(SCARLET,(len(p),1)).astype(np.uint8)
    # Fine dark sill and the exposed trailing edge of the otherwise red wings.
    c[y<.075]=INK
    if name=='RearWing': c[z>2.455]=INK
    if abs(normal[0])>.65 and 'Wing' not in name:
        if 'RearEndplate' in name: decals=[(firestone,2.30,.69,.30,.050)]
        elif 'FrontEndplate' in name: decals=[]
        else: decals=side
        for art,cz,cy,w,h in decals:
            overlay(c,art,(z-cz)/w*(-1 if normal[0]>0 else 1)+.5,.5-(y-cy)/h)
    if normal[1]>.45 and name=='Nose':
        overlay(c,number,x/.23+.5,(z+1.72)/.28+.5)
        overlay(c,bradley,x/.25+.5,(z+1.13)/.33+.5)
    return c

bake(paint,'buzz_calkins_2001.png')
