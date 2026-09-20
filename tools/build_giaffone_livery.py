"""Felipe Giaffone #21 Hollywood reference artwork on the shared car atlas."""
from livery_baker import *
from PIL import ImageDraw

NAVY=(19,20,52)
CORAL=(255,45,68)
GREEN=(0,116,77)
WHITE=(236,237,234)

def number_art():
    raw=Image.fromarray(lettering('21',WHITE,True,'Impact'))
    im=Image.new('RGBA',(raw.width+12,raw.height+12),(*NAVY,255))
    im.alpha_composite(raw,(6,6));return np.asarray(im)

def badge():
    im=Image.new('RGBA',(180,180));d=ImageDraw.Draw(im)
    d.ellipse((8,8,172,172),fill=WHITE,outline=NAVY,width=6)
    art=Image.fromarray(lettering('IRL',NAVY,True)).resize((115,60),Image.Resampling.LANCZOS)
    im.alpha_composite(art,(33,60));return np.asarray(im)

hollywood=lettering('HOLLYWOOD',WHITE,True,'Arial')
number=number_art()
side=[(hollywood,.37,.325,1.20,.165),
      (hollywood,.38,.65,.45,.060),(number,.37,.845,.22,.17),
      (badge(),.17,.85,.083,.083),
      (lettering('FIREHAWK',NAVY,True),1.10,.61,.49,.07),
      (lettering('Firestone',WHITE,True),.41,.725,.27,.038),
      (lettering('Hollywood',WHITE,True,'Segoe Script'),-1.48,.27,.30,.065),
      (lettering('PPG',NAVY,True),1.43,.20,.18,.06)]

def overlay(c,art,u,v):
    hit=(u>=0)&(u<1)&(v>=0)&(v<1)
    rgba=art[(v[hit]*art.shape[0]).astype(int),(u[hit]*art.shape[1]).astype(int)]
    a=rgba[:,3:4]/255
    c[hit]=(rgba[:,:3]*a+c[hit]*(1-a)).astype(np.uint8)

def zigzag(t,period):
    return 1-4*abs((t/period)%1-.5)

def paint(p,normal,name):
    x,y,z=p.T
    c=np.tile(NAVY,(len(p),1)).astype(np.uint8)
    if 'Wing' in name:
        if name=='RearWing': c[z<2.19]=CORAL
    elif 'RearEndplate' in name: c[:]=CORAL
    elif 'FrontEndplate' in name:
        c[(z> -2.04+.035*zigzag(y,.095))]=GREEN
    else:
        # Navy sidepod panel and fin, fluorescent coral rear body and lower sill.
        rear_edge=1.00+.10*zigzag(y,.28)
        c[z>rear_edge]=CORAL
        c[y<.095]=CORAL
        # A red dorsal wedge falls forward from the back of the engine cover.
        c[(z>.62)&(y>.84-.40*(z-.62))]=CORAL
        # Alternating angular green/red shapes run down the nose on both sides.
        if name=='Nose':
            nose=z<-.76
            c[nose]=GREEN
            cap=-1.82+.14*zigzag(abs(x)+y*.35,.22)
            c[nose&(z<cap)]=CORAL
            trim=-1.06+.10*zigzag(y+abs(x)*.30,.145)
            c[nose&(z>trim)]=CORAL
            c[nose&(z>trim+.035)]=NAVY
            # Narrow navy edging makes the lightning-shaped divisions legible.
            c[nose&(z>cap)&(z<cap+.032)]=NAVY
    if abs(normal[0])>.65 and 'Wing' not in name:
        if 'RearEndplate' in name:
            decals=[(letter_firehawk,2.30,.88,.31,.047),(number,2.30,.77,.17,.13)]
        elif 'FrontEndplate' in name: decals=[(hollywood,-2.035,.17,.25,.047)]
        else: decals=side
        for art,cz,cy,w,h in decals:
            overlay(c,art,(z-cz)/w*(-1 if normal[0]>0 else 1)+.5,.5-(y-cy)/h)
    if normal[1]>.45 and name=='Nose':
        overlay(c,number,x/.23+.5,(z+1.80)/.29+.5)
    return c

letter_firehawk=lettering('FIREHAWK',NAVY,True)
bake(paint,'felipe_giaffone_2001.png')
