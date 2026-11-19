"""Layered ("paper-doll") character sprites.

Every human is the same rig, drawn as separate layers that line up frame for frame:
  body_<variant>   skin, hair, rag tunic, trousers, bare feet  (prisoner, guard)
  back_<tier>      cloak / mantle      (1 tattered, 2 Gaolwarden red, 3 Rift-teal mantle)
  head_<tier>      hood / helm         (1 hood, 2 Gaolwarden iron helm, 3 imperial bronze helm)
  torso_<tier>     armour              (1 leather jerkin, 2 mail + tabard, 3 bronze cuirass)
  hands_<tier>     wrists and hands    (0 broken shackles, 1 cloth wraps, 2 leather gloves, 3 bronze gauntlets)
  feet_<tier>      footwear            (1 rag wraps, 2 leather boots, 3 iron greaves)
The game stacks the layers it needs at runtime (scripts/CharacterSprite.gd), then adds the
outline and a normal map, so any combination of gear works.

Sheet layout (every layer, and the full gaoler/hound sheets): 4 columns x 12 rows.
  Rows: for each direction (down, up, right): idle(2), walk(4), crouch(2), act(1) frames.
  Left = right mirrored. Human frames are 24x32, the Gaoler 32x40, the hound 32x24.

Outputs: assets/art/chars/human/*.png, gaoler.png, hound.png,
         and previews in assets/art/style_test/chars_* (lineups x4 and walking GIFs).
Run: python3 tools/pixelart/characters.py
"""
import os, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import style_test as st

ROOT = st.ROOT
OUT = os.path.join(ROOT, "assets", "art", "chars")
PREV = st.OUT
DIRS = ["down", "up", "right"]
ANIMS = ["idle", "walk", "crouch", "act"]
NFRAMES = {"idle": 2, "walk": 4, "crouch": 2, "act": 1}
COLS, ROWS = 4, 12
ORDER = {"down": ["back", "body", "feet", "torso", "hands", "head"],
         "right": ["back", "body", "feet", "torso", "hands", "head"],
         "up": ["body", "feet", "torso", "hands", "back", "head"]}

HUMAN = dict(FW=24, FH=32, cx=12, head_w=8, head_h=8, head_y=3, torso_w=10, torso_y=11, torso_h=9,
             arm_w=2, leg_w=3, leg_gap=2, leg_y=20, leg_h=8)
BRUTE = dict(FW=32, FH=40, cx=16, head_w=6, head_h=6, head_y=8, torso_w=18, torso_y=11, torso_h=13,
             arm_w=4, leg_w=4, leg_gap=2, leg_y=24, leg_h=11)

def C(name):
    return st.rgb(name) + (255,)

class Canvas:
    def __init__(self, w, h):
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0)); self.w, self.h = w, h
    def rect(self, x, y, w, h, name):
        for yy in range(int(y), int(y + h)):
            for xx in range(int(x), int(x + w)):
                if 0 <= xx < self.w and 0 <= yy < self.h:
                    self.img.putpixel((xx, yy), C(name))
    def px(self, x, y, name):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.img.putpixel((int(x), int(y)), C(name))

# --- Poses ---------------------------------------------------------------------------
def pose(d, anim, f):
    p = dict(bob=0, cr=0, ll=0, lr=0, al=0, ar=0, swing=0, kick=False, raise_arms=False)
    if anim == "idle":
        p["bob"] = f            # breathing
    elif anim == "walk":
        p["bob"] = -1 if f in (1, 3) else 0
        if d == "right":
            p["swing"] = [0, 2, 0, -2][f]
        else:
            p["ll"] = 1 if f == 1 else 0; p["lr"] = 1 if f == 3 else 0
            p["al"] = [0, -1, 0, 1][f]; p["ar"] = -p["al"]
    elif anim == "crouch":
        p["cr"] = 4
        if d == "right":
            p["swing"] = [0, 1][f]
        else:
            p["ll"] = f
    elif anim == "act":
        p["kick"] = True; p["raise_arms"] = True
    return p

def geometry(R, d, p):
    """Rectangles (x, y, w, h) for each body part in this pose."""
    cx = R["cx"]; U = p["bob"] + p["cr"]
    g = {"dir": d}
    hw, hh = R["head_w"], R["head_h"]
    g["head"] = (cx - hw // 2, R["head_y"] + U, hw, hh)
    tw = R["torso_w"] if d != "right" else max(4, int(R["torso_w"] * 0.7))
    th = R["torso_h"] - (1 if p["cr"] else 0)
    g["torso"] = (cx - tw // 2, R["torso_y"] + U, tw, th)
    tx, ty = g["torso"][0], g["torso"][1]
    aw = R["arm_w"]; ah = th - 1
    lift = -2 if p["raise_arms"] else 0
    if d == "right":
        s = p["swing"]
        g["arm_far"] = (cx - aw // 2 - 1 - s // 2, ty + 1 + lift, aw, ah)
        g["arm_near"] = (cx - aw // 2 + 1 + s // 2 + (2 if p["raise_arms"] else 0), ty + 1 + lift, aw, ah)
    else:
        g["arm_l"] = (tx - aw, ty + 1 + p["al"] + lift, aw, ah)
        g["arm_r"] = (tx + tw, ty + 1 + p["ar"] + lift, aw, ah)
    lw, ly = R["leg_w"], R["leg_y"] + p["cr"]
    lh = R["leg_h"] - p["cr"]
    if d == "right":
        s = p["swing"]
        g["leg_back"] = (cx - lw // 2 - s, ly, lw, lh)
        if p["kick"]:
            g["leg_front"] = (cx, ly + 2, lh + 2, lw)          # leg out straight: a kick
        else:
            g["leg_front"] = (cx - lw // 2 + s, ly, lw, lh)
    else:
        spread = 1 if p["cr"] else 0
        g["leg_l"] = (cx - R["leg_gap"] // 2 - lw - spread, ly, lw, lh - p["ll"])
        g["leg_r"] = (cx + R["leg_gap"] // 2 + spread, ly, lw, lh - p["lr"])
    return g

def arms(g):
    return [("arm_far", True), ("arm_near", False)] if g["dir"] == "right" else [("arm_l", False), ("arm_r", True)]

def legs(g):
    return [("leg_back", True), ("leg_front", False)] if g["dir"] == "right" else [("leg_l", False), ("leg_r", True)]

def is_kick(g, name):
    return g["dir"] == "right" and name == "leg_front" and g["leg_front"][2] > g["leg_front"][3]

# --- Layers -------------------------------------------------------------------------
BODIES = {
    "prisoner": dict(skin="skin2", skin_dark="skin1", hair="wood0", tunic="rag1", tunic_dark="rag0", pants="stone3", pants_dark="stone2"),
    "guard": dict(skin="stone6", skin_dark="stone5", hair="stone1", tunic="stone3", tunic_dark="stone2", pants="stone2", pants_dark="stone1"),
    "brute": dict(skin="stone6", skin_dark="stone5", hair="stone1", tunic="wood1", tunic_dark="wood0", pants="wood1", pants_dark="wood0"),
}

def draw_body(c, g, v):
    d = g["dir"]
    # Far limbs first (darker), then torso, then near limbs.
    for name, far in legs(g):
        x, y, w, h = g[name]
        c.rect(x, y, w, h, v["pants_dark"] if far else v["pants"])
        if is_kick(g, name):
            c.rect(x + w - 1, y - 1, 2, h + 1, v["skin_dark"])
        else:
            c.rect(x - (0 if d != "right" else 0), y + h - 1, w + (1 if d == "right" else 0), 1, v["skin_dark"])  # bare feet
    for name, far in arms(g):
        if far:
            x, y, w, h = g[name]; c.rect(x, y, w, h, v["skin_dark"])
    x, y, w, h = g["torso"]
    c.rect(x, y, w, h, v["tunic"])
    c.rect(x + w - 1, y, 1, h, v["tunic_dark"])
    for i in range(0, w, 2):
        c.px(x + i, y + h, v["tunic_dark"])          # ragged hem
    for name, far in arms(g):
        if not far:
            x, y, w, h = g[name]; c.rect(x, y, w, h, v["skin"])
    hx, hy, hw, hh = g["head"]
    c.rect(g["torso"][0] + g["torso"][2] // 2 - 1, hy + hh, 2, 1, v["skin_dark"])  # neck
    if d == "down":
        c.rect(hx, hy, hw, 3, v["hair"])
        c.rect(hx + 1, hy + 3, hw - 2, hh - 3, v["skin"])
        c.rect(hx, hy + 3, 1, 3, v["hair"]); c.rect(hx + hw - 1, hy + 3, 1, 3, v["hair"])
        c.rect(hx + 1, hy + hh - 1, hw - 2, 1, v["skin_dark"])
        c.px(hx + 2, hy + 4, "stone0"); c.px(hx + hw - 3, hy + 4, "stone0")
    elif d == "up":
        c.rect(hx, hy, hw, hh, v["hair"])
        c.rect(hx + 1, hy + hh - 1, hw - 2, 1, v["skin_dark"])
    else:
        c.rect(hx, hy, hw, 3, v["hair"])
        c.rect(hx, hy + 3, hw // 2, hh - 4, v["hair"])
        c.rect(hx + hw // 2, hy + 3, hw - hw // 2, hh - 3, v["skin"])
        c.rect(hx + 1, hy + hh - 1, hw - 2, 1, v["skin_dark"])
        c.px(hx + hw - 2, hy + 4, "stone0")
        c.px(hx + hw, hy + 5, v["skin_dark"])         # nose

def draw_back(c, g, tier):
    cols = {1: ("stone3", "stone2"), 2: ("red1", "red0"), 3: ("rift1", "rift0")}[tier]
    x, y, w, h = g["torso"]
    d = g["dir"]
    if d == "down":
        rx, ry, rw, rh = x - 1, y + 1, w + 2, h + 4
    elif d == "up":
        rx, ry, rw, rh = x, y, w, h + 5
    else:
        rx, ry, rw, rh = x - 3, y + 1, 4, h + 4
    c.rect(rx, ry, rw, rh, cols[0])
    c.rect(rx, ry + rh - 2, rw, 2, cols[1])
    if tier == 1:   # tattered hem
        for i in range(0, rw, 3):
            c.rect(rx + i, ry + rh - 1, 1, 1, "stone2"); c.img.putpixel((min(c.w - 1, rx + i + 1), min(c.h - 1, ry + rh - 1)), (0, 0, 0, 0))
    if tier == 3:   # bronze trim and clasp
        c.rect(rx, ry + rh - 1, rw, 1, "wood3")
        if d == "up":
            c.rect(rx + rw // 2 - 1, ry, 2, 1, "fire4")

def draw_head(c, g, tier):
    hx, hy, hw, hh = g["head"]
    d = g["dir"]
    if tier == 1:   # hood
        c.rect(hx - 1, hy - 1, hw + 2, 4, "stone4")
        c.rect(hx - 1, hy + 3, 1, hh - 3, "stone4"); c.rect(hx + hw, hy + 3, 1, hh - 3, "stone4")
        if d == "up":
            c.rect(hx - 1, hy - 1, hw + 2, hh + 1, "stone4")
        c.rect(hx - 1, hy - 1, hw + 2, 1, "stone5")
        if d == "right":
            c.rect(hx - 1, hy - 1, hw // 2 + 1, hh, "stone4")
    elif tier == 2:  # Gaolwarden iron helm with a nasal guard
        c.rect(hx - 1, hy - 1, hw + 2, 4, "metal1")
        c.rect(hx - 1, hy - 1, hw + 2, 1, "metal2")
        c.rect(hx - 1, hy + 3, 1, hh - 2, "metal0"); c.rect(hx + hw, hy + 3, 1, hh - 2, "metal0")
        if d == "down":
            c.rect(hx + hw // 2 - 1 + (hw % 2), hy + 3, 1, 3, "metal1")
        elif d == "up":
            c.rect(hx - 1, hy - 1, hw + 2, hh, "metal1"); c.rect(hx, hy, hw, 1, "metal2")
        else:
            c.rect(hx - 1, hy - 1, hw // 2 + 1, hh, "metal1"); c.px(hx + hw - 1, hy + 3, "metal1")
    elif tier == 3:  # imperial bronze helm with a red crest
        c.rect(hx - 1, hy - 1, hw + 2, 4, "wood3")
        c.rect(hx - 1, hy - 1, hw + 2, 1, "fire4")
        c.rect(hx - 1, hy + 3, 1, hh - 2, "wood2"); c.rect(hx + hw, hy + 3, 1, hh - 2, "wood2")
        if d == "up":
            c.rect(hx - 1, hy - 1, hw + 2, hh, "wood3")
        elif d == "right":
            c.rect(hx - 1, hy - 1, hw // 2 + 1, hh, "wood3")
        if d == "right":
            c.rect(hx - 1, hy - 3, hw - 1, 2, "red1"); c.rect(hx - 2, hy - 2, 1, 3, "red0")
        else:
            c.rect(hx + hw // 2 - 1, hy - 3, 2, 2, "red1"); c.px(hx + hw // 2 - 1, hy - 3, "red2")

def draw_torso(c, g, tier):
    x, y, w, h = g["torso"]
    d = g["dir"]
    if tier == 1:   # scavenged leather jerkin with a strap
        c.rect(x, y, w, h - 1, "wood1"); c.rect(x, y, 1, h - 1, "wood2"); c.rect(x + w - 1, y, 1, h - 1, "wood0")
        for i in range(min(w, h - 1)):
            c.px(x + i, y + i, "wood0")
        c.rect(x, y + h - 2, w, 1, "wood0")
    elif tier == 2:  # mail with a Gaolwarden tabard
        c.rect(x, y, w, h, "metal1"); c.rect(x, y, w, 1, "metal2")
        for yy in range(y + 1, y + h, 2):
            for xx in range(x + (yy % 2), x + w, 2):
                c.px(xx, yy, "metal0")
        if d != "up":
            tx0 = x + 2 if d == "down" else x + 1
            tw = w - 4 if d == "down" else w - 2
            c.rect(tx0, y + 1, tw, h + 3, "red1"); c.rect(tx0 + tw - 1, y + 1, 1, h + 3, "red0")
            if d == "down":
                c.rect(x + w // 2 - 1, y + 3, 2, 2, "metal2")    # emblem
        else:
            c.rect(x + 2, y + 1, w - 4, h + 2, "red0")
    elif tier == 3:  # imperial bronze cuirass with pauldrons
        c.rect(x, y, w, h - 1, "wood3"); c.rect(x, y, w, 1, "fire4"); c.rect(x + w - 1, y, 1, h - 1, "wood2")
        c.rect(x + 1, y + h - 2, w - 2, 1, "wood2")
        if d != "right":
            c.rect(x - 2, y - 1, 3, 3, "wood3"); c.rect(x + w - 1, y - 1, 3, 3, "wood3")
            c.px(x - 2, y - 1, "fire4"); c.px(x + w + 1, y - 1, "fire4")
        else:
            c.rect(x + 1, y - 1, 4, 3, "wood3"); c.px(x + 1, y - 1, "fire4")
        if d == "down":
            c.rect(x + w // 2 - 1, y + 2, 2, 3, "rift2")       # a Rift-glass inset

def draw_hands(c, g, tier):
    for name, far in arms(g):
        x, y, w, h = g[name]
        if tier == 0:   # broken shackles: an iron cuff, a stub of chain on one wrist
            c.rect(x, y + h - 3, w, 1, "metal1")
            if not far:
                c.px(x + w // 2, y + h, "metal2"); c.px(x + w // 2, y + h + 1, "metal1")
        elif tier == 1:
            c.rect(x, y + h - 4, w, 4, "rag0"); c.rect(x, y + h - 4, w, 1, "rag1")
        elif tier == 2:
            c.rect(x, y + h - 3, w, 3, "wood0"); c.rect(x, y + h - 3, w, 1, "wood1")
        elif tier == 3:
            c.rect(x, y + h - 5, w, 5, "wood3"); c.rect(x, y + h - 5, w, 1, "fire4")

def draw_feet(c, g, tier):
    for name, far in legs(g):
        x, y, w, h = g[name]
        if is_kick(g, name):
            # Leg is horizontal: footwear goes on the end.
            cols = {1: "rag0", 2: "wood0", 3: "metal1"}[tier]
            c.rect(x + w - 3, y - 1, 3, h + 1, cols)
            if tier == 3:
                c.rect(x, y, w - 3, h, "metal1"); c.rect(x, y, w - 3, 1, "metal2")
            continue
        ext = 1 if g["dir"] == "right" else 0
        if tier == 1:
            c.rect(x, y + h - 3, w + ext, 3, "rag0")
        elif tier == 2:
            c.rect(x, y + h - 4, w + ext, 4, "wood0"); c.rect(x, y + h - 4, w, 1, "wood1")
        elif tier == 3:
            c.rect(x, y + h - 7, w, 7, "metal1"); c.rect(x, y + h - 7, w, 1, "metal2")
            c.rect(x, y + h - 1, w + ext, 1, "metal0")

LAYERS = {"back": draw_back, "head": draw_head, "torso": draw_torso, "hands": draw_hands, "feet": draw_feet}

# --- Sheets ---------------------------------------------------------------------------
def frame_slots():
    for di, d in enumerate(DIRS):
        for ai, a in enumerate(ANIMS):
            for f in range(NFRAMES[a]):
                yield di * 4 + ai, f, d, a

def sheet(R, painter):
    FW, FH = R["FW"], R["FH"]
    img = Image.new("RGBA", (COLS * FW, ROWS * FH), (0, 0, 0, 0))
    for row, f, d, a in frame_slots():
        c = Canvas(FW, FH)
        painter(c, geometry(R, d, pose(d, a, f)))
        img.alpha_composite(c.img, (f * FW, row * FH))
    return img

def outline(img, FW, FH):
    """1px dark outline around the silhouette, frame by frame (never across frame edges)."""
    px = img.load(); w, h = img.size
    out = img.copy(); op = out.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if xx // FW != x // FW or yy // FH != y // FH:
                        continue
                    if 0 <= xx < w and 0 <= yy < h and px[xx, yy][3] > 0:
                        op[x, y] = C("void"); break
    return out

def compose(R, body, gear):
    """Stack layers the way the game does (for previews and the gaoler sheet)."""
    FW, FH = R["FW"], R["FH"]
    full = Image.new("RGBA", (COLS * FW, ROWS * FH), (0, 0, 0, 0))
    for row, f, d, a in frame_slots():
        g = geometry(R, d, pose(d, a, f))
        c = Canvas(FW, FH)
        for slot in ORDER[d]:
            if slot == "body":
                draw_body(c, g, BODIES[body])
            elif slot in gear and gear[slot] is not None:
                LAYERS[slot](c, g, gear[slot])
        full.alpha_composite(c.img, (f * FW, row * FH))
    return outline(full, FW, FH)

# --- Hound: a simple quadruped, side view used for every direction ------------------------
def hound_sheet():
    FW, FH = 32, 24
    img = Image.new("RGBA", (COLS * FW, ROWS * FH), (0, 0, 0, 0))
    for row, f, d, a in frame_slots():
        c = Canvas(FW, FH)
        step = [0, 1, 0, -1][f] if a == "walk" else 0
        low = 3 if a == "crouch" else 0
        lunge = 3 if a == "act" else 0
        by = 9 + low
        c.rect(7, by, 16, 6, "wood2"); c.rect(7, by + 4, 16, 2, "wood1")        # body
        c.rect(9, by - 1, 10, 1, "wood1")                                           # raised hackles
        c.rect(22 + lunge, by - 3, 6, 5, "wood2"); c.rect(27 + lunge, by - 1, 3, 2, "wood1")  # head, snout
        c.px(29 + lunge, by - 1, "void"); c.px(25 + lunge, by - 2, "red2")             # nose, eye
        c.rect(23 + lunge, by - 5, 2, 2, "wood1")                                    # ear
        c.rect(3, by - 2, 4, 2, "wood1"); c.px(2, by - 3, "wood1")                   # tail
        if a == "act":
            c.px(28 + lunge, by + 1, "rag2"); c.px(27 + lunge, by + 1, "rag2")       # teeth
        for lx, ph in ((9, 1), (12, -1), (18, 1), (21, -1)):
            c.rect(lx + step * ph, by + 6, 2, 6 - low, "wood1")
            c.px(lx + step * ph, by + 11 - low, "wood0")
        img.alpha_composite(c.img, (f * FW, row * FH))
    return outline(img, FW, FH)

# --- Build everything -------------------------------------------------------------------------
PRESETS = {
    "Prisoner":     {"hands": 0},
    "Scavenger":    {"back": 1, "head": 1, "torso": 1, "hands": 1, "feet": 1},
    "Turncoat":     {"back": 2, "head": 2, "torso": 2, "hands": 2, "feet": 2},
    "Relic-bearer": {"back": 3, "head": 3, "torso": 3, "hands": 3, "feet": 3},
}
GUARD_GEAR = {"back": 2, "head": 2, "torso": 2, "hands": 2, "feet": 3}
GAOLER_GEAR = {"head": 2, "torso": 2, "hands": 3, "feet": 3}

def frame(img, R, row, col):
    return img.crop((col * R["FW"], row * R["FH"], (col + 1) * R["FW"], (row + 1) * R["FH"]))

def previews():
    R = HUMAN
    # Lineup: each preset facing down, right (walking) and up, plus a guard and the gaoler.
    sheets = [(name, compose(R, "prisoner", gear)) for name, gear in PRESETS.items()]
    sheets.append(("Guard", compose(R, "guard", GUARD_GEAR)))
    s = 4
    cellw, cellh = 3 * R["FW"] * s + 40, R["FH"] * s + 60
    line = Image.new("RGB", (cellw * 3, cellh * 2 + 20), st.rgb("stone1"))
    from PIL import ImageDraw
    dr = ImageDraw.Draw(line)
    for i, (name, sh) in enumerate(sheets):
        x0 = (i % 3) * cellw + 20; y0 = (i // 3) * cellh + 20
        for j, (row, col) in enumerate([(0, 0), (9, 1), (4, 0)]):   # down idle, right walk, up idle
            fr = frame(sh, R, row, col).resize((R["FW"] * s, R["FH"] * s), Image.NEAREST)
            line.paste(fr, (x0 + j * R["FW"] * s, y0), fr)
        dr.text((x0, y0 + R["FH"] * s + 8), name, fill=st.rgb("rag2"))
    gsh = compose(BRUTE, "brute", GAOLER_GEAR)
    x0 = 2 * cellw + 20; y0 = cellh + 20
    for j, (row, col) in enumerate([(0, 0), (9, 1)]):
        fr = frame(gsh, BRUTE, row, col).resize((BRUTE["FW"] * 3, BRUTE["FH"] * 3), Image.NEAREST)
        line.paste(fr, (x0 + j * BRUTE["FW"] * 3, y0), fr)
    dr.text((x0, y0 + BRUTE["FH"] * 3 + 8), "Gaoler", fill=st.rgb("rag2"))
    line.save(os.path.join(PREV, "chars_lineup_x4.png"))
    # Walking GIF: the four presets side by side, walking right then down.
    frames = []
    for row in (9, 1):
        for col in range(4):
            fimg = Image.new("RGB", (4 * R["FW"] * s, R["FH"] * s), st.rgb("stone1"))
            for i, (name, sh) in enumerate(sheets[:4]):
                fr = frame(sh, R, row, col).resize((R["FW"] * s, R["FH"] * s), Image.NEAREST)
                fimg.paste(fr, (i * R["FW"] * s, 0), fr)
            frames.extend([fimg] * 1)
    frames[0].save(os.path.join(PREV, "chars_walk.gif"), save_all=True, append_images=frames[1:] * 3, duration=140, loop=0)
    # Mix and match: prisoner who has found boots and a helm, nothing else.
    mixed = compose(R, "prisoner", {"hands": 0, "feet": 2, "head": 2})
    m = frame(mixed, R, 0, 0).resize((R["FW"] * s, R["FH"] * s), Image.NEAREST)
    m.save(os.path.join(PREV, "chars_mixed_example_x4.png"))
    # The four poses of the prisoner facing right: idle, walk, crouch, kick.
    sh = sheets[0][1]
    poses = Image.new("RGB", (4 * R["FW"] * s, R["FH"] * s), st.rgb("stone1"))
    for i, (row, col) in enumerate([(8, 0), (9, 1), (10, 0), (11, 0)]):
        fr = frame(sh, R, row, col).resize((R["FW"] * s, R["FH"] * s), Image.NEAREST)
        poses.paste(fr, (i * R["FW"] * s, 0), fr)
    poses.save(os.path.join(PREV, "chars_poses_x4.png"))

def main():
    hum = os.path.join(OUT, "human"); os.makedirs(hum, exist_ok=True)
    R = HUMAN
    for v in ("prisoner", "guard"):
        sheet(R, lambda c, g, v=v: draw_body(c, g, BODIES[v])).save(os.path.join(hum, f"body_{v}.png"))
    for slot, fn in LAYERS.items():
        tiers = [0, 1, 2, 3] if slot == "hands" else [1, 2, 3]
        for t in tiers:
            sheet(R, lambda c, g, fn=fn, t=t: fn(c, g, t)).save(os.path.join(hum, f"{slot}_{t}.png"))
    # Full sheets (composed, outlined) for the non-human-sized characters.
    compose(BRUTE, "brute", GAOLER_GEAR).save(os.path.join(OUT, "gaoler.png"))
    hound_sheet().save(os.path.join(OUT, "hound.png"))
    previews()
    print("Wrote character layers to", OUT)

if __name__ == "__main__":
    main()
