"""Al Unser Jr. #3 Starz reference livery on the existing UV atlas."""
from livery_baker import *
from PIL import ImageDraw

PEARL=(231,235,233)
INK=(13,16,20)
RED=(177,23,26)

def slanted(text,colour,family='Arial'):
    im=Image.fromarray(lettering(text,colour,True,family))
    pad=int(im.height*.18)
    return im.transform((im.width+pad,im.height),Image.Transform.AFFINE,
                        (1,.18,-pad,0,1,0),Image.Resampling.BICUBIC)

def starz():
    im=Image.new('RGBA',(980,320));d=ImageDraw.Draw(im)
    # Tilted film-frame emblem beside the lowercase wordmark.
    d.polygon([(18,103),(75,67),(117,128),(60,163)],fill=INK)
    for x,y in [(22,99),(32,117),(41,136),(77,73),(89,91),(100,109)]:
        d.rectangle((x,y,x+6,y+8),fill=PEARL)
    im.alpha_composite(slanted('starz',INK,'Arial Black').resize((840,225),Image.Resampling.LANCZOS),(130,0))
    im.alpha_composite(slanted('SUPER PAK.',RED).resize((590,62),Image.Resampling.LANCZOS),(295,240))
    return np.asarray(im)

def panel(text,colour,bg,family='Arial'):
    raw=Image.fromarray(lettering(text,colour,True,family))
    im=Image.new('RGBA',(raw.width+16,raw.height+12),(*bg,255))
    im.alpha_composite(raw,(8,6));return np.asarray(im)

logo=starz()
number=panel('3',INK,PEARL,'Impact')
bud=lettering('Budweiser',RED,True,'Segoe Script')
tv=panel('TV',PEARL,RED)
auto=lettering('auto bliss',RED,True)
auto_white=lettering('auto bliss',PEARL,True)
side=[(logo,.37,.31,1.24,.28),(bud,.85,.735,.70,.10),
      (number,.36,.835,.17,.19),(tv,.58,.835,.105,.10),
      (auto_white,.88,.855,.30,.06),
      (auto,-.02,.565,.22,.069),
      (lettering('FIREHAWK',INK,True),.28,.56,.28,.043),
      (lettering('BOSCH',INK,True),1.34,.32,.20,.05),
      (lettering('Mobil 1',INK,True),1.34,.25,.22,.045),
      (lettering('G RACING',INK,True),-1.51,.28,.32,.052)]

def overlay(c,art,u,v):
    hit=(u>=0)&(u<1)&(v>=0)&(v<1)
    rgba=art[(v[hit]*art.shape[0]).astype(int),(u[hit]*art.shape[1]).astype(int)]
    a=rgba[:,3:4]/255
    c[hit]=(rgba[:,:3]*a+c[hit]*(1-a)).astype(np.uint8)

def paint(p,normal,name):
    x,y,z=p.T
    c=np.tile(PEARL,(len(p),1)).astype(np.uint8)
    if 'Wing' in name or 'Endplate' in name:
        if name=='FrontWing': c[z>-2.04]=RED
    else:
        # Black shoulder deck above the white sponsor panel, separated by red piping.
        edge=.47+.025*np.clip(z,0,1.4)
        c[(y>edge)&(y<edge+.045)]=INK
        c[(y>edge+.045)&(y<edge+.060)]=RED
        c[y<.085]=INK
        cap=-1.79+.16*abs(x)
        c[z<cap]=INK
        c[(z>=cap)&(z<cap+.025)]=RED
        # White engine-cover flank beneath a black upper spine.
        roof=.84-.155*(z-.35)
        c[(z>.22)&(y>roof)]=INK
        c[(z>.48)&(y>roof-.015)&(y<=roof)]=RED
        c[(z<-.60)&(z>-1.12)&(abs(x)<.14)&(y>.40)]=INK
        if name=='RollHoopFairing': c[:]=INK
        if 'Mirror' in name: c[:]=RED
    if abs(normal[0])>.65 and 'Wing' not in name:
        if 'RearEndplate' in name:
            decals=[(logo,2.30,.83,.33,.11),(bud,2.30,.70,.25,.06)]
        elif 'FrontEndplate' in name: decals=[(logo,-2.035,.17,.26,.07)]
        else: decals=side
        for art,cz,cy,w,h in decals:
            overlay(c,art,(z-cz)/w*(-1 if normal[0]>0 else 1)+.5,.5-(y-cy)/h)
    if normal[1]>.45:
        if name=='Nose': overlay(c,number,x/.18+.5,(z+1.48)/.28+.5)
        if name=='FrontWing': overlay(c,bud,(abs(x)-.53)/.42+.5,(z+2.035)/.17+.5)
    return c

bake(paint,'al_unser_jr_2001.png')
