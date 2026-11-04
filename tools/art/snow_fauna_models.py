"""Original models for the full Snow roster, on the established pixel3d rig."""
import math
import numpy as np
from pixel3d import Part, Box, rot
from snow_quadrupeds import wolf_spec, ram_spec, quadruped, RAM

FROST = ["#eef4fc", "#c0d9ec", "#85a9cc", "#577391", "#35465e"]
HIDE = ["#c3b6a0", "#9a8670", "#705e50", "#4b3d38", "#30282c"]
BRONZE = ["#efc47d", "#bd9254", "#856136", "#58432c", "#342b25"]
RED = ["#d69b78", "#ac6654", "#79443d", "#502e34"]
BLUE = ["#b0c4dc", "#7c94b8", "#536d94", "#354664", "#242c42"]
DARK = ["#696674", "#4b4658", "#332f42", "#211e30"]
FIRE = ["#fff1b0", "#f9b563", "#d97048", "#823e3d"]
# b3 readability: mid-tone coats that separate from snow (caribou grey-brown, slate).
STAG = ["#b8a68c", "#8c7761", "#634f40", "#44362d", "#2a2220"]
SLATE = ["#a9b8c8", "#7d8ea3", "#56667d", "#3a4658", "#252d3a"]
# b4: the crown elder, a summit-grey bellback with rime along its spine.
ELDER_FUR = ["#b9bcc2", "#93979f", "#6d717b", "#4d505a", "#33353d"]
ELDER_DARK = ["#5c5862", "#45414b", "#302d36", "#211f27"]
PINE = ["#86a88f", "#5f8070", "#415f54", "#2b443d"]
MOSS = ["#d9d58a", "#aeb064", "#7f8648", "#565d34"]


def _ramp(hexes):
    return [np.array([int(c[i:i+2], 16) for i in (1, 3, 5)], float) for c in hexes]


def quadruped_model(kind, state, frame):
    spec = ram_spec() if kind in ("frost_stag", "tuskback") else wolf_spec()
    body, head = spec["body"], spec["head"]

    def torso():
        parts = body()
        if kind == "tuskback":
            parts = [p for p in parts if p.name != "mane"]
            parts += [Part("ridge", (0, 17, -2), (1, 1.5, 7), DARK)]
        elif kind == "pine_prowler":
            parts = [p for p in parts if p.name not in ("mane", "tail")]
            parts += [Part("long_tail", (0, 12, -15), (1.1, 1.1, 7), HIDE, rot(pitch=-12))]
        elif kind == "ashmaw":
            parts += [Part("spine", (0, 17, -1), (1.5, 3, 7), RED)]
            for side in (-1, 1):
                parts += [Box("wing_fin", (side * 6, 14, -3), (3, 0.6, 6), RED, rot(roll=side * 35))]
        return parts

    def skull(jaw, ears):
        parts = head(jaw, ears)
        if kind == "frost_stag":
            parts = [p for p in parts if p.name not in ("horn", "beard")]
            for side in (-1, 1):
                parts += [Part("antler", (side * 4, 23, 8), (0.8, 6, 0.8), HIDE, rot(roll=-side * 25))]
                for y in (22, 25):
                    parts += [Part("tine", (side * 6, y, 9), (2.5, 0.6, 0.6), HIDE, rot(roll=side * 20))]
        elif kind == "tuskback":
            parts = [p for p in parts if p.name not in ("horn", "beard")]
            for side in (-1, 1):
                parts += [Part("tusk", (side * 3, 13, 15), (0.8, 2.8, 1.1), FROST, rot(pitch=-25, roll=side * 25))]
        elif kind == "pine_prowler":
            parts = [p for p in parts if p.name not in ("snout", "nose")]
            parts += [Part("cat_muzzle", (0, 16, 13), (2.4, 1.5, 1.5), HIDE)]
        elif kind == "ashmaw":
            for side in (-1, 1):
                parts += [Part("horn", (side * 3, 22, 8), (1, 3.5, 1), RED, rot(pitch=25))]
        return parts

    spec.update(body=torso, head=skull)
    parts, marks = quadruped(spec, state, frame)
    palette = STAG if kind == "frost_stag" else RED if kind == "ashmaw" else HIDE
    for part in parts:
        if part.name not in ("tusk", "antler", "tine", "horn", "wing_fin"):
            part.ramp = [np.array([int(c[i:i+2], 16) for i in (1, 3, 5)], float) for c in palette]
    return parts, marks


def elder_model(kind, state, frame):
    spec = ram_spec()
    base = spec["body"]
    spec.update(body=lambda: base() + [Part("rime", (0, 18.4, z), (0.9, 2.4, 0.9), FROST, rot(pitch=-18)) for z in (-6.5, -3.0, 0.5, 4.0)])
    parts, marks = quadruped(spec, state, frame)
    for part in parts:
        if part.name in ("fleece", "chest", "rump", "thigh", "neck", "brow"):
            part.ramp = _ramp(ELDER_FUR)
        elif part.name in ("tail", "mane", "skull", "muzzle", "beard", "jaw", "shin", "ear"):
            part.ramp = _ramp(ELDER_DARK)
    return parts, marks


def biped(kind, state, frame):
    giant = kind == "hoarfrost_giant"
    empty = kind == "hollow_carrier"
    fire = kind == "cinder_acolyte"
    pal = SLATE if giant else BLUE if empty else RED if fire else HIDE
    phase = frame * math.pi / 2 if state == "walk" else 0
    swing = math.sin(phase) * 24
    attack = ([-25, 55, 12][frame] if state == "attack" else 0)
    pitch = -12 if state == "hit" else 0
    parts = [Part("coat", (0, 13, 0), (4.3, 7, 3), pal),
             Box("belt", (0, 11, 0), (4.5, 0.7, 3.2), BRONZE),
             Part("hood", (0, 22, 0), (3.8, 4, 3.4), pal),
             Part("face", (0, 22, 2.7), (2.5, 2.7, 1), DARK if empty else BRONZE if fire else HIDE)]
    for side in (-1, 1):
        parts.append(Part("leg", (side * 2.1, 4, 0), (1.7, 4, 1.8), DARK).moved(rot(pitch=swing * side), (side * 2.1, 8, 0)))
        parts.append(Part("arm", (side * 5, 14, 0), (1.5, 5, 1.5), pal).moved(rot(pitch=attack if side == 1 else -swing * 0.5), (side * 5, 18, 0)))
    if kind == "relay_cutthroat":
        parts += [Box("blade", (6, 11, 3), (0.7, 5, 0.5), BRONZE).moved(rot(pitch=attack), (5, 18, 0))]
    elif kind == "relay_slinger":
        parts += [Part("pouch", (6, 12, 3), (2, 1.7, 1), HIDE), Box("sling", (6, 17, 3), (0.4, 5, 0.4), DARK)]
    elif fire:
        parts += [Box("staff", (7, 11, 2), (0.7, 11, 0.7), DARK), Part("flame", (7, 25, 2), (2.2, 4, 2), FIRE)]
    elif empty:
        parts += [Box("scarf", (0, 19, 3.4), (4, 1, 0.5), FROST), Box("rag", (-4, 6, -2), (1, 4, 0.4), FROST)]
    elif giant:
        parts += [Part("beard", (0, 17, 3.4), (2.8, 5, 1.8), FROST), Box("club", (7, 10, 2), (1.3, 10, 1.3), HIDE), Part("ice_head", (7, 21, 2), (3, 4, 3), FROST)]
    parts = [p.moved(rot(pitch=pitch), (0, 10, 0)) for p in parts]
    if state == "death":
        parts = [p.moved(rot(roll=45 if frame == 0 else 88), (0, 13, 0), (0, 0, 0)) for p in parts]
    return parts, []


def crystal(kind, state, frame):
    crawler = kind == "glassback_crawler"
    bob = math.sin(frame * math.pi / 2) if state == "walk" else 0
    pal = BLUE if crawler else FROST
    parts = [Part("shell", (0, 5 + bob, 0), (7, 4, 8), pal)] if crawler else [Part("core", (0, 13 + bob, 0), (4, 6, 4), BLUE)]
    if crawler:
        for side in (-1, 1):
            for i, z in enumerate((-5, 0, 5)):
                parts += [Part("leg", (side * 7, 2, z + math.sin((frame + i) * math.pi / 2)), (3, 1, 1.3), DARK, rot(roll=side * 25))]
        for x, z in ((0, 1), (-3, -3), (3, -3)):
            parts += [Part("quartz", (x, 10, z), (1.5, 5, 1.5), FROST, rot(roll=x * 8))]
    else:
        for side in (-1, 1):
            parts += [Part("prong", (side * 6, 13 + bob, 0), (1.2, 7, 1.2), FROST, rot(roll=side * 25)),
                      Part("prong", (0, 13 + bob, side * 6), (1.2, 5, 1.2), FROST, rot(pitch=side * 25))]
        if state == "attack":
            parts += [Part("bolt", (0, 13, 7 + frame * 2), (1.5, 1.5, 3), BLUE)]
    if state == "hit": parts = [p.moved(rot(roll=-12), (0, 4, 0)) for p in parts]
    if state == "death": parts = [p.moved(rot(roll=45 if frame == 0 else 88), (0, 0, 0)) for p in parts]
    return parts, []


# b4 scales: people about hero height, beasts a tile and a half long, large species in
# larger cells (CELLS) instead of being shrunk to fit the shared 84x76 cell.
SPECS = {
    "frost_stag": (quadruped_model, 1.95), "tuskback": (quadruped_model, 2.3),
    "pine_prowler": (quadruped_model, 1.85), "relay_cutthroat": (biped, 2.05),
    "relay_slinger": (biped, 2.05), "cinder_acolyte": (biped, 1.95),
    "hollow_carrier": (biped, 2.25), "glassback_crawler": (crystal, 2.15),
    "rime_lantern": (crystal, 1.95), "ashmaw": (quadruped_model, 2.75),
    "hoarfrost_giant": (biped, 3.6), "elder_bellback": (elder_model, 3.1),
}
MEDIUM, LARGE = ((104, 92), (52, 84)), ((140, 124), (70, 115))
CELLS = {"frost_stag": MEDIUM, "pine_prowler": MEDIUM, "tuskback": MEDIUM, "hollow_carrier": MEDIUM, "ashmaw": LARGE, "hoarfrost_giant": LARGE, "elder_bellback": LARGE}
