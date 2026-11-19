"""Floor material generators for the Penance Cells (Gloamhold's prison floor).

Each generator returns (albedo RGB float array, height array, emissive RGB array) at any size.
Outputs to assets/art/style_test/materials/:
  swatches_penance_cells.png    each candidate material, lit the same way, labelled
  cellblock_vignette.png        the materials together in a small cell block (x2)
Run: python3 tools/pixelart/materials.py
"""
import os, sys, math, random
import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import style_test as st

OUT = os.path.join(st.OUT, "materials")

def col(name):
    return np.array(st.rgb(name), np.float64) / 255.0

# --- Noise at any size -----------------------------------------------------------
def value_noise(h, w, scale, seed):
    r = np.random.default_rng(seed)
    g = r.random((h // scale + 3, w // scale + 3))
    y = np.arange(h) / scale; x = np.arange(w) / scale
    yi = y.astype(int); xi = x.astype(int)
    fy = y - yi; fx = x - xi
    fy = fy * fy * (3 - 2 * fy); fx = fx * fx * (3 - 2 * fx)
    a = g[yi][:, xi]; b = g[yi][:, xi + 1]; c = g[yi + 1][:, xi]; d = g[yi + 1][:, xi + 1]
    top = a + (b - a) * fx[None, :]; bot = c + (d - c) * fx[None, :]
    return top + (bot - top) * fy[:, None]

def fbm(h, w, base, octaves, seed):
    t = np.zeros((h, w)); amp = 1.0; n = 0.0; s = base
    for o in range(octaves):
        t += value_noise(h, w, max(2, int(s)), seed + o) * amp
        n += amp; amp *= 0.5; s /= 2
    return t / n

def grid(h, w):
    return np.mgrid[0:h, 0:w].astype(np.float64)

def mix(a, b, t):
    t = np.asarray(t)[..., None] if np.ndim(t) else t
    return a * (1 - t) + b * t

# --- 1. Rock-cut floor: hewn from the cliff, with chisel marks ------------------------
def rock_cut(h, w, seed=1):
    YY, XX = grid(h, w)
    base = fbm(h, w, 64, 4, seed)
    # Patches worked in different directions (one chisel stroke direction per patch).
    r = random.Random(seed)
    cell = 46.0
    ny, nx = int(h / cell) + 3, int(w / cell) + 3
    ang = np.array([[r.uniform(0, math.pi) for _ in range(nx)] for _ in range(ny)])
    jx = np.array([[r.random() for _ in range(nx)] for _ in range(ny)])
    jy = np.array([[r.random() for _ in range(nx)] for _ in range(ny)])
    wx = XX + (fbm(h, w, 24, 2, seed + 5) - 0.5) * 14
    wy = YY + (fbm(h, w, 24, 2, seed + 6) - 0.5) * 14
    gx = (wx // cell).astype(int); gy = (wy // cell).astype(int)
    best = np.full((h, w), 1e9); A = np.zeros((h, w))
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            cx = np.clip(gx + ox, 0, nx - 1); cy = np.clip(gy + oy, 0, ny - 1)
            sx = (cx + jx[cy, cx]) * cell; sy = (cy + jy[cy, cx]) * cell
            d = np.hypot(wx - sx, wy - sy)
            closer = d < best
            A = np.where(closer, ang[cy, cx], A); best = np.where(closer, d, best)
    along = XX * np.cos(A) + YY * np.sin(A)
    strokes = np.sin(along * 0.9 + fbm(h, w, 10, 2, seed + 7) * 6)
    tool = np.clip(strokes, 0, 1) ** 3 * (0.4 + fbm(h, w, 30, 2, seed + 8) * 0.6)
    # Natural fissures in the rock (ridged noise).
    ridge = np.abs(fbm(h, w, 55, 3, seed + 9) - 0.5)
    fiss = (ridge < 0.006) & (fbm(h, w, 35, 2, seed + 12) > 0.55)   # thin, and only in places
    height = base * 0.6 + tool * 0.12 - fiss * 0.3
    t = np.clip(base * 1.3 - 0.25, 0, 1)
    alb = mix(col("stone2"), col("stone4"), t)
    alb = mix(alb, col("stone5"), tool * 0.25)
    dust = np.clip((0.38 - base) * 4, 0, 1) * 0.3 * (fbm(h, w, 12, 2, seed + 13) > 0.5)
    alb = mix(alb, col("stone3") * 0.7 + col("wood1") * 0.3, dust)
    alb = np.where(fiss[..., None], col("stone0"), alb)
    return alb, height, np.zeros((h, w, 3))

# --- 2. Dressed slabs: imperial paving in uneven courses ---------------------------------
def dressed_slabs(h, w, seed=2):
    YY, XX = grid(h, w)
    r = random.Random(seed)
    wx = XX + (fbm(h, w, 40, 2, seed + 1) - 0.5) * 3   # slabs have shifted over the centuries
    wy = YY + (fbm(h, w, 40, 2, seed + 2) - 0.5) * 3
    height = np.zeros((h, w)); tone = np.zeros((h, w)); edge = np.full((h, w), 99.0)
    sid = np.zeros((h, w), int)
    y = -r.randint(0, 20); k = 0
    while y < h + 40:
        ch = r.choice([r.randint(22, 34), r.randint(34, 52), r.randint(52, 70)])
        x = -r.randint(0, 40)
        while x < w + 60:
            sw = int(ch * r.uniform(0.9, 2.4))
            m = (wx >= x) & (wx < x + sw) & (wy >= y) & (wy < y + ch)
            ex = np.minimum(wx - x, x + sw - wx); ey = np.minimum(wy - y, y + ch - wy)
            e = np.minimum(ex, ey)
            # Chipped, rounded corners.
            corner = np.hypot(np.maximum(4 - ex, 0), np.maximum(4 - ey, 0))
            e = np.where(corner > 0, np.minimum(e, 4 - corner), e)
            sink = r.uniform(-0.12, 0.08); slope_x = r.uniform(-0.002, 0.002); slope_y = r.uniform(-0.002, 0.002)
            height = np.where(m, 0.5 + sink + (wx - x) * slope_x + (wy - y) * slope_y, height)
            tone = np.where(m, r.random(), tone)
            edge = np.where(m, e, edge); sid = np.where(m, k, sid)
            k += 1; x += sw
        y += ch
    joint = edge < 1.3 + fbm(h, w, 20, 2, seed + 3) * 1.2
    bevel = np.clip(edge / 4.0, 0, 1)
    height = np.where(joint, 0.1, height + bevel * 0.15)
    macro = fbm(h, w, 120, 2, seed + 4)
    t = np.clip(tone * 0.35 + macro * 0.5 + bevel * 0.1, 0, 1)
    alb = mix(col("stone2"), col("stone4"), t)
    alb = mix(alb, col("stone5"), bevel * 0.12)
    alb = np.where(joint[..., None], col("stone1") * 0.7 + col("stone0") * 0.3, alb)
    # Cracks through a few slabs.
    cr = random.Random(seed + 10); crack = np.zeros((h, w), bool)
    for _ in range(int(w * h / 4000)):
        x, y0 = cr.randint(0, w - 1), cr.randint(0, h - 1)
        yy = y0
        for _ in range(cr.randint(8, 22)):
            if not (0 <= x < w and 0 <= yy < h) or joint[yy, x]:
                break
            crack[yy, x] = True
            x += cr.choice([-1, 0, 1]); yy += cr.choice([0, 1, 1])
    alb = np.where(crack[..., None], col("stone0"), alb)
    height = np.where(crack, 0.15, height)
    return alb, height, np.zeros((h, w, 3))

# --- 3. Packed earth and straw: inside the cells ----------------------------------------
def earth_straw(h, w, seed=3, straw_amount=1.0):
    YY, XX = grid(h, w)
    n = fbm(h, w, 30, 4, seed)
    earth = col("stone1") * 0.55 + col("wood0") * 0.45
    alb = mix(col("stone2"), earth, np.clip(n * 1.4 - 0.3, 0, 0.8))
    height = n * 0.3
    r = random.Random(seed)
    for _ in range(int(w * h / 90)):   # grit
        x, y = r.randrange(w), r.randrange(h)
        alb[y, x] = col("stone2") if r.random() < 0.7 else col("stone3")
    clump = fbm(h, w, 40, 2, seed + 1)
    straw_h = np.zeros((h, w))
    base_ang = r.uniform(0, math.pi)
    for _ in range(int(w * h / 40 * straw_amount)):
        x, y = r.uniform(0, w), r.uniform(0, h)
        if clump[int(y) % h, int(x) % w] < 0.5 + r.random() * 0.25:
            continue
        a = base_ang + r.gauss(0, 0.7)
        L = r.randint(4, 10)
        c = [col("rag1"), col("rag1"), col("wood3"), col("rag0"), col("wood2")][r.randrange(5)] * 0.85
        for i in range(L):
            px, py = int(x + math.cos(a) * i), int(y + math.sin(a) * i)
            if 0 <= px < w and 0 <= py < h:
                alb[py, px] = c * (0.8 + 0.2 * (i / L)); straw_h[py, px] = 0.5 + 0.2 * r.random()
    height = np.maximum(height, straw_h)
    return alb, height, np.zeros((h, w, 3))

# --- 4. Iron grate over an oubliette shaft (a window into the Drop) ------------------------
def iron_grate(h, w, seed=4, frame=10):
    YY, XX = grid(h, w)
    alb, height, emis = dressed_slabs(h, w, seed + 20)
    x0, y0, x1, y1 = frame, frame, w - frame, h - frame
    inside = (XX >= x0) & (XX < x1) & (YY >= y0) & (YY < y1)
    # The shaft: darkness with depth, and faint rift light far below.
    e = np.minimum(np.minimum(XX - x0, x1 - 1 - XX), np.minimum(YY - y0, y1 - 1 - YY))
    depth = np.clip(1 - e / 24.0, 0, 1)
    alb = np.where(inside[..., None], mix(col("void"), col("stone1"), depth * 0.7), alb)
    height = np.where(inside, 0.0, height)
    r = random.Random(seed)
    for _ in range(int((x1 - x0) * (y1 - y0) / 700)):
        x, y = r.randrange(x0 + 8, x1 - 8), r.randrange(y0 + 8, y1 - 8)
        alb[y, x] = col("rift2"); emis[y, x] += col("rift3") * 0.8
    # Bars, a riveted frame, rust, and a couple of bars rusted through.
    pitch, bar = 16, 4
    gxm = ((XX - x0) % pitch) < bar
    gym = ((YY - y0) % pitch) < bar
    rust = fbm(h, w, 18, 3, seed + 1)
    broken = (rust > 0.72) & ~(gxm & gym)
    bars = inside & (gxm | gym) & ~broken
    rim = (~inside) & (XX >= x0 - 4) & (XX < x1 + 4) & (YY >= y0 - 4) & (YY < y1 + 4)
    metal = bars | rim
    shade = np.where(gxm & gym, 0.85, 0.6)
    iron = mix(col("metal0"), col("metal1"), shade)
    iron = mix(iron, col("fire1") * 0.6 + col("wood1") * 0.4, np.clip((rust - 0.5) * 3, 0, 1))
    alb = np.where(metal[..., None], iron, alb)
    height = np.where(metal, 0.75 + (gxm & gym) * 0.15, height)
    rivet = rim & ((XX - x0 + 2) % 24 < 2) & (((YY - y0 + 2) % 24) < 2)
    alb = np.where(rivet[..., None], col("metal2"), alb)
    return alb, height, emis

# --- 5. Bronze sentencing seal set into the paving ------------------------------------------
def bronze_inlay(h, w, seed=5):
    YY, XX = grid(h, w)
    alb, height, emis = dressed_slabs(h, w, seed + 30)
    cx, cy = w / 2, h / 2
    d = np.hypot(XX - cx, YY - cy)
    R = min(w, h) * 0.38
    ring = (np.abs(d - R) < 3) | (np.abs(d - R * 0.62) < 2)
    ang = np.arctan2(YY - cy, XX - cx)
    spokes = (np.abs(np.sin(ang * 6)) < 0.08) & (d > R * 0.62) & (d < R)
    glyph = (np.abs(np.sin(ang * 18 + 0.4)) < 0.25) & (np.abs(d - R * 0.82) < 4) & (np.sin(ang * 3) > -0.2)
    core = d < R * 0.18
    inlay = ring | spokes | glyph | core
    tarnish = fbm(h, w, 14, 3, seed + 1)
    polish = np.exp(-((XX - cx) / (w * 0.25)) ** 2)   # a polished band where feet cross it
    bronze = mix(col("wood1"), col("wood3"), np.clip(polish * 0.9, 0, 1))
    bronze = mix(bronze, col("fire4") * 0.6 + col("wood3") * 0.4, np.clip(polish - 0.75, 0, 1))
    bronze = mix(bronze, col("rift1") * 0.7 + col("stone3") * 0.3, np.clip((tarnish - 0.45) * 2.5 * (1 - polish * 0.8), 0, 1))  # verdigris
    alb = np.where(inlay[..., None], bronze, alb)
    height = np.where(inlay, height + 0.12, height)
    return alb, height, emis

# --- Lighting and palette ------------------------------------------------------------
PAL = np.array([st.rgb(n) for n in st.PALETTE], np.float64) / 255.0

def quantize(alb):
    h, w = alb.shape[:2]
    bayer = np.tile(st.BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w]
    j = alb + (bayer[..., None] - 0.5) * 0.05
    d2 = ((j[..., None, :] - PAL[None, None]) ** 2).sum(-1)
    return PAL[np.argmin(d2, -1)]

def light(alb, height, emis, lights, ambient=(0.32, 0.32, 0.44)):
    h, w = height.shape
    YY, XX = grid(h, w)
    hp = np.pad(height, 1, mode="edge")
    dx = (hp[1:-1, 2:] - hp[1:-1, :-2]) * 2.4
    dy = (hp[2:, 1:-1] - hp[:-2, 1:-1]) * 2.4
    N = np.stack([-dx, -dy, np.ones_like(dx)], -1); N /= np.linalg.norm(N, axis=-1, keepdims=True)
    L_total = np.ones((h, w, 3)) * np.array(ambient)
    for (lx, ly, radius, c, inten) in lights:
        ddx, ddy = lx - XX, ly - YY
        dist = np.hypot(ddx, ddy)
        L = np.stack([ddx, ddy, np.full_like(ddx, 40.0)], -1); L /= np.linalg.norm(L, axis=-1, keepdims=True)
        ndl = np.clip((N * L).sum(-1), 0, 1)
        fall = np.clip(1 - dist / radius, 0, 1) ** 1.5
        L_total += (ndl * fall)[..., None] * c * inten
    return np.clip(quantize(alb) * L_total + emis, 0, 1)

def to_img(a):
    return Image.fromarray((a * 255).astype(np.uint8), "RGB")

# --- Swatch sheet -----------------------------------------------------------------------
def swatches():
    SW, SH = 240, 180
    items = [
        ("Rock-cut floor", "cells hewn into the cliff", rock_cut(SH, SW)),
        ("Dressed slabs", "imperial corridors and halls", dressed_slabs(SH, SW)),
        ("Packed earth + straw", "inside the cells", earth_straw(SH, SW)),
        ("Iron grate", "over the oubliette shafts", iron_grate(SH, SW)),
        ("Bronze seal", "judgement halls", bronze_inlay(SH, SW)),
        ("Rock-cut + straw", "an occupied hewn cell", None),
    ]
    a1, h1, e1 = rock_cut(SH, SW, 11)
    a2, h2, e2 = earth_straw(SH, SW, 12, straw_amount=0.6)
    m = (fbm(SH, SW, 40, 3, 13) > 0.5)[..., None]
    items[5] = (items[5][0], items[5][1], (np.where(m, a2, a1), np.where(m[..., 0], np.maximum(h1 * 0.5, h2), h1), e1))
    scale, pad, label_h = 2, 16, 40
    cols = 3
    sheet = Image.new("RGB", (cols * (SW * scale + pad) + pad, 2 * (SH * scale + pad + label_h) + pad), st.rgb("stone0"))
    d = ImageDraw.Draw(sheet)
    fire = col("fire4")
    for i, (name, where, (alb, hgt, emis)) in enumerate(items):
        lit = light(alb, hgt, emis, [(30, 20, 300, fire, 2.2)])
        img = to_img(lit).resize((SW * scale, SH * scale), Image.NEAREST)
        x = pad + (i % cols) * (SW * scale + pad); y = pad + (i // cols) * (SH * scale + pad + label_h)
        sheet.paste(img, (x, y))
        d.text((x, y + SH * scale + 6), f"{i + 1}. {name}", fill=st.rgb("rag2"))
        d.text((x, y + SH * scale + 20), where, fill=st.rgb("stone7"))
    sheet.save(os.path.join(OUT, "swatches_penance_cells.png"))

# --- Cell-block vignette: how the materials meet ---------------------------------------------
def vignette():
    W, H = 480, 270
    YY, XX = grid(H, W)
    corr_y0, corr_y1 = 120, 200            # the corridor (dressed slabs)
    wall_t = 14
    a_slab, h_slab, e_slab = dressed_slabs(H, W, 40)
    a_rock, h_rock, e_rock = rock_cut(H, W, 41)
    a_str, h_str, e_str = earth_straw(H, W, 42, straw_amount=0.8)
    alb = a_slab.copy(); hgt = h_slab.copy(); emis = np.zeros((H, W, 3))

    # Cells above the corridor: hewn rock, straw bedding near the back wall.
    cells = YY < corr_y0 - wall_t
    straw = cells & (fbm(H, W, 30, 3, 43) + np.clip((60 - YY) / 80, 0, 1) * 0.5 > 0.62)
    alb = np.where(cells[..., None], a_rock, alb); hgt = np.where(cells, h_rock, hgt)
    alb = np.where(straw[..., None], a_str, alb); hgt = np.where(straw, np.maximum(h_rock * 0.5, h_str), hgt)

    # Walls between cells (top-down: dark tops with a pale lip), with doorways.
    walls = np.zeros((H, W), bool)
    walls |= (YY >= corr_y0 - wall_t) & (YY < corr_y0)
    for cx in (0, 160, 320, 480):
        walls |= (np.abs(XX - cx) < 7) & (YY < corr_y0)
    walls |= (YY >= corr_y1) & (YY < corr_y1 + wall_t)
    doors = []
    for dx in (80, 240, 400):
        door = (np.abs(XX - dx) < 14) & (YY >= corr_y0 - wall_t) & (YY < corr_y0)
        walls &= ~door; doors.append(dx)
    alb = np.where(walls[..., None], mix(col("stone1"), col("stone2"), fbm(H, W, 8, 2, 44) * 0.6), alb)
    hgt = np.where(walls, 1.0, hgt)
    lip = walls & ~np.roll(walls, -1, 0)
    alb = np.where(lip[..., None], col("stone5"), alb)

    # A reason for every boundary: a long dressed sill stone in each doorway, and iron door posts.
    for dx in doors:
        sill = (np.abs(XX - dx) < 14) & (YY >= corr_y0 - wall_t) & (YY < corr_y0)
        e = np.minimum(np.minimum(XX - (dx - 14), (dx + 13) - XX), np.minimum(YY - (corr_y0 - wall_t), (corr_y0 - 1) - YY))
        alb = np.where(sill[..., None], mix(col("stone3"), col("stone5"), np.clip(e / 4, 0, 1) * 0.6), alb)
        hgt = np.where(sill, 0.55 + np.clip(e / 4, 0, 1) * 0.1, hgt)
        for px in (dx - 15, dx + 14):
            post = (np.abs(XX - px) < 2) & (YY >= corr_y0 - wall_t - 2) & (YY < corr_y0 + 1)
            alb = np.where(post[..., None], col("metal1"), alb); hgt = np.where(post, 1.0, hgt)

    # An oubliette grate in the corridor, and a bronze seal at its end.
    gx0, gy0, gw, gh = 180, corr_y0 + 16, 56, 48
    ga, gh_, ge = iron_grate(gh, gw, 45, frame=6)
    alb[gy0:gy0 + gh, gx0:gx0 + gw] = ga; hgt[gy0:gy0 + gh, gx0:gx0 + gw] = gh_; emis[gy0:gy0 + gh, gx0:gx0 + gw] = ge
    ba, bh, be = bronze_inlay(64, 64, 46)
    sx0, sy0 = 400, corr_y0 + 8
    circle = np.hypot(np.arange(64)[None, :] - 32, np.arange(64)[:, None] - 32) < 30
    alb[sy0:sy0 + 64, sx0:sx0 + 64] = np.where(circle[..., None], ba, alb[sy0:sy0 + 64, sx0:sx0 + 64])
    hgt[sy0:sy0 + 64, sx0:sx0 + 64] = np.where(circle, bh, hgt[sy0:sy0 + 64, sx0:sx0 + 64])

    # Below the lower wall: the cliff face of the Rift itself (rock-cut, rougher).
    below = YY >= corr_y1 + wall_t
    alb = np.where(below[..., None], a_rock * 0.85, alb); hgt = np.where(below, h_rock, hgt)

    fire = col("fire4")
    lit = light(alb, hgt, emis, [(80, corr_y0 + 6, 200, fire, 2.0), (320, corr_y0 + 6, 200, fire, 2.0), (240, 60, 120, fire, 0.8)])
    img = to_img(lit)
    # Drop a prisoner and a guard in for scale.
    img = img.convert("RGBA")
    img.alpha_composite(st.char_sprite("prisoner", 24, 32), (232, 40))
    img.alpha_composite(st.char_sprite("guard", 24, 32), (120, corr_y0 + 30))
    img.alpha_composite(st.torch(1), (72, corr_y0 - 22)); img.alpha_composite(st.torch(2), (312, corr_y0 - 22))
    img = img.convert("RGB")
    img.resize((W * 2, H * 2), Image.NEAREST).save(os.path.join(OUT, "cellblock_vignette.png"))

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    swatches()
    vignette()
    print("Wrote", OUT)
