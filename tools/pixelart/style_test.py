"""Generate the pixel-art style test for Gloamhold.

Writes to assets/art/style_test/:
  palette.gpl / palette.png   the shared colour palette (.gpl opens in Aseprite)
  tiles/, props/, chars/      individual sprites, each with a *_n.png normal map
  sheet_x4.png                every sprite on one sheet, 4x, with labels
  mockup_960x540.png          a lit test scene at the game's base resolution
  mockup_1920x1080.png        the same, scaled x2 (how it looks on a 1080p screen)
  mockup_detail_x3.png        a x3 close-up of the middle of the scene

Everything is drawn from code so it's reproducible and editable. Characters are
hand-authored pixel grids (see CHARS); tiles and props are procedural.
Run:  python3 tools/pixelart/style_test.py
"""
import os, math, random
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "art", "style_test")

# --- Palette -------------------------------------------------------------------
PALETTE = {
    # Stone and shadow: cold blue-violet greys
    "void": "0d0b14", "stone0": "17141f", "stone1": "221d2c", "stone2": "2e2839",
    "stone3": "3b3447", "stone4": "4b4357", "stone5": "5e5569", "stone6": "74697d", "stone7": "8d8296",
    # Water
    "water0": "0a1420", "water1": "10223a", "water2": "1a3554", "water3": "2a5276", "water4": "4a7a9c", "water5": "8fb5c9",
    # Firelight
    "fire0": "3a1a0e", "fire1": "6e2a12", "fire2": "a8441a", "fire3": "d9712b", "fire4": "f2a541", "fire5": "ffd77a", "fire6": "fff3c4",
    # Wood and leather
    "wood0": "3a2616", "wood1": "5a3b22", "wood2": "7d5532", "wood3": "a07443",
    # The Rift's glow
    "rift0": "0f2e2c", "rift1": "1f5a50", "rift2": "3f9a86", "rift3": "8fe0c8",
    # Danger / imperial red
    "red0": "4a1418", "red1": "8a2a2a", "red2": "c4483c",
    # Skin and cloth
    "skin0": "6b4a3a", "skin1": "9c7058", "skin2": "c99a78", "rag0": "74697d", "rag1": "b8a888", "rag2": "e8dcc0",
    # Metal
    "metal0": "3c4048", "metal1": "626a75", "metal2": "9aa3ad",
}
def rgb(name):
    h = PALETTE[name]
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

def write_palette():
    with open(os.path.join(OUT, "palette.gpl"), "w") as f:
        f.write("GIMP Palette\nName: Gloamhold\nColumns: 8\n#\n")
        for name in PALETTE:
            r, g, b = rgb(name)
            f.write(f"{r:3d} {g:3d} {b:3d}\t{name}\n")
    sw = Image.new("RGB", (8 * 16, math.ceil(len(PALETTE) / 8) * 16))
    d = ImageDraw.Draw(sw)
    for i, name in enumerate(PALETTE):
        x, y = (i % 8) * 16, (i // 8) * 16
        d.rectangle([x, y, x + 15, y + 15], fill=rgb(name))
    sw.resize((sw.width * 4, sw.height * 4), Image.NEAREST).save(os.path.join(OUT, "palette.png"))

# --- Helpers ---------------------------------------------------------------------
def canvas(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))

def put(img, x, y, name):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), rgb(name) + (255,))

def ramp(names, t):
    """Pick a colour from a ramp by t in 0..1."""
    i = max(0, min(len(names) - 1, int(t * len(names))))
    return names[i]

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
def dither(x, y, t, names):
    """Ordered dithering between ramp steps: hand-made-looking gradients."""
    n = len(names) - 1
    v = t * n
    lo = int(math.floor(v)); frac = v - lo
    lo = max(0, min(n, lo)); hi = min(n, lo + 1)
    return names[hi] if frac > BAYER[y % 4, x % 4] else names[lo]

# --- Tiles (32x32) -----------------------------------------------------------------
def floor_tile(seed, cracked=False):
    rnd = random.Random(seed)
    img = canvas(32, 32)
    # Two rows of flagstones with offset joints.
    joints = [(0, rnd.randint(10, 22)), (16, rnd.randint(4, 14))]
    for y in range(32):
        row = 0 if y < 16 else 1
        jx = joints[row][1]
        for x in range(32):
            mortar = (y % 16 == 0) or ((x - jx) % 32 == 0)
            if mortar:
                put(img, x, y, "stone0"); continue
            # Per-stone shade + bevel: lighter on top-left edges, darker bottom-right.
            local_y = y % 16
            local_x = (x - jx) % 32
            t = 0.45 + 0.08 * math.sin(seed * 3.1 + row * 1.7 + (1 if x > jx else 0))
            if local_y == 1 or local_x == 1: t += 0.25
            if local_y == 15 or local_x == 31: t -= 0.25
            t += (rnd.random() - 0.5) * 0.05
            put(img, x, y, dither(x, y, max(0, min(1, t)), ["stone2", "stone2", "stone3", "stone3"]))
    # Pits and pocks.
    for _ in range(5):
        put(img, rnd.randint(2, 29), rnd.randint(2, 29), "stone1")
    if cracked:
        x, y = rnd.randint(6, 12), rnd.randint(4, 10)
        for _ in range(16):
            put(img, x, y, "stone0"); put(img, x + 1, y, "stone1")
            x += rnd.choice([0, 1, 1]); y += rnd.choice([1, 1, 0])
    return img

def wall_face_tile(seed):
    """The vertical face of a wall, seen in 3/4 view: bricks with a dark base."""
    rnd = random.Random(seed)
    img = canvas(32, 32)
    for y in range(32):
        course = y // 8
        off = 0 if course % 2 == 0 else 8
        for x in range(32):
            if y % 8 == 0 or (x + off) % 16 == 0:
                put(img, x, y, "stone1"); continue
            t = 0.55 - (y / 32) * 0.35 + (rnd.random() - 0.5) * 0.05
            if y % 8 == 1: t += 0.2
            put(img, x, y, dither(x, y, max(0, min(1, t)), ["stone2", "stone3", "stone4", "stone5"]))
    for x in range(32):  # contact shadow at the foot of the wall
        put(img, x, 31, "stone0"); put(img, x, 30, "stone1")
    return img

def wall_top_tile(seed):
    """The top of a wall: dark capstones with a pale lip on the front edge."""
    rnd = random.Random(seed)
    img = canvas(32, 32)
    for y in range(32):
        for x in range(32):
            t = 0.4 + (rnd.random() - 0.5) * 0.04
            put(img, x, y, dither(x, y, t, ["stone1", "stone1", "stone2"]))
    for x in range(32):
        put(img, x, 31, "stone6"); put(img, x, 30, "stone5")
        if x % 16 == 0: put(img, x, 30, "stone2")
    return img

# --- Props ----------------------------------------------------------------------
def crate():
    img = canvas(32, 32)
    for y in range(3, 31):
        for x in range(2, 30):
            plank = (y - 3) // 7
            t = 0.55 + 0.1 * ((plank * 7) % 3 - 1) - (y - 3) / 56
            if (y - 3) % 7 == 0: t = 0.15
            put(img, x, y, dither(x, y, max(0, min(1, t)), ["wood0", "wood1", "wood2", "wood3"]))
    for i in range(26):  # diagonal brace
        put(img, 3 + i, 4 + i, "wood3"); put(img, 4 + i, 4 + i, "wood1")
    for x in range(2, 30):
        put(img, x, 3, "wood3"); put(img, x, 30, "wood0")
    for y in range(3, 31):
        put(img, 2, y, "wood0"); put(img, 29, y, "wood0")
    for (x, y) in [(4, 5), (27, 5), (4, 28), (27, 28)]:  # iron nails
        put(img, x, y, "metal2")
    return img

def barricade():
    """Waist-high stone rubble barricade, 64x24."""
    rnd = random.Random(7)
    img = canvas(64, 24)
    for i in range(14):
        cx, cy = rnd.randint(5, 58), rnd.randint(8, 19)
        r = rnd.randint(4, 7)
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r - 1, cx + r + 2):
                d = ((x - cx) / (r + 1)) ** 2 + ((y - cy) / r) ** 2
                if d <= 1:
                    t = 0.75 - (y - cy + r) / (2 * r) * 0.6
                    put(img, x, y, dither(x, y, max(0, min(1, t)), ["stone2", "stone3", "stone4", "stone5", "stone6"]))
    return img

def torch(frame):
    img = canvas(16, 24)
    for y in range(14, 22):  # bracket
        put(img, 7, y, "metal1"); put(img, 8, y, "metal0")
    for x in range(5, 11):
        put(img, x, 13, "metal1"); put(img, x, 21, "metal0")
    flame = [(8, 3), (7, 4), (8, 4), (7, 5), (8, 5), (9, 5), (6, 6), (7, 6), (8, 6), (9, 6),
             (6, 7), (7, 7), (8, 7), (9, 7), (6, 8), (7, 8), (8, 8), (9, 8), (7, 9), (8, 9), (7, 10), (8, 10), (7, 11), (8, 11), (7, 12), (8, 12)]
    sway = [0, 1, 0, -1][frame % 4]
    for (x, y) in flame:
        core = abs(x - 7.5) < 1 and y > 6
        name = "fire6" if core and y > 8 else ("fire5" if core else ("fire4" if y > 7 else "fire3"))
        put(img, x + (sway if y < 7 else 0), y, name)
    return img

def brazier():
    img = canvas(32, 32)
    for y in range(16, 30):  # bowl
        for x in range(4, 28):
            d = ((x - 15.5) / 12) ** 2 + ((y - 16) / 13) ** 2
            if d <= 1 and y >= 16:
                put(img, x, y, dither(x, y, 0.6 - (y - 16) / 26, ["metal0", "metal1", "metal2"]))
    for x in range(5, 27):
        put(img, x, 16, "fire2" if x % 3 else "fire4")  # glowing coals
        put(img, x, 17, "fire1")
    rnd = random.Random(3)
    for _ in range(30):  # flames
        x = rnd.randint(8, 23); h = rnd.randint(3, 13)
        for y in range(16 - h, 16):
            put(img, x, y, "fire5" if y > 16 - h / 2 else "fire3")
    for x in range(11, 21):
        for y in range(8, 16):
            if ((x - 15.5) / 5) ** 2 + ((y - 12.5) / 4.2) ** 2 <= 1:
                put(img, x, y, "fire6" if y > 10 else "fire5")
    return img

# --- Characters (hand-authored pixel grids) -----------------------------------------
COLORS = {
    "o": "void", "h": "wood0", "s": "skin2", "S": "skin1", "e": "stone0",
    "r": "rag1", "R": "rag0", "b": "wood1", "B": "wood2", "m": "metal1", "M": "metal2", "k": "metal0",
    "p": "stone3", "P": "stone2", "t": "red1", "T": "red0", "g": "stone6", "G": "stone5",
    "c": "metal2", "f": "wood2", "F": "wood1", "d": "wood0", "E": "red2", "w": "rag2", "n": "void",
}
CHARS = {
    "prisoner": [
        "......oooo......",
        ".....ohhhho.....",
        "....ohhhhhho....",
        "....ohhhhhho....",
        "....ohssssho....",
        "....osesseso....",
        "....oSssssSo....",
        ".....oSSSSo.....",
        "....orrssrro....",
        "...orrrrrrrro...",
        "..orrrRrrRrrro..",
        "..osrrRrrRrrso..",
        "..osrrrRRrrrso..",
        "..osrrrrrrrrso..",
        "..oSbbbbbbbbSo..",
        "..omrrrrrrrrmo..",
        "..oorrRrrRrroo..",
        "....orrrrrro....",
        "....oRrrrrRo....",
        "....oppppppo....",
        "....opppPppo....",
        "....oppo.oppo...",
        "....oppo.oppo...",
        "....oPpo.oPpo...",
        "....oSSo.oSSo...",
        "....oooo.oooo...",
    ],
    "guard": [
        "......oooo......",
        ".....oMMmmo.....",
        "....oMMmmmmo....",
        "....oMmmmmko....",
        "....okEeeEko....",
        "....omkkkkmo....",
        "...oommmmmmoo...",
        "..oMmmttttmmko..",
        "..oMmtttttTmko..",
        "..okmtttMtTmko..",
        "..okmttttTTmko..",
        "..okbbbbbbbbko..",
        "..oktttttTTTko..",
        "...ottttTTTTo...",
        "....okkkkkko....",
        "....okpppkko....",
        "....okko.okko...",
        "....okko.okko...",
        "....omko.omko...",
        "....oMko.oMko...",
        "...okkko.okkko..",
        "...ooooo.ooooo..",
    ],
    "gaoler": [
        "..........oooo..........",
        ".........oggggo.........",
        "........oggEEggo........",
        "........oGggggGo........",
        "...oooooooGGGGooooooo...",
        "..oMMmmmmkoGGokmmmmMMo..",
        ".oMMmmmmmkbbbbkmmmmmMMo.",
        ".oMMmmmmmkbbbbkmmmmmMMo.",
        ".okmmmmmkbBBBBbkmmmmmko.",
        ".okkkkkkbBBcBBBbkkkkkko.",
        "..oggGobBBBcBBBboGggo...",
        "..oggGobBBBcBBBboGggo...",
        "..oggGobBBBBcBBboGggo...",
        "..oggGobBBBBcBBboGggo...",
        "..oGGGobBBBBBcBboGGGo...",
        "..okkkobbbbbbbbbokkko...",
        "..okMkobbbbbbbbbokMko...",
        "...ooo.obBBBBBBbo.ooo...",
        ".......obBBBBBBbo.......",
        ".......obbbbbbbbo.......",
        "......obbbo..obbbo......",
        "......obBbo..obBbo......",
        "......obBbo..obBbo......",
        "......okmko..okmko......",
        "......okmko..okmko......",
        "......okMko..okMko......",
        ".....okkkko..okkkko.....",
        ".....oooooo..oooooo.....",
    ],
    "hound": [
        "..................oo....",
        ".................ofo....",
        "....ooooooooooooofFoo...",
        "...ofFFffffffffffEffo...",
        "..ofFFFfffffffffffffno..",
        ".odFFFffffffffffffwwwo..",
        "od.oFFffffffffffffoo....",
        "o...ofFFffffffffffo.....",
        "....ofo.ofo...ofo.ofo...",
        "....ofo.ofo...ofo.ofo...",
        "....odo.odo...odo.odo...",
        "....oo..oo....oo..oo....",
    ],
}

def char_sprite(name, w, h):
    rows = CHARS[name]
    bw = max(len(r) for r in rows)
    img = canvas(w, h)
    ox = (w - bw) // 2
    oy = h - len(rows) - 1
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                put(img, ox + x, oy + y, COLORS[ch])
    return img

# --- Normal maps -------------------------------------------------------------------
def normal_map(img, strength=2.0, bevel=True):
    """Height from luminance (+ a bevel from the silhouette), then Sobel -> normal map."""
    a = np.asarray(img).astype(np.float32) / 255.0
    lum = 0.3 * a[..., 0] + 0.59 * a[..., 1] + 0.11 * a[..., 2]
    alpha = a[..., 3]
    height = lum.copy()
    if bevel:
        # Distance-to-edge style bevel so silhouettes look rounded.
        m = alpha > 0.5
        dist = np.zeros_like(height)
        cur = m.copy()
        for i in range(1, 5):
            shrunk = cur.copy()
            shrunk[1:, :] &= cur[:-1, :]; shrunk[:-1, :] &= cur[1:, :]
            shrunk[:, 1:] &= cur[:, :-1]; shrunk[:, :-1] &= cur[:, 1:]
            dist += shrunk
            cur = shrunk
        height = height * 0.6 + dist / 4.0 * 0.4
    hp = np.pad(height, 1, mode="edge")
    dx = (hp[1:-1, 2:] - hp[1:-1, :-2]) * strength
    dy = (hp[2:, 1:-1] - hp[:-2, 1:-1]) * strength
    nz = np.ones_like(dx)
    n = np.stack([-dx, -dy, nz], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    out = ((n * 0.5 + 0.5) * 255).astype(np.uint8)
    out = np.concatenate([out, (alpha * 255).astype(np.uint8)[..., None]], axis=-1)
    return Image.fromarray(out, "RGBA")

# --- Build sprites -------------------------------------------------------------------
def build():
    sprites = {
        "tiles/floor_a": floor_tile(1), "tiles/floor_b": floor_tile(2), "tiles/floor_cracked": floor_tile(3, True),
        "tiles/wall_face": wall_face_tile(4), "tiles/wall_top": wall_top_tile(5),
        "props/crate": crate(), "props/barricade": barricade(), "props/brazier": brazier(),
        "props/torch_0": torch(0), "props/torch_1": torch(1), "props/torch_2": torch(2), "props/torch_3": torch(3),
        "chars/prisoner": char_sprite("prisoner", 24, 32), "chars/guard": char_sprite("guard", 24, 32),
        "chars/gaoler": char_sprite("gaoler", 32, 40), "chars/hound": char_sprite("hound", 32, 20),
    }
    for path, img in sprites.items():
        full = os.path.join(OUT, path + ".png")
        os.makedirs(os.path.dirname(full), exist_ok=True)
        img.save(full)
        normal_map(img, bevel=not path.startswith("tiles")).save(os.path.join(OUT, path + "_n.png"))
    return sprites

def sheet(sprites):
    scale, pad = 4, 12
    items = list(sprites.items())
    cols = 6
    cell_w = 40 * scale + pad; cell_h = 40 * scale + pad + 14
    rows = math.ceil(len(items) / cols)
    img = Image.new("RGB", (cols * cell_w + pad, rows * cell_h + pad), rgb("stone1"))
    d = ImageDraw.Draw(img)
    for i, (name, spr) in enumerate(items):
        x = pad + (i % cols) * cell_w; y = pad + (i // cols) * cell_h
        big = spr.resize((spr.width * scale, spr.height * scale), Image.NEAREST)
        img.paste(big, (x, y), big)
        d.text((x, y + 40 * scale + 2), name.split("/")[-1], fill=rgb("rag2"))
    img.save(os.path.join(OUT, "sheet_x4.png"))

# --- Lit mockup scene -------------------------------------------------------------------
W, H, T = 960, 540, 32

def mockup(sprites):
    albedo = Image.new("RGBA", (W, H), rgb("void") + (255,))
    normal = Image.new("RGBA", (W, H), (128, 128, 255, 255))
    emissive = np.zeros((H, W, 3), np.float32)  # self-lit pixels (flames, rift glow)
    rnd = random.Random(11)

    def blit(name, x, y):
        spr = sprites[name]
        n = normal_map(spr, bevel=not name.startswith("tiles"))
        albedo.alpha_composite(spr, (x, y))
        normal.paste(n, (x, y), spr)

    def glow(x0, y0, img, strength=1.0):
        a = np.asarray(img).astype(np.float32) / 255.0
        h, w = a.shape[:2]
        x1, y1 = min(W, x0 + w), min(H, y0 + h)
        sub = a[: y1 - y0, : x1 - x0]
        emissive[y0:y1, x0:x1] += sub[..., :3] * sub[..., 3:4] * strength

    cols, rows = W // T, math.ceil(H / T)
    # Floor everywhere.
    for ty in range(rows):
        for tx in range(cols):
            v = rnd.random()
            blit("tiles/floor_cracked" if v < 0.1 else ("tiles/floor_b" if v < 0.5 else "tiles/floor_a"), tx * T, ty * T)
    # Back wall: a row of capstones and a row of brick face.
    for tx in range(cols):
        blit("tiles/wall_top", tx * T, 0)
        blit("tiles/wall_face", tx * T, T)
    # A pillar.
    for (tx, ty) in [(4, 6)]:
        blit("tiles/wall_top", tx * T, ty * T); blit("tiles/wall_face", tx * T, (ty + 1) * T)

    # The Drop: a chasm with depth layers and a faint glow from the Rift far below.
    px0, py0, px1, py1 = 14 * T, 6 * T, 22 * T, 10 * T
    a = albedo.load()
    for y in range(py0, py1):
        for x in range(px0, px1):
            edge = min(x - px0, px1 - 1 - x, y - py0, py1 - 1 - y)
            t = max(0.0, 1.0 - edge / 26.0)
            a[x, y] = rgb(dither(x, y, t * 0.9, ["void", "stone0", "stone1", "stone2"])) + (255,)
    for i, inset in enumerate([34, 52, 68]):  # faint outlines of collapsed floors far below
        c = rgb(["stone1", "stone0", "stone0"][i])
        for x in range(px0 + inset, px1 - inset, 2):
            a[x, py0 + inset] = c + (255,); a[x, py1 - inset] = c + (255,)
    for _ in range(26):  # specks of rift light deep down
        x = rnd.randint(px0 + 60, px1 - 60); y = rnd.randint(py0 + 50, py1 - 40)
        a[x, y] = rgb("rift2") + (255,)
        emissive[y, x] += np.array(rgb("rift3")) / 255.0 * 0.7
    for x in range(px0 - 2, px1 + 2):  # pale worn lip on the near rim
        for y in (py0 - 1, py0 - 2):
            a[x, y] = rgb("stone6" if (x // 3) % 4 else "stone5") + (255,)
        a[x, py1] = rgb("stone5") + (255,)
    for y in range(py0, py1):
        a[px0 - 1, y] = rgb("stone5") + (255,); a[px1, y] = rgb("stone5") + (255,)

    # Deep water channel along the bottom.
    wy0 = 14 * T + 8
    for y in range(wy0, H):
        for x in range(0, 12 * T):
            t = 0.3 + 0.15 * math.sin(x * 0.18 + y * 0.6) * math.sin(y * 0.3)
            if (y - wy0) < 3: t = 0.9
            a[x, y] = rgb(dither(x, y, max(0, min(1, t)), ["water0", "water1", "water2", "water3", "water4"])) + (255,)
    for x in range(0, 12 * T):
        a[x, wy0 - 1] = rgb("stone6") + (255,)
    for y in range(wy0 - 1, H):
        a[12 * T, y] = rgb("stone6") + (255,)

    # Props and characters.
    blit("props/crate", 9 * T, 9 * T)
    blit("props/crate", 10 * T, 9 * T - 6)
    blit("props/barricade", 23 * T, 12 * T)
    blit("props/brazier", 18 * T, 12 * T)
    glow(18 * T, 12 * T, sprites["props/brazier"].point(lambda v: v), 0.0)
    for (tx, img) in [(6, "props/torch_1"), (25, "props/torch_2")]:
        blit(img, tx * T + 8, T + 4)
    blit("chars/prisoner", 8 * T + 10, 9 * T + 2)        # crouched behind the crates
    blit("chars/guard", 17 * T, 4 * T + 8)               # patrolling the chasm's rim
    blit("chars/gaoler", 26 * T, 8 * T)
    blit("chars/hound", 3 * T, 11 * T + 8)

    # Flames are emissive.
    def flame_emissive(name, x, y, s=1.4):
        spr = np.asarray(sprites[name]).astype(np.float32) / 255.0
        is_fire = (spr[..., 0] > 0.75) & (spr[..., 3] > 0)
        hh, ww = is_fire.shape
        emissive[y:y + hh, x:x + ww] += spr[..., :3] * is_fire[..., None] * s
    flame_emissive("props/brazier", 18 * T, 12 * T)
    flame_emissive("props/torch_1", 6 * T + 8, T + 4)
    flame_emissive("props/torch_2", 25 * T + 8, T + 4)

    # --- Lighting: ambient + point lights shaded by the normal maps ---
    alb = np.asarray(albedo).astype(np.float32)[..., :3] / 255.0
    nrm = np.asarray(normal).astype(np.float32)[..., :3] / 255.0 * 2.0 - 1.0
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    light = np.ones((H, W, 3), np.float32) * np.array([0.30, 0.30, 0.42])  # cold ambient
    def point(lx, ly, radius, color, intensity, height=40.0):
        dx, dy = lx - xx, ly - yy
        dist = np.sqrt(dx * dx + dy * dy)
        L = np.stack([dx, dy, np.full_like(dx, height)], -1)
        L /= np.linalg.norm(L, axis=-1, keepdims=True)
        ndl = np.clip((nrm * L).sum(-1), 0, 1)
        fall = np.clip(1.0 - dist / radius, 0, 1) ** 1.5
        return (ndl * fall)[..., None] * np.array(color) * intensity
    fire = np.array(rgb("fire4")) / 255.0
    light += point(18 * T + 16, 12 * T + 10, 360, fire, 2.6)
    light += point(6 * T + 16, T + 14, 400, fire, 2.4)
    light += point(25 * T + 16, T + 14, 400, fire, 2.3)
    light += point((px0 + px1) / 2, (py0 + py1) / 2, 240, np.array(rgb("rift2")) / 255.0, 0.9, height=10.0)
    light += point(1 * T, 16 * T, 320, np.array(rgb("water4")) / 255.0, 0.6)
    color = alb * light + emissive
    # Gentle vignette.
    v = 1.0 - 0.35 * (((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2)
    color *= np.clip(v, 0.35, 1)[..., None]
    out = Image.fromarray((np.clip(color, 0, 1) * 255).astype(np.uint8), "RGB")
    out.save(os.path.join(OUT, "mockup_960x540.png"))
    out.resize((W * 2, H * 2), Image.NEAREST).save(os.path.join(OUT, "mockup_1920x1080.png"))
    # A close-up (x3) of the middle of the scene, to judge the pixel work.
    out.crop((220, 110, 620, 335)).resize((1200, 675), Image.NEAREST).save(os.path.join(OUT, "mockup_detail_x3.png"))

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write_palette()
    s = build()
    sheet(s)
    mockup(s)
    print("Wrote", OUT)
