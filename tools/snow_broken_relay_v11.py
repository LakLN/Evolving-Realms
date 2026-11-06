"""Author and validate the isolated Broken Relay v11 spatial layout.

This writes a new layout package; it never edits the established v10 source.
The character grid is an authoring notation for gameplay geometry, not artwork.
"""
import json
from pathlib import Path

from snow_composed_layout import Area, Grid, LEGEND

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "content/land_layouts/snow_mountain_reference.json"
TARGET = ROOT / "content/land_layouts/snow_mountain_reference_v11.json"


def authored_grid():
    g = Grid("\n".join(["." * 48 for _ in range(40)]))

    # Irregular north-east massif and the high pass shelf (height 2).
    for y in range(0, 18):
        left = [34, 33, 32, 31, 30, 30, 29, 29, 29, 30, 30, 31, 31, 32, 33, 34, 35, 37][y]
        for x in range(left, 48):
            g.set(x, y, "M" if x >= 46 or y < 2 else ("%" if x == left or y == 17 else ":"))
    # A two-cell stair cuts through the high-shelf rim.
    for x in (34, 35):
        g.set(x, 16, "U")
        g.set(x, 17, "S")

    # Raised, deliberately contoured relay terrace (height 1).
    spans = {9:(18,29), 10:(15,34), 11:(13,37), 12:(12,38), 13:(11,39),
             14:(11,40), 15:(10,40), 16:(10,40), 17:(11,40), 18:(11,39),
             19:(12,38), 20:(13,37), 21:(14,36)}
    for y, (left, right) in spans.items():
        for x in range(left, right + 1):
            g.set(x, y, "#" if x in (left, right) or y == 21 else ",")
    # Main ascent, aligned to the lower shelf, and directed return drop.
    for x in (16, 17):
        g.set(x, 21, "S")
        g.set(x, 22, "s")
    for x in (32, 33):
        g.set(x, 21, "L")
        g.set(x, 22, "=")

    # Outpost is foundation/facade plus a genuinely walkable interior and south door.
    for y in range(11, 17):
        for x in range(18, 30):
            g.set(x, y, "T" if x in (18, 29) or y in (11, 16) else "f")
    for x in (23, 24):
        g.set(x, 16, "-")
    # Courtyard circulation, fire/supply negative space retained around it.
    g.road([(16, 20), (20, 18), (24, 18), (29, 19), (34, 18)], "-", 2)
    g.road([(24, 16), (24, 19)], "-", 2)

    # Organic gorge. Its banks vary by row; the bridge is the only crossing here.
    for y in range(24, 40):
        left = 21 + (1 if y in (25, 29, 35) else 0) - (1 if y in (27, 36, 37) else 0)
        right = 29 + (1 if y in (26, 34, 38) else 0) - (1 if y in (30, 31) else 0)
        for x in range(left, right + 1):
            g.set(x, y, "~")
        g.set(left - 1, y, "o")
        g.set(right + 1, y, "o")
    for x in range(20, 31):
        g.set(x, 32, "B")

    # South forest approach -> bridge -> lower shelf -> stairs; upper pass continues east.
    g.road([(43, 39), (42, 36), (37, 34), (31, 32)], "=", 2)
    g.road([(19, 32), (16, 29), (15, 25), (16, 22)], "=", 2)
    g.road([(34, 17), (38, 14), (42, 10), (45, 6)], "_", 2)
    # Optional western cache/vantage branch.
    g.road([(16, 27), (11, 26), (7, 23)], "=", 2)

    # Deterministic scenic clusters, outside mandatory route cells.
    for x, y in [(3,28),(5,31),(8,34),(11,36),(15,35),(38,29),(41,27),(44,24),(5,18),(7,20)]:
        if g.get(x, y) == ".": g.set(x, y, "^")
    for x, y in [(9,25),(12,29),(18,27),(33,28),(36,25),(40,22),(8,12)]:
        if g.get(x, y) == ".": g.set(x, y, "o")
    return g


TRANSITIONS = [
    {"a":[16,21], "b":[16,22]}, {"a":[17,21], "b":[17,22]},
    {"a":[34,16], "b":[34,17]}, {"a":[35,16], "b":[35,17]},
    {"a":[32,21], "b":[32,22], "one_way":True},
    {"a":[33,21], "b":[33,22], "one_way":True},
]


def build():
    grid = authored_grid()
    area = Area("broken_relay_v11", grid.lines(), TRANSITIONS, (43, 39), {
        "south entrance":(43,39), "bridge":(25,32), "main stair":(16,22),
        "courtyard":(24,18), "door":(24,16), "locker":(22,14),
        "strongbox":(28,18), "stash":(8,23), "upper pass":(44,7),
        "drop top":(32,21), "drop landing":(32,22),
    })
    reachable = area.check()
    assert (32,21) not in area.reach((32,22)), "one-way drop is climbable"
    assert (32,22) in area.reach((32,21)), "one-way drop cannot descend"
    return area, reachable


def main():
    area, reachable = build()
    layout = json.loads(SOURCE.read_text(encoding="utf-8"))
    layout["version"] = 11
    layout["notes"] = ("Isolated Broken Relay v11 preview. New authored geometry; v10 remains in "
                       "snow_mountain_reference.json. Windcut composed area is copied unchanged.")
    layout["reference_area"]["zones"] = area.zones()
    layout["reference_area"]["transitions"] = TRANSITIONS
    layout["reference_area"]["shelter"] = {"id":"relay_outpost", "rect":[18,11,12,6], "doors":[[23,16],[24,16]]}
    layout["reference_area"]["layer_contract"] = ["ground_opaque", "cliff_grounded", "world_facade_and_props", "actors_sorted_by_feet", "roof_only_and_rail_occluders", "weather_fog", "hud"]
    anchors = {"relay_locker":[22,14], "relay_strongbox":[28,18], "bandit_stash":[8,23]}
    for site in layout["sites"]:
        if site["id"] in anchors:
            site.pop("at", None); site.pop("shelter", None)
            site["spatial"] = anchors[site["id"]]
    homes = {"ambush_0":[38,34], "ambush_1":[15,27], "outpost_perch":[34,15],
             "relay_0":[20,19], "relay_1":[29,19], "relay_2":[35,18]}
    for home in layout["creature_homes"]:
        if home["id"] in homes:
            home.pop("at", None); home["spatial"] = homes[home["id"]]
    TARGET.write_text(json.dumps(layout, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote Broken Relay v11: {len(area.zones())} zones, {reachable} reachable cells")


if __name__ == "__main__":
    main()
