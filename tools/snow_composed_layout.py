"""Author the composed Snow areas of reference layout v10 (spatial layout v1 schema).

Each area is designed as a character map plus explicit sculpting steps and compiled
into run-length zones in content/land_layouts/snow_mountain_reference.json:
- Broken Relay (the reference patch): v9 geometry around unchanged anchors, plus a
  palisade rampart gated at the main stairs, a storage lean-to and a woodpile.
- Windcut Stair (composed area 'windcut'): seeded from the real surrounding terrain,
  then sculpted into a wind-cut defile with a north ledge shelf, a high eyrie and a
  south rime ledge. Roads enter and leave at ground level where the land's roads are.
v8/v9 Worlds keep their stored plans. Rebuild the art afterwards (tools/art).

    .venv/Scripts/python.exe tools/snow_composed_layout.py [--check [--print]]
"""
import json, sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LAYOUT = ROOT / 'content/land_layouts/snow_mountain_reference.json'

# char -> (style, height, surface)
LEGEND = {
    '.': ('snow', 0, 'snowfield'), ',': ('terrace', 1, 'snowfield'), ':': ('terrace', 2, 'snowfield'),
    '#': ('cliff', 1, 'cliff'), '%': ('cliff', 2, 'cliff'), 'M': ('cliff', 3, 'cliff'),
    '=': ('trail', 0, 'trail'), '-': ('trail', 1, 'trail'), '_': ('trail', 2, 'trail'),
    's': ('stairs', 0, 'trail'), 'S': ('stairs', 1, 'trail'), 'U': ('stairs', 2, 'trail'),
    'L': ('ledge', 1, 'trail'), '~': ('ravine', 0, 'water'), 'B': ('bridge', 0, 'trail'),
    'o': ('rock', 0, 'rock'), 'O': ('rock', 1, 'rock'), 'Q': ('rock', 2, 'rock'),
    '^': ('grove', 0, 'pine'), 'A': ('grove', 1, 'pine'), 'a': ('grove', 2, 'pine'),
    'T': ('timber', 1, 'timber'), 'f': ('floor', 1, 'floor'),
    'X': ('timber', 0, 'timber'), 'x': ('floor', 0, 'floor'),
    'P': ('palisade', 1, 'timber'), 'H': ('shed', 1, 'timber'), 'W': ('woodpile', 1, 'timber'),
}

#        0         1         2         3         4
#        012345678901234567890123456789012345678901234567
RELAY_MAP = """
.......==.............................MMMMMMMMMM
.......==............................MMMMMMMMMMM
...^....=.......................%%%%%%MMMMMMMMMM
.o......==.....................%%:a::%MMMMMMMMMM
........==.....###############%::::::%MMMMMMMMMM
..o.....=....##,,,,,,,,,,,,,,,%:::::::QMMMMMMMMM
.......==...#,,,A,,,,,,,,,,,,,%::::::::MMMMMMMMM
...^...=...#,,AA,,,,,,,,,,,,,,%%::UU:QMMMMMMMMMM
.......=..#,,,,A,,,,,,,,,,,,,,,%::UU::%MMMMMMMM.
..^...==..#,,,O,,,,,,,,,,,,,,,,%%%SS%%%%,MMMMMM.
......=...#,,,,,,,TTTTTTTTTT,,,,,,SS,,,,,,MMMMM.
.^...==...#,,,,,,,TffffffffT,,,,,,SS,,,,,,,MMMM.
.....=....#,,A,,,,TffffffffT,,,,,,--,,,,,O,,MM..
....==.....#,,,,,,Tfffffffff-------,,,,,,,,,#...
.^..=......#,,,,,,TffffffffT,,,,,,-,,,,A,,,,#...
^...=.......#,,,,,TffffffffT,,,,,,-,,,AA,,,,#...
....=..^....#,,,,,TTTT--TTTT,,,,,,-,,,,A,,,#....
^..==.......#,,,,,,,,,--,,,,,,,,,,-,,,,,,,,#....
...=....^...#,,,------------,,,,,,--,,,,,,,#.^..
..==........#,,--,,,,,,,,,,----------,,,,,,#....
.^=..........#,SS,,,,,,,,,,,,,,,,--,,,,,,##..o..
..=......^...#,SS,,,,,,,######,,LL,,,,,,#.......
..==.........##ss#######o~~~oo##LL#######....^..
^..==..........ss......oo~~~o...==..........^...
....==........====.....o~~~o....==..............
.^...==......==.......oo~~~o.....=.........^....
......==....==........o~~~o......=............^.
.......===.==..........o~~~o.....=.......o......
.^.......====..........o~~~o.....==...........^.
..........==...........o~~~o......=.............
..........==..........oo~~~oo....==.......^.....
..........=============BBBBB======.......^.^....
..........==...........BBBBB.............^......
...........=..........oo~~~~o..........^...^....
.^.........=.........oo~~~~~~o..................
...........==.......o~~~~~~~~~o.......^.........
..^.........=......o~~~~~~~~~~~o................
............=.......o~~~~~~~~~o..............^..
...^........==.......oo~~~~~oo..........^.......
............==..................................
"""

RELAY_TRANSITIONS = [
    {'a': [15, 21], 'b': [15, 22]}, {'a': [16, 21], 'b': [16, 22]},
    {'a': [34, 8], 'b': [34, 9]}, {'a': [35, 8], 'b': [35, 9]},
    {'a': [32, 22], 'b': [32, 23], 'one_way': True}, {'a': [33, 22], 'b': [33, 23], 'one_way': True},
]
WALKABLE = {'snowfield', 'trail', 'floor'}

# The land around Windcut Stair as generated (walls 'M', roads '='), 64x44; local
# (30, 30) is the Ledge hut anchor.
WINDCUT_BASE = """
....MMMMMM........==............................................
......MMMM........==............................................
..................==............................................
...................=...............MM...........................
...................=.........MMMMMMMMMMMMMMMMMM.................
..................==........MMMMMMMMMMMMMMMMMMMMMMMMMM..........
..................==........MMMMMMMMMMMMMMMMMMMMMMMMMMMMMM......
..................==........MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM....
..................==.........MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM.
..................=............MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
.................==..............MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
.................==.................MMMMMMMMMMMMMMMMMMMMMMMMMMMM
.................==.....................MMMMMMMMMMMMMMMMMMMMMMMM
.................==.........................MMMMMMMMMMMMMMMMMMM.
.................==..................................MMM........
.................=..............................................
................==..............................................
................==..............................................
................==..............................................
................==..............................................
.........===========================...........................=
================...=======================================...===
=======..................................======================.
................................................................
................................................................
................................................................
................................................................
................................................................
................................................................
................................................................
................................................................
................................................................
................................................................
...............................................................M
...........................................................MMMMM
........................................................MMMMMMMM
..............................................MMMMMMMMMMMMMMMMMM
.........................................MMMMMMMMMMMMMMMMMMMMMMM
.......................................MMMMMMMMMMMMMMMMMMMMMMMMM
....................................MMMMMMMMMMMMMMMMMMMMMMMMMMM.
...............................MMMMMMMMMMMMMMMMMMMMMMMMMMMMM....
...................MM...MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM.........
.............MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM............
........MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM..............
"""


class Grid:
    def __init__(self, text):
        self.cells = [list(l) for l in text.strip('\n').split('\n')]
        self.h, self.w = len(self.cells), len(self.cells[0])

    def get(self, x, y):
        return self.cells[y][x]

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.cells[y][x] = c

    def fill(self, x0, y0, x1, y1, c, only=None):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if only is None or self.get(x, y) in only:
                    self.set(x, y, c)

    def road(self, points, c='=', width=2):
        """A road `width` cells wide along straight segments between points."""
        for (ax, ay), (bx, by) in zip(points, points[1:]):
            n = max(abs(bx - ax), abs(by - ay), 1)
            for i in range(n + 1):
                x, y = round(ax + (bx - ax) * i / n), round(ay + (by - ay) * i / n)
                for k in range(width):
                    if abs(bx - ax) >= abs(by - ay):
                        self.set(x, y + k, c)
                    else:
                        self.set(x + k, y, c)

    def lines(self):
        return [''.join(r) for r in self.cells]


def relay_lines():
    g = Grid(RELAY_MAP)
    # A palisade rampart along the terrace's south edge, gated at the main stairs.
    for x in [14] + list(range(17, 24)) + [30, 31] + list(range(34, 40)):
        assert g.get(x, 21) == ',', (x, g.get(x, 21))
        g.set(x, 21, 'P')
    g.fill(16, 11, 17, 14, 'H', only=',')  # Storage lean-to against the west wall.
    g.set(28, 15, 'W')
    g.set(29, 15, 'W')  # Firewood stacked by the east door.
    return g.lines()


WINDCUT_TRANSITIONS = [
    {'a': [30, 16], 'b': [30, 17]}, {'a': [31, 16], 'b': [31, 17]},  # shelf stair
    {'a': [24, 10], 'b': [24, 11]}, {'a': [25, 10], 'b': [25, 11]},  # eyrie stair
    {'a': [35, 32], 'b': [35, 33]}, {'a': [36, 32], 'b': [36, 33]},  # rime-ledge stair
    {'a': [42, 16], 'b': [42, 17], 'one_way': True}, {'a': [43, 16], 'b': [43, 17], 'one_way': True},  # shelf drop
]


def windcut_lines():
    g = Grid(WINDCUT_BASE)
    for y in range(g.h):
        for x in range(g.w):
            if g.get(x, y) in '=^':
                g.set(x, y, '.')
    # Rock spurs pinch the corridor into the wind-cut defile toward the pass.
    import math
    for x in range(46, 61):
        for y in range(13, 16 + round(1.2 * math.sin(x * 0.55) + 0.6 * math.sin(x * 1.7))):
            g.set(x, y, 'M')
        for y in range(25 + round(1.1 * math.sin(x * 0.45 + 1) + 0.5 * math.sin(x * 1.3)), 34):
            g.set(x, y, 'M')
    g.fill(29, 9, 35, 11, 'M', only='.')  # Rock fills the cleft between the eyrie and the wall.
    # North ledge shelf (h1) under the wall, and the high eyrie (h2) at its west end.
    for x in range(20, 45):
        bottom = 16 if x < 24 or x > 40 else 17
        for y in range(12, bottom + 1):
            if g.get(x, y) != 'M':
                g.set(x, y, ',')
    for x in range(21, 29):
        for y in range(5, 12):
            if g.get(x, y) != 'M':
                g.set(x, y, ':')
    # South rime ledge (h1) at the foot of the south wall.
    for x in range(32, 41):
        for y in range(33, 38):
            if g.get(x, y) != 'M':
                g.set(x, y, ',')
    # Stairs and the one-way drop; their cells are exempt from the rings below.
    stairs = {}
    for x in (30, 31):
        stairs.update({(x, 15): 'S', (x, 16): 'S', (x, 17): 's', (x, 18): 's'})
    for x in (24, 25):
        stairs.update({(x, 9): 'U', (x, 10): 'U', (x, 11): 'S', (x, 12): 'S'})
    for x in (35, 36):
        stairs.update({(x, 31): 's', (x, 32): 's', (x, 33): 'S', (x, 34): 'S'})
    for x in (42, 43):
        stairs.update({(x, 15): 'L', (x, 16): 'L'})
    for (x, y), c in stairs.items():
        g.set(x, y, c)
    # Rings: a walkable cell above lower walkable ground becomes its level's cliff.
    pairs = {(tuple(t['a']), tuple(t['b'])) for t in WINDCUT_TRANSITIONS}
    pairs |= {(b, a) for a, b in pairs}
    cliff = {1: '#', 2: '%'}
    walk = lambda c: LEGEND[c][2] in WALKABLE
    changed = True
    while changed:
        changed = False
        for y in range(g.h):
            for x in range(g.w):
                c = g.get(x, y)
                if not walk(c) or LEGEND[c][1] == 0 or (x, y) in stairs:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < g.w and 0 <= ny < g.h and walk(g.get(nx, ny)) and LEGEND[g.get(nx, ny)][1] < LEGEND[c][1] and ((x, y), (nx, ny)) not in pairs:
                        g.set(x, y, cliff[LEGEND[c][1]])
                        changed = True
                        break
    # Roads at ground level: from the relay (north), the west shore, east to the pass.
    g.road([(18, 0), (18, 6), (17, 12), (17, 18), (18, 20)])
    g.road([(0, 21), (8, 22), (15, 21), (18, 20)])
    g.road([(18, 20), (26, 20), (31, 19), (38, 19), (44, 20), (49, 21), (54, 20), (58, 19), (63, 20)])
    g.road([(42, 17), (42, 18)])
    g.road([(26, 21), (27, 23), (28, 25)])
    g.road([(30, 19), (30, 18)])
    g.road([(35, 29), (35, 31)])
    g.road([(36, 21), (36, 28)])
    # The Ledge hut: a stone-footed waystation with its door toward the road.
    g.fill(28, 26, 31, 29, 'X')
    g.fill(29, 27, 30, 28, 'x')
    g.set(29, 26, 'x')
    # Talus at the wall feet, ruin stones at the old kiln, wind-bent pines in the lee.
    for x, y in [(47, 17), (48, 17), (51, 17), (56, 17), (57, 17), (47, 24), (52, 24), (53, 24), (58, 24), (45, 18),
                 (9, 3), (10, 4), (12, 3), (19, 13), (21, 17), (33, 35), (39, 33), (40, 34), (44, 30), (45, 31),
                 (4, 27), (8, 27), (9, 28), (5, 34), (9, 33), (2, 29)]:
        if g.get(x, y) == '.':
            g.set(x, y, 'o')
    for x, y in [(10, 9), (12, 10), (11, 12), (14, 8), (13, 14), (9, 15), (15, 11), (12, 17), (22, 14), (40, 13),
                 (11, 34), (13, 36), (12, 38), (15, 35), (22, 38), (25, 40), (3, 39), (6, 41), (55, 37), (40, 27), (42, 26)]:
        if g.get(x, y) in '.,':
            g.set(x, y, '^' if g.get(x, y) == '.' else 'A')
    return g.lines()


class Area:
    def __init__(self, name, lines, transitions, start, must):
        self.name, self.lines, self.transitions, self.start, self.must = name, lines, transitions, start, must
        self.h, self.w = len(lines), len(lines[0])
        for i, l in enumerate(lines):
            assert len(l) == self.w and all(c in LEGEND for c in l), '%s row %d malformed' % (name, i)

    def cell(self, x, y):
        return LEGEND[self.lines[y][x]]

    def reach(self, start):
        edges = {}
        for t in self.transitions:
            a, b = tuple(t['a']), tuple(t['b'])
            edges.setdefault(a, set()).add(b)
            if not t.get('one_way'):
                edges.setdefault(b, set()).add(a)
        seen, todo = {start}, deque([start])
        while todo:
            x, y = todo.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if not (0 <= n[0] < self.w and 0 <= n[1] < self.h) or n in seen or self.cell(*n)[2] not in WALKABLE:
                    continue
                if self.cell(*n)[1] != self.cell(x, y)[1] and n not in edges.get((x, y), ()):
                    continue
                seen.add(n)
                todo.append(n)
        return seen

    def check(self):
        # Every walkable height change is a visible edge (cliff) or an authored connector.
        pairs = {(tuple(t['a']), tuple(t['b'])) for t in self.transitions} | {(tuple(t['b']), tuple(t['a'])) for t in self.transitions}
        for y in range(self.h):
            for x in range(self.w):
                a = self.cell(x, y)
                for dx, dy in ((1, 0), (0, 1)):
                    if x + dx >= self.w or y + dy >= self.h:
                        continue
                    b = self.cell(x + dx, y + dy)
                    if a[2] in WALKABLE and b[2] in WALKABLE and a[1] != b[1]:
                        assert ((x, y), (x + dx, y + dy)) in pairs, '%s: unmarked height edge at %s' % (self.name, (x, y))
        got = self.reach(self.start)
        bad = [k for k, v in self.must.items() if v not in got]
        assert not bad, '%s unreachable: %s' % (self.name, bad)
        # Border cells are low ground or massif, matching the land outside.
        for x in range(self.w):
            for y in (0, self.h - 1):
                assert self.cell(x, y)[1] in (0, 3), (self.name, x, y)
        for y in range(self.h):
            for x in (0, self.w - 1):
                assert self.cell(x, y)[1] in (0, 3), (self.name, x, y)
        return len(got)

    def zones(self):
        out = [{'rect': [0, 0, self.w, self.h], 'height': 0, 'surface': 'snowfield', 'style': 'snow'}]
        for y, line in enumerate(self.lines):
            x = 0
            while x < self.w:
                c = line[x]
                e = x
                while e + 1 < self.w and line[e + 1] == c:
                    e += 1
                if c != '.':
                    style, height, surface = LEGEND[c]
                    out.append({'rect': [x, y, e - x + 1, 1], 'height': height, 'surface': surface, 'style': style})
                x = e + 1
        return out


def relay():
    a = Area('relay', relay_lines(), RELAY_TRANSITIONS, (7, 0),
             {'north road': (7, 0), 'south road': (12, 39), 'outpost floor': (22, 14), 'east door': (27, 13),
              'court': (22, 17), 'lookout': (34, 6), 'strongbox': (35, 5), 'bridge': (24, 32), 'ledge landing': (32, 23),
              'stash': (1, 6), 'cutthroat': (4, 31), 'slinger': (5, 34), 'terrace slinger': (18, 20), 'east low': (40, 30)})
    n = a.check()
    l = a.lines
    assert LEGEND[l[28][25]][2] == 'water' and LEGEND[l[22][15]][1] == 0 and LEGEND[l[21][15]][1] == 1
    assert LEGEND[l[22][33]][0] == 'ledge' and LEGEND[l[23][32]][1] == 0
    assert (22, 17) in a.reach((32, 23))  # back up by the bridge, the west road and the main stairs
    return a, n


def windcut():
    a = Area('windcut', windcut_lines(), WINDCUT_TRANSITIONS, (18, 0),
             {'north road': (18, 0), 'west road': (0, 21), 'east road': (63, 20), 'hut floor': (29, 27), 'shelf': (35, 14),
              'eyrie': (26, 7), 'rime ledge': (38, 35), 'kiln': (6, 30), 'acolyte': (3, 30), 'kiln slinger': (3, 33),
              'road slinger': (21, 19), 'road slinger 2': (21, 22), 'drop landing': (42, 18), 'drake': (23, 7)})
    n = a.check()
    assert a.cell(26, 7)[1] == 2 and a.cell(38, 35)[1] == 1 and a.cell(35, 14)[1] == 1
    # The shelf drop is one-way: from its landing the shelf is reached only by the stair.
    assert (42, 15) in a.reach((42, 18)) and a.cell(42, 16)[0] == 'ledge'
    return a, n


WINDCUT_SITES = {'ashmaw_nest': [26, 7], 'rime_ledge': [38, 35]}
WINDCUT_HOMES = {'nest_drake': [23, 7], 'stair_0': [21, 19], 'stair_1': [21, 22]}


def main():
    areas = [relay(), windcut()]
    if '--check' in sys.argv:
        for a, n in areas:
            print('%s geometry ok, %d reachable cells' % (a.name, n))
        if '--print' in sys.argv:
            for i, line in enumerate(areas[1][0].lines):
                print('%2d %s' % (i, line))
        return
    text = LAYOUT.read_text(encoding='utf-8')
    layout = json.loads(text)
    (r, _), (w, _) = areas
    layout['reference_area']['zones'] = r.zones()
    layout['reference_area']['transitions'] = r.transitions
    hut = next(s for s in layout['shelters'] if s['id'] == 'stair_hut')
    layout['composed_areas'] = [{'id': 'windcut', 'version': 1, 'anchor': hut['at'], 'offset': [30, 30],
                                 'size': {'x': w.w, 'y': w.h}, 'zones': w.zones(), 'transitions': w.transitions,
                                 'shelter': {'id': 'stair_hut', 'rect': [28, 26, 4, 4], 'doors': [[29, 26]]}}]
    for site in layout['sites']:
        if site['id'] in WINDCUT_SITES:
            site['spatial'], site['patch'] = WINDCUT_SITES[site['id']], 'windcut'
    for home in layout['creature_homes']:
        if home['id'] in WINDCUT_HOMES:
            home['spatial'], home['patch'] = WINDCUT_HOMES[home['id']], 'windcut'
            home.pop('at', None)
    layout['version'] = 10
    layout['notes'] = ('Reference terrain v3 / atlas plan v3 / layout v10. Broken Relay and Windcut Stair are composed '
                       'areas with discrete height levels and authored connectors (Windcut as composed_areas[windcut]). '
                       'Old v4-v9 plans and terrain v1/v2 are never changed. Geometry source: tools/snow_composed_layout.py.')
    LAYOUT.write_text(json.dumps(layout, indent=2, ensure_ascii=False) + '\n', encoding='utf-8', newline='\r\n' if '\r\n' in text else '\n')
    print('Wrote layout v10: relay %d zones, windcut %d zones' % (len(r.zones()), len(w.zones())))


if __name__ == '__main__':
    main()
