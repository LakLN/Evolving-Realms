"""Quadruped rig for Snow P0 creatures (scree wolf C02, bellback sentinel C03).

One parametric body per species; poses come from torso offset/pitch, head pitch, jaw
and four two-segment legs swinging from the hips. Gait = sine-phased diagonal pairs.
"""
import math

import numpy as np

from pixel3d import Part, rot

WOLF = {"fur": ["#aab1c3", "#8991a7", "#6b728a", "#4e546c", "#343a4e"],
        "light": ["#eeece6", "#d2d3db", "#aaadbd", "#7f8398", "#595d72"],
        "dark": ["#4b4757", "#373442", "#26232f"], "eye": "#e6b54c"}
RAM = {"fur": ["#d3cab8", "#b0a590", "#8a7f6b", "#645a4b", "#453d33"],
       "light": ["#f1ece2", "#d8d0c0", "#b2a793", "#867b68", "#5e5547"],
       "dark": ["#8b7c6b", "#6b5e50", "#4e4339", "#362e27"], "hoof": ["#3c3434", "#282224"],
       "bronze": ["#e3b66e", "#bc8c4c", "#8f6538", "#61442a", "#3c2a1b"], "eye": "#d9cf7a"}
GAIT = {"LF": 0.0, "RH": 0.0, "RF": math.pi, "LH": math.pi}
COLUMNS = [("idle", 0), ("walk", 0), ("walk", 1), ("walk", 2), ("walk", 3),
           ("attack", 0), ("attack", 1), ("attack", 2), ("hit", 0), ("death", 0), ("death", 1)]
COLUMN_NAMES = ["idle", "walk1", "walk2", "walk3", "walk4", "attack1", "attack2", "attack3", "hit", "death1", "death2"]


def quadruped(s: dict, state: str, frame: int):
    dz = dy = pitch = head_pitch = jaw = ears = 0.0
    swing = dict.fromkeys(GAIT, 0.0)
    lift = dict.fromkeys(GAIT, 0.0)
    eyes_open = True
    if state == "walk":
        phase = frame * math.pi / 2
        for leg, offset in GAIT.items():
            swing[leg] = s["stride"] * math.sin(phase + offset)
            lift[leg] = max(0.0, math.cos(phase + offset)) * s["lift"]
        dy = s["bob"] * math.cos(2 * phase)
    elif state == "attack":  # wind-up, lunge with open jaw, recover
        dz, dy, pitch, head_pitch, jaw, front = [(-2.0, -1.0, -4, 14, 0, -12), (3.0, 0.2, 8, -6, 28, 18),
                                                 (1.6, 0.0, 3, 4, 6, 10)][frame]
        swing.update(LF=front, RF=front * 0.8, LH=-front * 0.6, RH=-front * 0.4)
    elif state in ("hit", "death"):
        dz, pitch, head_pitch, ears, eyes_open = -1.6, -9, -14, 35, False
        swing.update(LF=-10, RF=-6, LH=12, RH=8)
    tilt = rot(pitch=pitch)
    pivot = (0, s["hip"], 0)
    neck = np.array(s["neck"])
    head_m = rot(pitch=head_pitch + s.get("carry", 0))  # habitual head carriage (ram: low, horns forward)
    parts = [p.moved(tilt, pivot, (0, dy, dz)) for p in s["body"]()]
    parts += [p.moved(head_m, neck).moved(tilt, pivot, (0, dy, dz)) for p in s["head"](jaw, ears)]
    for leg, (x, z) in s["legs"].items():
        swing_m = rot(pitch=swing[leg])
        parts += [p.moved(swing_m, (x, s["hip"], z), (0, lift[leg] + dy * 0.5, dz * 0.6)) for p in s["leg"](x, z)]

    def place(point):
        return tilt @ (head_m @ (np.array(point, float) - neck) + neck - pivot) + pivot + (0, dy, dz)

    ex, ey, ez = s["eye"]
    colour = s["pal"]["eye"] if eyes_open else s["pal"]["dark"][1]
    marks = [(place((ex * side, ey, ez)), colour) for side in (-1, 1)]
    if state == "death":  # tip onto the side, then lie flat
        roll = rot(roll=45 if frame == 0 else 86)
        drop = (2.5, -1.5, 1.0) if frame == 0 else (5.0, -4.0, 2.5)  # recentre the outflung legs
        return [p.moved(roll, (0, 0, 0), drop) for p in parts], [(roll @ m + drop, c) for m, c in marks]
    return parts, marks


def wolf_spec() -> dict:
    w = WOLF

    def body():
        return [Part("torso", (0, 11.5, -1.5), (4.3, 4.6, 9.2), w["fur"]),
                Part("belly", (0, 9.6, 0.5), (3.3, 2.6, 6.6), w["light"]),
                Part("chest", (0, 12.4, 5.2), (4.5, 5.2, 4.4), w["light"]),
                Part("mane", (0, 15.0, 4.0), (4.6, 3.6, 4.6), w["fur"]),
                Part("tail", (0, 11.0, -12.5), (1.8, 1.9, 5.4), w["fur"], rot(pitch=28))]

    def head(jaw, ears):
        parts = [Part("neck", (0, 15.6, 7.6), (3.0, 3.6, 3.0), w["fur"], rot(pitch=-30)),
                 Part("head", (0, 17.4, 10.2), (3.5, 3.3, 3.7), w["fur"]),
                 Part("cheek", (0, 16.3, 11.0), (3.2, 2.2, 2.8), w["light"]),
                 Part("snout", (0, 16.2, 13.9), (1.6, 1.5, 2.7), w["light"]),
                 Part("nose", (0, 16.7, 16.3), (0.8, 0.7, 0.6), w["dark"]),
                 Part("jaw", (0, 15.0, 13.0), (1.3, 0.8, 2.3), w["light"]).moved(rot(pitch=jaw), (0, 15.6, 11.0))]
        for side in (-1, 1):
            parts.append(Part("ear", (2.0 * side, 20.8, 9.3), (1.0, 2.3, 0.8), w["dark"], rot(pitch=ears, roll=-12 * side)))
        return parts

    def leg(x, z):
        return [Part("thigh", (x, 7.4, z), (1.5, 3.4, 1.8), w["fur"]),
                Part("shin", (x, 3.0, z + 0.3), (1.0, 2.6, 1.1), w["light"]),
                Part("paw", (x, 0.8, z + 0.9), (1.2, 0.8, 1.6), w["dark"])]
    return {"pal": w, "body": body, "head": head, "leg": leg, "hip": 10.5, "neck": (0, 15.6, 7.6),
            "legs": {"LF": (-2.5, 5.4), "RF": (2.5, 5.4), "LH": (-2.7, -6.8), "RH": (2.7, -6.8)},
            "eye": (1.8, 18.2, 12.6), "stride": 19, "lift": 1.4, "bob": 0.4}


def ram_spec() -> dict:
    r = RAM

    def body():
        return [Part("fleece", (0, 12.0, -1.0), (5.6, 5.6, 9.0), r["fur"]),
                Part("chest", (0, 12.6, 5.4), (5.4, 5.8, 4.6), r["fur"]),
                Part("belly", (0, 9.4, 0.0), (4.4, 3.0, 6.8), r["light"]),
                Part("rump", (0, 13.0, -7.6), (5.0, 5.0, 3.6), r["fur"]),
                Part("tail", (0, 13.4, -11.2), (1.4, 1.6, 1.2), r["dark"]),
                Part("mane", (0, 14.4, 5.6), (4.6, 3.4, 3.4), r["dark"])]

    def head(jaw, ears):
        parts = [Part("neck", (0, 15.0, 7.4), (3.6, 3.8, 3.2), r["fur"], rot(pitch=-20)),
                 Part("skull", (0, 16.4, 10.2), (3.3, 3.4, 3.4), r["dark"]),
                 Part("muzzle", (0, 14.6, 13.0), (2.1, 2.2, 2.4), r["dark"], rot(pitch=25)),
                 Part("brow", (0, 18.4, 10.6), (3.0, 1.4, 2.2), r["fur"]),
                 Part("beard", (0, 12.6, 9.8), (2.6, 3.0, 2.2), r["dark"]),
                 Part("jaw", (0, 13.0, 12.6), (1.5, 0.8, 1.8), r["dark"]).moved(rot(pitch=jaw * 0.6), (0, 14.0, 10.8))]
        for side in (-1, 1):  # heavy horns curling back, down and forward: weathered bell bronze
            for k in range(8):
                ang = math.radians(100 + k * 38)
                radius = 3.6 - k * 0.12
                c = (side * (3.4 + k * 0.32), 18.0 + radius * math.sin(ang) * 0.9, 9.6 - radius * math.cos(ang))
                size = 1.75 - k * 0.12
                parts.append(Part("horn", c, (size, size, size), r["bronze"]))
            parts.append(Part("ear", (3.6 * side, 16.0, 9.2), (1.6, 0.7, 1.0), r["dark"], rot(pitch=ears, roll=25 * side)))
        return parts

    def leg(x, z):
        return [Part("thigh", (x, 7.0, z), (2.0, 3.6, 2.2), r["fur"]),
                Part("shin", (x, 2.8, z + 0.2), (1.2, 2.4, 1.3), r["dark"]),
                Part("hoof", (x, 0.7, z + 0.5), (1.3, 0.8, 1.5), r["hoof"])]
    return {"pal": r, "body": body, "head": head, "leg": leg, "hip": 10.0, "neck": (0, 15.0, 7.4), "carry": 14,
            "legs": {"LF": (-3.0, 5.0), "RF": (3.0, 5.0), "LH": (-3.2, -6.4), "RH": (3.2, -6.4)},
            "eye": (2.6, 17.0, 12.2), "stride": 16, "lift": 1.0, "bob": 0.3}


WOLF_SPEC, RAM_SPEC = wolf_spec(), ram_spec()


def wolf(state, frame):
    return quadruped(WOLF_SPEC, state, frame)


def ram(state, frame):
    return quadruped(RAM_SPEC, state, frame)
