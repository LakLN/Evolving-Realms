"""Author Broken Relay geometry for reference layout v9 (spatial layout v1 schema).

The area is designed here as a character map and compiled into run-length zones in
content/land_layouts/snow_mountain_reference.json. Anchors used by content/tests
(stairs, ledge, outpost, lookout, strongbox, bridge, sites) keep v8 coordinates;
everything around them is reshaped. v8 Worlds keep their stored v8 plans.

    .venv/Scripts/python.exe tools/relay_layout_v9.py [--check]
"""
import json, sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LAYOUT = ROOT / 'content/land_layouts/snow_mountain_reference.json'
W, H = 48, 40

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
}

#        0         1         2         3         4
#        012345678901234567890123456789012345678901234567
MAP = """
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

TRANSITIONS = [
    {'a': [15, 21], 'b': [15, 22]}, {'a': [16, 21], 'b': [16, 22]},
    {'a': [34, 8], 'b': [34, 9]}, {'a': [35, 8], 'b': [35, 9]},
    {'a': [32, 22], 'b': [32, 23], 'one_way': True}, {'a': [33, 22], 'b': [33, 23], 'one_way': True},
]
WALKABLE = {'snowfield', 'trail', 'floor'}


def rows():
    lines = [l for l in MAP.strip('\n').split('\n')]
    assert len(lines) == H, 'map has %d rows' % len(lines)
    for i, l in enumerate(lines):
        assert len(l) == W, 'row %d has %d columns' % (i, len(l))
        assert all(c in LEGEND for c in l), 'row %d has an unknown glyph' % i
    return lines


def zones(lines):
    out = [{'rect': [0, 0, W, H], 'height': 0, 'surface': 'snowfield', 'style': 'snow'}]
    for y, line in enumerate(lines):
        x = 0
        while x < W:
            c = line[x]
            e = x
            while e + 1 < W and line[e + 1] == c:
                e += 1
            if c != '.':
                style, height, surface = LEGEND[c]
                out.append({'rect': [x, y, e - x + 1, 1], 'height': height, 'surface': surface, 'style': style})
            x = e + 1
    return out


def reach(lines, start):
    cell = lambda x, y: LEGEND[lines[y][x]]
    edges = {}
    for t in TRANSITIONS:
        a, b = tuple(t['a']), tuple(t['b'])
        edges.setdefault(a, set()).add(b)
        if not t.get('one_way'):
            edges.setdefault(b, set()).add(a)
    seen, todo = {start}, deque([start])
    while todo:
        x, y = todo.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if not (0 <= n[0] < W and 0 <= n[1] < H) or n in seen or cell(*n)[2] not in WALKABLE:
                continue
            if cell(*n)[1] != cell(x, y)[1] and n not in edges.get((x, y), ()):
                continue
            seen.add(n)
            todo.append(n)
    return seen


def check(lines):
    must = {'north road': (7, 0), 'south road': (12, 39), 'outpost floor': (22, 14), 'east door': (27, 13),
            'court': (22, 17), 'lookout': (34, 6), 'strongbox': (35, 5), 'bridge': (24, 32), 'ledge landing': (32, 23),
            'stash': (1, 6), 'cutthroat': (4, 31), 'slinger': (5, 34), 'terrace slinger': (18, 20), 'east low': (40, 30)}
    # Every walkable height change must be a visible edge (cliff) or an authored connector.
    pairs = {(tuple(t['a']), tuple(t['b'])) for t in TRANSITIONS} | {(tuple(t['b']), tuple(t['a'])) for t in TRANSITIONS}
    for y in range(H):
        for x in range(W):
            a = LEGEND[lines[y][x]]
            for dx, dy in ((1, 0), (0, 1)):
                if x + dx >= W or y + dy >= H:
                    continue
                b = LEGEND[lines[y + dy][x + dx]]
                if a[2] in WALKABLE and b[2] in WALKABLE and a[1] != b[1]:
                    assert ((x, y), (x + dx, y + dy)) in pairs, 'unmarked height edge at %s' % ((x, y),)
    got = reach(lines, (7, 0))
    bad = [k for k, v in must.items() if v not in got]
    assert not bad, 'unreachable: %s' % bad
    assert LEGEND[lines[28][25]][2] == 'water' and LEGEND[lines[22][15]][1] == 0 and LEGEND[lines[21][15]][1] == 1
    assert LEGEND[lines[22][33]][0] == 'ledge' and LEGEND[lines[23][32]][1] == 0
    # The ledge really is one-way: the terrace is not reachable from below except by the stairs.
    below = reach(lines, (32, 23))
    assert (22, 17) in below  # by the bridge, the west road and the main stairs
    # Every border cell is low walkable ground or massif, matching the land outside.
    for x in range(W):
        for y in (0, H - 1):
            assert LEGEND[lines[y][x]][1] in (0, 3), (x, y)
    for y in range(H):
        for x in (0, W - 1):
            assert LEGEND[lines[y][x]][1] in (0, 3), (x, y)
    return len(got)


def main():
    lines = rows()
    n = check(lines)
    if '--check' in sys.argv:
        print('v9 geometry ok, %d reachable cells' % n)
        return
    text = LAYOUT.read_text(encoding='utf-8')
    layout = json.loads(text)
    area = layout['reference_area']
    area['zones'] = zones(lines)
    area['transitions'] = TRANSITIONS
    layout['version'] = 9
    layout['notes'] = ('Reference terrain v3 / atlas plan v3 / layout v9. Broken Relay is composed with discrete '
                       'height levels and authored connectors; v9 reshapes the v8 geometry around unchanged anchors '
                       'and joins the north and south roads. Old v4-v8 plans and terrain v1/v2 are never changed. '
                       'Geometry source: tools/relay_layout_v9.py.')
    LAYOUT.write_text(json.dumps(layout, indent=2, ensure_ascii=False) + '\n', encoding='utf-8', newline='\r\n' if '\r\n' in text else '\n')
    print('Wrote layout v9: %d zones, %d reachable cells' % (len(area['zones']), n))


if __name__ == '__main__':
    main()
