"""Pixel-art Yatagarasu: the same parcel-carrying crow as a hand-placed 32×32 sprite.

Each cell is 32×32 px on the 1024 icon canvas. `character_layer()` and `background_layer()`
return the icon's two RGBA layers: the crow with a cream sticker outline, and a stepped
sunrise (or night sky).
"""
import numpy as np
from PIL import Image

N, CELL = 32, 32

PALETTE = {
    "K": "#141519",  # ink: brows, creases
    "B": "#2B2C32",  # body
    "L": "#3B3C44",  # body light (crown sheen)
    "D": "#1F2025",  # body shadow
    "W": "#3A3B43",  # wing
    "e": "#0C0C0F",  # eye
    "w": "#FFFFFF",  # eye shine
    "P": "#55565E",  # beak
    "p": "#8A8B94",  # beak shine
    "Q": "#34353B",  # lower beak
    "R": "#F59AA5",  # blush
    "Y": "#FFC53D",  # sun mark
    "T": "#EFC995",  # box top
    "F": "#DDAB73",  # box front
    "S": "#C4915B",  # box side
    "t": "#C99760",  # tape on top
    "u": "#BD8853",  # tape on front
    "E": "#F8DDB0",  # box edge highlight
    "O": "#FF8A2A",  # foot
    "o": "#E8701A",  # foot shade
    "C": "#FFFBF2",  # sticker outline
}

# The sprite is described in local cells (col 0 = canvas col OX, row 0 = canvas row OY):
# a body silhouette by row, then features stamped on top.
OX, OY = 6, 3

SILHOUETTE = {  # row: (first col, last col)
    0: (6, 13), 1: (4, 15), 2: (3, 16), 3: (2, 17),
    **{r: (1, 18) for r in range(4, 14)},
    14: (0, 19),
    **{r: (-1, 20) for r in range(15, 22)},
    22: (0, 19), 23: (2, 17),
}

EYE = [".eee.", "ewwee", "ewwee", "eeeee", "eeewe", ".eee."]

STAMPS = [  # (col, row, rows of characters; "." leaves the cell unchanged)
    # crown sheen, crown tuft and cheek tufts
    (5, 1, ["LLL"]), (4, 2, ["LL"]), (3, 3, ["L"]),
    (0, 12, ["B"]), (19, 11, ["B"]),
    # sun mark
    (7, 1, ["Y.Y.Y", ".YYY.", "YYYYY", ".YYY.", "Y.Y.Y"]),
    # brows
    (3, 5, [".KK", "K.."]), (14, 5, ["KK.", "..K"]),
    # eyes
    (2, 7, EYE), (13, 7, EYE),
    # beak
    (8, 10, [".PP.", "PPpP", "PPPP", ".QQ."]),
    # blush
    (1, 13, ["RR"]), (17, 13, ["RR"]),
    # box: top face, side face, front face, tape
    (5, 14, ["TTTTTttTTTT"]),
    (4, 15, ["STTTTTttTTTTT"]),
    (4, 16, ["SEEEEEuuEEEEE"]),
    (4, 17, ["SFFFFFuuFFFFF"]),
    *[(4, r, ["SFFFFFFFFFFFF"]) for r in range(18, 22)],
    # left wing: three fingers over the box
    (-1, 15, ["BWW"]),
    (-1, 16, ["WWWW"]),
    (-1, 17, ["WWWWWW"]),
    (-1, 18, ["WWWKKW"]),
    (-1, 19, ["WWWWWW"]),
    (-1, 20, ["WWWKKW"]),
    (-1, 21, ["DWWWW"]),
    (-2, 21, ["D"]), (-2, 22, ["DD"]),
    # right wing
    (18, 16, ["WWW"]),
    (16, 17, ["WWWWW"]),
    (16, 18, ["WKKWW"]),
    (16, 19, ["WWWWW"]),
    (16, 20, ["WKKWW"]),
    (17, 21, ["WWWB"]),
    # feet
    (4, 22, ["O.O", "OOO", "ooo"]),
    (9, 22, ["O.O", "OOO", "ooo"]),
    (14, 22, ["O.O", "OOO", "ooo"]),
]


def grid():
    cells = [["."] * N for _ in range(N)]
    for r, (c0, c1) in SILHOUETTE.items():
        for c in range(c0, c1 + 1):
            cells[OY + r][OX + c] = "B"
    for c0, r0, rows in STAMPS:
        for dr, row in enumerate(rows):
            for dc, ch in enumerate(row):
                if ch != ".":
                    cells[OY + r0 + dr][OX + c0 + dc] = ch
    return ["".join(row) for row in cells]


SUNRISE = ["#FFF3DC", "#FFEBCB", "#FFE3BB", "#FFDAAB", "#FFD29E", "#FFCB92"]
NIGHT = ["#343B86", "#2E3478", "#282D6A", "#22265C", "#1C1F4E", "#171A42"]


def rgba(hex_, a=255):
    return tuple(int(hex_[i:i + 2], 16) for i in (1, 3, 5)) + (a,)


def outline(cells):
    """Cells adjacent (8-neighbourhood) to the sprite but not part of it."""
    filled = np.array([[c != "." for c in row] for row in cells])
    pad = np.pad(filled, 1)
    near = np.zeros_like(filled)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            near |= pad[1 + dy:1 + dy + N, 1 + dx:1 + dx + N]
    return near & ~filled


def paint(cells_rgba):
    img = np.zeros((N, N, 4), np.uint8)
    for (y, x), col in cells_rgba.items():
        img[y, x] = col
    return Image.fromarray(img, "RGBA").resize((N * CELL, N * CELL), Image.NEAREST)


def character_layer(sticker=True):
    cells = grid()
    out = {}
    if sticker:
        for y, x in zip(*np.nonzero(outline(cells))):
            out[(y, x)] = rgba(PALETTE["C"])
    for y, row in enumerate(cells):
        for x, c in enumerate(row):
            if c != ".":
                out[(y, x)] = rgba(PALETTE[c])
    return paint(out)


def background_layer(bands=SUNRISE):
    out = {}
    for y in range(N):
        band = bands[min(len(bands) - 1, y * len(bands) // N)]
        for x in range(N):
            out[(y, x)] = rgba(band)
    return paint(out)
