"""Greg Ray #2 Johns Manville reference livery on the shared UV atlas."""
from livery_baker import *
from PIL import ImageDraw
BLUE=(15,20,65)
WHITE=(240,241,235)
YELLOW=(255,220,20)
ORANGE=(255,122,20)
RED=(225,35,42)

def overlay(c,art,u,v):
    hit=(u>=0)&(u<1)&(v>=0)&(v<1)
    rgba=art[(v[hit]*art.shape[0]).astype(int),(u[hit]*art.shape[1]).astype(int)]
    a=rgba[:,3:4]/255
    c[hit]=(rgba[:,:3]*a+c[hit]*(1-a)).astype(np.uint8)

def jm():
    im=Image.new('RGBA',(950,300))
    im.alpha_composite(Image.fromarray(lettering('JM',WHITE,True,'Impact')).resize((355,265)),(0,18))
    for word,y in [('Johns',8),('Manville',155)]:
        im.alpha_composite(Image.fromarray(lettering(word,WHITE,True)).resize((570,130)),(380,y))
    return np.asarray(im)

def stanley():
    im=Image.new('RGBA',(440,125),(*YELLOW,255))
    im.alpha_composite(Image.fromarray(lettering('STANLEY',BLUE,True)).resize((410,105)),(15,10))
    return np.asarray(im)

number=lettering('2',WHITE,True,'Impact')
side=[(jm(),.43,.31,1.11,.235),(number,.38,.86,.18,.19),
      (lettering('MENARDS',WHITE,True),.93,.77,.51,.085),
      (lettering('FIRESTONE',WHITE,True),.93,.59,.42,.038),
      (lettering('GREG RAY',WHITE),-.12,.55,.32,.029),
      (lettering('DURACELL',WHITE,True),-1.14,.255,.38,.055),
      (stanley(),-.65,.29,.30,.10),
      (lettering('BOSCH',WHITE,True),1.34,.27,.16,.035)]
quaker=lettering('QUAKER STATE',WHITE,True)
menards=lettering('MENARDS',YELLOW,True)

def paint(p,normal,name):
    x,y,z=p.T
    c=np.tile(BLUE,(len(p),1)).astype(np.uint8)
    body='Wing' not in name and 'Endplate' not in name
    if body:
        edge=.12+.46*np.clip((z+2.25)/1.70,0,1)
        c[(y>edge-.030)&(y<edge+.006)]=RED
        c[(y>=edge+.006)&(y<edge+.033)]=ORANGE
        c[(y>=edge+.033)&(y<edge+.059)]=YELLOW
        if abs(normal[0])>.65:
            for art,cz,cy,w,h in side:
                overlay(c,art,(z-cz)/w*(-1 if normal[0]>0 else 1)+.5,.5-(y-cy)/h)
    if normal[1]>.45 and name=='Nose':
        overlay(c,number,x/.22+.5,(z+1.46)/.29+.5)
        overlay(c,menards,x/.28+.5,(z+1.88)/.13+.5)
        overlay(c,quaker,x/.27+.5,(z+1.13)/.12+.5)
    if 'RearEndplate' in name and abs(normal[0])>.65:
        overlay(c,quaker,(z-1.93)/.38*(-1 if normal[0]>0 else 1)+.5,.5-(y-.79)/.075)
    if 'FrontEndplate' in name and abs(normal[0])>.65:
        overlay(c,quaker,(z+1.84)/.28*(-1 if normal[0]>0 else 1)+.5,.5-(y-.12)/.035)
    if name=='RearWing' and normal[1]>.45:
        overlay(c,letter_rear,x/.86+.5,(z-1.92)/.25+.5)
    return c

letter_rear=lettering('JM',WHITE,True,'Impact')
bake(paint,'greg_ray_2001.png')
