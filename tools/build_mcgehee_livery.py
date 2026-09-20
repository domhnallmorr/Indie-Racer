"""Robbie McGehee #10: dark/blue/silver reference study on the shared atlas."""
from livery_baker import *
from PIL import ImageDraw

DARK=(12,20,19)
BLUE=(18,49,113)
SILVER=(178,193,200)
WHITE=(233,235,228)

def plate():
    raw=Image.fromarray(lettering('10',WHITE,True,'Impact'))
    im=Image.new('RGBA',(raw.width+16,raw.height+12),(*DARK,255))
    im.alpha_composite(raw,(8,6));return np.asarray(im)

def fram():
    im=Image.new('RGBA',(480,140));d=ImageDraw.Draw(im)
    d.rectangle((3,4,477,136),fill=(174,32,35),outline=WHITE,width=5)
    raw=Image.fromarray(lettering('FRAM',WHITE,True)).resize((435,102),Image.Resampling.LANCZOS)
    im.alpha_composite(raw,(22,19));return np.asarray(im)

def badge():
    im=Image.new('RGBA',(180,110));d=ImageDraw.Draw(im)
    d.ellipse((5,5,175,105),fill=(225,195,24))
    raw=Image.fromarray(lettering('IRL',DARK,True)).resize((84,42),Image.Resampling.LANCZOS)
    im.alpha_composite(raw,(48,34));return np.asarray(im)

number=plate()
side=[(number,.33,.61,.25,.15),(fram(),.87,.80,.39,.077),
      (badge(),1.24,.54,.13,.075),
      (lettering('Firestone',WHITE,True),-.10,.50,.28,.035),
      (lettering('ROBBIE McGEHEE',WHITE),.26,.50,.34,.025),
      (lettering('BOSCH',WHITE,True),1.34,.28,.19,.035)]

def overlay(c,art,u,v):
    hit=(u>=0)&(u<1)&(v>=0)&(v<1)
    rgba=art[(v[hit]*art.shape[0]).astype(int),(u[hit]*art.shape[1]).astype(int)]
    a=rgba[:,3:4]/255
    c[hit]=(rgba[:,:3]*a+c[hit]*(1-a)).astype(np.uint8)

def paint(p,normal,name):
    x,y,z=p.T
    c=np.tile(DARK,(len(p),1)).astype(np.uint8)
    if 'RearWing' in name or 'RearEndplate' in name: c[:]=SILVER
    elif 'FrontWing' in name or 'FrontEndplate' in name: pass
    else:
        # Blue lower sill sweeps up at the front of the sidepod.
        edge=.16+.12*np.clip((.12-z)/.70,0,1)
        c[(z>-.78)&(z<1.45)&(y<edge)]=BLUE
        c[y<.075]=DARK
        c[(z>1.35)&(y>.43)]=SILVER
    if abs(normal[0])>.65 and 'Wing' not in name and 'Endplate' not in name:
        for art,cz,cy,w,h in side:
            overlay(c,art,(z-cz)/w*(-1 if normal[0]>0 else 1)+.5,.5-(y-cy)/h)
    if normal[1]>.45 and name=='Nose':
        overlay(c,number,x/.23+.5,(z+1.66)/.28+.5)
    return c

bake(paint,'robbie_mcgehee_2001.png')
