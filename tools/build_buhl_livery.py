"""Robbie Buhl #24 Purex reference artwork for the existing car atlas."""
from livery_baker import *
from PIL import ImageDraw, ImageFilter

BLUE=(18,39,103)
YELLOW=(246,203,20)
ORANGE=(243,50,8)
WHITE=(238,240,231)
INK=(17,26,36)

def outlined(text,colour,family='Arial',border=WHITE):
    raw=Image.fromarray(lettering(text,colour,True,family))
    pad=int(raw.height*.18)
    raw=raw.transform((raw.width+pad,raw.height),Image.Transform.AFFINE,(1,.18,-pad,0,1,0),Image.Resampling.BICUBIC)
    im=Image.new('RGBA',(raw.width+16,raw.height+16));im.alpha_composite(raw,(8,8))
    out=Image.new('RGBA',im.size,(*border,255));out.putalpha(im.getchannel('A').filter(ImageFilter.MaxFilter(13)));out.alpha_composite(im)
    return out

def purex():
    im=Image.new('RGBA',(900,420));d=ImageDraw.Draw(im)
    # Orange/yellow tilted oval behind the dark outlined wordmark.
    d.ellipse((139,24,758,394),fill=ORANGE)
    d.ellipse((183,57,725,349),fill=(255,134,4))
    d.ellipse((219,75,688,329),fill=YELLOW)
    im.alpha_composite(outlined('Purex',INK,'Arial Black').resize((890,265),Image.Resampling.LANCZOS),(5,68))
    im.alpha_composite(Image.fromarray(lettering('Laundry Detergent',INK)).resize((340,32),Image.Resampling.LANCZOS),(330,351))
    return np.asarray(im)

def infiniti():
    im=Image.new('RGBA',(400,220));d=ImageDraw.Draw(im)
    d.ellipse((90,8,310,119),outline=BLUE,width=12)
    d.line([(144,109),(200,36),(256,109)],fill=BLUE,width=13)
    im.alpha_composite(Image.fromarray(lettering('I N F I N I T I',BLUE)).resize((375,40),Image.Resampling.LANCZOS),(12,155))
    return np.asarray(im)

logo=purex();number=np.asarray(outlined('24',BLUE,'Impact',YELLOW));brand=infiniti()
side=[(logo,.38,.32,1.26,.34),(brand,.39,.85,.32,.145),
      (lettering('RACING for KIDS',(154,38,24),True),.88,.825,.53,.048),
      (lettering('Aventis',BLUE,False,'Georgia'),.80,.715,.42,.065),
      (lettering('FIREHAWK',WHITE,True),1.10,.155,.34,.035),
      (lettering('BOSCH',WHITE,True),1.39,.245,.19,.035)]

def overlay(c,art,u,v):
    hit=(u>=0)&(u<1)&(v>=0)&(v<1)
    rgba=art[(v[hit]*art.shape[0]).astype(int),(u[hit]*art.shape[1]).astype(int)]
    a=rgba[:,3:4]/255
    c[hit]=(rgba[:,:3]*a+c[hit]*(1-a)).astype(np.uint8)

def paint(p,normal,name):
    x,y,z=p.T
    c=np.tile(YELLOW,(len(p),1)).astype(np.uint8)
    if 'RearEndplate' in name: c[:]=ORANGE
    elif name=='RearWing': c[:]=INK
    elif 'FrontWing' in name or 'FrontEndplate' in name: c[:]=BLUE
    else:
        edge=.47+.04*np.clip(z,0,1.6)
        nose=z<-.75
        edge=np.where(nose,.13+.21*np.clip((z+2.275)/1.525,0,1),edge)
        c[y<edge]=BLUE
        c[(y>=edge)&(y<edge+.022)]=WHITE
        # Warm band fades from scarlet to orange to the yellow upper body.
        band=(y>=edge+.022)&(y<edge+.105)
        t=np.clip((y[band]-edge[band]-.022)/.083,0,1)[:,None]
        c[band]=(np.array(ORANGE)*(1-t)+np.array(YELLOW)*t).astype(np.uint8)
        if 'Mirror' in name: c[:]=ORANGE
    if abs(normal[0])>.65 and 'Wing' not in name:
        if 'RearEndplate' in name: decals=[(number,2.30,.79,.30,.24)]
        elif 'FrontEndplate' in name: decals=[(logo,-2.035,.17,.26,.105)]
        else: decals=side
        for art,cz,cy,w,h in decals:
            overlay(c,art,(z-cz)/w*(-1 if normal[0]>0 else 1)+.5,.5-(y-cy)/h)
    if normal[1]>.45:
        if name=='Nose':
            overlay(c,number,x/.24+.5,(z+1.73)/.27+.5)
            overlay(c,logo,x/.26+.5,(z+1.17)/.34+.5)
        if name=='FrontWing': overlay(c,logo,(abs(x)-.53)/.44+.5,(z+2.035)/.21+.5)
    return c

bake(paint,'robbie_buhl_2001.png')
