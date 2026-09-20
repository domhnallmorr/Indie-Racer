"""Buddy Lazier #91: paint reconstructed from the supplied side reference."""
from livery_baker import *
from PIL import ImageFilter

PURPLE=(30,17,61)
SILVER=(230,231,239)
LIME=(213,244,0)
INK=(23,20,32)

def outline(text, colour, family='Arial', border=INK):
    raw=Image.fromarray(lettering(text,colour,True,family))
    im=Image.new('RGBA',(raw.width+16,raw.height+16))
    im.paste(raw,(8,8))
    out=Image.new('RGBA',im.size,(*border,255))
    out.putalpha(im.getchannel('A').filter(ImageFilter.MaxFilter(17)))
    out.alpha_composite(im)
    return np.asarray(out)

def coors():
    im=Image.new('RGBA',(1050,200))
    for art,box in [(outline('Coors',(174,15,33),'Segoe Script'),(0,0,490,190)),
                    (outline('LIGHT',INK,'Georgia',SILVER),(485,35,555,145))]:
        im.alpha_composite(Image.fromarray(art).resize((box[2],box[3]),Image.Resampling.LANCZOS),(box[0],box[1]))
    return np.asarray(im)

number=outline('91',INK,'Impact',SILVER)
nose_number=outline('91',SILVER,'Impact',INK)
taebo=lettering('TAEBO',SILVER)
coors_logo=coors()
fitness=lettering('Life Fitness',(108,19,34),True,'Segoe Script')
side=[(taebo,.39,.30,1.35,.23),
      (coors_logo,.75,.535,.90,.105),
      (number,.40,.82,.23,.16),
      (fitness,.86,.745,.57,.095),
      (lettering('Oldsmobile',SILVER),.72,.855,.39,.043),
      (lettering('DELTA',(99,103,110)), -.25,.55,.36,.075),
      (lettering('HEMELGARN',INK,True),-.57,.51,.39,.045),
      (lettering('FIREHAWK',INK,True),-.43,.432,.34,.046),
      (lettering('BOSCH',SILVER,True),1.40,.29,.23,.051),
      (lettering('hemelgarnracing.com',SILVER),.5,.13,.83,.035)]
rear=[(lettering('Super Fitness',INK,False,'Georgia'),2.30,.87,.33,.054),
      (lettering('FIREHAWK',SILVER,True),2.30,.785,.32,.051),
      (coors_logo,2.30,.681,.29,.054)]
front=[(lettering('Carmeuse',INK,True),-2.035,.16,.24,.045)]

def overlay(c,art,u,v):
    hit=(u>=0)&(u<1)&(v>=0)&(v<1)
    rgba=art[(v[hit]*art.shape[0]).astype(int),(u[hit]*art.shape[1]).astype(int)]
    alpha=rgba[:,3:4]/255
    c[hit]=(rgba[:,:3]*alpha+c[hit]*(1-alpha)).astype(np.uint8)

def paint(p,normal,name):
    x,y,z=p.T
    c=np.tile(SILVER,(len(p),1)).astype(np.uint8)
    if 'Wing' in name or 'Endplate' in name:
        if 'RearEndplate' in name:
            c[(y>.745)&(y<.825)]=PURPLE
    else:
        # Purple lower sidepods, a tapering fluorescent shoulder stripe and white deck.
        edge=.43-.045*np.clip(z,0,1.7)
        c[y<edge]=PURPLE
        stripe=.042*np.clip((1.45-z)/1.65,0,1)
        c[(z>-.85)&(y>=edge)&(y<edge+stripe)]=LIME
        c[(z< -1.17)]=PURPLE
        c[(z< -2.15)]=LIME
        # Dark fin cap and slim purple sweep under the Life Fitness wordmark.
        c[(z>.2)&(y>.94-.22*(z-.3))]=PURPLE
        sweep=.685-.095*(z-.7)
        c[(z>.54)&(y>sweep)&(y<sweep+.022)]=PURPLE
        if name=='RollHoopFairing': c[:]=LIME
    if abs(normal[0])>.65 and 'Wing' not in name:
        decals=rear if 'RearEndplate' in name else (front if 'FrontEndplate' in name else side)
        for art,cz,cy,w,h in decals:
            overlay(c,art,(z-cz)/w*(-1 if normal[0]>0 else 1)+.5,.5-(y-cy)/h)
    if normal[1]>.45:
        if name=='Nose': overlay(c,nose_number,x/.25+.5,(z+1.62)/.29+.5)
        if name=='FrontWing':
            overlay(c,fitness,(abs(x)-.51)/.46+.5,(z+2.035)/.19+.5)
        if name=='RearWing': overlay(c,taebo,x/.90+.5,(z-2.30)/.21+.5)
    return c

bake(paint,'buddy_lazier_2001.png')
