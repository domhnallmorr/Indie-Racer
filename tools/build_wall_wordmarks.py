"""Editable vector wall wordmarks. Uses font outlines so Godot needs no system fonts."""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'content/tracks/mile_oval/wall_ads'
def text_path(text,font_path,x,y,width,height,color):
    font=TTFont(font_path); glyphs=font.getGlyphSet(); cmap=font.getBestCmap()
    pen=SVGPathPen(glyphs); paths=[]; advance=0
    for char in text:
        name=cmap[ord(char)]; p=SVGPathPen(glyphs); glyphs[name].draw(p)
        paths.append(f'<g transform="translate({advance},0)"><path d="{p.getCommands()}"/></g>')
        advance+=glyphs[name].width
    cap=font['OS/2'].sCapHeight if hasattr(font['OS/2'],'sCapHeight') else font['hhea'].ascent*.78
    return f'<g fill="{color}" transform="translate({x},{y}) scale({width/advance},{-height/cap})">'+''.join(paths)+'</g>'
marlboro='<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="240" viewBox="0 0 1024 240"><path d="M15 82V15H165V82L90 40Z" fill="#cf1d2b"/>'
marlboro+=text_path('Marlboro','C:/Windows/Fonts/timesbd.ttf',195,194,810,168,'#171717')+'</svg>'
(OUT/'marlboro.svg').write_text(marlboro)
target='<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="240" viewBox="0 0 1024 240"><circle cx="120" cy="120" r="99" fill="#cc172c"/><circle cx="120" cy="120" r="65" fill="white"/><circle cx="120" cy="120" r="32" fill="#cc172c"/>'
target+=text_path('TARGET','C:/Windows/Fonts/arialbd.ttf',258,192,740,145,'#cc172c')+'</svg>'
(OUT/'target.svg').write_text(target)
