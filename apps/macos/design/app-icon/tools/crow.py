"""Vector drawing of the Yatagarasu character: a three-legged crow carrying a parcel.

Coordinates follow the 1024×1024 reference image (../reference.webp) so the drawing can be
overlaid on it. `character_svg()` returns the character's SVG markup; `render()` rasterises
an SVG document with skia.
"""

# ---------------------------------------------------------------- palette
INK = "#141519"          # outlines and creases
BODY = "#2B2C32"
BODY_HI = "#3B3C44"
BODY_LO = "#202126"
WING = "#303137"
TAIL = "#222328"
EYE = "#0C0C0F"
EYE_GLOSS = "#30323A"
GLINT = "#6E7079"
BEAK = "#4A4B52"
BEAK_LO = "#303137"
BEAK_HI = "#80818A"
BLUSH = "#F59AA5"
SUN = "#FFC53D"
BOX_TOP = "#EBC48F"
BOX_FRONT = "#DDAB73"
BOX_SIDE = "#C99660"
TAPE_TOP = "#D2A169"
TAPE_FRONT = "#C38F57"
TAPE_SIDE = "#B4804B"
BOX_EDGE = "#F6D7A6"
FOOT = "#FF8A2A"
FOOT_LO = "#EC7019"
STICKER = "#FFFBF2"


# ---------------------------------------------------------------- path helpers
def smooth(points, closed=True, corners=(), tension=1.0):
    """Catmull-Rom spline through `points` as SVG cubic Béziers.

    Indices listed in `corners` get zero-length handles, giving a sharp tip.
    """
    n = len(points)
    def P(i):
        return points[i % n] if closed else points[max(0, min(n - 1, i))]
    d = "M%.1f %.1f" % points[0]
    last = n if closed else n - 1
    for i in range(last):
        p0, p1, p2, p3 = P(i - 1), P(i), P(i + 1), P(i + 2)
        k = tension / 6
        c1 = (p1[0] + (p2[0] - p0[0]) * k, p1[1] + (p2[1] - p0[1]) * k)
        c2 = (p2[0] - (p3[0] - p1[0]) * k, p2[1] - (p3[1] - p1[1]) * k)
        if i % n in corners:
            c1 = p1
        if (i + 1) % n in corners:
            c2 = p2
        d += " C%.1f %.1f %.1f %.1f %.1f %.1f" % (*c1, *c2, *p2)
    return d + (" Z" if closed else "")


def poly(points):
    return "M" + " L".join("%.1f %.1f" % p for p in points) + " Z"


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def bilinear(q, u, v):
    """Point in quad q = (p00, p10, p11, p01) at (u, v)."""
    top = lerp(q[0], q[1], u)
    bottom = lerp(q[3], q[2], u)
    return lerp(top, bottom, v)


def quad_region(q, u0, u1, v0, v1):
    return poly([bilinear(q, u0, v0), bilinear(q, u1, v0), bilinear(q, u1, v1), bilinear(q, u0, v1)])


# ---------------------------------------------------------------- shapes
BODY_PTS = [
    (512, 56), (606, 66), (690, 116), (750, 192), (782, 276), (794, 344),
    (828, 386),  # right cheek tuft (corner)
    (802, 398), (800, 446), (832, 520), (852, 610), (850, 712), (824, 806),
    (772, 878), (668, 914), (552, 926), (436, 926), (330, 908), (244, 866),
    (192, 796), (170, 700), (174, 598), (198, 520), (214, 470), (198, 426),
    (172, 414),  # left cheek tuft (corner)
    (204, 380), (206, 302), (218, 236), (234, 202),
    (216, 172),  # crown tuft (corner)
    (258, 158), (306, 116), (368, 82), (436, 62),
]
BODY_CORNERS = (6, 25, 30)

TAIL_PTS = [(236, 742), (180, 760), (134, 790), (176, 812), (150, 846), (206, 864), (262, 852)]

LEFT_WING = ("M176 560 C178 520 236 498 296 516 C312 522 322 532 330 540 C362 566 400 600 440 624 C470 640 484 660 466 674 "
             "C456 680 446 680 438 680 C460 690 476 706 460 720 C450 728 436 730 424 730 "
             "C432 744 422 762 398 764 C360 768 300 766 252 750 C210 732 182 700 176 650 "
             "C172 620 174 590 176 560 Z")
LEFT_CREASES = ["M438 680 C400 676 350 662 316 646", "M424 730 C386 728 340 718 300 700",
                "M206 640 C222 668 246 690 280 704"]
RIGHT_WING = ("M822 508 C806 532 804 590 812 628 C790 632 768 638 762 652 C758 664 770 672 794 676 "
              "C774 682 764 696 770 708 C776 718 790 722 806 724 C792 730 788 744 800 750 "
              "C812 758 826 762 838 760 C872 744 892 700 888 640 C884 580 852 522 832 506 C828 503 824 504 822 508 Z")
RIGHT_CREASES = ["M794 676 C820 678 846 674 866 664", "M806 724 C826 726 846 722 862 714"]

BOX = dict(
    top=((360, 497), (712, 470), (822, 542), (452, 570)),
    front=((452, 570), (822, 542), (815, 786), (457, 822)),
    side=((360, 497), (452, 570), (457, 822), (372, 770)),
)

FEET = [  # centre x, centre y, rotation (deg)
    (424, 890, -12),
    (590, 884, 0),
    (744, 872, 12),
]

FOOT_PATH = ("M-56 0 C-60 -28 -54 -52 -38 -58 C-28 -62 -19 -56 -18 -48 C-16 -60 -8 -66 0 -66 "
             "C8 -66 16 -60 18 -48 C19 -56 28 -62 38 -58 C54 -52 60 -28 56 0 "
             "C54 34 30 64 0 66 C-30 64 -54 34 -56 0 Z")


def foot(cx, cy, rot, fill, extra=""):
    return f'<path transform="translate({cx} {cy}) rotate({rot})" fill="{fill}" {extra} d="{FOOT_PATH}"/>'


def foot_shading(cx, cy, rot):
    return (f'<g transform="translate({cx} {cy}) rotate({rot})">'
            f'<path d="{FOOT_PATH}" fill="url(#footShade)"/>'
            '<path d="M-18 -48 C-17 -42 -16 -38 -14 -34 M18 -48 C17 -42 16 -38 14 -34" fill="none" '
            f'stroke="{FOOT_LO}" stroke-width="4" stroke-linecap="round"/>'
            '<ellipse cx="-28" cy="-14" rx="11" ry="18" fill="#FFB16B" opacity="0.7" transform="rotate(12 -28 -14)"/>'
            "</g>")


def eye(cx, cy, mirror, tilt):
    s = -1 if mirror else 1
    return f'''
<g transform="translate({cx} {cy}) rotate({tilt})">
  <ellipse cx="0" cy="0" rx="61" ry="64" fill="{INK}"/>
  <ellipse cx="{-6 * s}" cy="1" rx="53" ry="57" fill="#FFFFFF"/>
  <ellipse cx="{5 * s}" cy="2" rx="51" ry="56" fill="{EYE}"/>
  <path d="M-30 30 C-14 46 18 48 36 30 C24 52 -16 54 -30 30 Z" fill="{EYE_GLOSS}"/>
  <circle cx="-10" cy="-17" r="19" fill="#FFFFFF"/>
  <circle cx="27" cy="25" r="10" fill="#FFFFFF"/>
  <circle cx="24" cy="-18" r="6" fill="{GLINT}"/>
</g>'''


def sun(cx, cy, tilt):
    rays = "".join(
        f'<line x1="0" y1="-50" x2="0" y2="-72" transform="rotate({a})"/>' for a in range(0, 360, 45))
    return (f'<g transform="translate({cx} {cy}) rotate({tilt})">'
            f'<circle r="35" fill="{SUN}"/>'
            f'<g stroke="{SUN}" stroke-width="11" stroke-linecap="round">{rays}</g></g>')


def silhouette(fill, stroke=None, width=0):
    """Union of every outer shape, used for the sticker outline and for masks."""
    attrs = f'fill="{fill}"'
    if stroke:
        attrs += f' stroke="{stroke}" stroke-width="{width}" stroke-linejoin="round"'
    feet = "".join(foot(x, y, r, fill, f'stroke="{stroke}" stroke-width="{width}"' if stroke else "")
                   for x, y, r in FEET)
    return (f'<g {attrs}>'
            f'<path d="{smooth(TAIL_PTS)}"/>'
            f'<path d="{smooth(BODY_PTS, corners=BODY_CORNERS)}"/>'
            + f'<path d="{LEFT_WING}"/><path d="{RIGHT_WING}"/>'
            + "".join(f'<path d="{poly(q)}"/>' for q in BOX.values())
            + f'</g>{feet}')


def character_svg(sticker=True, sticker_width=40):
    tilt = -4
    body_path = smooth(BODY_PTS, corners=BODY_CORNERS)
    top, front, side = BOX["top"], BOX["front"], BOX["side"]
    out = ['<defs>'
           '<radialGradient id="bodyShade" cx="0.42" cy="0.22" r="0.75">'
           f'<stop offset="0" stop-color="{BODY_HI}"/><stop offset="0.55" stop-color="{BODY}"/>'
           f'<stop offset="1" stop-color="{BODY_LO}"/></radialGradient>'
           '<linearGradient id="frontShade" x1="0" y1="0" x2="0" y2="1">'
           f'<stop offset="0" stop-color="#E3B37C"/><stop offset="1" stop-color="{BOX_FRONT}"/></linearGradient>'
           '<linearGradient id="footShade" x1="0" y1="0" x2="0" y2="1">'
           f'<stop offset="0.45" stop-color="{FOOT}"/><stop offset="1" stop-color="{FOOT_LO}"/></linearGradient>'
           '</defs>']
    if sticker:
        out.append(silhouette(STICKER, STICKER, sticker_width * 2))
    # tail, body
    out.append(f'<path d="{smooth(TAIL_PTS)}" fill="{TAIL}" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>')
    out.append(f'<path d="M168 812 C196 818 224 826 246 840" fill="none" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>')
    out.append(f'<path d="{body_path}" fill="url(#bodyShade)" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>')
    # belly sheen between the box and the feet
    out.append(f'<ellipse cx="560" cy="858" rx="190" ry="44" fill="{BODY_HI}" opacity="0.2"/>')
    # box
    out.append(f'<g stroke-linejoin="round">'
               f'<path d="{poly(side)}" fill="{BOX_SIDE}" stroke="{BOX_SIDE}" stroke-width="6"/>'
               f'<path d="{poly(front)}" fill="url(#frontShade)" stroke="{BOX_FRONT}" stroke-width="6"/>'
               f'<path d="{poly(top)}" fill="{BOX_TOP}" stroke="{BOX_TOP}" stroke-width="6"/></g>')
    out.append(f'<path d="{quad_region(top, 0.44, 0.58, 0, 1)}" fill="{TAPE_TOP}"/>')
    out.append(f'<path d="{quad_region(top, 0, 1, 0.40, 0.56)}" fill="{TAPE_TOP}"/>')
    out.append(f'<path d="{quad_region(front, 0.44, 0.58, 0, 0.24)}" fill="{TAPE_FRONT}"/>')
    out.append(f'<path d="{quad_region(side, 0.40, 0.56, 0, 0.26)}" fill="{TAPE_SIDE}"/>')
    out.append(f'<path d="M{top[3][0]} {top[3][1]} L{top[2][0]} {top[2][1]}" stroke="{BOX_EDGE}" stroke-width="5" stroke-linecap="round"/>')
    out.append(f'<path d="M{top[0][0]} {top[0][1]} L{top[3][0]} {top[3][1]}" stroke="{BOX_EDGE}" stroke-width="4" stroke-linecap="round" opacity="0.8"/>')
    # wings (fingers overlap the box)
    for wing in (LEFT_WING, RIGHT_WING):
        out.append(f'<path d="{wing}" fill="{WING}" stroke="{INK}" stroke-width="5" stroke-linejoin="round"/>')
    creases = "".join(f'<path d="{d}"/>' for d in LEFT_CREASES + RIGHT_CREASES)
    out.append(f'<g fill="none" stroke="{INK}" stroke-width="5" stroke-linecap="round">{creases}</g>')
    # feet
    for x, y, r in FEET:
        out.append(foot(x, y, r, FOOT, f'stroke="{FOOT}" stroke-width="2"'))
        out.append(foot_shading(x, y, r))
    # face
    out.append(sun(511, 179, tilt))
    out.append(f'<g fill="none" stroke="{INK}" stroke-width="10" stroke-linecap="round">'
               '<path d="M336 254 C352 236 378 230 396 236"/>'
               '<path d="M628 224 C648 212 672 214 686 228"/></g>')
    out.append(eye(381, 347, False, tilt))
    out.append(eye(657, 328, True, tilt))
    out.append(f'<g transform="rotate({tilt} 526 392)">'
               f'<ellipse cx="324" cy="426" rx="37" ry="23" fill="{BLUSH}"/>'
               f'<ellipse cx="724" cy="426" rx="37" ry="23" fill="{BLUSH}"/>'
               '<circle cx="316" cy="417" r="5" fill="#FFFFFF" opacity="0.9"/>'
               '<circle cx="732" cy="417" r="5" fill="#FFFFFF" opacity="0.9"/>'
               f'<path d="M472 418 C506 432 548 442 582 440 C570 454 538 458 510 450 C492 444 480 434 472 418 Z" fill="{BEAK_LO}" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>'
               f'<path d="M466 412 C468 372 500 340 536 340 C574 340 600 368 598 402 C597 420 590 434 582 440 C546 438 502 428 466 412 Z" fill="{BEAK}" stroke="{INK}" stroke-width="4" stroke-linejoin="round"/>'
               f'<path d="M548 356 C560 356 570 372 568 398 C566 408 560 408 556 400 C550 386 546 370 548 356 Z" fill="{BEAK_HI}" opacity="0.9"/>'
               '</g>')
    return "\n".join(out)


def placed(inner, scale, dx, dy):
    """Scale the character about the canvas centre and shift it."""
    return f'<g transform="translate({512 + dx} {512 + dy}) scale({scale}) translate(-512 -512)">{inner}</g>'


def svg_doc(inner):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{inner}</svg>'


def render(svg, path):
    """Rasterise a 1024×1024 SVG document to a PNG with a transparent background."""
    import skia
    dom = skia.SVGDOM.MakeFromStream(skia.MemoryStream(svg.encode()))
    dom.setContainerSize(skia.Size(1024, 1024))
    surface = skia.Surface(1024, 1024)
    canvas = surface.getCanvas()
    canvas.clear(skia.ColorTRANSPARENT)
    dom.render(canvas)
    surface.makeImageSnapshot().save(path, skia.kPNG)
