"""Layered ("paper-doll") character sprites, with shading, detail and smooth animation.

Every human is the same rig, drawn as separate layers that line up frame for frame:
  body_<variant>   skin, hair, face, tunic, trousers, bare feet   (prisoner, guard)
  back_<tier>      cloak / mantle      (1 tattered, 2 Gaolwarden red, 3 Rift-teal mantle)
  head_<tier>      hood / helm         (1 hood, 2 Gaolwarden iron helm, 3 imperial bronze helm)
  torso_<tier>     armour              (1 leather jerkin, 2 mail + tabard, 3 bronze cuirass)
  hands_<tier>     wrists and hands    (0 broken shackles, 1 cloth wraps, 2 leather gloves, 3 bronze gauntlets)
  feet_<tier>      footwear            (1 rag wraps, 2 leather boots, 3 iron greaves)
The game stacks the layers at runtime (scripts/CharacterSprite.gd), then outlines them and
builds a normal map, so any combination of gear works.

Every part is shaded with light from the upper left (a highlight edge, a base tone and a
shadow edge), and has hand-placed details: faces, belts, patches, rivets, folds, laces.

Sheet layout (every layer, and the full Gaoler/hound sheets): 8 columns x 15 rows.
  Rows: for each direction (down, up, right; left = right mirrored), five animations:
    idle (4 frames), walk (8), crouch (4), strike (3), kick (3).
  Human frames are 24x32, the Gaoler 32x40, the hound 32x24.

Outputs: assets/art/chars/human/*.png, gaoler.png, hound.png,
         previews in assets/art/style_test/chars_* (lineup, poses, walking GIF).
Run: python3 tools/pixelart/characters.py
"""
import os, sys, math
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import style_test as st

ROOT = st.ROOT
OUT = os.path.join(ROOT, "assets", "art", "chars")
PREV = st.OUT
DIRS = ["down", "up", "right"]
ANIMS = ["idle", "walk", "crouch", "strike", "kick"]
NFRAMES = {"idle": 4, "walk": 8, "crouch": 4, "strike": 3, "kick": 3}
COLS, ROWS = 8, len(DIRS) * len(ANIMS)
ORDER = {"down": ["back", "body", "feet", "torso", "hands", "head"],
         "right": ["back", "body", "feet", "torso", "hands", "head"],
         "up": ["body", "feet", "torso", "hands", "back", "head"]}

HUMAN = dict(FW=24, FH=32, cx=12, head_w=8, head_h=8, head_y=3, torso_w=10, torso_y=11, torso_h=9,
             arm_w=2, leg_w=3, leg_gap=2, leg_y=20, leg_h=8)
BRUTE = dict(FW=32, FH=40, cx=16, head_w=6, head_h=6, head_y=9, torso_w=18, torso_y=12, torso_h=13,
             arm_w=4, leg_w=4, leg_gap=2, leg_y=25, leg_h=11)

# Shading ramps: (highlight, base, shadow).
RAMP = {
    "skin": ("rag2", "skin2", "skin1"), "skin_pale": ("stone7", "stone6", "stone5"),
    "hair": ("wood2", "wood1", "wood0"), "hair_dark": ("stone3", "stone2", "stone1"),
    "rags": ("rag2", "rag1", "rag0"), "grey_cloth": ("stone5", "stone4", "stone3"),
    "trousers": ("stone4", "stone3", "stone2"), "dark_trousers": ("stone3", "stone2", "stone1"),
    "leather": ("wood3", "wood2", "wood1"), "dark_leather": ("wood2", "wood1", "wood0"),
    "iron": ("metal2", "metal1", "metal0"), "red": ("red2", "red1", "red0"),
    "bronze": ("fire4", "wood3", "wood2"), "teal": ("rift2", "rift1", "rift0"),
    "hood": ("stone5", "stone4", "stone3"), "fur": ("wood3", "wood2", "wood1"),
}

def C(name):
    return st.rgb(name) + (255,)

class Canvas:
    def __init__(self, w, h):
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0)); self.w, self.h = w, h
    def px(self, x, y, name):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.img.putpixel((x, y), C(name))
    def clear(self, x, y):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.img.putpixel((x, y), (0, 0, 0, 0))
    def rect(self, x, y, w, h, name):
        for yy in range(int(y), int(y + h)):
            for xx in range(int(x), int(x + w)):
                self.px(xx, yy, name)
    def shaded(self, x, y, w, h, ramp, light_top=True):
        """A block lit from the upper left: highlight on the top/left edge, shadow bottom/right."""
        hi, base, sh = RAMP[ramp]
        x, y, w, h = int(x), int(y), int(w), int(h)
        self.rect(x, y, w, h, base)
        if w >= 2:
            self.rect(x + w - 1, y, 1, h, sh)
        if h >= 3:
            self.rect(x, y + h - 1, w, 1, sh)
        if light_top and h >= 2:
            self.rect(x, y, max(1, w - 1), 1, hi)
        if w >= 3 and h >= 3:
            self.rect(x, y, 1, h - 1, hi)

# --- Poses ---------------------------------------------------------------------------
def pose(d, anim, f):
    p = dict(bob=0, cr=0, ll=0, lr=0, al=0, ar=0, swing=0, arm_swing=0, kick=-1, strike=-1, lean=0)
    if anim == "idle":
        p["bob"] = [0, 0, 1, 1][f]
    elif anim == "walk":
        s = math.sin(f / 8 * math.tau)
        p["bob"] = -1 if abs(s) < 0.4 else 0                 # passing pose rises
        if d == "right":
            p["swing"] = int(round(2.6 * s)); p["arm_swing"] = int(round(-1.6 * s))
            p["ll"] = 1 if math.cos(f / 8 * math.tau) > 0.6 else 0   # lifting the front foot
        else:
            p["ll"] = 2 if s > 0.85 else (1 if s > 0.35 else 0)
            p["lr"] = 2 if s < -0.85 else (1 if s < -0.35 else 0)
            p["al"] = int(round(-1.4 * s)); p["ar"] = -p["al"]
    elif anim == "crouch":
        p["cr"] = 4
        s = math.sin(f / 4 * math.tau)
        if d == "right":
            p["swing"] = int(round(1.5 * s))
        else:
            p["ll"] = 1 if s > 0.5 else 0; p["lr"] = 1 if s < -0.5 else 0
    elif anim == "strike":
        p["strike"] = f; p["lean"] = [-1, 1, 1][f]
    elif anim == "kick":
        p["kick"] = f; p["lean"] = [-1, -1, 0][f]
    return p

def geometry(R, d, p):
    """Rectangles (x, y, w, h) for each body part, plus which limbs are held out straight."""
    cx = R["cx"]; U = p["bob"] + p["cr"]
    lean_x = p["lean"] if d == "right" else 0
    lean_y = max(0, p["lean"]) if d == "down" else 0
    g = {"dir": d, "horiz": set()}
    hw, hh = R["head_w"], R["head_h"]
    g["head"] = (cx - hw // 2 + lean_x, R["head_y"] + U + lean_y, hw, hh)
    tw = R["torso_w"] if d != "right" else max(4, int(R["torso_w"] * 0.7))
    th = R["torso_h"] - (1 if p["cr"] else 0)
    g["torso"] = (cx - tw // 2 + lean_x, R["torso_y"] + U + lean_y, tw, th)
    tx, ty = g["torso"][0], g["torso"][1]
    aw = R["arm_w"]; ah = th - 1
    st_ = p["strike"]
    if d == "right":
        s = p["arm_swing"]
        g["arm_far"] = (cx - aw // 2 - 1 - s + lean_x, ty + 1, aw, ah)
        if st_ == 0:
            g["arm_near"] = (cx - aw // 2 - 3 + lean_x, ty - 1, aw, ah)        # drawn back
        elif st_ in (1, 2):
            reach = ah + (2 if st_ == 1 else 0)
            g["arm_near"] = (cx + lean_x, ty + 2 + (st_ - 1) * 2, reach, aw)   # thrust forward
            g["horiz"].add("arm_near")
        else:
            g["arm_near"] = (cx - aw // 2 + 1 + s + lean_x, ty + 1, aw, ah)
    else:
        lift = {0: -2, 1: 1, 2: 0}.get(st_, 0)
        inward = 1 if st_ == 1 else 0
        g["arm_l"] = (tx - aw + inward, ty + 1 + p["al"] + lift, aw, ah)
        g["arm_r"] = (tx + tw - inward, ty + 1 + p["ar"] + lift, aw, ah)
    lw, ly = R["leg_w"], R["leg_y"] + p["cr"]
    lh = R["leg_h"] - p["cr"]
    k = p["kick"]
    if d == "right":
        s = p["swing"]
        g["leg_back"] = (cx - lw // 2 - s, ly, lw, lh)
        if k == 1:
            g["leg_front"] = (cx, ly + 1, lh + 3, lw); g["horiz"].add("leg_front")       # full kick
        elif k == 2:
            g["leg_front"] = (cx + 1, ly + 2, lh, lw); g["horiz"].add("leg_front")       # pulling back
        elif k == 0:
            g["leg_front"] = (cx + 1, ly - 1, lw, lh - 3)                                # knee up
        else:
            g["leg_front"] = (cx - lw // 2 + s, ly, lw, lh - p["ll"])
    else:
        spread = 1 if p["cr"] else 0
        kl = {0: 3, 1: 4, 2: 2}.get(k, 0)
        g["leg_l"] = (cx - R["leg_gap"] // 2 - lw - spread, ly, lw, lh - p["ll"])
        g["leg_r"] = (cx + R["leg_gap"] // 2 + spread, ly, lw, lh - p["lr"] - kl)
    return g

def arms(g):
    return [("arm_far", True), ("arm_near", False)] if g["dir"] == "right" else [("arm_l", False), ("arm_r", True)]

def legs(g):
    return [("leg_back", True), ("leg_front", False)] if g["dir"] == "right" else [("leg_l", False), ("leg_r", True)]

def limb_end(g, name, n):
    """The last n pixels of a limb (the hand or the foot)."""
    x, y, w, h = g[name]
    if name in g["horiz"]:
        return (x + w - n, y, n, h)
    return (x, y + h - n, w, n)

# --- Body ---------------------------------------------------------------------------
BODIES = {
    "prisoner": dict(skin="skin", hair="hair", tunic="rags", pants="trousers", eyes="stone0", patch=True, belt=True),
    "guard": dict(skin="skin_pale", hair="hair_dark", tunic="grey_cloth", pants="dark_trousers", eyes="red2", patch=False, belt=False),
    "brute": dict(skin="skin_pale", hair="hair_dark", tunic="dark_leather", pants="dark_leather", eyes="red2", patch=False, belt=False),
}

def draw_body(c, g, v):
    d = g["dir"]
    sk = RAMP[v["skin"]]
    # Far limbs first (darker), then the torso, then near limbs.
    for name, far in legs(g):
        x, y, w, h = g[name]
        c.shaded(x, y, w, h, v["pants"])
        if far:
            c.rect(x, y, w, h, RAMP[v["pants"]][2])
        fx, fy, fw, fh = limb_end(g, name, 2)
        c.rect(fx, fy, fw + (1 if d == "right" and name not in g["horiz"] else 0), fh, sk[2])   # bare feet
        if v["patch"] and not far and h >= 6 and name not in g["horiz"]:
            c.px(x + 1, y + 2, "rag0"); c.px(x + 1, y + 3, "rag0")                              # knee patch
    for name, far in arms(g):
        if far:
            x, y, w, h = g[name]; c.rect(x, y, w, h, sk[2])
    x, y, w, h = g["torso"]
    c.shaded(x, y, w, h, v["tunic"])
    if d != "up":
        c.px(x + w // 2, y, RAMP[v["tunic"]][2]); c.px(x + w // 2 - 1, y + 1, RAMP[v["tunic"]][2])  # neckline
    for i in range(0, w, 2):
        c.px(x + i, y + h, RAMP[v["tunic"]][2])                                                    # ragged hem
    if v["patch"] and d == "down":
        c.rect(x + 1, y + 4, 3, 3, "rag0"); c.px(x + 2, y + 4, "rag1"); c.px(x + 1, y + 6, "stone3")  # a stitched patch
    if v["belt"]:
        c.rect(x, y + h - 3, w, 1, "wood2")
        if d == "down":
            c.px(x + w // 2 + 1, y + h - 2, "wood2"); c.px(x + w // 2 + 2, y + h - 1, "wood1")       # knot and loose end
    for name, far in arms(g):
        if not far:
            ax, ay, aw, ah = g[name]
            c.shaded(ax, ay, aw, ah, v["skin"])
    hx, hy, hw, hh = g["head"]
    c.rect(g["torso"][0] + g["torso"][2] // 2 - 1, hy + hh, 2, 1, sk[2])                         # neck
    hr = RAMP[v["hair"]]
    if d == "down":
        c.shaded(hx + 1, hy + 2, hw - 2, hh - 2, v["skin"])
        c.rect(hx, hy, hw, 3, hr[1]); c.rect(hx + 1, hy, hw - 3, 1, hr[0])
        c.rect(hx, hy + 3, 1, 3, hr[1]); c.rect(hx + hw - 1, hy + 3, 1, 4, hr[2])
        c.px(hx + 2, hy + 3, hr[2])                                                                # a fringe strand
        c.px(hx + 2, hy + 4, v["eyes"]); c.px(hx + hw - 3, hy + 4, v["eyes"])                     # eyes
        c.px(hx + 2, hy + 3, sk[2]) if v["skin"] == "skin_pale" else None                         # sunken brow
        c.px(hx + hw // 2 - 1, hy + 5, sk[0])                                                      # nose highlight
        c.rect(hx + 3, hy + 6, 2, 1, sk[2])                                                        # mouth
        if v["skin"] == "skin":
            c.px(hx + 1, hy + 6, "skin1"); c.px(hx + hw - 2, hy + 6, "skin1")                      # stubble
    elif d == "up":
        c.rect(hx, hy, hw, hh, hr[1]); c.rect(hx + 1, hy, hw - 3, 2, hr[0]); c.rect(hx + hw - 1, hy, 1, hh, hr[2])
        c.px(hx + 3, hy + 3, hr[2]); c.px(hx + 5, hy + 5, hr[2])                                   # strands
        c.rect(hx + 1, hy + hh - 1, hw - 2, 1, sk[2])
    else:
        c.shaded(hx + hw // 2, hy + 2, hw - hw // 2, hh - 2, v["skin"])
        c.rect(hx, hy, hw, 3, hr[1]); c.rect(hx + 1, hy, hw - 2, 1, hr[0])
        c.rect(hx, hy + 3, hw // 2, hh - 4, hr[1]); c.rect(hx, hy + 3, 1, hh - 4, hr[2])
        c.px(hx + hw - 2, hy + 4, v["eyes"])
        c.px(hx + hw, hy + 5, sk[1]); c.px(hx + hw, hy + 4, sk[0])                                 # nose
        c.px(hx + hw - 2, hy + 6, sk[2])
        c.px(hx + hw // 2 + 1, hy + 4, sk[2])                                                      # ear

# --- Gear layers -----------------------------------------------------------------------
def draw_back(c, g, tier):
    ramp = {1: "grey_cloth", 2: "red", 3: "teal"}[tier]
    x, y, w, h = g["torso"]
    d = g["dir"]
    if d == "down":
        rx, ry, rw, rh = x - 1, y + 1, w + 2, h + 4
    elif d == "up":
        rx, ry, rw, rh = x - 1, y, w + 2, h + 6
    else:
        rx, ry, rw, rh = x - 3, y + 1, 4, h + 5
    c.shaded(rx, ry, rw, rh, ramp)
    for i in range(2, rw - 1, 3):                     # folds
        c.rect(rx + i, ry + 2, 1, rh - 3, RAMP[ramp][2])
    if tier == 1:                                     # tattered hem
        for i in range(0, rw, 2):
            c.clear(rx + i, ry + rh - 1)
            if i % 4 == 0:
                c.clear(rx + i, ry + rh - 2)
    if tier == 2 and d == "up":
        c.rect(rx + rw // 2 - 1, ry + 3, 2, 2, "metal2")                     # key sigil
    if tier == 3:
        c.rect(rx, ry + rh - 1, rw, 1, "wood3")                              # bronze trim
        c.px(rx + 1, ry + rh - 2, "fire4")
        if d == "up":
            c.rect(rx + rw // 2 - 1, ry, 2, 1, "fire4")

def draw_head(c, g, tier):
    hx, hy, hw, hh = g["head"]
    d = g["dir"]
    if tier == 1:   # hood: shadows the eyes
        c.shaded(hx - 1, hy - 1, hw + 2, 4, "hood")
        c.rect(hx - 1, hy + 3, 1, hh - 2, "stone4"); c.rect(hx + hw, hy + 3, 1, hh - 2, "stone3")
        if d == "down":
            c.rect(hx + 1, hy + 3, hw - 2, 1, "stone2")                     # shadow under the rim
        elif d == "up":
            c.shaded(hx - 1, hy - 1, hw + 2, hh + 2, "hood")
            c.rect(hx + 2, hy + 2, 1, hh - 2, "stone3")                     # seam
        else:
            c.shaded(hx - 1, hy - 1, hw // 2 + 2, hh + 1, "hood")
            c.px(hx + hw - 1, hy + 3, "stone2")
    elif tier == 2:  # Gaolwarden iron helm: rivets, nasal guard, cheek guards
        c.shaded(hx - 1, hy - 1, hw + 2, 4, "iron")
        c.rect(hx - 1, hy + 3, 1, hh - 2, "metal1"); c.rect(hx + hw, hy + 3, 1, hh - 2, "metal0")
        for i in range(0, hw + 2, 3):
            c.px(hx - 1 + i, hy + 1, "metal2")                              # rivets
        if d == "down":
            c.rect(hx + hw // 2 - 1 + (hw % 2), hy + 3, 1, 3, "metal1")
            c.rect(hx, hy + 5, 1, 2, "metal1"); c.rect(hx + hw - 1, hy + 5, 1, 2, "metal0")
        elif d == "up":
            c.shaded(hx - 1, hy - 1, hw + 2, hh, "iron")
            c.rect(hx + hw // 2 - 1, hy - 1, 2, hh, "metal0")              # crest ridge
        else:
            c.shaded(hx - 1, hy - 1, hw // 2 + 2, hh, "iron"); c.px(hx + hw - 1, hy + 3, "metal1")
    elif tier == 3:  # imperial bronze helm with a horsehair crest
        c.shaded(hx - 1, hy - 1, hw + 2, 4, "bronze")
        c.rect(hx - 1, hy + 3, 1, hh - 2, "wood3"); c.rect(hx + hw, hy + 3, 1, hh - 2, "wood2")
        c.rect(hx, hy + 1, hw, 1, "wood2")                                  # engraved band
        if d == "up":
            c.shaded(hx - 1, hy - 1, hw + 2, hh, "bronze")
        elif d == "right":
            c.shaded(hx - 1, hy - 1, hw // 2 + 2, hh, "bronze")
        if d == "right":
            c.rect(hx - 2, hy - 3, hw, 2, "red1"); c.rect(hx - 3, hy - 2, 1, 4, "red0"); c.px(hx + 1, hy - 3, "red2")
        else:
            c.rect(hx + hw // 2 - 1, hy - 3, 2, 2, "red1"); c.px(hx + hw // 2 - 1, hy - 3, "red2")
            c.px(hx + hw // 2, hy - 1, "red0")

def draw_torso(c, g, tier):
    x, y, w, h = g["torso"]
    d = g["dir"]
    if tier == 1:   # scavenged leather jerkin: stitching, a strap with a buckle
        c.shaded(x, y, w, h - 1, "leather")
        for yy in range(y + 2, y + h - 2, 2):
            c.px(x + 1, yy, "wood1")                                        # stitching
        if d != "up":
            for i in range(min(w, h - 1)):
                c.px(x + i, y + i, "wood0")
            c.px(x + min(w, h - 1) // 2, y + min(w, h - 1) // 2, "metal2")  # buckle
        c.rect(x, y + h - 2, w, 1, "wood0")
    elif tier == 2:  # mail under a Gaolwarden tabard bearing a key
        c.shaded(x, y, w, h, "iron")
        for yy in range(y + 1, y + h, 2):
            for xx in range(x + (yy % 2), x + w, 2):
                c.px(xx, yy, "metal0")
        if d != "up":
            tx0 = x + 2 if d == "down" else x + 1
            tw = w - 4 if d == "down" else w - 2
            c.shaded(tx0, y + 1, tw, h + 3, "red")
            c.rect(tx0, y + h + 3, tw, 1, "wood3")                          # trim
            if d == "down":
                kx, ky = x + w // 2 - 1, y + 3
                c.px(kx, ky, "metal2"); c.px(kx + 1, ky, "metal2")          # the key sigil
                c.px(kx, ky + 1, "metal2"); c.px(kx, ky + 2, "metal2"); c.px(kx + 1, ky + 2, "metal2")
        else:
            c.shaded(x + 2, y + 1, w - 4, h + 2, "red")
    elif tier == 3:  # bronze cuirass: sheen, engraving, pauldrons, a glowing Rift-glass inset
        c.shaded(x, y, w, h - 1, "bronze")
        c.rect(x + 1, y + 1, 1, h - 4, "fire4")                             # sheen
        c.rect(x + 1, y + h - 3, w - 2, 1, "wood2")                         # engraved line
        if d != "right":
            c.shaded(x - 2, y - 1, 3, 3, "bronze"); c.shaded(x + w - 1, y - 1, 3, 3, "bronze")
        else:
            c.shaded(x + 1, y - 1, 4, 3, "bronze")
        if d == "down":
            c.rect(x + w // 2 - 1, y + 2, 2, 3, "rift2"); c.px(x + w // 2 - 1, y + 3, "rift3")

def draw_hands(c, g, tier):
    for name, far in arms(g):
        horiz = name in g["horiz"]
        if tier == 0:   # broken iron cuffs, a stub of chain on one wrist
            x, y, w, h = limb_end(g, name, 3)
            if horiz:
                c.rect(x, y, 1, h, "metal1")
            else:
                c.rect(x, y, w, 1, "metal1"); c.px(x, y, "metal2")
            if not far and not horiz:
                c.px(x + w // 2, y + 3, "metal2"); c.px(x + w // 2, y + 4, "metal1")
        elif tier == 1:
            x, y, w, h = limb_end(g, name, 4)
            c.shaded(x, y, w, h, "rags")
        elif tier == 2:
            x, y, w, h = limb_end(g, name, 3)
            c.shaded(x, y, w, h, "dark_leather")
        elif tier == 3:
            x, y, w, h = limb_end(g, name, 5)
            c.shaded(x, y, w, h, "bronze")
            if not horiz:
                c.px(x, y + h - 2, "fire4")                                 # knuckle plate

def draw_feet(c, g, tier):
    for name, far in legs(g):
        horiz = name in g["horiz"]
        ext = 1 if g["dir"] == "right" and not horiz else 0
        if tier == 1:
            x, y, w, h = limb_end(g, name, 3)
            c.shaded(x, y, w + ext, h, "rags")
        elif tier == 2:
            x, y, w, h = limb_end(g, name, 4)
            c.shaded(x, y, w + ext, h, "dark_leather")
            if not horiz:
                c.rect(x, y + h - 1, w + ext, 1, "wood0")                  # sole
                c.px(x + w // 2, y + 1, "wood2")                            # laces
        elif tier == 3:
            x, y, w, h = limb_end(g, name, 7)
            c.shaded(x, y, w + ext, h, "iron")
            if not horiz:
                c.rect(x, y, w, 1, "metal2"); c.px(x, y + 2, "metal2")     # knee cop
                c.rect(x, y + h - 1, w + ext, 1, "metal0")

LAYERS = {"back": draw_back, "head": draw_head, "torso": draw_torso, "hands": draw_hands, "feet": draw_feet}

# --- Gaoler extras: hanging chains and a ring of keys ---------------------------------------
def draw_gaoler_extras(c, g):
    x, y, w, h = g["torso"]
    d = g["dir"]
    if d == "down":
        for i in range(5):                                  # chain across the chest
            c.px(x + 2 + i * 3, y + 2 + (i % 2), "metal2"); c.px(x + 3 + i * 3, y + 3 - (i % 2), "metal1")
        kx, ky = x + w - 4, y + h
        c.px(kx, ky, "fire4"); c.px(kx + 1, ky + 1, "fire4"); c.px(kx - 1, ky + 1, "fire4")   # key ring
        c.px(kx, ky + 2, "wood3"); c.px(kx + 1, ky + 3, "wood3")
    elif d == "right":
        kx, ky = x + w - 2, y + h
        c.px(kx, ky, "fire4"); c.px(kx + 1, ky + 1, "fire4"); c.px(kx, ky + 2, "wood3")
        for i in range(4):
            c.px(x - 1, y + 3 + i * 2, "metal2")            # chain down the back
    else:
        for i in range(4):
            c.px(x + 3 + i * 3, y + 4 + (i % 2), "metal2")

# --- Sheets ---------------------------------------------------------------------------
def frame_slots():
    for di, d in enumerate(DIRS):
        for ai, a in enumerate(ANIMS):
            for f in range(NFRAMES[a]):
                yield di * len(ANIMS) + ai, f, d, a

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

def compose(R, body, gear, extras=None):
    """Stack layers the way the game does (for previews and the Gaoler sheet)."""
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
        if extras:
            extras(c, g)
        full.alpha_composite(c.img, (f * FW, row * FH))
    return outline(full, FW, FH)

# --- Hound: lean, mangy, a side view used for every direction -------------------------------
def hound_sheet():
    FW, FH = 32, 24
    img = Image.new("RGBA", (COLS * FW, ROWS * FH), (0, 0, 0, 0))
    for row, f, d, a in frame_slots():
        c = Canvas(FW, FH)
        n = NFRAMES[a]
        ph = f / n * math.tau
        gallop = a == "walk"
        low = 3 if a == "crouch" else 0
        lunge = [0, 4, 2][f] if a in ("strike", "kick") else 0
        by = 9 + low + (int(round(math.sin(ph * 2) * 0.8)) if gallop else 0) + ([0, 0, 1, 1][f] if a == "idle" else 0)
        bx = 7 + lunge
        # Body: deep chest, tucked belly, a ridge of spine, ribs showing.
        c.shaded(bx, by, 15, 5, "fur")
        c.rect(bx + 9, by + 5, 6, 1, "wood1")                              # chest
        c.rect(bx, by - 1, 12, 1, "wood0")                                   # raised hackles
        for i in range(3):
            c.px(bx + 7 + i * 2, by + 2, "wood1")                            # ribs
        c.px(bx + 3, by + 1, "stone3"); c.px(bx + 4, by + 2, "stone3")       # mange patch
        # Head and snout, a glowing eye, jaws open when it strikes.
        hx, hy = bx + 14, by - 3
        c.shaded(hx, hy, 6, 5, "fur")
        c.rect(hx + 5, hy + 2, 4, 2, "wood2"); c.px(hx + 8, hy + 2, "void")
        c.px(hx + 3, hy + 1, "red2"); c.px(hx + 4, hy + 1, "fire4")
        c.rect(hx + 1, hy - 2, 2, 2, "wood1")                                # ear
        if a in ("strike", "kick") and f >= 1:
            c.rect(hx + 5, hy + 4, 4, 1, "red0"); c.px(hx + 6, hy + 4, "rag2"); c.px(hx + 8, hy + 4, "rag2")
        # Tail.
        tw = int(round(math.sin(ph) * 1)) if gallop else 0
        c.rect(bx - 4, by - 2 + tw, 4, 1, "wood1"); c.px(bx - 5, by - 3 + tw, "wood1")
        # Legs: a gallop cycle (front and back pairs out of phase).
        for lx, off in ((bx + 2, 0.0), (bx + 4, 0.5), (bx + 11, 0.25), (bx + 13, 0.75)):
            sw = int(round(math.sin(ph + off * math.tau) * 2)) if gallop else 0
            lh = 6 - low
            c.rect(lx + sw, by + 5, 2, lh, "wood1")
            c.px(lx + sw, by + 4 + lh, "wood0"); c.px(lx + sw + 1, by + 4 + lh, "wood0")
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

def row_of(d, a):
    return DIRS.index(d) * len(ANIMS) + ANIMS.index(a)

def frame(img, R, row, col):
    return img.crop((col * R["FW"], row * R["FH"], (col + 1) * R["FW"], (row + 1) * R["FH"]))

def previews():
    R = HUMAN
    s = 4
    sheets = [(name, compose(R, "prisoner", gear)) for name, gear in PRESETS.items()]
    sheets.append(("Guard", compose(R, "guard", GUARD_GEAR)))
    cellw, cellh = 3 * R["FW"] * s + 40, R["FH"] * s + 60
    line = Image.new("RGB", (cellw * 3, cellh * 2 + 20), st.rgb("stone1"))
    dr = ImageDraw.Draw(line)
    for i, (name, sh) in enumerate(sheets):
        x0 = (i % 3) * cellw + 20; y0 = (i // 3) * cellh + 20
        for j, (row, col) in enumerate([(row_of("down", "idle"), 0), (row_of("right", "walk"), 2), (row_of("up", "idle"), 0)]):
            fr = frame(sh, R, row, col).resize((R["FW"] * s, R["FH"] * s), Image.NEAREST)
            line.paste(fr, (x0 + j * R["FW"] * s, y0), fr)
        dr.text((x0, y0 + R["FH"] * s + 8), name, fill=st.rgb("rag2"))
    gsh = compose(BRUTE, "brute", GAOLER_GEAR, draw_gaoler_extras)
    x0 = 2 * cellw + 20; y0 = cellh + 20
    for j, (row, col) in enumerate([(row_of("down", "idle"), 0), (row_of("right", "walk"), 2)]):
        fr = frame(gsh, BRUTE, row, col).resize((BRUTE["FW"] * 3, BRUTE["FH"] * 3), Image.NEAREST)
        line.paste(fr, (x0 + j * BRUTE["FW"] * 3, y0), fr)
    hsh = hound_sheet()
    fr = frame(hsh, {"FW": 32, "FH": 24}, row_of("right", "walk"), 1).resize((32 * 3, 24 * 3), Image.NEAREST)
    line.paste(fr, (x0 + 2 * BRUTE["FW"] * 3 - 20, y0 + 40), fr)
    dr.text((x0, y0 + BRUTE["FH"] * 3 + 8), "Gaoler and scent-hound", fill=st.rgb("rag2"))
    line.save(os.path.join(PREV, "chars_lineup_x4.png"))
    # Walking GIF: the four presets walking right, then down; 8 frames each.
    frames = []
    for d in ("right", "down"):
        for col in range(8):
            fimg = Image.new("RGB", (5 * R["FW"] * s, R["FH"] * s), st.rgb("stone1"))
            for i, (name, sh) in enumerate(sheets[:4]):
                fr = frame(sh, R, row_of(d, "walk"), col).resize((R["FW"] * s, R["FH"] * s), Image.NEAREST)
                fimg.paste(fr, (i * R["FW"] * s, 0), fr)
            hfr = frame(hsh, {"FW": 32, "FH": 24}, row_of("right", "walk"), col).resize((32 * 3, 24 * 3), Image.NEAREST)
            fimg.paste(hfr, (4 * R["FW"] * s, R["FH"] * s - 24 * 3), hfr)
            frames.append(fimg)
    frames[0].save(os.path.join(PREV, "chars_walk.gif"), save_all=True, append_images=frames[1:] * 2, duration=85, loop=0)
    # The prisoner facing right through every animation, one strip per animation.
    sh = sheets[0][1]
    strip = Image.new("RGB", (8 * R["FW"] * s, len(ANIMS) * R["FH"] * s), st.rgb("stone1"))
    for ai, a in enumerate(ANIMS):
        for col in range(NFRAMES[a]):
            fr = frame(sh, R, row_of("right", a), col).resize((R["FW"] * s, R["FH"] * s), Image.NEAREST)
            strip.paste(fr, (col * R["FW"] * s, ai * R["FH"] * s), fr)
    strip.save(os.path.join(PREV, "chars_poses_x4.png"))

def main():
    hum = os.path.join(OUT, "human"); os.makedirs(hum, exist_ok=True)
    R = HUMAN
    for v in ("prisoner", "guard"):
        sheet(R, lambda c, g, v=v: draw_body(c, g, BODIES[v])).save(os.path.join(hum, f"body_{v}.png"))
    for slot, fn in LAYERS.items():
        tiers = [0, 1, 2, 3] if slot == "hands" else [1, 2, 3]
        for t in tiers:
            sheet(R, lambda c, g, fn=fn, t=t: fn(c, g, t)).save(os.path.join(hum, f"{slot}_{t}.png"))
    compose(BRUTE, "brute", GAOLER_GEAR, draw_gaoler_extras).save(os.path.join(OUT, "gaoler.png"))
    hound_sheet().save(os.path.join(OUT, "hound.png"))
    previews()
    print("Wrote character layers to", OUT)

if __name__ == "__main__":
    main()
