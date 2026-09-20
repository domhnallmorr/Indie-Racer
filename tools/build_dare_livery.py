"""Airton Dare #88 Bar None reference livery on the existing UV atlas."""
from livery_baker import *
from PIL import ImageDraw

PURPLE=(43,9,60)
LIME=(198,241,0)
INK=(20,22,24)
WHITE=(237,238,226)

def barnone():
    im=Image.new('RGBA',(1100,340))
    im.alpha_composite(Image.fromarray(lettering('1-800-',LIME,True,'Impact')).resize((410,163),Image.Resampling.LANCZOS),(0,4))
    im.alpha_composite(Image.fromarray(lettering('BAR NONE',LIME,True,'Impact')).resize((790,220),Image.Resampling.LANCZOS),(302,114))
    return np.asarray(im)

def plate():
    raw=Image.fromarray(lettering('88',INK,True,'Arial'))
    im=Image.new('RGBA',(raw.width+16,raw.height+12),(*WHITE,255))
    im.alpha_composite(raw,(8,6));return np.asarray(im)

def infiniti():
    im=Image.new('RGBA',(400,210));d=ImageDraw.Draw(im)
    d.ellipse((97,10,303,114),outline=INK,width=11)
    d.line([(143,104),(200,37),(257,104)],fill=INK,width=11)
    im.alpha_composite(Image.fromarray(lettering('INFINITI',INK)).resize((375,40),Image.Resampling.LANCZOS),(12,147))
    return np.asarray(im)

logo=barnone();number=plate();brand=infiniti()
firehawk=lettering('FIREHAWK',INK,True)
side=[(logo,.37,.31,1.28,.29),(number,.39,.82,.23,.17),
      (brand,.75,.84,.28,.10),(firehawk,1.15,.535,.40,.058),
      (lettering('Airton Dare',INK,True,'Segoe Script'),.20,.67,.25,.042),
      (lettering('BAR NONE',INK,True),-.22,.56,.24,.035),
      (lettering('BOSCH',WHITE,True),1.35,.27,.20,.034)]

def overlay(c,art,u,v):
    hit=(u>=0)&(u<1)&(v>=0)&(v<1)
    rgba=art[(v[hit]*art.shape[0]).astype(int),(u[hit]*art.shape[1]).astype(int)]
    a=rgba[:,3:4]/255
    c[hit]=(rgba[:,:3]*a+c[hit]*(1-a)).astype(np.uint8)

def paint(p,normal,name):
    x,y,z=p.T
    c=np.tile(LIME,(len(p),1)).astype(np.uint8)
    if name=='FrontWing': c[:]=PURPLE
    elif name=='RearWing': c[z>2.23]=PURPLE
    elif 'RearEndplate' in name: pass
    elif 'FrontEndplate' in name: pass
    else:
        boundary=.49+.035*np.clip(z,0,1.5)
        c[y<boundary]=PURPLE
        c[(z< -1.38+.22*abs(x))]=PURPLE
        c[(z>1.45)&(y<.63)]=PURPLE
        if name=='RollHoopFairing' or 'Mirror' in name: c[:]=LIME
    if abs(normal[0])>.65 and 'Wing' not in name:
        if 'RearEndplate' in name:
            decals=[(speedway,2.30,.845,.32,.06),(firehawk,2.30,.755,.32,.055)]
        elif 'FrontEndplate' in name: decals=[(brand,-2.035,.16,.24,.07)]
        else: decals=side
        for art,cz,cy,w,h in decals:
            overlay(c,art,(z-cz)/w*(-1 if normal[0]>0 else 1)+.5,.5-(y-cy)/h)
    if normal[1]>.45:
        if name=='Nose':
            overlay(c,number,x/.24+.5,(z+1.70)/.28+.5)
            overlay(c,brand,x/.24+.5,(z+1.05)/.27+.5)
        if name=='FrontWing': overlay(c,logo,(abs(x)-.53)/.44+.5,(z+2.035)/.21+.5)
    return c

speedway=lettering('SPEEDWAY',INK,True)
bake(paint,'airton_dare_2001.png')
