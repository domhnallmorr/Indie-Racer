"""Sam Hornish Jnr. Pennzoil reference study; run with Python on Windows."""
from livery_baker import *
from PIL import ImageDraw, ImageFilter

YELLOW = (240, 195, 16)
INK = (24, 23, 19)

def outlined(text):
    raw = Image.fromarray(lettering(text, INK, True, 'Impact'))
    im = Image.new('RGBA', (raw.width+16, raw.height+16))
    im.paste(raw, (8,8))
    border = Image.new('RGBA', im.size, (248,247,227,255))
    border.putalpha(im.getchannel('A').filter(ImageFilter.MaxFilter(9)))
    border.alpha_composite(im)
    return np.asarray(border)

def bowtie():
    im=Image.new('RGBA',(500,190))
    d=ImageDraw.Draw(im)
    points=[(38,62),(178,62),(178,23),(310,23),(310,62),(475,62),
            (448,131),(310,131),(310,169),(178,169),(178,131),(12,131)]
    d.polygon(points, fill=(156,49,33))
    points=[(53,78),(194,78),(194,39),(294,39),(294,78),(451,78),
            (437,115),(294,115),(294,153),(194,153),(194,115),(37,115)]
    d.polygon(points, fill=YELLOW)
    return np.asarray(im)

def rexhall():
    im=Image.new('RGBA',(600,235))
    d=ImageDraw.Draw(im)
    d.ellipse((5,7,594,227),outline=INK,width=7)
    for text,box in [('REXHALL',(60,48,480,82)),('MOTORHOMES',(120,142,360,40))]:
        art=Image.fromarray(lettering(text,INK,True)).resize((box[2],box[3]),Image.Resampling.LANCZOS)
        im.alpha_composite(art,(box[0],box[1]))
    return np.asarray(im)

def panther():
    # Sparse black contours evoke the reference's leaping panther on the yellow fin.
    im=Image.new('RGBA',(900,420))
    d=ImageDraw.Draw(im)
    contours=[[(45,115),(68,90),(117,78),(92,105),(54,119)],
      [(119,69),(169,31),(154,74)],[(168,84),(243,106),(366,149),(520,174),(698,206),(841,193)],
      [(131,134),(112,149),(100,184),(67,181),(48,162)],
      [(153,150),(188,173),(193,207),(233,229),(273,218)],
      [(283,221),(354,249),(420,277),(371,278),(318,261)],
      [(477,260),(564,278),(674,282),(769,267)],
      [(365,290),(346,315),(321,322),(294,353),(263,353),(279,332)],
      [(225,246),(204,273),(185,282)],[(248,286),(226,302),(220,324)]]
    for pts in contours: d.line(pts,fill=INK,width=9,joint='curve')
    return np.asarray(im)

wordmark=outlined('PENNZOIL')
number=outlined('4')
side=[(wordmark,.38,.32,1.19,.24), (bowtie(),.44,.835,.44,.15),
      (panther(),.96,.68,.95,.31),
      (lettering('FIREHAWK',INK,True),1.20,.52,.41,.052),
      (lettering('Firestone',INK,True),-.52,.54,.29,.045),
      (lettering('BOSCH',INK,True),-.37,.35,.18,.044),
      (lettering('DELCO',INK,True),-.37,.285,.17,.038),
      (lettering('NGK',INK,True),-.37,.23,.13,.035),
      (lettering('HPC',INK,True),-1.54,.30,.16,.057),
      (lettering('PENNZOIL',INK,True),-.36,.48,.24,.04)]
rear=[(rexhall(),2.30,.81,.31,.12),(wordmark,2.32,.675,.29,.055)]
front=[(wordmark,-2.035,.16,.23,.060)]

def overlay(c, art, u, v):
    hit=(u>=0)&(u<1)&(v>=0)&(v<1)
    rgba=art[(v[hit]*art.shape[0]).astype(int),(u[hit]*art.shape[1]).astype(int)]
    a=rgba[:,3:4]/255
    c[hit]=(rgba[:,:3]*a+c[hit]*(1-a)).astype(np.uint8)

def paint(p, normal, name):
    x,y,z=p.T
    c=np.tile(YELLOW,(len(p),1)).astype(np.uint8)
    # Fine dark sill line and the wing's exposed trailing edge.
    c[y<.085]=INK
    if 'Wing' in name:
        c[(z>2.45)|(z<-2.185)]=INK
    if abs(normal[0])>.62:
        decals=rear if 'RearEndplate' in name else (front if 'FrontEndplate' in name else side)
        if 'Wing' not in name:
            for art,cz,cy,w,h in decals:
                overlay(c,art,(z-cz)/w*(-1 if normal[0]>0 else 1)+.5,.5-(y-cy)/h)
    if normal[1]>.45 and name=='Nose':
        overlay(c,number,x/.19+.5,(z+1.54)/.32+.5)
    return c

bake(paint,'sam_hornish_2001.png')
