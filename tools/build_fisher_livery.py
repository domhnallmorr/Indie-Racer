"""Sarah Fisher #15 Kroger: reference paint projected onto the shared car atlas."""
from livery_baker import *
from PIL import ImageDraw

BLUE = (16, 113, 178)
WHITE = (246, 247, 244)
INK = (15, 20, 27)
KROGER_BLUE = (24, 71, 149)


def overlay(c, art, u, v):
    hit = (u >= 0) & (u < 1) & (v >= 0) & (v < 1)
    rgba = art[(v[hit] * art.shape[0]).astype(int), (u[hit] * art.shape[1]).astype(int)]
    alpha = rgba[:, 3:4] / 255
    c[hit] = (rgba[:, :3] * alpha + c[hit] * (1 - alpha)).astype(np.uint8)


def kroger():
    im = Image.new('RGBA', (480, 370))
    d = ImageDraw.Draw(im)
    d.ellipse((8, 8, 472, 362), fill=KROGER_BLUE, outline=WHITE, width=10)
    word = Image.fromarray(lettering('Kroger', WHITE, False, 'Arial'))
    im.alpha_composite(word.resize((405, 180), Image.Resampling.LANCZOS), (38, 94))
    # Tall loop strokes evoke the reference's distinctive K and g wordmark.
    d.arc((66, 42, 158, 198), 175, 355, fill=WHITE, width=9)
    d.arc((292, 163, 365, 313), 0, 185, fill=WHITE, width=8)
    return np.asarray(im)


logo = kroger()
number_im = Image.new('RGBA', (270, 270), (*WHITE, 255))
number_im.alpha_composite(Image.fromarray(lettering('15', INK, True, 'Impact')).resize((238, 246)), (16, 12))
number = np.asarray(number_im)
mead = lettering('mead', WHITE, False, 'Arial')
firehawk = lettering('FIREHAWK', WHITE, True)
driver = lettering('SARAH FISHER', WHITE, True)
side = [(logo, .96, .68, .42, .25), (number, .40, .78, .32, .25),
        (mead, .80, .845, .32, .07), (firehawk, 1.03, .30, .42, .045),
        (driver, -.16, .56, .32, .026)]


def paint(p, normal, name):
    x, y, z = p.T
    c = np.tile(BLUE, (len(p), 1)).astype(np.uint8)
    if name in ('FrontWing', 'RearWing'):
        c[:] = WHITE
    if name == 'Nose':
        # White center panel tapers toward the blue tip; blue remains along edges.
        width = .035 + .19 * np.clip((z + 2.24) / 1.45, 0, 1)
        c[(abs(x) < width) & (y > .20) & (z > -2.13) & (z < -.68)] = WHITE
        edge = .23 + .26 * np.clip((z + 2.15) / 1.35, 0, 1)
        c[(abs(y - edge) < .019) & (z > -2.1) & (z < -.68)] = WHITE
    if name == 'Nose' or name.startswith('Sidepod'):
        # White sweep surrounding the blue upper sidepod panel.
        sweep = .44 + .10 * np.sin(np.clip((z + .25) / 1.9, 0, 1) * np.pi)
        c[(abs(y - sweep) < .016) & (abs(x) > .32) & (z > -.45)] = WHITE
        if normal[1] > .45:
            rim = .59 + .10 * np.sin(np.clip((z + .35) / 2.0, 0, 1) * np.pi)
            c[(abs(abs(x) - rim) < .025) & (z > -.35)] = WHITE
            overlay(c, logo, (abs(x) - .49) / .28 + .5, (z - .56) / .40 + .5)
    if abs(normal[0]) > .65 and 'Wing' not in name and 'Endplate' not in name:
        for art, cz, cy, w, h in side:
            overlay(c, art, (z - cz) / w * np.where(x > 0, -1, 1) + .5, .5 - (y - cy) / h)
    if normal[1] > .45:
        if name == 'Nose':
            overlay(c, number, x / .23 + .5, (z + 1.40) / .28 + .5)
            overlay(c, logo, x / .18 + .5, (z + 1.85) / .23 + .5)
        if name == 'FrontWing':
            overlay(c, logo, (abs(x) - .57) / .35 + .5, (z + 2.035) / .24 + .5)
        if name == 'RearWing':
            overlay(c, logo, x / .52 + .5, (z - 2.30) / .29 + .5)
    return c


if __name__ == '__main__':
    bake(paint, 'sarah_fisher_2001.png')
