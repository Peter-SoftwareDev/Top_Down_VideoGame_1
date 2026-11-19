"""Natural-looking dungeon floor prototype: no repeating tiles.

Instead of stamping 32x32 tiles, the whole room is generated as one surface:
  1. Voronoi flagstones with domain warping: every stone is a unique, irregular shape.
  2. Per-stone tone, height and bevel, plus cracks and a few missing stones.
  3. Low-frequency "macro" noise so large areas drift in colour, as real floors do.
  4. Maps driven by the room's layout:
       moisture (near water, low spots) -> damp stone, moss in the joints, puddles
       wear (along the routes people walk) -> smoother, paler, polished stone
       grime (corners, wall bases, pit rims) -> darker ambient occlusion and dirt
  5. Scattered details (Poisson-disc spacing): pebbles, straw, bones, rubble.
  6. Irregular masonry walls: random block lengths and course heights.
  7. Everything is snapped to the game palette with ordered dithering (stays pixel art),
     then lit with the same normal-mapped lighting as the style test.

Writes assets/art/style_test/natural_*.png. Run: python3 tools/pixelart/natural_room.py
"""
import os, sys, math, random
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import style_test as st

W, H = 960, 540
rng = np.random.default_rng(42)
OUT = st.OUT

# --- Noise -----------------------------------------------------------------------
def value_noise(scale, seed):
    r = np.random.default_rng(seed)
    gh, gw = H // scale + 3, W // scale + 3
    g = r.random((gh, gw))
    y = np.arange(H) / scale; x = np.arange(W) / scale
    yi = y.astype(int); xi = x.astype(int)
    fy = y - yi; fx = x - xi
    fy = fy * fy * (3 - 2 * fy); fx = fx * fx * (3 - 2 * fx)
    a = g[yi][:, xi]; b = g[yi][:, xi + 1]; c = g[yi + 1][:, xi]; d = g[yi + 1][:, xi + 1]
    top = a + (b - a) * fx[None, :]; bot = c + (d - c) * fx[None, :]
    return top + (bot - top) * fy[:, None]

def fbm(base, octaves, seed):
    total = np.zeros((H, W)); amp = 1.0; norm = 0.0; s = base
    for o in range(octaves):
        total += value_noise(max(2, int(s)), seed + o) * amp
        norm += amp; amp *= 0.5; s /= 2
    return total / norm

YY, XX = np.mgrid[0:H, 0:W].astype(np.float64)

# --- Room layout (same as the style test so the two can be compared) -----------------
T = 32
WALL_H = 64
PIT = (14 * T, 6 * T, 22 * T, 10 * T)
WATER_Y = 14 * T + 8
WATER_X1 = 12 * T

def dist_to_rect(x0, y0, x1, y1):
    dx = np.maximum(np.maximum(x0 - XX, 0), XX - x1)
    dy = np.maximum(np.maximum(y0 - YY, 0), YY - y1)
    return np.hypot(dx, dy)

def dist_to_polyline(pts):
    best = np.full((H, W), 1e9)
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        vx, vy = bx - ax, by - ay
        t = np.clip(((XX - ax) * vx + (YY - ay) * vy) / (vx * vx + vy * vy), 0, 1)
        best = np.minimum(best, np.hypot(XX - (ax + t * vx), YY - (ay + t * vy)))
    return best

d_wall = np.maximum(YY - WALL_H, 0)
d_pit = dist_to_rect(*PIT)
d_water = dist_to_rect(0, WATER_Y, WATER_X1, H)
# A worn route: from a doorway on the left, past the crates, around the pit, out on the right.
d_path = dist_to_polyline([(0, 300), (180, 290), (330, 360), (520, 380), (700, 360), (800, 300), (960, 250)])

macro = fbm(220, 3, 1)
moisture = np.clip(np.exp(-d_water / 110.0) * 1.1 + (fbm(160, 3, 2) - 0.55) * 0.9, 0, 1)
wear = np.clip(np.exp(-(d_path / 46.0) ** 2) * (0.7 + 0.5 * fbm(60, 2, 3)), 0, 1)
grime = np.clip(np.exp(-d_wall / 26.0) * 0.9 + np.exp(-d_pit / 18.0) * 0.6 + (fbm(90, 3, 4) - 0.5) * 0.5, 0, 1)

# --- 1. Warped Voronoi flagstones, in three sizes chosen by zone ----------------------------
warp = 6.0
wx = XX + (fbm(40, 3, 10) - 0.5) * 2 * warp
wy = YY + (fbm(40, 3, 11) - 0.5) * 2 * warp

def voronoi(cell, jitter, seed):
    r = np.random.default_rng(seed)
    ny, nx = int(H / cell) + 4, int(W / cell) + 4
    jx = r.random((ny, nx)); jy = r.random((ny, nx))
    # Stretch some cells sideways or up-down so slabs aren't all round.
    stretch = 0.75 + r.random((ny, nx)) * 0.5
    gx = np.floor(wx / cell).astype(int); gy = np.floor(wy / cell).astype(int)
    F1 = np.full((H, W), 1e9); F2 = np.full((H, W), 1e9); ID = np.zeros((H, W), int)
    for oy in (-2, -1, 0, 1, 2):
        for ox in (-2, -1, 0, 1, 2):
            cx = np.clip(gx + ox, -1, nx - 3); cy = np.clip(gy + oy, -1, ny - 3)
            sx = (cx + 0.5 + (jx[cy + 1, cx + 1] - 0.5) * jitter) * cell
            sy = (cy + 0.5 + (jy[cy + 1, cx + 1] - 0.5) * jitter) * cell
            k = stretch[cy + 1, cx + 1]
            d = np.hypot((wx - sx) * k, (wy - sy) / k)
            sid = (cy + 1) * nx + (cx + 1) + seed * 100000
            closer = d < F1
            F2 = np.where(closer, F1, np.minimum(F2, d))
            ID = np.where(closer, sid, ID)
            F1 = np.where(closer, d, F1)
    return (F2 - F1) * 0.5, ID

edge_big, id_big = voronoi(36.0, 0.9, 1)      # big worn slabs
edge_mid, id_mid = voronoi(23.0, 0.95, 2)     # ordinary flagstones
edge_small, id_small = voronoi(12.0, 1.0, 3)  # rough small cobbles in damp ground
zone_big = (wear > 0.35) | (fbm(170, 2, 20) > 0.66)
zone_small = (~zone_big) & (moisture > 0.5)
edge = np.where(zone_big, edge_big, np.where(zone_small, edge_small, edge_mid))
ID = np.where(zone_big, id_big, np.where(zone_small, id_small, id_mid))
# A joint wherever two zones meet, so slabs don't merge into cobbles.
zone = zone_big.astype(int) * 2 + zone_small.astype(int)
zp = np.pad(zone, 1, mode="edge")
seam = (zp[1:-1, 2:] != zone) | (zp[2:, 1:-1] != zone)
edge = np.where(seam, 0.0, edge)
joint_w = 0.5 + fbm(30, 2, 12) * 0.7 + grime * 0.6 - wear * 0.45
joint = edge < joint_w

def per_stone(seed):
    return (np.sin(ID * 12.9898 + seed * 78.233) * 43758.5453) % 1.0
tone = per_stone(5)          # per-stone colour
tilt = per_stone(6)          # per-stone height
missing = (per_stone(7) < 0.02) & ~zone_big

# --- 2. Height (for lighting) and albedo --------------------------------------------------
bevel = np.clip(edge / 3.0, 0, 1)
height = np.where(joint, 0.15, 0.35 + bevel * 0.3 + tilt * 0.15 - wear * 0.1)
height = np.where(missing, 0.0 + fbm(6, 1, 13) * 0.15, height)

def col(name):
    return np.array(st.rgb(name), np.float64) / 255.0

stone_dark, stone_mid, stone_light = col("stone2"), col("stone3"), col("stone4")
polished = col("stone5")
mortar_c = col("stone1") * 0.7 + col("stone0") * 0.3
damp_c, moss_c = col("water1"), col("rift1")
dirt_c = col("stone1") * 0.6 + col("wood0") * 0.4

t = np.clip(tone * 0.35 + macro * 0.5 + bevel * 0.1, 0, 1)[..., None]
alb = stone_dark * (1 - t) + stone_mid * t
alb = alb + (stone_light - alb) * (bevel * (1 - grime) * 0.18)[..., None]
alb = alb + (polished - alb) * (wear * 0.45 * bevel)[..., None]               # worn route
alb = alb * (1 - moisture * 0.25)[..., None] + damp_c * (moisture * 0.25)[..., None]  # damp
alb = alb * (1 - grime * 0.35)[..., None]                                     # grime / AO
mj = (moisture > 0.45) & joint & (fbm(8, 2, 14) > 0.45)
alb = np.where(joint[..., None], mortar_c, alb)
alb = np.where(mj[..., None], moss_c, alb)                                    # moss in joints
alb = np.where(missing[..., None], dirt_c * (0.8 + fbm(5, 1, 15)[..., None] * 0.3), alb)

# Cracks: short random walks inside some stones.
crack = np.zeros((H, W), bool)
cr = random.Random(9)
for _ in range(110):
    x, y = cr.randint(0, W - 1), cr.randint(WALL_H, H - 1)
    if joint[y, x]:
        continue
    for _ in range(cr.randint(5, 14)):
        if not (0 <= x < W and 0 <= y < H) or joint[y, x]:
            break
        crack[y, x] = True
        x += cr.choice([-1, 0, 1, 1]); y += cr.choice([0, 1, 1])
alb = np.where(crack[..., None], mortar_c, alb)
height = np.where(crack, 0.1, height)

# Puddles in damp low spots.
puddle = (moisture > 0.72) & (fbm(25, 2, 16) > 0.58) & (YY < WATER_Y - 4)
alb = np.where(puddle[..., None], col("water2") * 0.8 + col("water3") * 0.2, alb)
height = np.where(puddle, 0.2, height)

# --- 3. Irregular masonry wall -------------------------------------------------------------
wr = random.Random(21)
y = 0
courses = []
while y < WALL_H:
    h = wr.randint(9, 13)
    courses.append((y, min(WALL_H, y + h))); y += h
wall_alb = np.zeros((WALL_H, W, 3)); wall_h = np.zeros((WALL_H, W))
for (y0, y1) in courses:
    x = -wr.randint(0, 20)
    while x < W:
        bw = wr.randint(14, 34)
        shade = 0.3 + wr.random() * 0.5
        for yy in range(y0, y1):
            for xx in range(max(0, x), min(W, x + bw)):
                ex = min(xx - x, x + bw - 1 - xx); ey = min(yy - y0, y1 - 1 - yy)
                e = min(ex, ey)
                if e == 0:
                    wall_alb[yy, xx] = col("stone1"); wall_h[yy, xx] = 0.05
                else:
                    k = shade + (0.15 if ey == 1 and yy - y0 == 1 else 0) - (yy / WALL_H) * 0.25
                    k = min(1, max(0, k))
                    wall_alb[yy, xx] = col("stone3") * (1 - k) + col("stone5") * k
                    wall_h[yy, xx] = 0.4 + min(e, 3) / 3 * 0.4
        x += bw
# Darker capstone band on top, contact shadow at the base.
wall_alb[:14] = wall_alb[:14] * 0.45
wall_alb[-3:] = col("stone0")
alb[:WALL_H] = wall_alb; height[:WALL_H] = wall_h

# --- 4. Pit and water (same as the style test, with a damp rim) -------------------------------
px0, py0, px1, py1 = PIT
# A collapsed floor has a ragged edge: push the rectangle's outline in and out with noise,
# following the joints of the stones around it so whole stones break away.
e_rect = np.minimum(np.minimum(XX - px0, px1 - 1 - XX), np.minimum(YY - py0, py1 - 1 - YY))
ragged = (fbm(26, 3, 40) - 0.5) * 34 + np.where(joint, -3.0, 0.0)
inside = e_rect > ragged
e_in = np.maximum(e_rect - ragged, 0)
depth_t = np.clip(1 - e_in / 30.0, 0, 1)
alb = np.where(inside[..., None], col("void") * (1 - depth_t[..., None]) + col("stone1") * depth_t[..., None] * 0.9, alb)
height = np.where(inside, 0.0, height)
ip = np.pad(inside, 2, mode="constant")
near_in = np.zeros_like(inside)
for oy in range(-2, 3):
    for ox in range(-2, 3):
        near_in |= ip[2 + oy:2 + oy + H, 2 + ox:2 + ox + W]
lip = (~inside) & near_in
alb = np.where(lip[..., None], col("stone6") * 0.9, alb)
water = (YY >= WATER_Y) & (XX < WATER_X1)
ripple = 0.35 + 0.15 * np.sin(XX * 0.18 + YY * 0.6) * np.sin(YY * 0.3)
alb = np.where(water[..., None], col("water1") * (1 - ripple[..., None]) + col("water3") * ripple[..., None], alb)
height = np.where(water, 0.15, height)
wlip = (~water) & (d_water < 2.0)
alb = np.where(wlip[..., None], col("stone5"), alb)

# --- 5. Scattered details (Poisson-disc) --------------------------------------------------------
def poisson(n, min_d, seed, region):
    r = random.Random(seed); pts = []
    tries = 0
    while len(pts) < n and tries < n * 60:
        tries += 1
        x, y = r.randint(4, W - 5), r.randint(WALL_H + 4, H - 5)
        if not region(x, y):
            continue
        if all((x - a) ** 2 + (y - b) ** 2 >= min_d * min_d for a, b in pts):
            pts.append((x, y))
    return pts
floor_ok = lambda x, y: not inside[y, x] and not water[y, x]
alb_img = alb.copy()
for (x, y) in poisson(160, 14, 31, lambda x, y: floor_ok(x, y) and wear[y, x] < 0.5):   # pebbles
    c = col("stone5") if (x + y) % 3 else col("stone6")
    alb_img[y, x] = c; alb_img[y, x + 1] = c * 0.8; alb_img[y + 1, x] = col("stone1")
    height[y, x] = 0.8
for (x, y) in poisson(40, 22, 32, lambda x, y: floor_ok(x, y) and grime[y, x] > 0.45):  # straw near walls
    for i in range(5):
        xx = x + i - 2; yy = y + (i % 2)
        alb_img[yy, xx] = col("fire1") if i % 2 else col("wood2")
for (x, y) in poisson(5, 120, 33, lambda x, y: floor_ok(x, y) and wear[y, x] < 0.2):    # bones
    for i in range(7):
        alb_img[y, x + i] = col("rag1")
    alb_img[y - 1, x] = alb_img[y + 1, x] = alb_img[y - 1, x + 6] = alb_img[y + 1, x + 6] = col("rag2")
for (x, y) in poisson(14, 40, 34, lambda x, y: floor_ok(x, y) and d_pit[y, x] < 40):    # rubble by the pit
    for dy in range(-1, 2):
        for dx in range(-2, 3):
            if dx * dx + dy * dy * 2 <= 4:
                alb_img[y + dy, x + dx] = col("stone4") if dy < 1 else col("stone2")
                height[y + dy, x + dx] = 0.9

# --- 6. Snap to the palette with ordered dithering -----------------------------------------
pal = np.array([st.rgb(n) for n in st.PALETTE], np.float64) / 255.0
bayer = np.tile(st.BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
jittered = alb_img + (bayer[..., None] - 0.5) * 0.05
d2 = ((jittered[..., None, :] - pal[None, None, :, :]) ** 2).sum(-1)
alb_q = pal[np.argmin(d2, axis=-1)]

# --- 7. Props, characters and lighting --------------------------------------------------------
albedo = Image.fromarray((alb_q * 255).astype(np.uint8), "RGB").convert("RGBA")
hp = np.pad(height, 1, mode="edge")
dx = (hp[1:-1, 2:] - hp[1:-1, :-2]) * 2.2
dy = (hp[2:, 1:-1] - hp[:-2, 1:-1]) * 2.2
nrm = np.stack([-dx, -dy, np.ones_like(dx)], -1)
nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
normal = Image.fromarray(((nrm * 0.5 + 0.5) * 255).astype(np.uint8), "RGB").convert("RGBA")
emissive = np.zeros((H, W, 3))

def blit(spr, x, y):
    albedo.alpha_composite(spr, (x, y))
    normal.paste(st.normal_map(spr), (x, y), spr)

crate = st.crate(); torch1 = st.torch(1); torch2 = st.torch(2); braz = st.brazier()
blit(crate, 9 * T, 9 * T); blit(crate, 10 * T, 9 * T - 6)
blit(st.barricade(), 23 * T, 12 * T)
blit(braz, 18 * T, 12 * T)
blit(torch1, 6 * T + 8, 20); blit(torch2, 25 * T + 8, 20)
blit(st.char_sprite("prisoner", 24, 32), 8 * T + 10, 9 * T + 2)
blit(st.char_sprite("guard", 24, 32), 17 * T, 4 * T + 8)
blit(st.char_sprite("gaoler", 32, 40), 26 * T, 8 * T)
blit(st.char_sprite("hound", 32, 20), 3 * T, 11 * T + 8)
def flame(spr, x, y, s=1.4):
    a = np.asarray(spr).astype(np.float64) / 255.0
    f = (a[..., 0] > 0.75) & (a[..., 3] > 0)
    h, w = f.shape
    emissive[y:y + h, x:x + w] += a[..., :3] * f[..., None] * s
flame(braz, 18 * T, 12 * T); flame(torch1, 6 * T + 8, 20); flame(torch2, 25 * T + 8, 20)
r2 = random.Random(41)
for _ in range(26):
    x = r2.randint(px0 + 60, px1 - 60); y = r2.randint(py0 + 50, py1 - 40)
    albedo.putpixel((x, y), st.rgb("rift2") + (255,)); emissive[y, x] += col("rift3") * 0.7

A = np.asarray(albedo).astype(np.float64)[..., :3] / 255.0
N = np.asarray(normal).astype(np.float64)[..., :3] / 255.0 * 2 - 1
light = np.ones((H, W, 3)) * np.array([0.30, 0.30, 0.42])
def point(lx, ly, radius, c, inten, h=40.0):
    ddx, ddy = lx - XX, ly - YY
    dist = np.hypot(ddx, ddy)
    L = np.stack([ddx, ddy, np.full_like(ddx, h)], -1)
    L /= np.linalg.norm(L, axis=-1, keepdims=True)
    ndl = np.clip((N * L).sum(-1), 0, 1)
    fall = np.clip(1 - dist / radius, 0, 1) ** 1.5
    return (ndl * fall)[..., None] * c * inten
fire = col("fire4")
light += point(18 * T + 16, 12 * T + 10, 360, fire, 2.6)
light += point(6 * T + 16, 34, 400, fire, 2.4)
light += point(25 * T + 16, 34, 400, fire, 2.3)
light += point((px0 + px1) / 2, (py0 + py1) / 2, 240, col("rift2"), 0.9, 10.0)
light += point(1 * T, 16 * T, 320, col("water4"), 0.6)
out = A * light + emissive
v = 1 - 0.35 * (((XX - W / 2) / (W / 2)) ** 2 + ((YY - H / 2) / (H / 2)) ** 2)
out *= np.clip(v, 0.35, 1)[..., None]
img = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), "RGB")
img.save(os.path.join(OUT, "natural_960x540.png"))
img.resize((W * 2, H * 2), Image.NEAREST).save(os.path.join(OUT, "natural_1920x1080.png"))
img.crop((220, 110, 620, 335)).resize((1200, 675), Image.NEAREST).save(os.path.join(OUT, "natural_detail_x3.png"))

# Side by side with the tiled version: top = tiled, bottom = natural.
old = Image.open(os.path.join(OUT, "mockup_960x540.png")).convert("RGB")
both = Image.new("RGB", (W, H * 2 + 6), (0, 0, 0))
both.paste(old, (0, 0)); both.paste(img, (0, H + 6))
both.save(os.path.join(OUT, "natural_vs_tiled.png"))

# Debug view of the layout maps (R = wear, G = moisture, B = grime).
maps = np.stack([wear, moisture, grime], -1)
Image.fromarray((maps * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, "natural_maps.png"))
print("Wrote natural_*.png to", OUT)
