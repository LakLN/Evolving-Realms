"""Compose a Snow spatial-layout area into one painted ground image.

Reads the SAME authored spatial plan used for collision/navigation (zones, heights,
styles) and paints it as a single coherent environment: organic worn paths, real
cliff faces with snow caps and occlusion, a frozen ravine with banks, a built
bridge, carved stairs, a timber-and-stone outpost and shaded vegetation.
Presentation only: geometry is never changed. Output is keyed by layout id+version.

    .venv/Scripts/python.exe tools/art/compose_snow_area.py [--preview out.png]
"""
import json, sys, hashlib
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage
sys.path.insert(0, str(Path(__file__).resolve().parent))
import snow_env as E
from snow_env import TS

ROOT = Path(__file__).resolve().parents[2]
LAYOUT = ROOT / 'content/land_layouts/snow_mountain_reference.json'
OUT_DIR = ROOT / 'assets/game/snow/reference'
WALK = {'snow', 'terrace', 'trail', 'stairs', 'ledge', 'bridge', 'floor'}


def grid(area):
    W, H = area['size']['x'], area['size']['y']
    style = np.full((H, W), 'snow', dtype=object)
    height = np.zeros((H, W), int)
    for z in area['zones']:
        x, y, w, h = z['rect']
        style[y:y + h, x:x + w] = z['style']
        height[y:y + h, x:x + w] = z['height']
    return style, height


def up(cell_mask):
    """Cell mask -> pixel mask."""
    return np.kron(cell_mask.astype(np.uint8), np.ones((TS, TS), np.uint8)).astype(bool)


def soft(mask, sigma):
    return ndimage.gaussian_filter(mask.astype(np.float32), sigma)


class Painter:
    def __init__(self, area, seed):
        self.style, self.height = grid(area)
        self.H, self.W = self.style.shape
        self.h, self.w = self.H * TS, self.W * TS
        self.rng = np.random.default_rng(seed)
        self.img = np.zeros((self.h, self.w, 3), np.float32)
        self.solid = np.zeros((self.h, self.w), np.float32)  # Sprites never feather out.
        self.yy, self.xx = np.mgrid[0:self.h, 0:self.w]
        self.cy, self.cx = self.yy // TS, self.xx // TS
        self.hpx = self.height[self.cy, self.cx]
        self.spx = self.style[self.cy, self.cx]
        self.mat = np.asarray(Image.open(OUT_DIR / 'materials.png').convert('RGB'), np.float32)
        self.tiles = np.asarray(Image.open(ROOT / 'assets/game/snow/terrain/ground.png').convert('RGB'), np.float32)
        self.kinds = json.loads((ROOT / 'assets/game/snow/snow_terrain_index.json').read_text())['ground']['kinds']

    def S(self, *names):
        return np.isin(self.style, names)

    def material(self, index, mask, ox=0, oy=0, segment=0):
        """Sample a 160px material field; optional per-segment offset breaks repeats."""
        mx, my = (index % 4) * 160, (index // 4) * 160
        offx = ox
        if segment:
            seg = self.xx // segment
            offx = ox + (seg * 53) % 160
        u = (self.xx + offx) % 160 + mx
        v = (self.yy + oy) % 160 + my
        self.img[mask] = self.mat[v[mask], u[mask]]

    def regional(self, kind, mask):
        """Paint regional T1 tiles (weighted variants by cell hash) under a mask."""
        out = np.zeros_like(self.img)
        variants = self.kinds[kind]
        bag = [v for v in variants for _ in range(int(v[2]))]
        for cy in range(self.H):
            for cx in range(self.W):
                ys, xs = slice(cy * TS, cy * TS + TS), slice(cx * TS, cx * TS + TS)
                if not mask[ys, xs].any():
                    continue
                v = bag[(cx * 73856093 ^ cy * 19349663) % len(bag)]
                out[ys, xs] = self.tiles[v[1] * TS:(v[1] + 1) * TS, v[0] * TS:(v[0] + 1) * TS]
        self.img[mask] = out[mask]

    def height_of(self, cy, cx):
        if 0 <= cy < self.H and 0 <= cx < self.W:
            return self.height[cy, cx]
        return 0

    # --- layers ---------------------------------------------------------------
    def snow(self):
        """Open ground is the regional ground itself; higher terraces wear brighter snow."""
        self.regional('frozen', self.hpx == 0)
        self.regional('snow', self.hpx >= 1)

    def paths(self):
        """A packed-snow corridor over the trail cells with a narrow worn track
        following the corridor's centre line: no rectangles, rounded junctions."""
        r = self.rng
        cells = self.S('trail', 'ledge')
        corridor = np.zeros((self.h, self.w), np.float32)
        track = np.zeros((self.h, self.w), bool)
        wob = E.noise(r, self.h, self.w, 22) - 0.5
        q = 4  # Centre lines are traced at quarter resolution, then smoothed back up.
        for lvl in np.unique(self.height[cells]):
            joins = (cells | self.S('stairs', 'bridge', 'floor')) & (self.height == lvl)
            own = up(cells & (self.height == lvl))
            # Diagonal steps of one-cell roads merge into one continuous ribbon.
            small = up(joins)[::q, ::q]
            # Blur before thinning so cell staircases become smooth curves.
            body = (ndimage.gaussian_filter(small.astype(np.float32), 4.5) > 0.3) | ndimage.binary_closing(small, structure=np.ones((9, 9)))
            line = E.thin(body)
            line = np.kron(line.astype(np.uint8), np.ones((q, q), np.uint8)).astype(bool)[:self.h, :self.w]
            near = ndimage.distance_transform_edt(~line)
            reach = ndimage.binary_dilation(own, iterations=6)
            track |= reach & (near < 9 + wob * 9) & ~up(self.S('cliff', 'ravine', 'timber', 'rock', 'grove'))
            corridor = np.maximum(corridor, np.clip((22 + wob * 12 - near) / 12.0, 0, 1) * reach)
        self.path = track
        packed = self.img.copy()
        save = self.img
        self.img = packed
        self.regional('trail', corridor > 0)
        self.img = save
        a = (corridor * 0.9)[..., None]
        self.img[:] = self.img * (1 - a) + packed * a
        border = np.minimum.reduce([self.yy, self.xx, self.h - 1 - self.yy, self.w - 1 - self.xx])
        track &= border > TS * 2.2 + wob * 30
        td = ndimage.distance_transform_edt(track)
        t = 0.55 + (E.noise(r, self.h, self.w, 7) - 0.5) * 0.45 - np.clip(td / 10.0, 0, 1) * 0.15
        earth = E.ramp(E.EARTH, t)
        # Edges of the track dither into the packed snow instead of a hard line.
        mix = track & ((td > 2.2) | (E.BAYER[self.yy % 4, self.xx % 4] > -0.1 + (2.2 - td) * 0.2))
        self.img[mix] = earth[mix]
        frost = track & (E.noise(r, self.h, self.w, 6) > 0.74)
        self.img[frost] = self.img[frost] * 0.45 + E.SNOW[3] * 0.55
        ys, xs = np.nonzero(track & (td > 2))
        for i in r.choice(len(ys), size=min(len(ys), int(track.sum() / 420)), replace=False):
            rr = r.uniform(1.1, 2.3)
            E.stamp_stone(self.img, xs[i], ys[i], rr * r.uniform(1, 1.5), rr, E.ROCK[2:6], r, snow_cap=r.random() < 0.3)
        # Shallow rut shading on the north side of the track (the bank lifts there).
        outside = ~track
        sh = track & np.roll(outside, 2, 0)
        E.shade(self.img, sh, 0.8)

    def cliffs(self):
        r = self.rng
        cap_n = E.noise(r, self.h, self.w, 9)
        buttress = E.noise(r, self.h, self.w, 22)
        drip = E.noise(r, self.h, self.w, 3)
        rock = self.mat[:, 320:480]
        ly, lx = np.mgrid[0:TS, 0:TS]
        talus = []
        for cy, cx in zip(*np.nonzero(self.S('cliff'))):
            hgt = self.height[cy, cx]

            def low(dy, dx):
                y, x = cy + dy, cx + dx
                if not (0 <= y < self.H and 0 <= x < self.W):
                    return True
                return self.height[y, x] < hgt and not (self.style[y, x] == 'cliff' and self.height[y, x] == hgt)
            south, north, west, east = low(1, 0), low(-1, 0), low(0, -1), low(0, 1)
            ys, xs = slice(cy * TS, cy * TS + TS), slice(cx * TS, cx * TS + TS)
            reg = self.img[ys, xs]
            gx, gy = self.xx[ys, xs], self.yy[ys, xs]
            tex = rock[(gy + (gx // 120) * 61) % 160, (gx + (gx // 120) * 37) % 160]
            but = buttress[ys, xs]
            if south:
                cap = 4 + (cap_n[ys, xs][0] * 10).astype(int)
                face = ly >= cap[None, :]
                depth = (ly - cap[None, :]) / (TS - cap[None, :] + 1e-3)
                light = 1.0 - depth * 0.45 + (but - 0.5) * 0.5
                col = tex * light[..., None] * np.array([0.92, 0.96, 1.04])
                reg[face] = col[face]
                reg[face & (but < 0.3)] *= 0.72
                reg[face & (np.abs(but - 0.62) < 0.015)] = E.ROCK[1]
                reg[ly < cap[None, :]] = E.SNOW[5]
                reg[ly == cap[None, :] - 1] = E.SNOW[2]
                reg[ly == 0] = E.SNOW[6]
                ice = face & (ly < cap[None, :] + 2 + (drip[ys, xs] * 10).astype(int)) & (drip[ys, xs] > 0.8)
                reg[ice] = E.ICE[3]
                foot = TS - 2 - (E.noise(r, TS, TS, 7)[0] * 7).astype(int)
                drift = ly >= foot[None, :]
                reg[drift] = E.SNOW[3]
                reg[drift & (ly == foot[None, :])] = E.SNOW[5]
                if cy + 1 < self.H and self.style[cy + 1, cx] in WALK:
                    talus.append((cy, cx))
            elif north:
                edge = 2 + (cap_n[ys, xs][0] * 5).astype(int)
                reg[ly < edge[None, :]] = E.ROCK[2]
                reg[ly < edge[None, :] - 2] = E.ROCK[0]
                reg[ly == edge[None, :]] = E.SNOW[6]
                reg[ly == edge[None, :] + 1] = E.SNOW[5]
            if west or east:
                # A steep rocky flank: rock exposed toward the drop, snow streaks upslope.
                t = (lx if west else TS - 1 - lx) / TS
                t = t + (cap_n[ys, xs] - 0.5) * 0.5
                bare = t < 0.55
                lit = 1.08 if west else 0.66
                col = tex * (lit - (0.55 - t[..., None]) * 0.3)
                m = bare & ~((ly < 6) if south else np.zeros_like(bare))
                reg[m] = col[m]
                streak = m & (E.noise(r, TS, TS, 4) > 0.66)
                reg[streak] = reg[streak] * 0.3 + E.SNOW[4 if west else 2] * 0.7
                rim = (~bare) & (t < 0.62)
                reg[rim] = E.SNOW[6] if west else E.SNOW[3]
            self.img[ys, xs] = reg
        for cy, cx in talus:
            for k in range(int(r.integers(0, 3))):
                E.stamp_stone(self.img, cx * TS + r.uniform(4, 36), (cy + 1) * TS + r.uniform(2, 9), r.uniform(2, 4), r.uniform(1.5, 2.6), E.ROCK[1:6], r)
        # Occlusion on the lower ground beneath faces and beside the flanks.
        cl = self.S('cliff')
        below = np.zeros_like(cl)
        below[1:] = cl[:-1] & (self.height[1:] < self.height[:-1])
        east = np.zeros_like(cl)
        east[:, 1:] = cl[:, :-1] & (self.height[:, 1:] < self.height[:, :-1]) & ~cl[:, 1:]
        west = np.zeros_like(cl)
        west[:, :-1] = cl[:, 1:] & (self.height[:, :-1] < self.height[:, 1:]) & ~cl[:, :-1]
        fy, fx = self.yy % TS, self.xx % TS
        ao = soft(up(below) & (fy < 16), 6) * 0.5 + soft(up(east) & (fx < 18), 6) * 0.55 + soft(up(west) & (fx > 30), 4) * 0.2
        ao *= up(~self.S('cliff', 'timber', 'ravine'))
        ao = np.clip(ao, 0, 0.6)[..., None]
        self.img[:] = self.img * (1 - ao) + self.img * (E.SHADOW / 255.0) * ao

    def ravine(self):
        r = self.rng
        rav = self.S('ravine')
        walk = up(np.isin(self.style, list(WALK)) & ~self.S('bridge'))
        # Rounded water: corners soften into the banks, never into walkable ground.
        water = (soft(up(rav), 14) > 0.5) & ~walk
        banks = up(self.S('rock')) & ndimage.binary_dilation(up(rav), iterations=40)
        near_w = ndimage.distance_transform_edt(~water)
        # Rocky banks: bare stone close to the water, snow above, boulders at the edge.
        bare = banks & ~water & (near_w < 10 + E.noise(r, self.h, self.w, 7) * 16)
        hf = E.fbm(r, self.h, self.w, [24, 9], [0.6, 0.4])
        gy, gx = np.gradient(ndimage.gaussian_filter(hf, 1.5))
        light = np.clip(0.8 - (gx + gy) * 80 - np.clip(1 - near_w / 20.0, 0, 1) * 0.25, 0.35, 1.2)
        rk = self.mat[self.yy % 160, (self.xx % 160) + 320] * light[..., None]
        self.img[bare] = rk[bare]
        self.material(6, water, 7, 11)
        dist = ndimage.distance_transform_edt(water)
        self.img[water] *= (0.75 + np.clip(dist / 30.0, 0, 0.35))[water][:, None]
        # Ice shelves grow with the water's width: thin in the gorge, a sheet on the pool.
        width = ndimage.maximum_filter(dist, size=81)
        shelf = water & (dist < 3 + width * 0.3 + E.noise(r, self.h, self.w, 6) * 9)
        icecol = E.ramp(E.ICE, 0.55 + (E.noise(r, self.h, self.w, 5) - 0.5) * 0.6)
        self.img[shelf] = icecol[shelf]
        crack = shelf & (np.abs(E.noise(r, self.h, self.w, 11) - 0.5) < 0.02)
        self.img[crack] = E.ICE[1]
        edge = shelf & ~ndimage.binary_erosion(shelf) & (dist > 2)
        self.img[edge] = E.ICE[4]
        drop = water & ~shelf & np.roll(shelf, 1, 0)
        self.img[drop] = E.WATER[0]
        # A frozen cascade on the cliff face wherever the gorge begins beneath it.
        for cy, cx in zip(*np.nonzero(self.S('cliff'))):
            if cy + 1 < self.H and (rav[cy + 1, cx] or (cy + 2 < self.H and rav[cy + 2, cx] and self.style[cy + 1, cx] == 'rock')):
                ys, xs = slice(cy * TS, cy * TS + TS), slice(cx * TS, cx * TS + TS)
                ly = self.yy[ys, xs] - cy * TS
                lx = self.xx[ys, xs] - cx * TS
                n = E.noise(r, TS, TS, 4)
                falls = (ly > 5) & ((np.abs((lx + cx * 7) % 13 - 6) < 2 + n * 3) | (n > 0.72))
                col = E.ramp(E.ICE, 0.45 + ly / TS * 0.45 + (n - 0.5) * 0.3, dither=False)
                reg = self.img[ys, xs]
                reg[falls] = col[falls]
                self.img[ys, xs] = reg
                # Spray ice frozen where the falls meet the water.
                foot = (self.yy >= (cy + 1) * TS) & (self.yy < (cy + 1) * TS + 10) & (self.xx >= cx * TS) & (self.xx < cx * TS + TS) & water
                self.img[foot] = E.ICE[4]
        # Boulders along the waterline, a few snow-capped.
        ys, xs = np.nonzero(bare & (near_w > 2) & (near_w < 7))
        for i in r.choice(len(ys), size=min(len(ys), int(bare.sum() / 380)), replace=False):
            rr = r.uniform(3.5, 7)
            E.stamp_stone(self.img, xs[i], ys[i], rr * 1.2, rr * 0.8, E.ROCK[1:6], r, snow_cap=r.random() < 0.45)

    def bridge(self):
        r = self.rng
        cells = self.S('bridge')
        ys, xs = np.nonzero(cells)
        y0, y1 = ys.min() * TS + 4, (ys.max() + 1) * TS - 2
        x0, x1 = xs.min() * TS - 6, (xs.max() + 1) * TS + 6
        # Shadow cast on the water and banks south of the deck.
        sh = (self.yy >= y1) & (self.yy < y1 + 12) & (self.xx >= x0 + 4) & (self.xx < x1 + 4)
        E.shade(self.img, sh, 0.62)
        deck = (self.yy >= y0) & (self.yy < y1) & (self.xx >= x0) & (self.xx < x1)
        self.material(7, deck, 3, 5)
        boards = deck & (((self.xx - x0) % 9) == 0)
        self.img[boards] *= 0.7
        wear = deck & (np.abs(self.yy - (y0 + y1) / 2) < 14) & (E.noise(r, self.h, self.w, 5) > 0.55)
        self.img[wear] *= 1.08
        dust = deck & (E.noise(r, self.h, self.w, 6) > 0.8)
        self.img[dust] = E.SNOW[4]
        # Side beams (deck thickness) and rails with posts and snow caps.
        beam = (self.yy >= y1) & (self.yy < y1 + 6) & (self.xx >= x0) & (self.xx < x1)
        self.img[beam] = E.WOOD[1]
        for ry in (y0 - 1, y1 - 7):
            rail = (self.yy >= ry) & (self.yy < ry + 5) & (self.xx >= x0 - 2) & (self.xx < x1 + 2)
            self.img[rail] = E.WOOD[3]
            self.img[rail & (self.yy == ry)] = E.SNOW[5]
            self.img[rail & (self.yy == ry + 4)] = E.WOOD[1]
            for px in range(x0, x1 + 1, 33):
                post = (self.yy >= ry - 5) & (self.yy < ry + 7) & (self.xx >= px - 3) & (self.xx < px + 3)
                self.img[post] = E.WOOD[2]
                self.img[post & (self.xx == px - 3)] = E.WOOD[4]
                self.img[post & (self.yy < ry - 3)] = E.SNOW[6]

    def stairs(self):
        """Broad stone steps cut into the slope, cheek walls capped with snow."""
        r = self.rng
        for group in self._groups(self.S('stairs')):
            ys, xs = zip(*group)
            y0, y1 = min(ys) * TS, (max(ys) + 1) * TS
            x0, x1 = min(xs) * TS + 4, (max(xs) + 1) * TS - 4
            area = (self.yy >= y0) & (self.yy < y1) & (self.xx >= x0) & (self.xx < x1)
            ly = self.yy - y0
            n = max(4, (y1 - y0) // 14)
            step = (y1 - y0) / n
            k = ly / step
            frac = k - np.floor(k)
            stone = self.mat[(self.yy % 160) + 160, (self.xx % 160) + 160]
            tread = stone * 0.5 + E.ROCK[5] * 0.5
            self.img[area] = tread[area]
            riser = area & (frac > 0.66)
            self.img[riser] = (stone * 0.35 + E.ROCK[1] * 0.65)[riser]
            nose = area & (frac < 0.09)
            self.img[nose] = E.ROCK[6]
            dust = area & (frac < 0.6) & (E.noise(r, self.h, self.w, 4) > 0.7)
            self.img[dust] = E.SNOW[5]
            # Cheek walls: lit on the west, shaded on the east, snow on each block.
            for side, cx0, cx1, col in ((0, x0 - 6, x0, E.ROCK[4]), (1, x1, x1 + 6, E.ROCK[2])):
                cheek = (self.yy >= y0 - 4) & (self.yy < y1) & (self.xx >= cx0) & (self.xx < cx1)
                self.img[cheek] = col
                self.img[cheek & (self.xx == (cx0 if side == 0 else cx1 - 1))] = E.ROCK[1]
                self.img[cheek & (self.yy < y0 + 1)] = E.SNOW[6]
                self.img[cheek & (np.abs(frac - 0.05) < 0.06)] = E.SNOW[4]

    def ledge(self):
        """One-way drops: a low rounded lip, clearly shorter than a cliff."""
        cells = self.S('ledge')
        for cy, cx in zip(*np.nonzero(cells)):
            if self.height_of(cy + 1, cx) >= self.height[cy, cx]:
                continue
            y0 = (cy + 1) * TS - 12
            x0 = cx * TS
            area = (self.yy >= y0) & (self.yy < y0 + 12) & (self.xx >= x0) & (self.xx < x0 + TS)
            ly = self.yy - y0
            self.img[area] = (self.mat[(self.yy % 160), (self.xx % 160) + 320] * (1.0 - ly[..., None] / 24.0))[area]
            self.img[area & (ly < 3)] = E.SNOW[6]
            self.img[area & (ly == 3)] = E.SNOW[3]
            for k in range(3):
                E.stamp_stone(self.img, x0 + 8 + k * 12, y0 + 16, 3.5, 2.2, E.ROCK[2:6], self.rng)

    def outpost(self):
        r = self.rng
        floor = self.S('floor')
        fm = up(floor)
        self.material(3, fm, 0, 0)
        row = self.yy // 10
        shift = (row * 37) % 160
        u = (self.xx + shift) % 160 + 480
        self.img[fm] = self.mat[(self.yy % 160)[fm], u[fm]] * 0.86
        seams = fm & ((self.yy % 10) == 0)
        self.img[seams] *= 0.7
        # Blown-in snow at the doors; warm worn centre.
        doors = floor & ~ndimage.binary_erosion(floor | self.S('timber'), border_value=0) & ~self.S('timber')
        dsoft = soft(up(floor & (self.height >= 0)) & False, 1)
        for cy, cx in zip(*np.nonzero(floor)):
            n = [self.style[cy + dy, cx + dx] if 0 <= cy + dy < self.H and 0 <= cx + dx < self.W else 'snow' for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1))]
            if any(v in ('terrace', 'trail', 'snow') for v in n):
                ys, xs = slice(cy * TS, cy * TS + TS), slice(cx * TS, cx * TS + TS)
                blown = E.noise(r, TS, TS, 5) > 0.45
                self.img[ys, xs][blown] = self.img[ys, xs][blown] * 0.4 + E.SNOW[4] * 0.6
        walls = self.S('timber')
        for cy, cx in zip(*np.nonzero(walls)):
            ys, xs = slice(cy * TS, cy * TS + TS), slice(cx * TS, cx * TS + TS)
            ly, lx = np.mgrid[0:TS, 0:TS]
            reg = self.img[ys, xs]
            inside_s = 0 <= cy + 1 < self.H and floor[cy + 1, cx]
            inside_n = cy > 0 and floor[cy - 1, cx]
            inside_e = cx + 1 < self.W and floor[cy, cx + 1]
            inside_w = cx > 0 and floor[cy, cx - 1]
            logs = self.mat[(ly + cy * TS) % 160, (lx + cx * TS) % 160 + 480]
            if inside_s:
                # North wall: its inner face is what we see. Eave, logs, a shuttered window.
                face = logs * (0.78 - (TS - ly[..., None]) / TS * 0.18)
                reg[:] = face
                reg[(ly % 8) == 0] *= 0.6
                reg[ly < 7] = E.ROCK[2]
                reg[ly < 4] = E.SNOW[5]
                reg[ly == 7] = E.WOOD[0]
                if cx % 3 == 1:
                    win = (lx >= 12) & (lx < 28) & (ly >= 14) & (ly < 28)
                    reg[win] = E.WOOD[0]
                    reg[win & ((lx == 12) | (lx == 27) | (ly == 14) | (ly == 27) | (lx == 20))] = E.WOOD[3]
                reg[ly >= TS - 3] = E.WOOD[0]
            elif inside_n:
                # South wall seen from outside: snowy wall top, then a granite footing face.
                stone = self.mat[(ly + cy * 11) % 160 + 160, (lx + cx * TS) % 160 + 160]
                reg[:] = stone * (1.0 - ly[..., None] / TS * 0.35)
                reg[ly < 14] = logs[ly < 14] * 0.9
                reg[ly < 5] = E.SNOW[6]
                reg[ly == 5] = E.SNOW[3]
                reg[ly == 14] = E.WOOD[0]
            else:
                # Side walls from above: a snow-capped log top over a stone footing.
                stone = self.mat[(ly + cy * 11) % 160 + 160, (lx + cx * 17) % 160 + 160]
                reg[:] = stone * 0.85
                top = (lx >= 10) & (lx < 30)
                reg[top] = logs[top] * 0.95
                reg[top & ((lx == 10) | (lx == 29))] = E.WOOD[0]
                cap = (lx >= 13) & (lx < 27) & (E.noise(r, TS, TS, 6) > 0.35)
                reg[cap] = E.SNOW[5]
                if inside_e:
                    reg[lx >= 30] = reg[lx >= 30] * 0.6
                if inside_w:
                    reg[lx < 10] = reg[lx < 10] * 0.6
            # Corner posts.
            corner = (not inside_s and not inside_n and (cy + 1 < self.H and walls[cy + 1, cx]) != (cy > 0 and walls[cy - 1, cx]))
            if corner or (inside_s and (cx > 0 and not walls[cy, cx - 1] or cx + 1 < self.W and not walls[cy, cx + 1])):
                post = (lx >= 12) & (lx < 28)
                reg[post] = E.WOOD[2]
                reg[post & (lx == 12)] = E.WOOD[4]
                reg[post & (ly < 6)] = E.SNOW[6]
            self.img[ys, xs] = reg
        # Interior shadow under the north wall and the house's shadow to the south-east.
        under = up(floor) & (self.yy % TS < 12) & up(np.roll(walls, 1, 0))
        E.shade(self.img, under, 0.72)
        south_shadow = up(np.roll(walls, 1, 0) & ~walls & ~floor) & (self.yy % TS < 9)
        E.shade(self.img, south_shadow, 0.8)

    def vegetation(self, skip=()):
        """Pines and boulders from the accepted props sheet, grounded with shadows."""
        props = np.asarray(Image.open(ROOT / 'assets/game/snow/props.png').convert('RGBA'), np.float32)
        r = self.rng
        yy, xx = np.ogrid[0:self.h, 0:self.w]
        for kind, sx in (('grove', 0), ('rock', 96)):
            cells = self.S(kind) & ~ndimage.binary_dilation(self.S('ravine'), iterations=1, structure=np.ones((3, 3)))
            for cy, cx in sorted(zip(*np.nonzero(cells))):
                if (cx, cy) in skip:
                    continue
                fx, fy = cx * TS + TS // 2, cy * TS + TS // 2 + int(TS * 0.32)
                # Cool shadow pooled to the lower right, under the sprite's own base.
                sh = ((xx - fx - 10) / (22.0 if kind == 'grove' else 16.0)) ** 2 + ((yy - fy + 4) / 7.0) ** 2 <= 1
                E.shade(self.img, sh, 0.84)
                sprite = props[:, sx:sx + 96]
                if r.random() < 0.5:
                    sprite = sprite[:, ::-1]
                self._paste(sprite, fx - 48, fy - 84)

    def _paste(self, rgba, x0, y0):
        h, w = rgba.shape[:2]
        ys, xs = max(0, -y0), max(0, -x0)
        ye, xe = min(h, self.h - y0), min(w, self.w - x0)
        if ye <= ys or xe <= xs:
            return
        src = rgba[ys:ye, xs:xe]
        a = (src[..., 3:4] / 255.0)
        solid = self.solid[y0 + ys:y0 + ye, x0 + xs:x0 + xe]
        solid[:] = np.maximum(solid, a[..., 0])
        dst = self.img[y0 + ys:y0 + ye, x0 + xs:x0 + xe]
        dst[:] = dst * (1 - a) + src[..., :3] * a

    def _groups(self, mask):
        lab, n = ndimage.label(mask)
        return [list(zip(*np.nonzero(lab == i))) for i in range(1, n + 1)]

    def edge_alpha(self, margin):
        """Feather the outer border so the area melts into the surrounding land."""
        d = np.minimum.reduce([self.yy, self.xx, self.h - 1 - self.yy, self.w - 1 - self.xx]).astype(np.float32)
        n = E.noise(self.rng, self.h, self.w, 30) * margin * 0.6
        a = np.clip((d - n) / (margin * 0.6), 0, 1)
        keep = soft(up(~self.S('snow', 'grove', 'rock', 'trail') & ~(self.S('cliff') & (self.height >= 3))), 20)
        return np.clip(np.maximum(np.maximum(a, keep * 2.0), self.solid), 0, 1)

    def massif(self):
        """Mountain mass above every walkable level: the regional cliff-top tiles."""
        m = up(self.S('cliff') & (self.height >= 3))
        if m.any():
            self.regional('cliff', m)

    def decals(self, items):
        """Small authored stories on open ground: no collision implied."""
        r = self.rng
        for kind, (cx, cy) in items:
            fx, fy = cx * TS + TS // 2, cy * TS + TS // 2
            if kind == 'firepit':
                yy, xx = np.ogrid[0:self.h, 0:self.w]
                trodden = ((xx - fx) / 40.0) ** 2 + ((yy - fy) / 28.0) ** 2 <= 1
                self.img[trodden & (E.noise(r, self.h, self.w, 5) > 0.35)] *= 0.93
                ash = ((xx - fx) / 9.0) ** 2 + ((yy - fy) / 6.0) ** 2 <= 1
                self.img[ash] = E.ROCK[1]
                self.img[ash & (E.noise(r, self.h, self.w, 2) > 0.6)] = E.ROCK[0]
                for k in range(9):
                    a = k / 9 * 2 * np.pi
                    E.stamp_stone(self.img, fx + np.cos(a) * 12, fy + np.sin(a) * 8, 3, 2.2, E.ROCK[2:6], r)
                for dx, dy, ln in ((-26, -6, 22), (14, 14, 18)):
                    y0, x0 = fy + dy, fx + dx
                    self.img[y0:y0 + 5, x0:x0 + ln] = E.WOOD[2]
                    self.img[y0, x0:x0 + ln] = E.SNOW[5]
                    self.img[y0 + 4, x0:x0 + ln] = E.WOOD[0]
                    self.img[y0:y0 + 5, x0 + ln - 2:x0 + ln] = E.WOOD[4]
            elif kind == 'mast':
                # The relay's signal mast, snapped: stump, splintered top, fallen arm.
                bx = fx - 4
                self.img[fy - 4:fy + 4, fx - 14:fx + 18] *= 0.82
                self.img[fy - 46:fy + 6, bx:bx + 9] = E.WOOD[2]
                self.img[fy - 46:fy + 6, bx:bx + 2] = E.WOOD[4]
                self.img[fy - 46:fy + 6, bx + 7:bx + 9] = E.WOOD[0]
                for i, h in enumerate((5, 9, 3, 7, 2, 6, 4, 8, 3)):
                    self.img[fy - 46 - h:fy - 46, bx + i] = E.WOOD[3 if i < 4 else 1]
                for k in range(26):
                    y, x = fy + 2 - k // 3, fx + 6 + k
                    self.img[y:y + 4, x:x + 2] = E.WOOD[2]
                    self.img[y, x:x + 2] = E.SNOW[5]
                for k in range(14):
                    self.img[fy - 30 + k, bx + 9 + k // 2] = E.ROCK[1]
                self.img[fy - 30:fy - 24, bx - 6:bx + 15] = E.WOOD[1]
                self.img[fy - 30, bx - 6:bx + 15] = E.SNOW[6]

    def paint(self, decals=()):
        self.snow()
        self.massif()
        self.cliffs()
        self.paths()
        self.ravine()
        self.bridge()
        self.stairs()
        self.ledge()
        self.outpost()
        self.decals(decals)
        self.vegetation(skip={c for _, c in decals})
        rgb = np.clip(self.img, 0, 255).astype(np.uint8)
        alpha = (self.edge_alpha(TS * 2.0) * 255).astype(np.uint8)
        return np.dstack([rgb, alpha])


def main():
    layout = json.loads(LAYOUT.read_text(encoding='utf-8'))
    area = layout['reference_area']
    key = '%s_v%d' % (layout['id'].split('/')[-1], int(layout['version']))
    seed = int(hashlib.sha256(key.encode()).hexdigest()[:8], 16)
    # Authored stories: the cutthroats' roadside fire, the relay's snapped mast.
    out = Painter(area, seed).paint(decals=[('firepit', (2, 8)), ('mast', (37, 7))])
    path = OUT_DIR / ('%s_ground.png' % key)
    Image.fromarray(out, 'RGBA').save(path, optimize=True)
    print('Composed', path.relative_to(ROOT), out.shape[1], 'x', out.shape[0])
    if '--preview' in sys.argv:
        Image.fromarray(out[..., :3]).save(sys.argv[sys.argv.index('--preview') + 1])


if __name__ == '__main__':
    main()
