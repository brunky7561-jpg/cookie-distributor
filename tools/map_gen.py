"""Generates the explorable world for the place file as Roblox XML (parts only, no terrain).

Layout (north is -Z, east is +X), roads on x/z = -250, 0, 250:

    Whispering Woods (NW)   | Industrial Yards + MegaCrumb HQ (NE)
    Maple Heights suburbs   | Sugar Street downtown          | Sunny Bay beach (E)
    ------------------- Cookie Square (center) ---------------
    Crumb University        | Farmers Market + Orchard       |
    Autumn Hills (W)        | Farmstead (S)                  |

Tags used by src/server/Services: BakeStation, MeetupSpot, PropertyPlot, Landmark, ReceivingArea.
"""
import base64
import itertools
import math
import random
from xml.sax.saxutils import escape

rng = random.Random(7)
_ids = itertools.count(100000)

MATERIALS = {
    "Plastic": 256, "SmoothPlastic": 272, "Neon": 288, "Wood": 512, "WoodPlanks": 528, "Slate": 800,
    "Concrete": 816, "Granite": 832, "Brick": 848, "Pebble": 864, "Cobblestone": 880, "Rock": 896,
    "Sandstone": 912, "CorrodedMetal": 1040, "DiamondPlate": 1056, "Metal": 1088, "Grass": 1280,
    "LeafyGrass": 1284, "Sand": 1296, "Fabric": 1312, "Snow": 1328, "Mud": 1344, "Ground": 1360,
    "Asphalt": 1376, "Glass": 1568,
}
SHAPES = {"Ball": 0, "Block": 1, "Cylinder": 2}

# ---------- math ----------
I3 = ((1, 0, 0), (0, 1, 0), (0, 0, 1))


def mul(a, b):
    return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)) for i in range(3))


def Ry(t):
    c, s = math.cos(t), math.sin(t)
    return ((c, 0, s), (0, 1, 0), (-s, 0, c))


def Rz(t):
    c, s = math.cos(t), math.sin(t)
    return ((c, -s, 0), (s, c, 0), (0, 0, 1))


ROT_UP = Rz(math.pi / 2)  # cylinder axis X -> world Y
ROT_Z = Ry(math.pi / 2)  # cylinder axis X -> world Z


def rgb(r, g, b):
    return 0xFF000000 | (int(r) << 16) | (int(g) << 8) | int(b)


def C(r, g, b):
    return (r, g, b)


# ---------- xml ----------
def part(name, pos, size, color, mat="Plastic", shape="Block", rot=None, transp=0.0, collide=True,
         tags=(), cls="Part"):
    x, y, z = pos
    r = rot or I3
    sx, sy, sz = size
    p = (
        '<bool name="Anchored">true</bool>'
        f'<CoordinateFrame name="CFrame"><X>{x:.3f}</X><Y>{y:.3f}</Y><Z>{z:.3f}</Z>'
        f'<R00>{r[0][0]:.5f}</R00><R01>{r[0][1]:.5f}</R01><R02>{r[0][2]:.5f}</R02>'
        f'<R10>{r[1][0]:.5f}</R10><R11>{r[1][1]:.5f}</R11><R12>{r[1][2]:.5f}</R12>'
        f'<R20>{r[2][0]:.5f}</R20><R21>{r[2][1]:.5f}</R21><R22>{r[2][2]:.5f}</R22></CoordinateFrame>'
        f'<Vector3 name="size"><X>{sx:.3f}</X><Y>{sy:.3f}</Y><Z>{sz:.3f}</Z></Vector3>'
        f'<Color3uint8 name="Color3uint8">{rgb(*color)}</Color3uint8>'
        f'<token name="Material">{MATERIALS[mat]}</token>'
        '<token name="TopSurface">0</token><token name="BottomSurface">0</token>'
    )
    if cls == "Part":
        p += f'<token name="shape">{SHAPES[shape]}</token>'
    if transp:
        p += f'<float name="Transparency">{transp}</float>'
    if not collide:
        p += '<bool name="CanCollide">false</bool>'
    if cls == "SpawnLocation":
        p += '<bool name="Neutral">true</bool><int name="Duration">0</int>'
    if tags:
        p += f'<BinaryString name="Tags">{base64.b64encode(chr(0).join(tags).encode()).decode()}</BinaryString>'
    return f'<Item class="{cls}" referent="RBX{next(_ids)}"><Properties><string name="Name">{escape(name)}</string>{p}</Properties></Item>'


def folder(name, children):
    return (
        f'<Item class="Folder" referent="RBX{next(_ids)}"><Properties><string name="Name">{escape(name)}</string>'
        f'</Properties>{"".join(children)}</Item>'
    )


# ---------- primitives (world coordinates, y = center height) ----------
def block(out, name, x, y, z, sx, sy, sz, color, mat="Plastic", rot=None, **kw):
    out.append(part(name, (x, y, z), (sx, sy, sz), color, mat, rot=rot, **kw))


def ball(out, name, x, y, z, d, color, mat="Plastic", **kw):
    out.append(part(name, (x, y, z), (d, d, d), color, mat, shape="Ball", **kw))


def cyl(out, name, x, y, z, length, d, color, mat="Plastic", axis="y", **kw):
    rot = {"y": ROT_UP, "x": I3, "z": ROT_Z}[axis]
    out.append(part(name, (x, y, z), (length, d, d), color, mat, shape="Cylinder", rot=rot, **kw))


def ground(out, name, x, z, sx, sz, color, mat="Grass", y=0.1, t=0.2, **kw):
    block(out, name, x, y, z, sx, t, sz, color, mat, **kw)


class Frame:
    """Local coordinates for a rotated building: +z is the front, origin at the base center."""

    def __init__(self, out, x, z, yaw=0.0, base=0.0):
        self.out, self.x, self.z, self.yaw, self.base = out, x, z, yaw, base

    def world(self, lx, lz):
        c, s = math.cos(self.yaw), math.sin(self.yaw)
        return self.x + lx * c + lz * s, self.z - lx * s + lz * c

    def block(self, name, lx, ly, lz, sx, sy, sz, color, mat="Plastic", rot=None, **kw):
        wx, wz = self.world(lx, lz)
        self.out.append(part(name, (wx, self.base + ly, wz), (sx, sy, sz), color, mat,
                             rot=mul(Ry(self.yaw), rot or I3), **kw))

    def cyl(self, name, lx, ly, lz, length, d, color, mat="Plastic", axis="y", **kw):
        wx, wz = self.world(lx, lz)
        rot = {"y": ROT_UP, "x": I3, "z": ROT_Z}[axis]
        self.out.append(part(name, (wx, self.base + ly, wz), (length, d, d), color, mat, shape="Cylinder",
                             rot=mul(Ry(self.yaw), rot), **kw))

    def ball(self, name, lx, ly, lz, d, color, mat="Plastic", **kw):
        wx, wz = self.world(lx, lz)
        self.out.append(part(name, (wx, self.base + ly, wz), (d, d, d), color, mat, shape="Ball",
                             rot=Ry(self.yaw), **kw))

    def gable(self, w, d, top, rise, color, mat="Slate", over=1.5):
        """Two tilted slabs forming a gable roof with ridge along local z."""
        half = w / 2 + over
        theta = math.atan2(rise, w / 2)
        length = math.hypot(half, rise * half / (w / 2))
        for sign in (-1, 1):
            self.block("Roof", sign * w / 4, top + rise / 2, 0, length, 0.8, d + 2 * over, color, mat,
                       rot=Rz(-sign * theta))
        self.block("RoofEnd", 0, top + rise * 0.28, d / 2, w * 0.56, rise * 0.56, 0.5, color, mat)
        self.block("RoofEnd", 0, top + rise * 0.28, -d / 2, w * 0.56, rise * 0.56, 0.5, color, mat)


# ---------- palette ----------
GRASS = C(104, 152, 76)
GRASS2 = C(122, 168, 84)
ASPHALT = C(52, 54, 60)
CONCRETE = C(170, 168, 160)
WOOD = C(139, 94, 60)
DARK_WOOD = C(98, 66, 42)
BRICK = C(156, 78, 62)
WHITE = C(240, 240, 238)
GLASS = C(150, 200, 230)
PASTELS = [C(244, 204, 170), C(200, 224, 240), C(214, 236, 200), C(246, 222, 232), C(250, 238, 184),
           C(222, 208, 240), C(240, 190, 170), C(186, 222, 214)]
ROOFS = [C(120, 70, 60), C(80, 90, 110), C(96, 80, 70), C(130, 60, 60), C(70, 96, 80)]
BRIGHT = [C(231, 76, 60), C(243, 156, 18), C(46, 204, 113), C(52, 152, 219), C(155, 89, 182), C(241, 196, 15)]
LEAVES = [C(70, 140, 70), C(90, 160, 60), C(60, 120, 80)]
AUTUMN = [C(214, 110, 40), C(200, 60, 40), C(224, 164, 40), C(170, 80, 40)]


def pick(seq):
    return seq[rng.randrange(len(seq))]


# ---------- props ----------
def oak(out, x, z, s=1.0, leaf=None):
    h = 9 * s
    cyl(out, "Trunk", x, h / 2, z, h, 2.2 * s, DARK_WOOD, "Wood")
    ball(out, "Leaves", x, h + 4 * s, z, 12 * s, leaf or pick(LEAVES), "Grass")


def pine(out, x, z, s=1.0):
    cyl(out, "Trunk", x, 3 * s, z, 6 * s, 1.8 * s, DARK_WOOD, "Wood")
    for i, d in enumerate((13, 10, 7)):
        cyl(out, "Pine", x, (7 + i * 4.2) * s, z, 4.6 * s, d * s, C(34, 96 + i * 10, 58), "Grass")
    cyl(out, "Pine", x, 20 * s, z, 3.5 * s, 4 * s, C(40, 118, 66), "Grass")


def palm(out, x, z):
    cyl(out, "Trunk", x, 7, z, 14, 1.6, C(150, 110, 70), "Wood")
    for i in range(4):
        a = i * math.pi / 2 + rng.random() * 0.4
        block(out, "Frond", x + math.cos(a) * 4, 14.4, z + math.sin(a) * 4, 9, 0.4, 3, C(60, 150, 70),
              "Grass", rot=mul(Ry(-a), Rz(-0.35)))


def bench(out, x, z, yaw=0.0, base=0.0):
    f = Frame(out, x, z, yaw, base)
    f.block("Seat", 0, 1.6, 0, 6, 0.4, 1.8, WOOD, "Wood")
    f.block("Back", 0, 2.7, -0.8, 6, 1.8, 0.3, WOOD, "Wood")
    for sx in (-2.6, 2.6):
        f.block("Leg", sx, 0.8, 0, 0.4, 1.6, 1.6, C(60, 60, 64), "Metal")


def lamp(out, x, z, base=0.0):
    cyl(out, "LampPost", x, base + 7, z, 14, 0.7, C(50, 52, 58), "Metal")
    ball(out, "Lamp", x, base + 14.5, z, 2.4, C(255, 236, 170), "Neon")


def fence(out, x, z, length, yaw=0.0, color=WHITE):
    f = Frame(out, x, z, yaw)
    f.block("Fence", 0, 1.4, 0, length, 2.4, 0.35, color, "Wood")


def tent(out, x, z, yaw, color):
    f = Frame(out, x, z, yaw)
    theta = math.atan2(5, 4)
    for sign in (-1, 1):
        f.block("Tent", sign * 2, 2.5, 0, 6.4, 0.3, 8, color, "Fabric", rot=Rz(-sign * theta))


def ring(out, name, x, z, tag="MeetupSpot", color=C(255, 190, 70), d=11, y=0.45):
    """Glowing circle on the ground. Customers meet you here; WorldService labels it with its name."""
    cyl(out, name, x, y, z, 0.3, d, color, "Neon", axis="y", tags=(tag,), collide=False)


def label_marker(out, name, x, z, sx, sz, tag, color):
    block(out, name, x, 0.35, z, sx, 0.3, sz, color, "SmoothPlastic", tags=(tag,), collide=False, transp=0.35)


def house(out, x, z, yaw, w=28, d=20, h=14):
    f = Frame(out, x, z, yaw)
    wall = pick(PASTELS)
    f.block("House", 0, h / 2, 0, w, h, d, wall, "SmoothPlastic")
    f.gable(w, d, h, 7, pick(ROOFS))
    f.block("Door", 0, 3.5, d / 2 + 0.1, 4, 7, 0.4, C(110, 70, 50), "Wood")
    for sx in (-w / 4, w / 4):
        f.block("Window", sx, h * 0.55, d / 2 + 0.1, 4.5, 4.5, 0.4, GLASS, "Glass")
        f.block("Shutter", sx - 3, h * 0.55, d / 2 + 0.1, 1, 4.5, 0.4, C(70, 100, 130), "Wood")
        f.block("Shutter", sx + 3, h * 0.55, d / 2 + 0.1, 1, 4.5, 0.4, C(70, 100, 130), "Wood")
    f.block("Chimney", w / 3, h + 5, -d / 4, 3, 7, 3, BRICK, "Brick")
    f.block("Step", 0, 0.5, d / 2 + 1.5, 6, 1, 3, CONCRETE, "Concrete")
    f.block("Path", 0, 0.25, d / 2 + 9, 3.5, 0.3, 14, CONCRETE, "Concrete")
    fx, fz = f.world(0, d / 2 + 15)
    fence(out, fx, fz, w, yaw)
    mx, mz = f.world(w / 2 - 2, d / 2 + 14)
    block(out, "Mailbox", mx, 2.2, mz, 1.2, 1.2, 2, C(60, 80, 160), "Metal")
    tx, tz = f.world(-w / 2 - 6, d / 4)
    oak(out, tx, tz, rng.uniform(0.8, 1.1))


def road(out, name, x, z, sx, sz, yellow_axis=None):
    block(out, name, x, 0.1, z, sx, 0.2, sz, ASPHALT, "Asphalt")
    if yellow_axis == "x":
        n = int(sx // 20)
        for i in range(n):
            px = x - sx / 2 + 10 + i * 20
            block(out, "Dash", px, 0.22, z, 6, 0.06, 0.6, C(240, 200, 60), "SmoothPlastic", collide=False)
    elif yellow_axis == "z":
        n = int(sz // 20)
        for i in range(n):
            pz = z - sz / 2 + 10 + i * 20
            block(out, "Dash", x, 0.22, pz, 0.6, 0.06, 6, C(240, 200, 60), "SmoothPlastic", collide=False)


def near_road(x, z, margin=14):
    return any(abs(x - r) < margin for r in (-250, 0, 250)) or any(abs(z - r) < margin for r in (-250, 0, 250))


# ---------- districts ----------
def build_roads():
    out = []
    for z in (-250, 0, 250):
        road(out, "Road", 0, z, 1000, 18, "x")
        for sgn in (-1, 1):
            block(out, "Sidewalk", 0, 0.15, z + sgn * 12, 1000, 0.3, 5, CONCRETE, "Concrete")
    for x in (-250, 0, 250):
        road(out, "Road", x, 0, 18, 1000, "z")
        for sgn in (-1, 1):
            block(out, "Sidewalk", x + sgn * 12, 0.15, 0, 5, 0.3, 1000, CONCRETE, "Concrete")
    return folder("Roads", out)


def build_plaza():
    out = []
    block(out, "PlazaFloor", 0, 0.2, 0, 100, 0.4, 100, C(184, 170, 148), "Cobblestone")
    block(out, "PlazaInlay", 0, 0.45, 0, 62, 0.1, 62, C(214, 196, 168), "Concrete")
    cyl(out, "FountainBasin", 0, 1.2, 0, 2.4, 26, C(150, 150, 156), "Concrete")
    cyl(out, "FountainWater", 0, 2.2, 0, 0.6, 23, C(80, 160, 220), "Glass", transp=0.35, collide=False)
    cyl(out, "FountainColumn", 0, 5, 0, 8, 3, C(190, 190, 196), "Concrete")
    # giant cookie monument
    cyl(out, "Cookie Monument", 0, 14, 0, 3, 14, C(214, 160, 90), "SmoothPlastic", axis="x", tags=("Landmark",))
    for _ in range(9):
        a, r = rng.random() * math.tau, rng.random() * 4.5
        for sx in (-1.7, 1.7):
            ball(out, "Chip", sx, 14 + math.sin(a) * r, math.cos(a) * r, 1.3, C(70, 42, 28), "SmoothPlastic")
    for sx in (-44, 44):
        for sz in (-44, 44):
            lamp(out, sx, sz, base=0.4)
    for i, (bx, bz, yaw) in enumerate(((0, 22, math.pi), (0, -22, 0), (22, 0, -math.pi / 2), (-22, 0, math.pi / 2))):
        bench(out, bx, bz, yaw, 0.4)
    for sx in (-1, 1):
        for sz in (-1, 1):
            oak(out, sx * 36, sz * 20 + (0 if sz < 0 else 0), 0.7)
    out.append(part("Spawn", (-30, 0.5, -57), (8, 1, 8), C(255, 214, 150), "SmoothPlastic", cls="SpawnLocation"))
    ring(out, "Market Square", -24, 34, d=9)
    # parked food truck (decor)
    f = Frame(out, 38, 36, 0.3)
    f.block("TruckBody", 0, 5.4, 0, 20, 9, 9, C(250, 196, 50), "SmoothPlastic")
    f.block("TruckCab", 12, 4, 0, 5, 7, 8.6, C(240, 170, 40), "SmoothPlastic")
    f.block("ServingWindow", 0, 6.5, 4.6, 8, 3.5, 0.3, C(30, 40, 50), "Glass")
    f.block("Awning", 0, 8.6, 6.2, 10, 0.4, 3.5, C(220, 60, 60), "Fabric", rot=Rx_tilt(0.25))
    for wx in (-6, 7):
        for wz in (-4.6, 4.6):
            f.cyl("Wheel", wx, 1.6, wz, 1.4, 3.6, C(30, 30, 34), axis="z")
    # grocery store
    g = Frame(out, -35, 72, math.pi)
    g.block("Store", 0, 9, 0, 40, 18, 28, C(250, 238, 200), "SmoothPlastic", tags=("Landmark",))
    g.block("Awning", 0, 13, 15, 36, 0.5, 5, C(60, 160, 90), "Fabric")
    g.block("Window", -8, 7, 14.1, 14, 8, 0.4, GLASS, "Glass")
    g.block("Door", 11, 5, 14.1, 6, 10, 0.4, DARK_WOOD, "Wood")
    g.block("Sign", 0, 18.8, 14.2, 28, 3, 0.6, C(40, 120, 70), "SmoothPlastic")
    g.gable(40, 28, 18, 3, C(120, 90, 70), "Wood", over=0.5)
    # property lot
    label_marker(out, "Corner Cookie Shop Plot", 28, -68, 24, 16, "PropertyPlot", C(120, 220, 140))
    return folder("MarketSquare", out)


def Rx_tilt(t):
    c, s = math.cos(t), math.sin(t)
    return ((1, 0, 0), (0, c, -s), (0, s, c))


def build_apartment():
    out = []
    f = Frame(out, -30, -75, 0)
    f.block("Floor", 0, 0.5, 0, 36, 1, 24, C(190, 150, 110), "WoodPlanks")
    f.block("BackWall", 0, 8, -11.5, 36, 14, 1, C(240, 226, 200), "SmoothPlastic")
    for sx in (-17.5, 17.5):
        f.block("SideWall", sx, 8, 0, 1, 14, 24, C(240, 226, 200), "SmoothPlastic")
    for sx in (-11, 11):
        f.block("FrontWall", sx, 8, 11.5, 14, 14, 1, C(240, 226, 200), "SmoothPlastic")
    f.block("FrontHeader", 0, 12, 11.5, 8, 6, 1, C(240, 226, 200), "SmoothPlastic")
    f.block("Roof", 0, 15.4, 0, 40, 1, 28, C(110, 70, 60), "Slate")
    f.block("Starter House", 0, 17.2, 13, 18, 2.4, 0.6, C(250, 200, 80), "SmoothPlastic", tags=("Landmark",))
    f.block("Counter", -9, 2.5, -8, 14, 4, 4, C(196, 140, 90), "Wood", tags=("BakeStation",))
    f.block("CounterTop", -9, 4.6, -8, 14.5, 0.4, 4.5, C(235, 232, 226), "Granite")
    f.block("Oven", 4, 2.5, -9, 6, 4.4, 4, C(40, 40, 46), "Metal", tags=("BakeStation",))
    f.block("OvenGlow", 4, 2.5, -6.95, 3.5, 2, 0.2, C(255, 140, 40), "Neon")
    f.block("Fridge", 11, 4.5, -9.5, 5, 8, 4, C(225, 228, 232), "Metal")
    f.block("Table", -8, 2, 3, 7, 0.5, 5, WOOD, "Wood")
    for sx in (-10.8, -5.2):
        f.block("TableLeg", sx, 1, 3, 0.5, 2, 0.5, DARK_WOOD, "Wood")
    f.block("Bed", 12, 1.6, 3, 6, 1.6, 9, C(90, 130, 200), "Fabric")
    f.block("Pillow", 12, 2.6, 6.8, 4, 0.8, 1.6, WHITE, "Fabric")
    f.block("Rug", 0, 1.05, 4, 10, 0.1, 7, C(190, 70, 70), "Fabric", collide=False)
    # short path from the front door to the square, and a supply kiosk beside the spawn
    block(out, "StarterPath", -30, 0.15, -56, 6, 0.3, 14, CONCRETE, "Concrete")
    k = Frame(out, -14, -55, -math.pi / 2)
    k.block("Supply Kiosk", 0, 4.5, 0, 8, 9, 6, C(250, 238, 200), "SmoothPlastic", tags=("Landmark",))
    k.block("Awning", 0, 8.4, 3.8, 9, 0.5, 3.5, C(238, 120, 109), "Fabric", rot=Rx_tilt(0.2))
    k.block("Counter", 0, 3, 3.2, 7, 1, 1.2, WOOD, "Wood")
    label_marker(out, "Delivery Mat (Starter Apartment)", -41, -57, 7, 7, "ReceivingArea", C(255, 196, 90))
    ring(out, "Your Kitchen (press E to bake)", -30 - 9, -75 - 4, tag="Landmark", color=C(255, 220, 120), d=7, y=1.1)
    return folder("StarterApartment", out)


def build_maple_heights():
    out = []
    ground(out, "SuburbLawn", -125, -125, 240, 240, GRASS, y=0.05, t=0.1)
    road(out, "MapleStreet", -125, -175, 240, 12, "x")
    for sgn in (-1, 1):
        block(out, "Sidewalk", -125, 0.15, -175 + sgn * 8.5, 240, 0.3, 4, CONCRETE, "Concrete")
    for x in (-218, -174, -130, -86, -42):
        house(out, x, -205, 0)
    for x in (-196, -152, -108, -64):
        house(out, x, -145, math.pi)
    # Maple Park with gazebo and pond
    ground(out, "ParkLawn", -135, -100, 70, 40, GRASS2, y=0.12, t=0.1)
    cyl(out, "Pond", -160, 0.3, -100, 0.3, 18, C(60, 130, 200), "Glass", transp=0.3, collide=False)
    f = Frame(out, -125, -100, 0)
    for sx in (-4, 4):
        for sz in (-4, 4):
            f.block("GazeboPost", sx, 4, sz, 0.8, 8, 0.8, WHITE, "Wood")
    f.block("GazeboFloor", 0, 0.4, 0, 10.5, 0.6, 10.5, C(210, 190, 160), "WoodPlanks")
    f.block("GazeboRoof", 0, 8.4, 0, 12, 0.8, 12, C(180, 70, 60), "Slate")
    f.block("GazeboTop", 0, 9.6, 0, 5, 1.6, 5, C(180, 70, 60), "Slate")
    ring(out, "Starter Row Gazebo", -125, -88, d=9)
    for bx in (-150, -110, -105):
        bench(out, bx, -112, 0)
    for tx, tz in ((-175, -92), (-150, -88), (-100, -90), (-172, -108), (-96, -112)):
        oak(out, tx, tz, rng.uniform(0.8, 1.2), leaf=C(236, 150, 170) if rng.random() < 0.4 else None)
    label_marker(out, "Garage Kitchen Plot", -75, -110, 24, 16, "PropertyPlot", C(120, 220, 140))
    return folder("StarterRow", out)


def build_downtown():
    out = []
    ground(out, "DowntownPaving", 125, -125, 240, 240, C(150, 150, 154), "Concrete", y=0.06, t=0.1)
    road(out, "SugarStreet", 125, -65, 240, 12, "x")
    names = ["Cookie Corner Cafe", "Sprinkle Bank", "Sweet Tooth Dental", "Flour Power Gym", "Dough Re Mi Music",
             "Butter Theater", "Whisk Hardware", "Choc-O-Lot Mall", "Sugar Rush Arcade", "Rolling Pin Pub"]
    ix = 0
    for row, z in enumerate((-35, -95)):
        for i, x in enumerate((40, 85, 130, 175, 220)):
            h = rng.randint(24, 50) if row == 0 else rng.randint(40, 96)
            f = Frame(out, x, z, 0)
            col = pick([C(214, 200, 184), C(180, 196, 214), C(226, 182, 170), C(196, 214, 190), C(232, 216, 170)])
            f.block("Building", 0, h / 2, 0, 38, h, 34, col, "SmoothPlastic")
            f.block("Cornice", 0, h + 0.8, 0, 40, 1.6, 36, C(90, 90, 98), "Concrete")
            f.block("Door", 0, 4, 17.1, 5, 8, 0.4, DARK_WOOD, "Wood")
            f.block("Awning", 0, 10, 19, 24, 0.5, 5, pick(BRIGHT), "Fabric", rot=Rx_tilt(0.2))
            for wy in range(16, int(h) - 4, 10):
                f.block("Windows", 0, wy, 17.1, 30, 4, 0.4, GLASS, "Glass")
            f.block("Sign", 0, 12.5, 17.3, 20, 2.2, 0.4, pick(BRIGHT), "Neon")
            if h > 60:
                f.cyl("WaterTank", 8, h + 5, 0, 7, 8, C(150, 110, 80), "Wood")
            if ix < len(names) and (ix % 3 == 0):
                f.block(names[ix], 0, h + 6, 17.5, 1, 1, 1, col, "SmoothPlastic", tags=("Landmark",), collide=False,
                        transp=1)
            ix += 1
    # Cookie Tower
    f = Frame(out, 60, -190, 0)
    f.cyl("TowerBase", 0, 40, 0, 80, 18, C(222, 190, 140), "Concrete")
    f.cyl("TowerMid", 0, 95, 0, 30, 12, C(240, 210, 160), "Concrete")
    f.cyl("CookieDisc", 0, 125, 0, 6, 30, C(214, 160, 90), "SmoothPlastic", axis="z", tags=("Landmark",))
    for _ in range(14):
        a, r = rng.random() * math.tau, 3 + rng.random() * 10
        for sz in (-3.4, 3.4):
            f.ball("Chip", math.cos(a) * r, 125 + math.sin(a) * r, sz, 2.6, C(70, 42, 28), "SmoothPlastic")
    out_names = [("Cookie Tower", 60, -190)]
    ring(out, "Business Avenue Plaza", 130, -65, d=10)
    label_marker(out, "Neighborhood Bakery Plot", 200, -170, 28, 18, "PropertyPlot", C(120, 220, 140))
    label_marker(out, "Cookie Workshop HQ Plot", 155, -200, 36, 24, "PropertyPlot", C(255, 220, 120))
    for x in (25, 75, 125, 175, 225):
        lamp(out, x, -59)
        lamp(out, x, -71)
    return folder("BusinessAvenue", out)


def build_campus():
    out = []
    ground(out, "QuadLawn", -125, 130, 240, 240, GRASS2, y=0.05, t=0.1)
    for (name, x, w, h) in (("Library", -200, 60, 38), ("Science Hall", -120, 50, 32), ("Dormitory", -50, 40, 28)):
        f = Frame(out, x, 55, math.pi)
        f.block(name, 0, h / 2, 0, w, h, 32, BRICK, "Brick", tags=("Landmark",) if name == "Library" else ())
        f.block("Cornice", 0, h + 0.8, 0, w + 2, 1.6, 34, WHITE, "Concrete")
        f.block("Door", 0, 5, 16.1, 7, 10, 0.4, DARK_WOOD, "Wood")
        for wy in (14, 24):
            for sx in range(-int(w / 2) + 6, int(w / 2) - 3, 9):
                f.block("Window", sx, wy, 16.1, 4, 5, 0.4, GLASS, "Glass")
        for sx in (-4, 4):
            f.cyl("Column", sx * 1.6, 8, 18, 16, 2, WHITE, "Concrete")
    block(out, "QuadPathNS", -125, 0.2, 150, 6, 0.2, 200, CONCRETE, "Concrete")
    block(out, "QuadPathEW", -125, 0.2, 150, 200, 0.2, 6, CONCRETE, "Concrete")
    f = Frame(out, -125, 150, 0)
    f.block("TowerBase", 0, 24, 0, 12, 48, 12, BRICK, "Brick", tags=("Landmark",))
    f.block("ClockBand", 0, 54, 0, 14, 12, 14, C(210, 200, 180), "Concrete")
    for lx, lz, ry in ((0, 7.1, 0), (0, -7.1, 0), (7.1, 0, math.pi / 2), (-7.1, 0, math.pi / 2)):
        f.cyl("ClockFace", lx, 54, lz, 0.4, 9, C(255, 250, 220), "Neon", axis="z" if ry == 0 else "x")
    f.block("TowerRoof", 0, 64, 0, 16, 2, 16, C(70, 100, 90), "Slate")
    f.block("TowerRoof", 0, 67, 0, 10, 4, 10, C(70, 100, 90), "Slate")
    f.block("TowerRoof", 0, 71, 0, 4, 4, 4, C(70, 100, 90), "Slate")
    ring(out, "Crumb U Quad", -125, 185, d=10)
    for bx, bz, yaw in ((-150, 130, 0), (-100, 130, math.pi), (-125, 110, 0), (-125, 190, math.pi),
                        (-180, 150, math.pi / 2), (-70, 150, -math.pi / 2)):
        bench(out, bx, bz, yaw)
    for _ in range(18):
        x, z = rng.uniform(-240, -10), rng.uniform(100, 240)
        if abs(x + 125) < 14 or abs(z - 150) < 14 or near_road(x, z, 14):
            continue
        oak(out, x, z, rng.uniform(0.8, 1.2), leaf=pick([C(236, 150, 170), C(250, 190, 200), C(90, 160, 60)]))
    for x, z in ((-180, 100), (-70, 100), (-180, 200), (-70, 200)):
        lamp(out, x, z)
    return folder("CrumbUniversity", out)


def build_market():
    out = []
    ground(out, "MarketGround", 125, 125, 240, 240, C(168, 150, 112), "Ground", y=0.05, t=0.1)
    ring(out, "Seasonal Plaza", 125, 65, d=10)
    produce = [C(210, 50, 40), C(240, 190, 40), C(90, 170, 60), C(230, 120, 30), C(150, 60, 160)]
    for z, yaw in ((45, 0), (85, math.pi)):
        for i, x in enumerate((35, 75, 115, 155, 195)):
            f = Frame(out, x, z, yaw)
            aw = BRIGHT[i % len(BRIGHT)]
            for sx in (-4.5, 4.5):
                for sz in (-2.5, 2.5):
                    f.block("Post", sx, 4, sz, 0.5, 8, 0.5, WOOD, "Wood")
            f.block("Awning", 0, 8.4, 0, 11, 0.5, 7, aw, "Fabric", rot=Rx_tilt(0.12))
            f.block("Table", 0, 2.6, 1.2, 9, 0.6, 3.5, WOOD, "Wood")
            f.block("Crate", -2.5, 3.6, 1.2, 3, 1.4, 2.6, DARK_WOOD, "Wood")
            f.block("Crate", 2.5, 3.6, 1.2, 3, 1.4, 2.6, DARK_WOOD, "Wood")
            for sx in (-3.4, -2.5, -1.6, 1.6, 2.5, 3.4):
                f.ball("Produce", sx, 4.6, 1.2, 1.2, pick(produce), "SmoothPlastic")
    # orchard
    for x in range(30, 240, 30):
        for z in (140, 175, 210):
            tx, tz = x + rng.uniform(-3, 3), z + rng.uniform(-3, 3)
            oak(out, tx, tz, 1.1, leaf=C(70, 150, 60))
            for _ in range(3):
                ball(out, "Fruit", tx + rng.uniform(-4, 4), 11 + rng.uniform(0, 3), tz + rng.uniform(-4, 4), 1.2,
                     pick([C(210, 40, 40), C(240, 200, 50)]), "SmoothPlastic")
    # scarecrow and hay
    block(out, "ScarecrowPole", 125, 5, 195, 0.6, 10, 0.6, DARK_WOOD, "Wood")
    block(out, "ScarecrowArms", 125, 7, 195, 7, 0.6, 0.6, DARK_WOOD, "Wood")
    ball(out, "ScarecrowHead", 125, 10.6, 195, 2.4, C(240, 210, 130), "Fabric")
    cyl(out, "ScarecrowHat", 125, 12, 195, 1.4, 3.2, C(120, 80, 50), "Fabric")
    for hx, hz in ((60, 158), (180, 158), (190, 225)):
        cyl(out, "HayBale", hx, 2, hz, 4, 4.5, C(224, 196, 100), "Fabric", axis="x")
    return folder("SeasonalPlaza", out)


def build_woods():
    out = []
    ground(out, "WoodsFloor", -250, -335, 500, 170, C(78, 124, 62), "Grass", y=0.05, t=0.1)
    # rolling hills
    for hx, hz, d in ((-420, -330, 110), (-330, -400, 90), (-80, -420, 100), (-170, -300, 60)):
        ball(out, "Hill", hx, -d * 0.36, hz, d, C(82, 132, 64), "Grass")
    # dirt trail
    pts = [(-8, -262), (-40, -285), (-80, -300), (-120, -318), (-150, -335), (-190, -320), (-230, -300), (-262, -285)]
    for (ax, az), (bx, bz) in zip(pts, pts[1:]):
        mx, mz = (ax + bx) / 2, (az + bz) / 2
        ln = math.hypot(bx - ax, bz - az)
        ang = math.atan2(-(bz - az), bx - ax)
        block(out, "Trail", mx, 0.2, mz, ln + 3, 0.2, 7, C(150, 116, 78), "Ground", rot=Ry(ang))
    placed = 0
    while placed < 140:
        x, z = rng.uniform(-495, -12), rng.uniform(-495, -262)
        if near_road(x, z, 14) or any(math.hypot(x - tx, z - tz) < 14 for tx, tz in ((-130, -310), (-350, -300))):
            continue
        if any(abs((x - ax) * (bz - az) - (z - az) * (bx - ax)) / (math.hypot(bx - ax, bz - az) + 0.1) < 9
               and min(ax, bx) - 5 <= x <= max(ax, bx) + 5 for (ax, az), (bx, bz) in zip(pts, pts[1:])):
            continue
        pine(out, x, z, rng.uniform(0.8, 1.4))
        placed += 1
    # campsite
    cyl(out, "FirePit", -130, 0.5, -310, 0.8, 5, C(90, 90, 96), "Rock")
    ball(out, "Flame", -130, 1.8, -310, 2.2, C(255, 140, 30), "Neon", collide=False)
    for a in range(6):
        t = a * math.tau / 6
        ball(out, "Stone", -130 + math.cos(t) * 3.2, 0.6, -310 + math.sin(t) * 3.2, 1.4, C(120, 120, 126), "Rock")
    cyl(out, "Log", -136, 1, -304, 6, 1.4, DARK_WOOD, "Wood", axis="x")
    cyl(out, "Log", -124, 1, -316, 6, 1.4, DARK_WOOD, "Wood", axis="x")
    tent(out, -145, -325, 0.5, C(230, 120, 60))
    tent(out, -112, -326, -0.4, C(70, 130, 200))
    ring(out, "Whispering Woods Campsite", -130, -296, d=9)
    # pond and rocks
    cyl(out, "WoodsPond", -350, 0.3, -300, 0.3, 40, C(60, 130, 190), "Glass", transp=0.3, collide=False)
    for _ in range(14):
        ball(out, "Boulder", rng.uniform(-480, -20), 1.5, rng.uniform(-480, -270), rng.uniform(3, 8),
             C(130, 130, 136), "Rock")
    cyl(out, "FallenLog", -60, 1.5, -330, 14, 3, DARK_WOOD, "Wood", axis="x")
    return folder("WhisperingWoods", out)


def build_industrial():
    out = []
    ground(out, "YardFloor", 250, -335, 500, 170, C(120, 120, 124), "Concrete", y=0.05, t=0.1)
    for i, x in enumerate((60, 140, 210)):
        f = Frame(out, x, -310, 0)
        f.block("Warehouse", 0, 13, 0, 60, 26, 45, C(110, 130, 150), "CorrodedMetal")
        f.block("RollDoor", 0, 8, 22.6, 22, 16, 0.5, C(70, 76, 84), "Metal")
        f.block("Stripe", 0, 20, 22.6, 60, 2, 0.3, pick(BRIGHT), "SmoothPlastic")
        f.block("Roof", 0, 26.6, 0, 62, 1.2, 47, C(80, 86, 92), "Metal")
    label_marker(out, "Commercial Kitchen Plot", 100, -272, 36, 14, "PropertyPlot", C(120, 220, 140))
    # shipping containers
    cols = [C(200, 70, 60), C(60, 110, 190), C(230, 170, 50), C(70, 150, 90), C(150, 90, 170)]
    for cx in (285, 305, 325):
        for cz in (-400, -380, -360, -340, -320, -300):
            if rng.random() < 0.25:
                continue
            for lvl in range(rng.randint(1, 3)):
                block(out, "Container", cx, 3.2 + lvl * 6.4, cz, 12, 6.4, 6, pick(cols), "CorrodedMetal")
    # chimneys and tanks
    for x, z in ((20, -400), (250 - 40, -405)):
        for i in range(5):
            cyl(out, "Chimney", x, 8 + i * 16, z, 16, 8 - i * 0.5, WHITE if i % 2 else C(200, 50, 50), "Concrete")
    for x, z in ((100, -405), (130, -405)):
        cyl(out, "Tank", x, 14, z, 28, 22, C(190, 195, 200), "Metal")
    # rival HQ
    f = Frame(out, 385, -330, 0)
    f.block("MegaCrumbHQ", 0, 28, 0, 64, 56, 50, C(230, 230, 232), "SmoothPlastic", tags=("Landmark",))
    f.block("RedBand", 0, 50, 25.2, 64, 10, 0.4, C(210, 40, 40), "SmoothPlastic")
    f.block("Sign", 0, 62, 20, 48, 6, 2, C(210, 40, 40), "Neon")
    f.block("Door", 0, 5, 25.2, 10, 10, 0.4, C(40, 40, 50), "Glass")
    for wy in (16, 28, 40):
        f.block("Windows", 0, wy, 25.2, 52, 5, 0.4, GLASS, "Glass")
    # back-alley wholesaler
    f = Frame(out, 40, -275, 0.2)
    f.block("Shed", 0, 5, 0, 16, 10, 12, C(60, 60, 68), "CorrodedMetal", tags=("Landmark",))
    f.block("Door", 0, 4, 6.1, 4, 8, 0.4, C(30, 30, 34), "Metal")
    f.block("Sign", 0, 11, 6.2, 12, 1.6, 0.4, C(90, 255, 130), "Neon")
    ring(out, "Back-Alley Wholesaler", 40, -262, tag="MeetupSpot", color=C(120, 255, 150), d=8)
    return folder("IndustrialLane", out)


def build_bay():
    out = []
    ground(out, "BeachSand", 380, 100, 240, 700, C(238, 220, 168), "Sand", y=0.05, t=0.1)
    block(out, "LakeBed", 430, 0.15, 190, 140, 0.1, 440, C(30, 90, 130), "Sand")
    block(out, "Lake", 430, 0.45, 190, 140, 0.4, 440, C(70, 150, 210), "Glass", transp=0.35, collide=False)
    # pier
    block(out, "Pier", 400, 1.1, 200, 130, 0.6, 10, C(150, 110, 70), "WoodPlanks")
    for x in range(345, 465, 12):
        for z in (195.5, 204.5):
            cyl(out, "PierPost", x, 0.2, z, 4, 1, DARK_WOOD, "Wood")
    ring(out, "Sunny Bay Pier", 345, 200, d=9, y=1.5)
    # boat
    f = Frame(out, 440, 120, 0.4)
    f.block("Hull", 0, 1.6, 0, 18, 2.4, 6, C(200, 60, 60), "SmoothPlastic")
    f.block("Cabin", -2, 3.8, 0, 6, 2.4, 4.4, WHITE, "SmoothPlastic")
    f.block("Mast", 3, 7, 0, 0.5, 11, 0.5, DARK_WOOD, "Wood")
    f.block("Sail", 3, 8, 0, 0.2, 8, 6, WHITE, "Fabric")
    # beach huts
    for i, z in enumerate((-190, -160, -130, -100, -70)):
        f = Frame(out, 300, z, math.pi / 2)
        f.block("Hut", 0, 4, 0, 10, 8, 10, BRIGHT[i % 6], "Wood")
        f.gable(10, 10, 8, 3, WHITE, "Wood", over=0.8)
        f.block("Door", 0, 3, 5.1, 3, 6, 0.3, WHITE, "Wood")
    # palms, umbrellas, tower, ice cream
    for _ in range(26):
        x, z = rng.uniform(268, 340), rng.uniform(-230, 420)
        if not near_road(x, z, 14):
            palm(out, x, z)
    for i in range(7):
        ux, uz = rng.uniform(320, 360), 60 + i * 20
        cyl(out, "UmbrellaPole", ux, 4, uz, 8, 0.4, WHITE, "Wood")
        cyl(out, "Umbrella", ux, 8.2, uz, 0.5, 9, BRIGHT[i % 6], "Fabric")
        block(out, "Towel", ux + 4, 0.25, uz, 3, 0.1, 6, BRIGHT[(i + 2) % 6], "Fabric", collide=False)
    f = Frame(out, 300, 40, math.pi / 2)
    for sx in (-2.5, 2.5):
        for sz in (-2.5, 2.5):
            f.block("Stilt", sx, 4, sz, 0.6, 8, 0.6, WHITE, "Wood")
    f.block("Cabin", 0, 10, 0, 7, 4, 7, C(240, 110, 80), "Wood")
    f.block("Roof", 0, 12.6, 0, 8.4, 0.8, 8.4, WHITE, "Wood")
    f = Frame(out, 300, 250 + 40, math.pi / 2)
    f.block("Scoop Shack", 0, 5, 0, 12, 10, 10, C(250, 190, 210), "SmoothPlastic", tags=("Landmark",))
    f.block("Awning", 0, 9, 6.5, 12, 0.5, 4, C(80, 190, 200), "Fabric")
    f.ball("Cone", 0, 12.5, 0, 4, C(250, 240, 200), "SmoothPlastic")
    # net
    for sz in (130, 150):
        cyl(out, "NetPost", 345, 4.5, sz, 9, 0.6, WOOD, "Wood")
    block(out, "Net", 345, 7, 140, 0.15, 3, 20, WHITE, "Fabric", collide=False, transp=0.3)
    return folder("SunnyBay", out)


def build_autumn_hills():
    out = []
    ground(out, "HillsGround", -380, 130, 240, 740, C(150, 140, 70), "Grass", y=0.05, t=0.1)
    for hx, hz, d in ((-430, 20, 90), (-380, 180, 120), (-440, 300, 100), (-330, 400, 90), (-440, 440, 80)):
        ball(out, "Hill", hx, -d * 0.36, hz, d, C(168, 138, 64), "Grass")
    placed = 0
    while placed < 110:
        x, z = rng.uniform(-495, -268), rng.uniform(-235, 495)
        if near_road(x, z, 14) or (abs(x + 380) < 30 and 150 < z < 260):
            continue
        oak(out, x, z, rng.uniform(0.9, 1.4), leaf=pick(AUTUMN))
        placed += 1
    # stream with bridge
    block(out, "Stream", -380, 0.3, 200, 14, 0.3, 300, C(70, 140, 200), "Glass", transp=0.3, collide=False)
    block(out, "BridgeDeck", -380, 1.8, 200, 14, 0.6, 8, WOOD, "WoodPlanks")
    for sz in (196, 204):
        block(out, "BridgeRail", -380, 3, sz, 14, 1.6, 0.4, DARK_WOOD, "Wood")
    for sx in (-6, 6):
        block(out, "BridgeRamp", -380 + sx * 1.0, 0.8, 200, 3, 0.6, 8, WOOD, "WoodPlanks")
    ring(out, "Autumn Hills Bridge", -380, 215, d=9)
    f = Frame(out, -330, 90, 0.3)
    f.block("Cabin", 0, 5, 0, 18, 10, 14, C(120, 80, 50), "Wood")
    f.gable(18, 14, 10, 5, C(100, 60, 44), "Wood")
    f.block("Door", 0, 3.5, 7.1, 4, 7, 0.4, DARK_WOOD, "Wood")
    f.block("Chimney", 6, 14, -3, 3, 8, 3, C(130, 130, 136), "Brick")
    for _ in range(12):
        x, z = rng.uniform(-480, -270), rng.uniform(-230, 480)
        if not near_road(x, z, 14):
            ball(out, "Pumpkin", x, 1.3, z, 2.6, C(230, 120, 30), "SmoothPlastic")
    return folder("AutumnHills", out)


def build_farmstead():
    out = []
    ground(out, "FarmGround", 0, 375, 500, 250, C(140, 170, 80), "Grass", y=0.05, t=0.1)
    # barn
    f = Frame(out, -100, 340, 0)
    f.block("Barn", 0, 13, 0, 40, 26, 30, C(170, 50, 44), "Wood", tags=("Landmark",))
    f.gable(40, 30, 26, 10, C(90, 90, 96), "Metal", over=1)
    f.block("Door", 0, 9, 15.1, 14, 18, 0.5, WHITE, "Wood")
    f.block("TrimX", 0, 9, 15.4, 1, 18, 0.3, WHITE, "Wood")
    f.cyl("Silo", 28, 18, 0, 36, 12, C(190, 190, 196), "Metal")
    f.ball("SiloTop", 28, 36, 0, 12, C(120, 120, 128), "Metal")
    ring(out, "Farmstead Barn", -100, 372, d=10)
    # farmhouse
    house(out, 20, 330, 0, w=30, d=22, h=15)
    # windmill (static)
    f = Frame(out, 140, 330, 0)
    f.block("MillBase", 0, 12, 0, 14, 24, 14, WHITE, "Wood")
    f.block("MillTop", 0, 27, 0, 10, 6, 10, C(170, 50, 44), "Wood")
    for ang in (0.0, math.pi / 2):
        f.block("Blade", 0, 28, 8, 34, 3, 0.5, C(230, 220, 190), "Wood", rot=Rz(ang + 0.5))
    # crops
    for r, col in enumerate((C(220, 190, 70), C(90, 160, 60), C(150, 190, 80))):
        for k in range(6):
            block(out, "CropRow", 150 + k * 6, 0.8, 400 + r * 40, 2.4, 1.4, 34, col, "Grass", collide=False)
    # pumpkins
    for _ in range(40):
        ball(out, "Pumpkin", rng.uniform(-200, -30), 1.3, rng.uniform(410, 480), 2.6, C(230, 120, 30), "SmoothPlastic")
    # fences and hay
    for i in range(10):
        fence(out, -200 + i * 14, 290, 14, 0, WOOD)
    for hx, hz in ((-60, 300), (-52, 304), (-130, 300)):
        cyl(out, "HayBale", hx, 2.2, hz, 4.4, 4.5, C(224, 196, 100), "Fabric", axis="x")
    cyl(out, "FarmPond", 60, 0.3, 450, 0.3, 36, C(60, 130, 190), "Glass", transp=0.3, collide=False)
    for _ in range(14):
        x, z = rng.uniform(-240, 240), rng.uniform(270, 490)
        if not near_road(x, z, 14) and not (-120 < x < -60 and 320 < z < 370):
            oak(out, x, z, rng.uniform(0.9, 1.2))
    return folder("Farmstead", out)


def build_border():
    out = []
    # outer mountains and invisible walls
    for side in range(4):
        for i in range(-5, 6):
            d = rng.uniform(150, 230)
            off = 640 + rng.uniform(-30, 30)
            t = i * 110 + rng.uniform(-20, 20)
            x, z = (off, t) if side == 0 else (-off, t) if side == 1 else (t, off) if side == 2 else (t, -off)
            ball(out, "Mountain", x, -d * 0.2, z, d, C(118, 118, 126), "Rock")
            ball(out, "Snow", x, d * 0.22, z, d * 0.5, WHITE, "Snow")
    for x, z, sx, sz in ((600, 0, 2, 1200), (-600, 0, 2, 1200), (0, 600, 1200, 2), (0, -600, 1200, 2)):
        block(out, "Wall", x, 100, z, sx, 200, sz, C(255, 255, 255), "Plastic", transp=1, collide=True)
    return folder("Border", out)


def build_world():
    """Returns a list of XML items to place inside Workspace."""
    base = [
        part("Baseplate", (0, -10, 0), (1200, 20, 1200), C(96, 140, 72), "Grass"),
    ]
    districts = [
        build_roads(), build_plaza(), build_apartment(), build_maple_heights(), build_downtown(),
        build_campus(), build_market(), build_woods(), build_industrial(), build_bay(), build_autumn_hills(),
        build_farmstead(), build_border(),
    ]
    return base + districts
