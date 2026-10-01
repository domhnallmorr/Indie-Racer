"""Jaques Lazier #99: yellow/red Sam Schmidt reference paint."""
from livery_baker import *
from PIL import ImageDraw
YELLOW=(255,211,19)
RED=(210,29,42)
BLACK=(22,20,23)
WHITE=(246,243,231)
def overlay(c,art,u,v):
    hit=(u>=0)&(u<1)&(v>=0)&(v<1)
    rgba=art[(v[hit]*art.shape[0]).astype(int),(u[hit]*art.shape[1]).astype(int)]
    a=rgba[:,3:4]/255
    c[hit]=(rgba[:,:3]*a+c[hit]*(1-a)).astype(np.uint8)
def plate():
    raw=Image.fromarray(lettering('99',BLACK,True,'Impact'))
    im=Image.new('RGBA',(raw.width+22,raw.height+16),(*WHITE,255))
    ImageDraw.Draw(im).rectangle((0,0,im.width-1,im.height-1),outline=BLACK,width=6)
    im.alpha_composite(raw,(11,8));return np.asarray(im)
number=plate()
side=[(number,.38,.70,.29,.22),
      (lettering('SPRINT PCS',BLACK,True),.96,.70,.60,.12),
      (lettering('Sam Schmidt',BLACK,True),.72,.85,.46,.045),
      (lettering('MOTORSPORTS',BLACK),.72,.807,.33,.03),
      (lettering('Firestone',WHITE,True,'Georgia'),-.06,.38,.51,.07),
      (lettering('JAQUES LAZIER',BLACK),-.02,.565,.24,.026),
      (lettering('Racing for a Reason',BLACK),-.17,.51,.37,.027)]
team=lettering('Sam Schmidt',YELLOW,True)
team_sub=lettering('Motorsports',BLACK,True)
engine=lettering('Oldsmobile',BLACK)
firehawk=lettering('FIREHAWK',BLACK,True)
rexx=lettering('REXHALL',BLACK,True)
def paint(p,normal,name):
    x,y,z=p.T
    c=np.tile(YELLOW,(len(p),1)).astype(np.uint8)
    if 'Endplate' in name:
        c[:]=RED
    elif 'Wing' not in name:
        edge=.435+.10*np.exp(-((z+.55)/.50)**2)
        c[y<edge]=RED
        c[abs(y-edge)<.013]=BLACK
        # Yellow nose tip and sides, broad red upper panel with black outline.
        if name=='Nose':
            nose=z<-.70
            c[nose]=YELLOW
            boundary=-1.78+.48*np.clip(abs(x)/.42,0,1)
            c[nose&(z>boundary)]=RED
            c[nose&(abs(z-boundary)<.035)]=BLACK
            c[(z>.24)&(z<.75)&(y>.88)]=RED
        if name=='RollHoopFairing':c[:]=RED
        if abs(normal[0])>.65:
            for art,cz,cy,w,h in side:
                overlay(c,art,(z-cz)/w*(-1 if normal[0]>0 else 1)+.5,.5-(y-cy)/h)
    if name=='Nose' and normal[1]>.45:
        overlay(c,number,x/.27+.5,(z+1.97)/.27+.5)
        overlay(c,team,x/.48+.5,(z+1.08)/.12+.5)
        overlay(c,team_sub,x/.38+.5,(z+1.23)/.075+.5)
        overlay(c,engine,x/.32+.5,(z+1.63)/.10+.5)
    if name=='RearWing' and normal[1]>.45:
        overlay(c,firehawk,x/.96+.5,(z-2.30)/.17+.5)
    if 'FrontEndplate' in name and abs(normal[0])>.65:
        overlay(c,rexx,(z+1.84)/.29*(-1 if normal[0]>0 else 1)+.5,.5-(y-.13)/.05)
    return c
bake(paint,'jaques_lazier_2001.png')
