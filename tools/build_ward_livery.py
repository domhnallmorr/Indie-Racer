"""Jeff Ward #35 pink/silver Aerosmith reference study on the shared car atlas."""
from livery_baker import *
from PIL import ImageDraw, ImageFilter

PINK=(194,31,99)
SILVER=(184,199,205)
INK=(30,28,29)
WHITE=(235,235,222)

def plate():
    raw=Image.fromarray(lettering('35',INK,True,'Impact'))
    im=Image.new('RGBA',(raw.width+16,raw.height+10),(*WHITE,255));im.alpha_composite(raw,(8,5))
    return np.asarray(im)

def menards():
    im=Image.new('RGBA',(620,180));d=ImageDraw.Draw(im)
    d.rounded_rectangle((2,20,618,166),radius=55,fill=(193,31,28))
    d.rectangle((15,20,605,66),fill=(235,198,15))
    raw=Image.fromarray(lettering('MENARDS',WHITE,True))
    text=raw.resize((552,105),Image.Resampling.LANCZOS)
    border=Image.new('RGBA',text.size,(*INK,255));border.putalpha(text.getchannel('A').filter(ImageFilter.MaxFilter(9)))
    border.alpha_composite(text);im.alpha_composite(border,(34,47));return np.asarray(im)

def aerosmith():
    im=Image.new('RGBA',(1000,410));d=ImageDraw.Draw(im)
    grey=(106,99,84)
    # Winged A emblem and script wordmark, rebuilt as vector-style artwork.
    for flip in [False,True]:
        pts=[(487,205),(397,69),(266,98),(53,39),(128,101),(65,99),(151,148),(107,151),(211,202),(173,214),(322,262),(435,244)]
        if flip: pts=[(1000-x,y) for x,y in pts]
        d.polygon(pts,fill=grey,outline=INK,width=7)
    d.ellipse((357,36,649,354),outline=INK,width=15)
    d.line([(379,295),(500,38),(618,295)],fill=grey,width=26)
    d.line([(420,224),(578,224)],fill=grey,width=21)
    raw=Image.fromarray(lettering('AEROSMITH',WHITE,True,'Segoe Script')).resize((660,150),Image.Resampling.LANCZOS)
    bg=Image.new('RGBA',raw.size,(*INK,255));bg.putalpha(raw.getchannel('A').filter(ImageFilter.MaxFilter(15)));bg.alpha_composite(raw)
    im.alpha_composite(bg,(170,232));return np.asarray(im)

def cover_art():
    # Stylized interpretation of the small blue figure and yellow cloth in the photo.
    im=Image.new('RGBA',(650,400));d=ImageDraw.Draw(im)
    d.polygon([(249,171),(390,145),(560,155),(609,211),(563,344),(476,372),(367,311),(306,343),(247,253)],fill=(241,214,36))
    for pts in [[(347,198),(381,295),(460,341)],[(408,173),(440,282),(552,312)],[(527,183),(505,283)],[(301,218),(336,291)]]:
        d.line(pts,fill=(255,245,137),width=13)
    d.ellipse((130,23,218,111),fill=(163,186,204),outline=(57,77,109),width=6)
    d.polygon([(143,104),(206,95),(245,148),(273,231),(233,248),(199,172),(185,256),(133,219),(112,148)],fill=(105,138,185))
    d.line([(151,112),(142,174),(169,226)],fill=(219,229,232),width=19)
    d.line([(201,126),(231,188),(271,216)],fill=(226,231,235),width=17)
    d.line([(183,155),(204,228),(240,269)],fill=(49,72,112),width=12)
    return np.asarray(im)

number=plate();logo=aerosmith();nose_logo=menards();illustration=cover_art()
side=[(logo,.39,.32,1.22,.34),(illustration,.94,.735,.68,.30),
      (number,.39,.83,.21,.16),
      (lettering('OLDSMOBILE',WHITE),.70,.905,.29,.028),
      (lettering('NorthernLight.com',WHITE),-.08,.545,.39,.033),
      (nose_logo,-1.59,.255,.49,.09),
      (lettering('PENNZOIL',INK,True),-.43,.40,.24,.038)]

def overlay(c,art,u,v):
    hit=(u>=0)&(u<1)&(v>=0)&(v<1)
    rgba=art[(v[hit]*art.shape[0]).astype(int),(u[hit]*art.shape[1]).astype(int)]
    a=rgba[:,3:4]/255
    c[hit]=(rgba[:,:3]*a+c[hit]*(1-a)).astype(np.uint8)

def paint(p,normal,name):
    x,y,z=p.T
    c=np.tile(PINK,(len(p),1)).astype(np.uint8)
    if 'FrontWing' in name or 'FrontEndplate' in name: c[:]=SILVER
    elif name=='Nose':
        # Torn-edge transition from the silver front to the pink sidepod.
        edge=-.29+.05*(1-4*abs((y/.065)%1-.5))
        c[z<edge]=SILVER
        c[(z>=edge)&(z<edge+.012)]=(90,91,85)
        c[(z<-.4)&(y>.52)]=PINK
    if abs(normal[0])>.65 and 'Wing' not in name:
        if 'RearEndplate' in name: decals=[(firehawk,2.30,.87,.31,.052)]
        elif 'FrontEndplate' in name: decals=[(nose_logo,-2.035,.16,.26,.055)]
        else:
            decals=side
            radius=((z+.43)/.14)**2+((y-.40)/.065)**2
            c[radius<1]=(239,206,20)
        for art,cz,cy,w,h in decals:
            overlay(c,art,(z-cz)/w*(-1 if normal[0]>0 else 1)+.5,.5-(y-cy)/h)
    if normal[1]>.45 and name=='Nose':
        overlay(c,number,x/.24+.5,(z+1.56)/.27+.5)
    return c

firehawk=lettering('FIREHAWK',INK,True)
bake(paint,'jeff_ward_2001.png')
