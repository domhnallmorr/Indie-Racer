"""Didier Andre #32 PlayStation 2 reference paint on the existing car atlas."""
from livery_baker import *
from PIL import ImageDraw

PEARL = (235, 238, 233)
INK = (12, 15, 24)
RED = (198, 30, 33)


def overlay(c, art, u, v):
    hit = (u >= 0) & (u < 1) & (v >= 0) & (v < 1)
    rgba = art[(v[hit] * art.shape[0]).astype(int), (u[hit] * art.shape[1]).astype(int)]
    alpha = rgba[:, 3:4] / 255
    c[hit] = (rgba[:, :3] * alpha + c[hit] * (1 - alpha)).astype(np.uint8)


def number_panel():
    im = Image.new('RGBA', (260, 250), (*PEARL, 255))
    im.alpha_composite(Image.fromarray(lettering('32', INK, True, 'Impact')).resize((230, 224)), (15, 13))
    return np.asarray(im)


def badge():
    # Small blue endplate mark reconstructed from the low-resolution reference.
    im = Image.new('RGBA', (200, 140))
    d = ImageDraw.Draw(im)
    d.ellipse((8, 8, 192, 132), fill=PEARL)
    d.line([(40, 46), (59, 97), (88, 51), (113, 98), (144, 45)], fill=(30, 129, 190), width=16)
    return np.asarray(im)


number = number_panel()
ps_black = lettering('PlayStation 2', INK, False, 'Arial Narrow')
ps_white = lettering('PlayStation 2', PEARL, False, 'Arial Narrow')
small_badge = badge()
side = [(ps_black, .40, .325, 1.12, .16),
        (number, .39, .805, .26, .205),
        (ps_white, .92, .785, .65, .064),
        (lettering('DIDIER ANDRE', INK, True), -.12, .565, .29, .026),
        (lettering('FIREHAWK', INK, True), 1.28, .285, .28, .034),
        (lettering('G RACING', INK, True), -1.49, .275, .29, .044)]


def paint(p, normal, name):
    x, y, z = p.T
    c = np.tile(PEARL, (len(p), 1)).astype(np.uint8)
    if 'Wing' in name or 'Endplate' in name:
        if name == 'FrontWing':
            c[:] = RED
            c[z > -2.025] = INK
        if name == 'RearWing':
            c[z < 2.20] = INK
    else:
        # White sidepods beneath fine red shoulder piping and a black rear sweep.
        shoulder = .52 + .015 * np.clip(z, 0, 1.5)
        c[(abs(y - shoulder) < .011) & (z > -.55)] = RED
        rear = (z > 1.17 + .30 * np.clip((.5 - y) / .35, 0, 1)) & (y < .54)
        c[rear] = INK
        c[y < .082] = INK
        # Black engine-cover cap, edged in red, with a red intake/front edge.
        roof = .725 - .095 * (z - .35)
        cap = (z > .23) & (y > roof)
        c[cap] = INK
        c[(z > .23) & (abs(y - roof) < .012)] = RED
        c[(z > .23) & (z < .31) & (y > .73)] = RED
        # Black nose tip and cockpit deck, white middle nose with red pinstripe.
        tip = -1.88 + .14 * abs(x)
        c[z < tip] = INK
        c[abs(z - tip) < .022] = RED
        c[(z > -1.17) & (z < -.53) & (abs(x) < .22) & (y > .37)] = INK
        c[(z < -.65) & (y < .17)] = RED
        if name == 'RollHoopFairing':
            c[:] = INK
        if 'Mirror' in name:
            c[:] = INK
    if abs(normal[0]) > .65 and 'Wing' not in name:
        if 'RearEndplate' in name:
            decals = [(small_badge, 2.36, .81, .16, .105)]
        elif 'FrontEndplate' in name:
            decals = [(small_badge, -1.99, .155, .16, .10)]
        else:
            decals = side
        for art, cz, cy, w, h in decals:
            overlay(c, art, (z - cz) / w * np.where(x > 0, -1, 1) + .5, .5 - (y - cy) / h)
    if normal[1] > .45 and name == 'Nose':
        overlay(c, number, x / .20 + .5, (z + 1.52) / .25 + .5)
    return c


if __name__ == '__main__':
    bake(paint, 'didier_andre_2001.png')
