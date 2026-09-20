"""Eddie Cheever #51: silver/black Excite artwork from the supplied reference."""
from livery_baker import *
from PIL import ImageDraw

SILVER=(170,185,193)
INK=(12,16,17)
RED=(201,29,28)
WHITE=(235,237,228)

def excitement(colour):
    im=Image.new('RGBA',(350,410));d=ImageDraw.Draw(im)
    # The hand-drawn X and red radiating strokes used throughout the scheme.
    d.line([(85,185),(155,241),(240,342),(271,365)],fill=colour,width=27)
    d.line([(236,176),(204,236),(160,325),(130,385)],fill=colour,width=23)
    for pts in [[(73,139),(48,104),(51,91),(85,128)],[(113,115),(104,55),(112,41),(127,116)],
                [(169,99),(174,12),(186,3),(182,99)],[(225,109),(250,40),(259,25),(241,117)]]:
        d.polygon(pts,fill=RED)
    return np.asarray(im)

def excite():
    im=Image.new('RGBA',(1040,290))
    raw=Image.fromarray(lettering('excite',WHITE,True))
    im.alpha_composite(raw.resize((990,188),Image.Resampling.LANCZOS),(20,97))
    d=ImageDraw.Draw(im)
    for pts in [[(230,90),(209,56),(215,50),(240,80)],[(270,82),(262,23),(271,17),(282,79)],
                [(312,74),(322,2),(331,0),(325,77)]]: d.polygon(pts,fill=RED)
    return np.asarray(im)

def infiniti(colour):
    im=Image.new('RGBA',(420,230));d=ImageDraw.Draw(im)
    d.ellipse((82,8,338,138),outline=colour,width=13)
    d.line([(142,125),(210,37),(278,125)],fill=colour,width=15)
    im.alpha_composite(Image.fromarray(lettering('I N F I N I T I',colour)).resize((404,42),Image.Resampling.LANCZOS),(8,173))
    return np.asarray(im)

def home(colour):
    im=Image.new('RGBA',(700,160))
    im.alpha_composite(Image.fromarray(lettering('@',RED,True)).resize((140,140),Image.Resampling.LANCZOS),(0,5))
    im.alpha_composite(Image.fromarray(lettering('Home',colour,True)).resize((540,125),Image.Resampling.LANCZOS),(155,20))
    return np.asarray(im)

raw=Image.fromarray(lettering('51',INK,True,'Impact'))
num=Image.new('RGBA',(raw.width+18,raw.height+12),(*WHITE,255));num.alpha_composite(raw,(9,6))
number=np.asarray(num)
logo=excite();symbol=excitement(INK);brand=infiniti(INK);wing_brand=infiniti(WHITE)
home_dark=home(INK);home_light=home(WHITE)
side=[(logo,.38,.315,1.20,.28),(symbol,.88,.735,.32,.32),
      (brand,.42,.84,.32,.15),(number,.42,.64,.25,.16),
      (home_dark,.69,.60,.33,.062),
      (lettering('Firestone',WHITE,True),-.35,.445,.32,.046),
      (lettering('BOSCH',WHITE,True),1.36,.285,.23,.043),
      (lettering('STANLEY',WHITE,True),1.37,.22,.22,.034)]

def overlay(c,art,u,v):
    hit=(u>=0)&(u<1)&(v>=0)&(v<1)
    rgba=art[(v[hit]*art.shape[0]).astype(int),(u[hit]*art.shape[1]).astype(int)]
    a=rgba[:,3:4]/255
    c[hit]=(rgba[:,:3]*a+c[hit]*(1-a)).astype(np.uint8)

def paint(p,normal,name):
    x,y,z=p.T
    c=np.tile(SILVER,(len(p),1)).astype(np.uint8)
    if 'Wing' in name or 'Endplate' in name: c[:]=INK
    else:
        edge=.465-.03*np.clip(z,0,1.6)
        c[y<edge]=INK
        c[(y>=edge)&(y<edge+.022)]=RED
        # Silver nose on top, black underside, red pinstripe following the taper.
        nose=z<-.78
        line=.12+.15*np.clip((z+2.27)/1.49,0,1)
        c[nose]=SILVER
        c[nose&(y<line)]=INK
        c[nose&(y>=line)&(y<line+.017)]=RED
        if name=='RollHoopFairing': c[:]=SILVER
    if abs(normal[0])>.65 and 'Wing' not in name:
        if 'RearEndplate' in name:
            decals=[(streaming,2.30,.85,.32,.065),(firestone,2.30,.73,.31,.058)]
        elif 'FrontEndplate' in name: decals=[(comcast,-2.035,.16,.25,.07)]
        else: decals=side
        for art,cz,cy,w,h in decals:
            overlay(c,art,(z-cz)/w*(-1 if normal[0]>0 else 1)+.5,.5-(y-cy)/h)
    if normal[1]>.45:
        if name=='Nose':
            overlay(c,number,x/.23+.5,(z+1.60)/.29+.5)
            overlay(c,brand,x/.23+.5,(z+1.94)/.22+.5)
            overlay(c,symbol,x/.28+.5,(z+1.02)/.36+.5)
            # Black shoulder decks carry the Home name, like the reference.
            for sign in [-1,1]:
                hit=(abs(x-sign*.52)<.19)&(z>-.42)&(z<.95)&(y>.45)&(y<.66)
                c[hit]=INK
                overlay(c,home_light,(z-.18)/.70*(-sign)+.5,(x-sign*.52)/.17+.5)
        if name=='RearWing': overlay(c,wing_brand,x/.89+.5,(z-2.30)/.28+.5)
        if name=='FrontWing': overlay(c,logo,(abs(x)-.53)/.44+.5,(z+2.035)/.21+.5)
    return c

streaming=lettering('STREAMING MEDIA',WHITE,True)
firestone=lettering('Firestone',WHITE,True)
comcast=lettering('Comcast',WHITE,True)
bake(paint,'eddie_cheever_2001.png')
