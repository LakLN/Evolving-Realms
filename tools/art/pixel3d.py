"""Tiny 3D-to-pixel renderer for creature/landmark production art (no AI, no network).

A model is a list of ellipsoid parts in model space (pixels; x right, y up, z forward =
the facing direction, origin = the feet point on the ground). `render` places it with a
yaw, views it through the fixed three-quarter orthographic camera of the Art Bible and
rasterises at native 1x: nearest-surface z-buffer, light from the upper left quantised
to each part's palette ramp, then a dark selective outline and depth-edge inner lines.
Every direction comes from the same model, so facing, scale and upper-left light stay
consistent (left is rendered, never mirrored). Output: RGBA uint8, hard 0/255 alpha.
"""
import math

import numpy as np

PITCH = math.radians(42)  # view direction below horizontal (three-quarter top-down)
RIGHT = np.array([1.0, 0.0, 0.0])
UP = np.array([0.0, math.cos(PITCH), -math.sin(PITCH)])
VIEW = np.array([0.0, -math.sin(PITCH), -math.cos(PITCH)])  # into the screen
_L = np.array([-0.62, 0.62, 0.48])  # screen space: left, up, toward the viewer
LIGHT = (_L[0] * RIGHT + _L[1] * UP - _L[2] * VIEW) / np.linalg.norm(_L)
YAW = {"down": 0.0, "right": 90.0, "up": 180.0, "left": -90.0}


def hexc(value: str) -> np.ndarray:
    value = value.lstrip("#")
    return np.array([int(value[i:i + 2], 16) for i in (0, 2, 4)], dtype=float)


def rot(yaw: float = 0.0, pitch: float = 0.0, roll: float = 0.0) -> np.ndarray:
    """Degrees. yaw about y, pitch about x (positive tips the +z end down), roll about z."""
    y, p, r = (math.radians(a) for a in (yaw, pitch, roll))
    ry = np.array([[math.cos(y), 0, math.sin(y)], [0, 1, 0], [-math.sin(y), 0, math.cos(y)]])
    rx = np.array([[1, 0, 0], [0, math.cos(p), math.sin(p)], [0, -math.sin(p), math.cos(p)]])
    rz = np.array([[math.cos(r), -math.sin(r), 0], [math.sin(r), math.cos(r), 0], [0, 0, 1]])
    return ry @ rx @ rz


class Part:
    """Ellipsoid: centre c, radii r, local rotation m, colour ramp (light -> dark)."""

    box = False

    def __init__(self, name, c, r, ramp, m=None, flat=False):
        self.name, self.c, self.r = name, np.array(c, float), np.array(r, float)
        self.m = np.eye(3) if m is None else m
        self.ramp, self.flat = [hexc(x) for x in ramp], flat

    def moved(self, matrix: np.ndarray, origin, offset=(0, 0, 0)) -> "Part":
        """Rigid transform about `origin`, then translate by `offset` (model space)."""
        origin = np.array(origin, float)
        copy = type(self).__new__(type(self))
        copy.name, copy.r, copy.ramp, copy.flat = self.name, self.r, self.ramp, self.flat
        copy.c = matrix @ (self.c - origin) + origin + np.array(offset, float)
        copy.m = matrix @ self.m
        return copy


class Box(Part):
    """Oriented box: centre c, half extents r (flat faces for timber, stone, cases)."""
    box = True


def _shift(a, dy, dx, fill):
    """Neighbour lookup without wrap-around (np.roll would leak pixels across edges)."""
    out = np.full_like(a, fill)
    h, w = a.shape[:2]
    out[max(dy, 0):h + min(dy, 0), max(dx, 0):w + min(dx, 0)] = a[max(-dy, 0):h + min(-dy, 0), max(-dx, 0):w + min(-dx, 0)]
    return out


def _grid(size, anchor):
    w, h = size
    cols, rows = np.meshgrid(np.arange(w) + 0.5, np.arange(h) + 0.5)
    return (cols - anchor[0]), (anchor[1] - rows)


def render(parts, size, anchor, yaw="down", outline="#1e1a26", marks=(), lines=True, scale=1.0):
    """Rasterise parts; `marks` are (model point, colour) surface details (eyes, rivets).
    `scale` = screen pixels per model unit (one model, several runtime sizes)."""
    world = rot(YAW.get(yaw, yaw) if isinstance(yaw, str) else yaw)
    su, sv = _grid(size, anchor)
    su, sv = su / scale, sv / scale
    origin = su[..., None] * RIGHT + sv[..., None] * UP  # point on the screen plane, t along VIEW
    depth = np.full(su.shape, np.inf)
    index = np.full(su.shape, -1)
    normal = np.zeros(su.shape + (3,))
    for i, part in enumerate(parts):
        m = world @ part.m
        centre = world @ part.c
        q = ((origin - centre) @ m) / part.r      # local unit-sphere / unit-cube coordinates
        d = (m.T @ VIEW) / part.r
        if part.box:  # slab test against [-1, 1]^3; normal = axis of the entry face
            with np.errstate(divide="ignore", invalid="ignore"):
                t1, t2 = (-1 - q) / d, (1 - q) / d
            near, far = np.minimum(t1, t2), np.maximum(t1, t2)
            entry = near.max(-1)
            hit = entry <= far.min(-1)
            t = np.where(hit, entry, np.inf)
            closer = t < depth
            if not closer.any():
                continue
            axis = near.argmax(-1)
            local = np.zeros(q.shape)
            np.put_along_axis(local, axis[..., None], -np.sign(d[axis])[..., None], -1)
            n = local @ m.T
        else:
            a = d @ d
            b = 2 * (q @ d)
            c = (q * q).sum(-1) - 1
            disc = b * b - 4 * a * c
            hit = disc >= 0
            t = np.where(hit, (-b - np.sqrt(np.where(hit, disc, 0))) / (2 * a), np.inf)
            closer = t < depth
            if not closer.any():
                continue
            local = q + np.where(hit, t, 0)[..., None] * d
            n = (local / part.r) @ m.T
        n /= np.linalg.norm(n, axis=-1, keepdims=True) + 1e-9
        depth = np.where(closer, t, depth)
        index = np.where(closer, i, index)
        normal = np.where(closer[..., None], n, normal)
    h, w = su.shape
    rgba = np.zeros((h, w, 4), np.uint8)
    shade = np.clip(normal @ LIGHT, -1, 1)
    for i, part in enumerate(parts):
        mask = index == i
        if not mask.any():
            continue
        steps = len(part.ramp)
        if part.flat:
            level = np.zeros(mask.sum(), int)
        else:  # light 1 -> tone 0; facing away -> darkest tone
            level = np.clip(((0.85 - shade[mask]) / 1.55 * steps).astype(int), 0, steps - 1)
        rgba[mask, :3] = np.array(part.ramp)[level]
        rgba[mask, 3] = 255
    solid = index >= 0
    if lines:  # inner line where a part sits clearly in front of a different one
        for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
            ni = _shift(index, dy, dx, -1)
            nd = _shift(depth, dy, dx, np.inf)
            gap = np.where(solid & (ni >= 0), depth - np.where(ni >= 0, nd, 0), 0)
            edge = solid & (ni >= 0) & (ni != index) & (gap > 2.5)
            for i, part in enumerate(parts):
                sel = edge & (index == i)
                rgba[sel, :3] = (part.ramp[-1] * 0.8).astype(np.uint8)
    for point, colour in marks:
        p = world @ np.array(point, float)
        x = int(math.floor(p @ RIGHT * scale + anchor[0]))
        y = int(math.floor(anchor[1] - p @ UP * scale))
        if 0 <= y < h and 0 <= x < w and solid[y, x] and abs((p - origin[y, x]) @ VIEW - depth[y, x]) < 2.0:
            rgba[y, x, :3] = hexc(colour)
    line = hexc(outline)
    out = np.zeros_like(solid)
    for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
        out |= _shift(solid, dy, dx, False)
    out &= ~solid
    rgba[out, :3] = line
    rgba[out, 3] = 255
    return rgba
