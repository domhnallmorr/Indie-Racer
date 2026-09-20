"""Shigeaki Hattori #55 Epson reference paint on the shared car UV atlas."""
from livery_baker import *

BLUE=(20,39,115)
WHITE=(227,235,237)
INK=(20,26,35)

def plate():
    raw=Image.fromarray(lettering('55',WHITE,True,'Impact'))
    im=Image.new('RGBA',(raw.width+10,raw.height+10),(*BLUE,255))
    im.alpha_composite(raw,(5,5));return np.asarray(im)

logo=lettering('EPSON',WHITE,True)
number=plate()
nose_number=lettering('55',INK,True,'Impact')
side=[(logo,.38,.32,1.10,.24),
      (lettering('IBARAKI TOYOPET',BLUE,True,'Georgia'),.77,.61,.79,.09),
      (lettering('BELL MARE',INK),.65,.755,.48,.05),
      (number,.38,.84,.24,.16),
      (lettering('TOYO',WHITE,True),.68,.872,.24,.047),
      (lettering('www.epson.com',INK),.45,.125,.89,.034),
      (lettering('Shigeaki Hattori',INK),-.31,.545,.33,.029)]

def overlay(c,art,u,v):
    hit=(u>=0)&(u<1)&(v>=0)&(v<1)
    rgba=art[(v[hit]*art.shape[0]).astype(int),(u[hit]*art.shape[1]).astype(int)]
    a=rgba[:,3:4]/255
    c[hit]=(rgba[:,:3]*a+c[hit]*(1-a)).astype(np.uint8)

def paint(p,normal,name):
    x,y,z=p.T
    c=np.tile(BLUE,(len(p),1)).astype(np.uint8)
    if 'Wing' not in name and 'Endplate' not in name:
        # White shoulder and silver-white upper body; navy cap above the intake.
        edge=.475+.025*np.clip(z,0,1.5)
        c[y>edge]=WHITE
        c[y<.15]=WHITE
        c[y<.08]=INK
        cap=.865-.16*(z-.35)
        c[(z>.24)&(y>cap)]=BLUE
        if name=='Nose':
            nose=z<-.70
            c[nose]=BLUE
            # Broad white stripe flows from the nose tip up onto the upper body.
            center=.13+.25*np.clip((z+2.275)/1.575,0,1)
            c[nose&(abs(y-center)<.045)]=WHITE
            c[nose&(abs(x)<.125)&(y>center)]=WHITE
        if name=='RollHoopFairing': c[:]=BLUE
    if abs(normal[0])>.65 and 'Wing' not in name and 'Endplate' not in name:
        for art,cz,cy,w,h in side:
            overlay(c,art,(z-cz)/w*(-1 if normal[0]>0 else 1)+.5,.5-(y-cy)/h)
    if normal[1]>.45 and name=='Nose':
        overlay(c,nose_number,x/.21+.5,(z+1.67)/.28+.5)
    return c

bake(paint,'shigeaki_hattori_2001.png')
