"""Billy Boat #98 CURB Records reference livery on the existing car atlas."""
from livery_baker import *
from PIL import ImageDraw

BLUE=(17,39,94)
PEARL=(230,235,237)
ACCENT=(178,24,42)

def slanted(text, family='Arial'):
    raw=Image.fromarray(lettering(text,PEARL,True,family))
    # Forward-leaning block lettering, like the reference CURB wordmark.
    pad=int(raw.height*.22)
    return np.asarray(raw.transform((raw.width+pad,raw.height),Image.Transform.AFFINE,
                      (1,.22,-pad,0,1,0),Image.Resampling.BICUBIC))

def curb():
    im=Image.new('RGBA',(850,280))
    im.alpha_composite(Image.fromarray(slanted('CURB')).resize((835,205),Image.Resampling.LANCZOS),(5,0))
    im.alpha_composite(Image.fromarray(lettering('R E C O R D S',PEARL,True)).resize((655,34),Image.Resampling.LANCZOS),(96,235))
    return np.asarray(im)

def infiniti():
    im=Image.new('RGBA',(420,230))
    d=ImageDraw.Draw(im)
    d.ellipse((82,8,338,138),outline=BLUE,width=13)
    d.line([(142,125),(210,37),(278,125)],fill=BLUE,width=15)
    im.alpha_composite(Image.fromarray(lettering('I N F I N I T I',BLUE)).resize((404,42),Image.Resampling.LANCZOS),(8,173))
    return np.asarray(im)

wordmark=curb()
number=slanted('98','Impact')
brand=infiniti()
side=[(wordmark,.38,.30,1.10,.245),(brand,.49,.82,.33,.17),
      (lettering('FIREHAWK',PEARL,True),1.03,.49,.34,.048),
      (lettering('BILLY BOAT',BLUE,True),-.35,.55,.29,.038),
      (lettering('CURB RECORDS',BLUE,True),-.28,.50,.38,.038),
      (lettering('Firestone',PEARL,True),1.31,.34,.27,.047),
      (lettering('Stant',PEARL,True,'Segoe Script'),1.39,.22,.28,.073)]

def overlay(c,art,u,v):
    hit=(u>=0)&(u<1)&(v>=0)&(v<1)
    rgba=art[(v[hit]*art.shape[0]).astype(int),(u[hit]*art.shape[1]).astype(int)]
    alpha=rgba[:,3:4]/255
    c[hit]=(rgba[:,:3]*alpha+c[hit]*(1-alpha)).astype(np.uint8)

def paint(p,normal,name):
    x,y,z=p.T
    c=np.tile(PEARL,(len(p),1)).astype(np.uint8)
    if 'Wing' in name or 'Endplate' in name:
        c[:]=BLUE
    else:
        edge=.465+.06*np.clip(z-.9,0,.7)
        c[y<edge]=BLUE
        # Thin red curve with a white keyline on the rear shoulder.
        stripe=edge+.037
        c[(z>.5)&(y>stripe)&(y<stripe+.014)]=ACCENT
        # Rounded blue nose cap, with parallel white and red rings.
        cap=-1.43+.40*(abs(x)/.45)**2
        c[z<cap]=BLUE
        c[(z>=cap+.022)&(z<cap+.050)]=ACCENT
        if name=='RollHoopFairing': c[:]=PEARL
    if abs(normal[0])>.65 and 'Wing' not in name:
        if 'RearEndplate' in name:
            decals=[(number,2.30,.80,.29,.23)]
        elif 'FrontEndplate' in name:
            decals=[(wordmark,-2.035,.17,.25,.075)]
        else: decals=side
        for art,cz,cy,w,h in decals:
            overlay(c,art,(z-cz)/w*(-1 if normal[0]>0 else 1)+.5,.5-(y-cy)/h)
    if normal[1]>.45:
        if name=='Nose': overlay(c,number,x/.24+.5,(z+1.72)/.31+.5)
        if name=='FrontWing': overlay(c,wordmark,(abs(x)-.53)/.43+.5,(z+2.035)/.21+.5)
    return c

bake(paint,'billy_boat_2001.png')
