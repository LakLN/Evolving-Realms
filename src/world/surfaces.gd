extends RefCounted
## Tile vocabulary shared by terrain v1 (values 0..5, frozen) and atlas terrain (M04).
## A tile value is a surface (walkable ground), a blocker or an impassable surface.
## Values 6/7 are the fallback palette's fog cells and are never terrain.
const FOREST := 0
const BEACH := 1
const MEADOW := 2
const WATER := 3
const TREE := 4
const ROCK := 5
const SNOW := 8
const TAIGA := 9
const PINE := 10
const ICE := 11
const ASH := 12
const CINDER := 13
const LAVA := 14
const BASALT := 15
const VEIL := 16
const ROAD := 17
const BY_NAME := {"forest": FOREST, "beach": BEACH, "meadow": MEADOW, "water": WATER, "tree": TREE, "rock": ROCK,
	"snowfield": SNOW, "taiga": TAIGA, "pine": PINE, "ice": ICE, "ashland": ASH, "cinder": CINDER, "lava": LAVA,
	"basalt": BASALT, "veil": VEIL, "road": ROAD}
const WALKABLE := [FOREST, BEACH, MEADOW, SNOW, TAIGA, ICE, ASH, CINDER, ROAD]
const OPAQUE := [TREE, ROCK, PINE, BASALT]
## Habitat names content may declare in spawn/movement biomes. The first three are the
## frozen v1 biomes; the rest only occur in atlas lands.
const HABITATS := ["forest", "beach", "meadow", "snowfield", "taiga", "ashland"]
## Surfaces where objects, creatures and places may be placed (never ice, cinder, roads).
const HABITAT_OF := {FOREST: "forest", BEACH: "beach", MEADOW: "meadow", SNOW: "snowfield", TAIGA: "taiga", ASH: "ashland"}
## Presentation kind (art ground set) per value; blockers draw on their land's ground.
const ART_KIND := {FOREST: "forest", BEACH: "beach", MEADOW: "meadow", WATER: "ocean", TREE: "forest", SNOW: "snow",
	TAIGA: "taiga", PINE: "taiga", ICE: "ice", ASH: "ash", CINDER: "cinder", LAVA: "lava", BASALT: "ash", VEIL: "veil", ROAD: "road"}
const NAME_OF := {FOREST: "forest", BEACH: "beach", MEADOW: "meadow", WATER: "ocean", TREE: "forest", ROCK: "rock",
	SNOW: "snowfield", TAIGA: "taiga", PINE: "taiga", ICE: "ice", ASH: "ashland", CINDER: "cinder", LAVA: "lava",
	BASALT: "ashland", VEIL: "veil", ROAD: "road"}

static func walkable(value: int) -> bool:
	return value in WALKABLE

static func opaque(value: int) -> bool:
	return value in OPAQUE

static func spawnable(value: int) -> bool:
	return HABITAT_OF.has(value)

static func hosts(terrain: RefCounted, value: int, point: Vector2i, content_id: String, biomes: Array) -> bool:
	## Whether content with these declared biomes may live on this tile. Atlas lands may
	## also host adapted content their ecology lists; terrain v1 is the plain biome test.
	if not HABITAT_OF.has(value):
		return false
	if HABITAT_OF[value] in biomes:
		return true
	return terrain.has_method("ecology_hosts") and terrain.ecology_hosts(value, point, content_id)
