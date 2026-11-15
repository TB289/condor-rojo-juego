"""Pinta el arte del mapa, los módulos y el HUD de Cóndor Rojo.

No toca las hojas del astronauta: esas son las de PixelLab
(assets/art/characters/astronaut_*.png y pixellab/nohelmet/).

Rehacer el mundo y los iconos: py -3 tools/make_placeholders.py
"""
from PIL import Image
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "art")

# Paleta de 32. docs/art-style.md / assets/art/palette/condor_rojo.gpl
SAND_HI = (248, 224, 160, 255)
SAND_LT = (246, 200, 120, 255)
SAND = (232, 137, 58, 255)
OCHRE = (212, 160, 90, 255)
TERRA = (194, 74, 28, 255)
PATCH = (168, 72, 40, 255)
ROCK = (138, 46, 20, 255)
STONE = (196, 120, 72, 255)
SH_RED = (138, 48, 88, 255)
SH_PUR = (90, 36, 104, 255)
OUT = (58, 26, 40, 255)
DEEP = (26, 12, 20, 255)
FLASH = (255, 252, 232, 255)
METAL_LT = (240, 244, 248, 255)
METAL = (122, 140, 154, 255)
METAL_DK = (58, 72, 84, 255)
SOLAR = (42, 138, 184, 255)
CRYSTAL = (62, 212, 232, 255)
CRYSTAL_HI = (184, 244, 255, 255)
SUIT = (255, 248, 236, 255)
SUIT_SH = (184, 176, 164, 255)
RIM = (255, 232, 176, 255)
ORANGE = (255, 106, 32, 255)
YEL = (255, 224, 0, 255)
BLUE = (26, 76, 220, 255)
RED = (232, 16, 48, 255)
LEAF_HI = (180, 248, 106, 255)
LEAF = (140, 232, 70, 255)
LEAF_DK = (46, 138, 40, 255)
SKY_PINK = (255, 192, 168, 255)
SKY_OR = (255, 138, 88, 255)
VISOR = (20, 32, 48, 255)

PALETTE = {
    SAND_HI, SAND_LT, SAND, OCHRE, TERRA, PATCH, ROCK, STONE,
    SH_RED, SH_PUR, OUT, DEEP, FLASH, METAL_LT, METAL, METAL_DK,
    SOLAR, CRYSTAL, CRYSTAL_HI, SUIT, SUIT_SH, RIM, ORANGE, YEL,
    BLUE, RED, LEAF_HI, LEAF, LEAF_DK, SKY_PINK, SKY_OR, VISOR,
}


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.p = [[None] * w for _ in range(h)]

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h and c is not None:
            self.p[y][x] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.px(x, y, c)

    def ellipse(self, cx, cy, rx, ry, c):
        if rx <= 0 or ry <= 0:
            return
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                    self.px(x, y, c)

    def shade_ellipse(self, cx, cy, rx, ry, light, mid, dark):
        """Luz arriba a la izquierda. Tres tonos planos, sin degradado."""
        if rx <= 0 or ry <= 0:
            return
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                nx = (x + 0.5 - cx) / rx
                ny = (y + 0.5 - cy) / ry
                if nx * nx + ny * ny > 1:
                    continue
                sun = nx + ny
                col = light if sun < -0.25 else dark if sun > 0.45 else mid
                self.px(x, y, col)

    def clear_below(self, y0):
        for y in range(y0, self.h):
            for x in range(self.w):
                self.p[y][x] = None

    def line(self, x0, y0, x1, y1, c, thick=2):
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(steps + 1):
            t = i / steps
            x = int(round(x0 + (x1 - x0) * t))
            y = int(round(y0 + (y1 - y0) * t))
            self.rect(x, y, x + thick - 1, y + thick - 1, c)

    def outline(self, col=OUT):
        add = []
        for y in range(self.h):
            for x in range(self.w):
                if self.p[y][x] is not None:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < self.w and 0 <= yy < self.h and self.p[yy][xx] is not None:
                        add.append((x, y))
                        break
        for x, y in add:
            self.p[y][x] = col

    def shadow(self, cx, cy, rx, ry):
        """Óvalo de contacto, solo donde el sprite no pinta. Sin contorno."""
        for y in range(self.h):
            for x in range(self.w):
                if self.p[y][x] is not None:
                    continue
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                    self.p[y][x] = SH_PUR if x > cx else SH_RED

    def img(self):
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for y in range(self.h):
            for x in range(self.w):
                if self.p[y][x]:
                    im.putpixel((x, y), self.p[y][x])
        return im


def check(im, name):
    bad = set()
    pixels = im.load()
    for y in range(im.height):
        for x in range(im.width):
            px = pixels[x, y]
            if px[3] == 0:
                continue
            if px not in PALETTE:
                bad.add(px)
    if bad:
        raise SystemExit("%s tiene colores fuera de la paleta: %s" % (name, bad))


def save(c, folder, name, do_outline=True, shadow=None):
    if do_outline:
        c.outline()
    if shadow:
        c.shadow(*shadow)
    im = c.img()
    check(im, name)
    path = os.path.join(ROOT, folder, name)
    im.save(path)
    return im


def window(c, x0, y0, x1, y1):
    c.rect(x0, y0, x1, y1, METAL_DK)
    c.rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, CRYSTAL)
    c.rect(x0 + 1, y0 + 1, x0 + 2, y0 + 2, CRYSTAL_HI)


def door(c, x0, y0, x1, y1):
    c.rect(x0, y0, x1, y1, OUT)
    c.rect(x0 + 1, y0 + 1, x1 - 1, y1, METAL_DK)
    c.rect(x0 + 2, y0 + 2, x1 - 2, y1 - 1, DEEP)
    c.rect(x1 - 4, y0 + (y1 - y0) // 2, x1 - 3, y0 + (y1 - y0) // 2 + 2, ORANGE)


def flag_mark(c, x, y):
    c.rect(x, y, x + 4, y, YEL)
    c.rect(x, y + 1, x + 4, y + 1, BLUE)
    c.rect(x, y + 2, x + 4, y + 2, RED)


def plant(c, x, y):
    c.rect(x, y - 2, x + 2, y, LEAF_DK)
    c.rect(x - 3, y - 6, x + 1, y - 3, LEAF_DK)
    c.rect(x - 2, y - 5, x, y - 3, LEAF)
    c.rect(x + 1, y - 9, x + 4, y - 5, LEAF_DK)
    c.rect(x + 1, y - 8, x + 3, y - 6, LEAF_HI)


# ---------- suelo 16x16, atlas 4x2 (mismo orden que MarsMap) ----------
def ground(base, specks):
    c = Canvas(16, 16)
    c.rect(0, 0, 15, 15, base)
    for x, y, col in specks:
        c.px(x, y, col)
    return c


def pebble(c, x, y):
    c.px(x, y, STONE)
    c.px(x + 1, y, ROCK)
    c.px(x, y - 1, SAND_HI)
    c.px(x + 1, y + 1, PATCH)


SPECK_A = [
    (3, 3, SAND_LT), (8, 2, OCHRE), (12, 4, SAND_LT),
    (5, 7, OCHRE), (11, 8, PATCH), (2, 11, SAND_LT),
    (9, 12, OCHRE), (13, 11, TERRA), (6, 13, SAND_LT),
]
SPECK_B = [
    (4, 2, OCHRE), (10, 3, TERRA), (13, 6, OCHRE),
    (2, 6, SAND_LT), (7, 8, TERRA), (8, 8, PATCH),
    (12, 10, OCHRE), (5, 12, SAND_LT), (11, 13, TERRA),
]


def crater_tile():
    c = ground(SAND, SPECK_A)
    c.ellipse(8, 9, 6.2, 4.4, STONE)
    c.ellipse(8, 9.4, 4.6, 3.1, ROCK)
    c.ellipse(8.4, 10, 2.8, 1.8, DEEP)
    c.ellipse(7, 6.2, 4.2, 1.2, SAND_HI)
    c.px(5, 7, RIM)
    c.px(10, 7, STONE)
    return c


def rock_tile():
    c = ground(SAND, [(4, 3, SAND_LT), (12, 5, OCHRE), (3, 12, PATCH)])
    c.ellipse(8, 11, 5.2, 2.2, SH_PUR)
    c.ellipse(8, 9, 4.4, 3.6, OUT)
    c.shade_ellipse(8, 8.2, 3.5, 2.8, SAND_LT, STONE, ROCK)
    c.px(6, 7, SAND_HI)
    c.px(7, 7, RIM)
    return c


def crack_tile():
    c = Canvas(16, 16)
    path = [(2, 6), (3, 6), (4, 7), (5, 7), (6, 8), (7, 8), (8, 9), (9, 8), (10, 9), (11, 10), (12, 10), (13, 11)]
    for x, y in path:
        c.px(x, y - 1, SAND_LT)
        c.px(x, y, ROCK)
        c.px(x, y + 1, DEEP)
        c.px(x, y + 2, SH_PUR)
    return c


def dust_tile():
    c = Canvas(16, 16)
    for x, y in ((4, 6), (5, 6), (6, 5), (6, 6), (7, 6), (8, 7), (5, 7), (9, 6), (7, 5), (10, 8), (4, 7)):
        c.px(x, y, SAND_HI if (x + y) % 2 == 0 else SAND_LT)
    c.px(8, 8, RIM)
    return c


def paint_tiles():
    tiles = [
        ground(SAND, SPECK_A),
        ground(SAND, SPECK_B),
        ground(SAND, [(3, 4, OCHRE), (11, 12, SAND_LT)]),
        ground(OCHRE, [
            (3, 4, SAND_LT), (6, 8, SAND), (10, 3, SAND_LT),
            (12, 9, STONE), (4, 12, SAND), (8, 6, SAND_HI), (13, 13, SAND_LT),
        ]),
        crater_tile(),
        rock_tile(),
        crack_tile(),
        dust_tile(),
    ]
    pebble(tiles[2], 5, 9)
    pebble(tiles[2], 11, 6)
    atlas = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    for i, tile in enumerate(tiles):
        im = tile.img()
        check(im, "tile %d" % i)
        atlas.paste(im, (16 * (i % 4), 16 * (i // 4)))
    check(atlas, "mars_tiles_16")
    atlas.save(os.path.join(ROOT, "tiles", "mars_tiles_16.png"))


def paint_props():
    sheet = Image.new("RGBA", (96, 32), (0, 0, 0, 0))
    # cráter mediano
    c = Canvas(32, 32)
    c.ellipse(16, 20, 13, 6.5, STONE)
    c.ellipse(16, 21, 10, 4.6, ROCK)
    c.ellipse(16.5, 22, 6.5, 2.6, DEEP)
    c.ellipse(14, 16.2, 9, 1.5, SAND_HI)
    c.px(8, 17, RIM)
    c.px(20, 16, STONE)
    c.outline()
    im = c.img()
    check(im, "crater prop")
    sheet.paste(im, (0, 0), im)
    # roca mediana
    c = Canvas(32, 32)
    c.shade_ellipse(16, 18, 9, 7.2, SAND_LT, STONE, ROCK)
    c.px(10, 14, SAND_HI)
    c.px(11, 14, RIM)
    c.px(12, 15, SAND_LT)
    save_part = c
    save_part.outline()
    save_part.shadow(18, 27, 10, 2.2)
    im = save_part.img()
    check(im, "rock med")
    sheet.paste(im, (32, 0), im)
    # roca grande, dos lóbulos
    c = Canvas(32, 32)
    c.shade_ellipse(12, 18, 8, 6.5, SAND_LT, STONE, ROCK)
    c.shade_ellipse(21, 19, 7, 6, OCHRE, STONE, ROCK)
    c.px(7, 14, SAND_HI)
    c.px(8, 15, RIM)
    c.px(18, 15, SAND_LT)
    c.outline()
    c.shadow(18, 28, 13, 2.2)
    im = c.img()
    check(im, "rock large")
    sheet.paste(im, (64, 0), im)
    check(sheet, "mars_props_32")
    sheet.save(os.path.join(ROOT, "tiles", "mars_props_32.png"))


# ---------- módulos ----------
def paint_habitat():
    c = Canvas(64, 48)
    c.shade_ellipse(32, 24, 24, 14, SUIT, SUIT_SH, SH_RED)
    c.clear_below(34)
    c.rect(7, 30, 56, 43, SUIT)
    c.rect(40, 30, 56, 43, SUIT_SH)
    c.rect(50, 32, 56, 43, SH_RED)
    c.rect(7, 40, 56, 43, METAL)
    c.rect(7, 33, 56, 34, ORANGE)
    c.rect(7, 35, 56, 35, RED)
    door(c, 26, 28, 38, 43)
    window(c, 12, 20, 21, 27)
    window(c, 43, 20, 52, 27)
    flag_mark(c, 10, 37)
    c.px(20, 14, FLASH)
    c.px(21, 14, RIM)
    c.px(22, 15, RIM)
    c.px(18, 16, SUIT)
    save(c, "base", "habitat.png", shadow=(36, 45.5, 24, 2.4))


def paint_greenhouse():
    c = Canvas(64, 48)
    c.shade_ellipse(32, 24, 24, 14, CRYSTAL_HI, CRYSTAL, SOLAR)
    c.clear_below(34)
    for x in range(12, 54, 8):
        for y in range(12, 34):
            if c.p[y][x] is not None:
                c.p[y][x] = METAL_DK
                if x + 1 < 64 and c.p[y][x + 1] is not None and x not in (28, 36):
                    c.p[y][x + 1] = METAL
    c.rect(7, 31, 56, 43, METAL)
    c.rect(44, 32, 56, 43, METAL_DK)
    c.rect(7, 40, 56, 43, METAL_DK)
    c.rect(7, 33, 56, 34, LEAF_DK)
    for x in (12, 18, 44, 50):
        plant(c, x, 32)
    door(c, 26, 28, 38, 43)
    c.px(18, 14, FLASH)
    c.px(19, 15, CRYSTAL_HI)
    save(c, "base", "greenhouse.png", shadow=(36, 45.5, 24, 2.4))


def paint_solar():
    c = Canvas(48, 32)
    c.rect(9, 18, 12, 28, METAL)
    c.rect(11, 18, 12, 28, METAL_DK)
    c.rect(35, 18, 38, 28, METAL)
    c.rect(37, 18, 38, 28, METAL_DK)
    for y in range(5, 19):
        shift = (18 - y) // 5
        x0, x1 = 4 + shift, 43 + shift
        for x in range(x0, x1 + 1):
            c.px(x, y, METAL_DK)
    for y in range(7, 17):
        shift = (18 - y) // 5
        for x in range(6 + shift, 41 + shift):
            on_grid = (x - shift) % 7 == 0 or y == 11
            c.px(x, y, METAL if on_grid else SOLAR)
        c.px(7 + shift, y, CRYSTAL_HI if y < 10 else SOLAR)
    c.px(8, 8, FLASH)
    c.px(9, 8, CRYSTAL_HI)
    save(c, "base", "solar_panel.png", shadow=(26, 29.5, 18, 2.1))


def paint_tanks():
    c = Canvas(32, 32)

    def tank(x):
        c.rect(x, 8, x + 11, 26, SUIT)
        c.rect(x + 7, 8, x + 11, 26, SUIT_SH)
        c.rect(x + 10, 8, x + 11, 26, SH_RED)
        c.ellipse(x + 5.5, 8, 6, 3.2, SUIT)
        c.ellipse(x + 8, 8, 3.2, 2.4, SUIT_SH)
        c.rect(x, 15, x + 11, 18, CRYSTAL)
        c.rect(x + 8, 15, x + 11, 18, SOLAR)
        c.rect(x + 4, 3, x + 7, 6, ORANGE)
        c.px(x + 5, 4, YEL)
        c.px(x + 2, 10, FLASH)
        c.px(x + 3, 11, RIM)

    tank(2)
    tank(17)
    save(c, "base", "oxygen_tank.png", shadow=(18, 29.2, 13, 2.0))


def paint_antenna():
    c = Canvas(32, 48)
    c.rect(8, 40, 23, 45, METAL_DK)
    c.rect(9, 41, 16, 44, METAL)
    c.rect(14, 20, 17, 40, METAL)
    c.rect(16, 20, 17, 40, METAL_DK)
    c.shade_ellipse(15, 16, 11, 8, SUIT, METAL_LT, METAL)
    c.shade_ellipse(16, 17, 6, 4.5, METAL, METAL_DK, VISOR)
    c.rect(15, 16, 16, 22, METAL_DK)
    c.px(21, 11, RED)
    c.px(22, 11, YEL)
    c.px(8, 12, FLASH)
    c.px(9, 13, RIM)
    save(c, "base", "antenna_dish.png", shadow=(18, 46.2, 11, 1.8))


def paint_rover():
    c = Canvas(48, 32)
    c.rect(8, 12, 40, 21, SUIT)
    c.rect(28, 12, 40, 21, SUIT_SH)
    c.rect(36, 13, 40, 21, SH_RED)
    c.rect(8, 16, 40, 17, ORANGE)
    c.rect(26, 6, 41, 13, SUIT)
    c.rect(36, 6, 41, 13, SUIT_SH)
    window(c, 28, 7, 39, 12)
    c.rect(10, 8, 11, 12, METAL_DK)
    c.px(10, 7, RED)
    c.px(11, 7, YEL)
    flag_mark(c, 14, 13)
    for x in (12, 24, 35):
        c.ellipse(x, 23, 5.2, 5.2, OUT)
        c.ellipse(x, 23, 3.6, 3.6, METAL_DK)
        c.ellipse(x - 0.6, 22, 1.5, 1.5, METAL_LT)
    save(c, "base", "rover.png", shadow=(26, 29.4, 18, 2.0))


def paint_lander():
    c = Canvas(64, 64)
    c.shade_ellipse(32, 28, 18, 15, SUIT, SUIT_SH, SH_RED)
    c.clear_below(40)
    c.line(16, 38, 8, 54, METAL, 2)
    c.line(48, 38, 56, 54, METAL, 2)
    c.line(26, 40, 20, 56, METAL, 2)
    c.line(38, 40, 44, 56, METAL, 2)
    for x in (5, 17, 41, 53):
        c.rect(x, 54, x + 7, 56, METAL_DK)
        c.rect(x, 54, x + 4, 54, METAL)
    c.rect(14, 34, 49, 46, METAL_LT)
    c.rect(36, 34, 49, 46, METAL)
    c.rect(44, 36, 49, 46, SH_RED)
    c.rect(14, 33, 49, 34, ORANGE)
    c.rect(14, 35, 49, 35, RED)
    window(c, 23, 18, 41, 28)
    door(c, 27, 36, 37, 46)
    flag_mark(c, 16, 37)
    c.rect(30, 10, 33, 16, METAL)
    c.px(31, 9, RED)
    c.px(32, 9, YEL)
    c.px(22, 18, FLASH)
    c.px(23, 19, RIM)
    save(c, "base", "lander.png", shadow=(36, 59.5, 26, 2.6))


def paint_flag():
    c = Canvas(16, 32)
    c.rect(1, 4, 2, 29, METAL)
    c.rect(2, 4, 2, 29, METAL_DK)
    c.px(1, 3, YEL)
    c.px(2, 3, ORANGE)
    bands = (
        (4, 11, YEL),
        (12, 15, BLUE),
        (16, 19, RED),
    )
    for y0, y1, col in bands:
        for y in range(y0, y1 + 1):
            fly = 13 if (y % 3) != 2 else 12
            shade = SH_RED if col == RED else (BLUE if col == BLUE else OCHRE)
            c.rect(4, y, fly, y, col)
            c.px(fly, y, shade)
            if col == YEL and y < 7:
                c.px(5, y, RIM)
    save(c, "base", "flag_ecuador.png", shadow=(6, 30.2, 5, 1.3))


def paint_crates():
    c = Canvas(32, 32)
    c.rect(15, 13, 28, 27, OCHRE)
    c.rect(15, 13, 28, 16, SAND_LT)
    c.rect(24, 16, 28, 27, PATCH)
    c.rect(19, 19, 22, 22, LEAF)
    c.px(20, 20, LEAF_HI)
    c.rect(3, 9, 17, 27, SUIT)
    c.rect(3, 9, 17, 12, FLASH)
    c.rect(13, 12, 17, 27, SUIT_SH)
    c.rect(7, 17, 11, 20, CRYSTAL)
    c.px(8, 18, CRYSTAL_HI)
    c.rect(5, 23, 15, 23, ORANGE)
    save(c, "base", "crates.png", shadow=(16, 29.4, 13, 1.8))


# ---------- HUD ----------
def paint_oxygen():
    c = Canvas(16, 16)
    c.ellipse(8, 8, 5.6, 5.6, CRYSTAL)
    c.ellipse(6.4, 6.6, 2.4, 2.2, CRYSTAL_HI)
    c.px(6, 6, FLASH)
    c.ellipse(12.2, 3.2, 1.7, 1.7, CRYSTAL)
    c.px(12, 3, FLASH)
    save(c, "ui", "icon_oxygen.png")


def paint_energy():
    c = Canvas(16, 16)
    bolts = [
        (8, 1), (9, 1), (10, 1),
        (7, 2), (8, 2), (9, 2),
        (6, 3), (7, 3), (8, 3),
        (5, 4), (6, 4), (7, 4), (8, 4),
        (4, 5), (5, 5), (6, 5), (7, 5), (8, 5), (9, 5),
        (5, 6), (6, 6), (7, 6), (8, 6), (9, 6), (10, 6),
        (7, 7), (8, 7), (9, 7), (10, 7), (11, 7),
        (8, 8), (9, 8), (10, 8),
        (7, 9), (8, 9), (9, 9),
        (6, 10), (7, 10), (8, 10),
        (5, 11), (6, 11), (7, 11),
        (4, 12), (5, 12), (6, 12),
        (4, 13), (5, 13),
    ]
    for x, y in bolts:
        c.px(x, y, YEL if x < 8 else ORANGE)
    c.px(8, 2, FLASH)
    save(c, "ui", "icon_energy.png")


def paint_food():
    c = Canvas(16, 16)
    c.ellipse(8, 9, 5.2, 5.0, LEAF)
    c.ellipse(6.5, 7.5, 2.2, 1.8, LEAF_HI)
    c.px(6, 7, FLASH)
    c.rect(7, 2, 8, 5, LEAF_DK)
    c.ellipse(11, 4, 2.4, 1.5, LEAF)
    c.px(11, 3, LEAF_HI)
    save(c, "ui", "icon_food.png")


def paint_water():
    c = Canvas(16, 16)
    for y, half in (
        (2, 0), (3, 1), (4, 2), (5, 3), (6, 4), (7, 4), (8, 4),
        (9, 4), (10, 3), (11, 3), (12, 2), (13, 1), (14, 0),
    ):
        xs = (8,) if half == 0 else range(8 - half, 8 + half)
        for x in xs:
            c.px(x, y, CRYSTAL if x < 8 else BLUE)
    c.px(6, 6, FLASH)
    c.px(6, 7, CRYSTAL_HI)
    save(c, "ui", "icon_water.png")


def paint_inti():
    c = Canvas(32, 32)
    rays = (
        (16, 2, 0, 1), (16, 28, 0, -1),
        (2, 15, 1, 0), (28, 15, -1, 0),
        (6, 6, 1, 1), (24, 6, -1, 1),
        (6, 24, 1, -1), (24, 24, -1, -1),
    )
    for x, y, dx, dy in rays:
        for i in range(5):
            col = YEL if i < 3 else ORANGE
            c.px(x + dx * i, y + dy * i, col)
            c.px(x + dx * i + (1 if dy == 0 else 0), y + dy * i + (1 if dx == 0 else 0), col)
    c.shade_ellipse(16, 16, 9.2, 9.2, YEL, RIM, ORANGE)
    c.ellipse(16, 16, 4.2, 4.2, CRYSTAL)
    c.ellipse(15, 15, 1.6, 1.6, CRYSTAL_HI)
    c.px(14, 14, FLASH)
    save(c, "ui", "inti_avatar.png", shadow=None)


def main():
    paint_tiles()
    paint_props()
    paint_habitat()
    paint_greenhouse()
    paint_solar()
    paint_tanks()
    paint_antenna()
    paint_rover()
    paint_lander()
    paint_flag()
    paint_crates()
    paint_oxygen()
    paint_energy()
    paint_food()
    paint_water()
    paint_inti()
    print("arte de mapa, modulos y HUD listo (hojas del astronauta sin tocar)")


if __name__ == "__main__":
    main()
