"""Bake floor art for the test room from its layout in scenes/Main.tscn.

Reads the walls and hazards from the scene, paints each area with a material, adds
layout-driven grime and damp, then writes into assets/art/rooms/:
  test_room_albedo.png     floor colours (palette-snapped, unlit: Godot lights it)
  test_room_normal.png     normal map, so torchlight shades the stones
  test_room_materials.png  1 pixel per 16x16 world cell, R channel = material id
                           (0 stone, 1 straw, 2 iron, 3 brick, 4 water): used for footsteps
  test_room_preview.png    a quick lit preview at half size

Areas: main hall = imperial dressed slabs; the Bridge = hewn rock, with an iron catwalk over
the gap between its pits; the Dark Hall = hewn cells with straw; the Channel = Cistern brick;
doorways = long sill stones.
Run after changing the room's layout:  python3 tools/pixelart/bake_test_room.py
"""
import os, re, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import materials as M
import style_test as st

ROOT = st.ROOT
SCENE = os.path.join(ROOT, "scenes", "Main.tscn")
OUT = os.path.join(ROOT, "assets", "art", "rooms")
W, H = 2200, 1400
CELL = 16
MAT = {"stone": 0, "straw": 1, "iron": 2, "brick": 3, "water": 4}

# --- Read the layout ---------------------------------------------------------------
def read_scene():
    txt = open(SCENE).read()
    walls, hazards = [], {}
    for m in re.finditer(r'\[node name="([^"]+)" type="[^"]+" parent="(Walls|Hazards)"\]\n((?:[^\[\n].*\n)*)', txt):
        name, parent, body = m.group(1), m.group(2), m.group(3)
        def vec(key):
            mm = re.search(key + r' = Vector2\(([-\d.]+), ([-\d.]+)\)', body)
            return (float(mm.group(1)), float(mm.group(2))) if mm else None
        pos, size = vec("position"), vec("size")
        if pos is None or size is None:
            continue
        rect = (pos[0] - size[0] / 2, pos[1] - size[1] / 2, pos[0] + size[0] / 2, pos[1] + size[1] / 2)
        if parent == "Walls":
            walls.append((name, rect, "low = true" in body))
        else:
            hazards[name] = (rect, "kind = 1" in body)
    return walls, hazards

walls, hazards = read_scene()
YY, XX = np.mgrid[0:H, 0:W].astype(np.float32)

def rect_mask(r, grow=0):
    x0, y0, x1, y1 = r
    return (XX >= x0 - grow) & (XX < x1 + grow) & (YY >= y0 - grow) & (YY < y1 + grow)

def dist_rect(r):
    x0, y0, x1, y1 = r
    dx = np.maximum(np.maximum(x0 - XX, 0), XX - x1); dy = np.maximum(np.maximum(y0 - YY, 0), YY - y1)
    return np.hypot(dx, dy)

wall_mask = np.zeros((H, W), bool); d_wall = np.full((H, W), 1e4, np.float32)
for name, r, low in walls:
    wall_mask |= rect_mask(r)
    if not low:
        d_wall = np.minimum(d_wall, dist_rect(r))
d_water = np.full((H, W), 1e4, np.float32); d_pit = np.full((H, W), 1e4, np.float32)
for name, (r, is_water) in hazards.items():
    if is_water:
        d_water = np.minimum(d_water, dist_rect(r))
    else:
        d_pit = np.minimum(d_pit, dist_rect(r))

# --- Areas -------------------------------------------------------------------------
main = (XX < 1400) & (YY < 900)
bridge = (XX >= 1440) & (YY < 600)
dark = (XX >= 1440) & (YY >= 640)
south = (XX < 1400) & (YY >= 940)
doorway = ~(main | bridge | dark | south) & ~wall_mask
pn, ps = hazards["BridgePitNorth"][0], hazards["BridgePitSouth"][0]
walkway = (XX >= max(pn[0], ps[0])) & (XX < min(pn[2], ps[2])) & (YY >= pn[3]) & (YY < ps[1])

alb = np.zeros((H, W, 3), np.float32); hgt = np.zeros((H, W), np.float32)
mat = np.zeros((H, W), np.uint8)

def paint(mask, gen, x0, y0, x1, y1, material, **kw):
    a, h, e = gen(y1 - y0, x1 - x0, **kw)
    sub = mask[y0:y1, x0:x1]
    alb[y0:y1, x0:x1][sub] = (a + e)[sub]
    hgt[y0:y1, x0:x1][sub] = h[sub]
    mat[y0:y1, x0:x1][sub] = MAT[material]

paint(main, M.dressed_slabs, 0, 0, 1400, 900, "stone", seed=101)
paint(bridge, M.rock_cut, 1440, 0, W, 600, "stone", seed=102)
paint(walkway, M.catwalk, 1440, 0, W, 600, "iron", seed=103, under="void")
paint(south, M.basketweave_brick, 0, 940, 1400, H, "brick", seed=104, damp=0.0)
# The Dark Hall: hewn rock cells, with straw bedding in patches.
paint(dark, M.rock_cut, 1440, 640, W, H, "stone", seed=105)
straw_noise = M.fbm(H - 640, W - 1440, 40, 3, 106)
straw = np.zeros((H, W), bool); straw[640:, 1440:] = straw_noise > 0.56
paint(dark & straw, M.earth_straw, 1440, 640, W, H, "straw", seed=107, straw_amount=0.8)

# Doorways: one long dressed sill stone each.
e_door = np.minimum.reduce([np.abs(XX - 1400), np.abs(1440 - XX), np.abs(YY - 900), np.abs(940 - YY), np.abs(YY - 600), np.abs(640 - YY)])
bev = np.clip(e_door / 5.0, 0, 1)
sill = M.mix(M.col("stone3"), M.col("stone5"), (bev * 0.55 + M.fbm(H, W, 30, 2, 108) * 0.2).astype(np.float32))
alb[doorway] = sill[doorway]; hgt[doorway] = (0.55 + bev * 0.12)[doorway]; mat[doorway] = MAT["stone"]

# --- Layout-driven ageing ------------------------------------------------------------
grime = np.clip(np.exp(-d_wall / 24.0) * 0.8 + np.exp(-d_pit / 16.0) * 0.5 + (M.fbm(H, W, 90, 3, 109) - 0.5) * 0.4, 0, 1)
moist = np.clip(np.exp(-d_water / 90.0) * (1.1 + (M.fbm(H, W, 150, 3, 110) - 0.5) * 0.8), 0, 1)   # damp only near water
alb = alb * (1 - grime * 0.35)[..., None]
alb = alb * (1 - moist * 0.25)[..., None] + M.col("water1") * (moist * 0.25)[..., None]
puddle = (moist > 0.75) & (M.fbm(H, W, 22, 2, 111) > 0.6) & ~walkway & ~doorway & ~dark
alb[puddle] = M.col("water1") * 0.6 + M.col("stone1") * 0.25 + M.col("water3") * 0.15
hgt[puddle] = 0.2; mat[puddle] = MAT["water"]
alb[wall_mask] = M.col("stone1"); hgt[wall_mask] = 0.5

# --- Palette snap (in chunks to keep memory low) and normals -------------------------------
# Floors only use stone, earth, straw and water colours; metal colours only where the floor is iron.
# (Otherwise mid-tone stone sometimes snaps to the cooler metal greys and looks green.)
names = list(st.PALETTE)
pal_all = M.PAL.astype(np.float32)
floor_ok = np.array([not (n.startswith("metal") or n.startswith("skin")) for n in names])
pal_floor = pal_all[floor_ok]
bayer = np.tile(st.BAYER.astype(np.float32), (H // 4 + 1, W // 4 + 1))[:H, :W]
out = np.zeros_like(alb)
for y0 in range(0, H, 100):
    a = alb[y0:y0 + 100] + (bayer[y0:y0 + 100, :, None] - 0.5) * 0.05
    q_floor = pal_floor[np.argmin(((a[..., None, :] - pal_floor[None, None]) ** 2).sum(-1), -1)]
    q_all = pal_all[np.argmin(((a[..., None, :] - pal_all[None, None]) ** 2).sum(-1), -1)]
    out[y0:y0 + 100] = np.where((mat[y0:y0 + 100] == MAT["iron"])[..., None], q_all, q_floor)
hp = np.pad(hgt, 1, mode="edge")
dx = (hp[1:-1, 2:] - hp[1:-1, :-2]) * 2.4; dy = (hp[2:, 1:-1] - hp[:-2, 1:-1]) * 2.4
# Godot uses OpenGL-style normal maps: green = up on screen. Our dy is in image space (down),
# so flip it.
nrm = np.stack([-dx, dy, np.ones_like(dx)], -1); nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)

os.makedirs(OUT, exist_ok=True)
Image.fromarray((out * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, "test_room_albedo.png"), optimize=True)
Image.fromarray(((nrm * 0.5 + 0.5) * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, "test_room_normal.png"), optimize=True)
cells = mat[CELL // 2::CELL, CELL // 2::CELL]
Image.fromarray((cells * 40).astype(np.uint8), "L").save(os.path.join(OUT, "test_room_materials.png"))
prev = Image.fromarray((np.clip(out * 1.4, 0, 1) * 255).astype(np.uint8), "RGB").resize((W // 2, H // 2), Image.NEAREST)
prev.save(os.path.join(OUT, "test_room_preview.png"))
print("Baked", W, "x", H, "->", OUT, " material grid", cells.shape[::-1])
