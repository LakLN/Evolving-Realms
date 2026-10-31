"""Small helpers for slicing AI-generated source sheets into game-ready pixel sprites.

Dev-only (Pillow, numpy, scipy). The game never runs Python: outputs are committed PNGs.
"""
from __future__ import annotations

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ALPHA_CUT = 128


def load(path) -> np.ndarray:
    return np.array(Image.open(path).convert("RGBA"))


def components(rgba: np.ndarray, box, dilate: int = 1, min_area: int = 2500, max_width: int = 0):
    """Labels opaque blobs inside box=(y0, x0, y1, x1). Small blobs (glow leaves, split
    slash arcs) are merged into the nearest large blob. Returns masks sorted by x."""
    y0, x0, y1, x1 = box
    solid = rgba[y0:y1, x0:x1, 3] > 24
    labels, count = ndimage.label(ndimage.binary_dilation(solid, iterations=dilate))
    big, small = [], []
    for index in range(1, count + 1):
        mask = (labels == index) & solid
        area = int(mask.sum())
        if area == 0:
            continue
        ys, xs = np.nonzero(mask)
        entry = {"mask": mask, "cx": xs.mean(), "cy": ys.mean(), "area": area}
        (big if area >= min_area else small).append(entry)
    for piece in small:
        if not big:
            break
        nearest = min(big, key=lambda b: (b["cx"] - piece["cx"]) ** 2 + (b["cy"] - piece["cy"]) ** 2)
        nearest["mask"] |= piece["mask"]
    big.sort(key=lambda b: b["cx"])
    masks = []
    for b in big:
        masks.extend(_split_wide(b["mask"], max_width))
    return [(m, (y0, x0)) for m in masks]


def _split_wide(mask: np.ndarray, max_width: int):
    """Two frames touching each other: cut at the thinnest column near the middle."""
    xs = np.nonzero(mask.any(axis=0))[0]
    if max_width <= 0 or xs.size == 0 or xs.max() - xs.min() <= max_width:
        return [mask]
    lo, hi = xs.min(), xs.max()
    span = hi - lo
    window = range(lo + span // 3, hi - span // 3)
    column = min(window, key=lambda x: mask[:, x].sum())
    left, right = mask.copy(), mask.copy()
    left[:, column:] = False
    right[:, :column] = False
    return _split_wide(left, max_width) + _split_wide(right, max_width)


def cut(rgba: np.ndarray, mask: np.ndarray, offset) -> np.ndarray:
    """Pixels of one blob only (neighbouring frames' overlapping effects are dropped)."""
    y0, x0 = offset
    h, w = mask.shape
    part = rgba[y0:y0 + h, x0:x0 + w].copy()
    part[~mask] = 0
    ys, xs = np.nonzero(part[..., 3] > 24)
    return part[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def is_glow(rgba: np.ndarray) -> np.ndarray:
    """Bright yellow-green magic glow; excluded when locating a character's feet."""
    r, g, b = (rgba[..., i].astype(int) for i in range(3))
    return (g > 150) & (g - b > 90) & (g >= r)


def foot_anchor(part: np.ndarray, glow_filter: bool) -> tuple[float, float]:
    body = part[..., 3] > ALPHA_CUT
    if glow_filter:
        body &= ~is_glow(part)
    labels, count = ndimage.label(body)
    if count > 1:  # Largest blob is the body; slash arcs and leaves are ignored.
        sizes = ndimage.sum(body, labels, range(1, count + 1))
        body = labels == (int(np.argmax(sizes)) + 1)
    ys, xs = np.nonzero(body)
    bottom = ys.max()
    low = ys >= bottom - (bottom - ys.min()) * 0.3
    return float(xs[low].mean()), float(bottom)


def downscale(part: np.ndarray, scale: float) -> Image.Image:
    """Area-average downscale on premultiplied colour, then a hard alpha edge so the
    result reads as crisp pixel art instead of a blurry painting."""
    h, w = part.shape[:2]
    size = (max(1, round(w * scale)), max(1, round(h * scale)))
    rgba = part.astype(np.float32) / 255.0
    rgba[..., :3] *= rgba[..., 3:4]
    channels = [Image.fromarray((rgba[..., i] * 255).astype(np.uint8)).resize(size, Image.BOX) for i in range(4)]
    out = np.stack([np.array(c, dtype=np.float32) / 255.0 for c in channels], axis=-1)
    alpha = out[..., 3:4]
    color = np.where(alpha > 0.001, out[..., :3] / np.maximum(alpha, 0.001), 0)
    solid = alpha[..., 0] > 0.5
    result = np.zeros(out.shape, dtype=np.uint8)
    result[..., :3] = np.clip(color * 255, 0, 255).astype(np.uint8)
    result[..., 3] = np.where(solid, 255, 0)
    image = Image.fromarray(result, "RGBA")
    sharp = image.filter(ImageFilter.UnsharpMask(radius=1, percent=60, threshold=2))
    sharp.putalpha(image.getchannel("A"))
    return sharp


def outline(image: Image.Image, color=(24, 18, 14, 255)) -> Image.Image:
    """1px dark outline where the sprite meets transparency (readability on grass)."""
    a = np.array(image)
    solid = a[..., 3] > 0
    ring = ndimage.binary_dilation(solid) & ~solid
    a[ring] = color
    return Image.fromarray(a, "RGBA")


def place(canvas: Image.Image, sprite: Image.Image, anchor_canvas, anchor_sprite) -> None:
    x = round(anchor_canvas[0] - anchor_sprite[0])
    y = round(anchor_canvas[1] - anchor_sprite[1])
    canvas.alpha_composite(sprite, (max(0, x), max(0, y)), (max(0, -x), max(0, -y)))
