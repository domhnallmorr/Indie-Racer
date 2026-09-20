"""Rebuild the Delphi reference livery with the shared UV baker."""
from livery_baker import *
import sys

dismore = '--dismore' in sys.argv
car_number = '28' if dismore else '8'
surname = 'DISMORE' if dismore else 'SHARPE'

# Dimensions and locations are metres in the existing car's coordinate system.
decals = [(lettering('DELPHI'), .36, .31, 1.23, .16),
          (lettering('Futaba', YELLOW, True), .72, .715, .55, .11),
          (lettering(car_number, WHITE, True), .36, .84, .24 if dismore else .17, .18),
          (lettering('BOMBARDIER', WHITE, True), -1.64, .27, .47, .062),
          (lettering('AEROSPACE', WHITE, True), -1.64, .205, .38, .052),
          (lettering('BRYANT', WHITE, True), .90, .56, .25, .065),
          (lettering('Firestone', WHITE, True), -.62, .55, .31, .053),
          (lettering(surname, BLACK, True), 1.39, .27, .25, .05)]

def paint(p, normal, name):
    x,y,z = p.T
    c = np.tile(RED, (len(p),1)).astype(np.uint8)
    c[y < .16] = YELLOW
    if 'Wing' in name:
        c[:] = BLACK
        c[(z > 2.22) | (z < -2.13)] = YELLOW
    elif 'Endplate' in name:
        c[:] = YELLOW
        if 'Rear' in name:
            c[y < .735] = RED
            c[(y >= .735) & (y < .76)] = BLACK
    else:
        # Yellow shoulder pinstripe separates the red sidepod from black decking.
        boundary = np.where(z < -.65, .36 + .15*(z+2.1)/1.45, .58)
        c[y > boundary] = BLACK
        c[(y > boundary-.035) & (y < boundary+.014)] = YELLOW
        c[(z > 1.05) & (y < .28+(z-1.05)*.75)] = YELLOW
        c[(np.abs(x) < .018) & (y > boundary) & (z < 0)] = YELLOW
        c[(z > .24) & (y > .94-.235*(z-.3))] = YELLOW
        if name == 'RollHoopFairing':
            c[:] = YELLOW
    if abs(normal[0]) > .65 and 'Wing' not in name and 'Endplate' not in name:
        # Small contingency badges, reconstructed as simple period-style marks.
        for cz,cy in [(1.05,.53),(1.31,.48),(.83,.62)]:
            radius=((z-cz)/.045)**2+((y-cy)/.026)**2
            c[radius<1]=YELLOW
            c[radius<.48]=BLACK
        c[(abs(z-.9)<.14)&(abs(y-.56)<.04)] = (174,20,29)
        for art, cz, cy, w, h in decals:
            u = (z-cz)/w * (-1 if normal[0] > 0 else 1) + .5
            v = .5-(y-cy)/h
            hit = (u>=0)&(u<1)&(v>=0)&(v<1)
            rgba = art[(v[hit]*art.shape[0]).astype(int), (u[hit]*art.shape[1]).astype(int)]
            alpha = rgba[:,3:4]/255
            c[hit] = (rgba[:,:3]*alpha+c[hit]*(1-alpha)).astype(np.uint8)
    # Number on the nose, facing the front of the car.
    if normal[1] > .45 and name == 'Nose':
        art = lettering_number
        u,v = x/(.24 if dismore else .18)+.5, (z+1.56)/.29+.5
        hit=(u>=0)&(u<1)&(v>=0)&(v<1)
        rgba=art[(v[hit]*art.shape[0]).astype(int),(u[hit]*art.shape[1]).astype(int)]
        alpha=rgba[:,3:4]/255
        c[hit]=(rgba[:,:3]*alpha+c[hit]*(1-alpha)).astype(np.uint8)
    return c

lettering_number = lettering(car_number, WHITE, True)
bake(paint, 'mark_dismore_2001.png' if dismore else 'scott_sharpe_2001.png')
