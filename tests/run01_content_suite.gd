extends SceneTree
## Run 01 content pack: applied through the real authoring pipeline into one World,
## then every content kind is exercised in an actual session (spawns, places, talents,
## books, skills, gear, item uses, random place outcomes, save/resume).
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const ContentPack = preload("res://src/content/content_pack.gd")
const Packs = preload("res://src/content/starter_pack.gd")
const Data = preload("res://src/data/json_data.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const Ledger = preload("res://src/world/region_ledger.gd")
const Inventory = preload("res://src/core/inventory.gd")
const Events = preload("res://src/core/world_events.gd")
const Talents = preload("res://src/core/talents.gd")
const Acceptance = preload("res://src/acceptance/standalone_check.gd")
const PACK := "res://content/ai_packs/run01"
const NS := "ai:run01/"
var checks := 0
var failures := 0
var store := Store.new()
var world: Dictionary

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)

func _run() -> void:
	var path := ProjectSettings.globalize_path("user://run01_tests/%s.sqlite" % Data.uuid())
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	check(store.open(path), "Open isolated database")
	world = store.create_world("Run 01 laboratory", 1847, 1, Packs.blueprint(1847))
	var packs := ContentPack.new()
	var pack := packs.load_pack(PACK)
	check(not pack.is_empty() and pack.modules.size() == 5, "Load the Run 01 pack manifest: " + packs.last_error)
	check(packs.status(store, world.world_id, pack).all(func(m: Dictionary) -> bool: return m.stage == "absent"), "A World without the pack has none of it (never auto-installed)")
	var applied := packs.apply(store, world.world_id, pack)
	check(not applied.has("error") and applied.modules.all(func(m: Dictionary) -> bool: return m.stage == "activated" and m.validation == "valid"), "Every module validates and activates through draft/confirm/activate: " + str(applied.get("error", "")))
	var count := store.content.list_definitions(world.world_id).size()
	check(not packs.apply(store, world.world_id, pack).has("error") and store.content.list_definitions(world.world_id).size() == count, "Applying the pack again is a no-op")
	var other: Dictionary = store.create_world("Untouched", 99, 1, Packs.blueprint(99))
	check(store.content.list_definitions(other.world_id).all(func(h: Dictionary) -> bool: return not str(h.content_id).begins_with(NS)), "Other Worlds stay without Run 01 content")

	Session.auto_awaken = false
	var a := Session.new(store)
	check(a.start_new(world.world_id, 501, "forest"), "A Run starts with the pack active (uses, loot, talents, statuses load): " + a.last_error)
	a.autosave_interval = 0
	_distribution(a)
	_talents(a)
	_loot(a)
	_skills_and_gear(a)
	_places(a)
	_chance_rolls()
	var run_id: String = a.run.run_id
	check(a.save(), "Save the Run with learned skills, gear and resolved places")
	var snapshot: Dictionary = a.run.state.duplicate(true)
	var b := Session.new(store)
	var resumed := b.resume(run_id)
	var differing: Array = []
	if resumed:
		for field in snapshot:
			if not Acceptance.same(b.run.state.get(field), snapshot[field]): differing.append(field)
		for field in snapshot.get("character", {}):
			if not Acceptance.same(b.run.state.character.get(field), snapshot.character[field]): differing.append("character." + field)
	check(resumed and differing.is_empty(), "Resume restores the exact Run state " + str(differing) + " " + b.last_error)
	store.close()
	print("RUN01 CONTENT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _distribution(a: RefCounted) -> void:
	## Creatures and places of the pack occur in fresh regions (scan, never establishes).
	var ledger: RefCounted = a.locations.ledger
	var home := Terrain.chunk_of(a.position)
	var species := {}
	var places := {}
	for dy in range(-9, 10):
		for dx in range(-9, 10):
			var chunk := home + Vector2i(dx, dy)
			var bytes: PackedByteArray = a.terrain.generate_chunk(chunk)
			for creature in a.roster.layer.preview_chunk(chunk, ledger.revision, bytes):
				species[creature.content_id] = true
			for place in a.locations.preview_chunk(chunk, ledger.revision, Ledger.LAYERS, bytes):
				places[place.content_id] = place
	for id in ["mossback_boar", "dusk_wolf", "thornhare", "glimmer_stag", "tidecaller_crab", "mire_lurker"]:
		check(species.has(NS + id), "Creature appears in new regions: " + id)
	for id in ["whispering_well", "moon_altar", "hunters_camp", "spore_ring", "rune_circle", "pearl_grotto"]:
		check(places.has(NS + "place/" + id), "Place appears in new regions: " + id)
	a.set_meta("places", places)

func _talents(a: RefCounted) -> void:
	var pool: Array = a.talent_catalog.pool
	var ids := pool.map(func(d: Dictionary) -> String: return d.content_id)
	var mine := ["pathfinder", "magpie", "quarry_sense", "tidebound", "mossheart", "stormblood", "ember_soul"].map(func(n: String) -> String: return NS + "talent/" + n)
	check(mine.all(func(id: String) -> bool: return id in ids), "All Run 01 talents are supported and in the awakening pool")
	var seen := {}
	for i in 4000:
		var context := {"mode": "normal", "spawn_biome": ["forest", "meadow", "beach"][i % 3]}
		for definition in a.talent_rules.awaken(pool, context, [], "run01-test/%d" % i):
			seen[definition.content_id] = true
	check(mine.all(func(id: String) -> bool: return seen.has(id)), "Every Run 01 talent can actually awaken: missing " + str(mine.filter(func(id: String) -> bool: return not seen.has(id))))
	var record: Dictionary = a.talent_rules.record(a.talent_definition(NS + "talent/mossheart", 1), 0, int(a.run.state.turn))
	var defense := int(a.combat_stats().defense)
	a.run.state.character.talents = [record]
	a.reload_talents()
	check(int(a.combat_stats().defense) == defense + 2, "Mossheart passive applies (+2 defense)")
	a.run.state.character.talents = []
	a.reload_talents()

func _loot(a: RefCounted) -> void:
	var counts := {}
	for source in ["dusk_wolf", "thornhare", "tidecaller_crab", "glimmer_stag"]:
		var definition: Dictionary = a._definition(NS + source, 1)
		for i in 300:
			for drop in a.loot_for(definition, "run01-loot/%s/%d" % [source, i]):
				counts[drop.content_id] = int(counts.get(drop.content_id, 0)) + 1
	for id in ["dusk_fang", "book/predators_instinct", "duskfang_blade", "hare_foot", "tide_pearl", "book/tidal_lash", "tideshell_helm", "glimmer_antler", "antler_sling"]:
		check(int(counts.get(NS + id, 0)) > 0, "Creature loot can drop " + id)
	var chest_books := 0
	for i in 300:
		for drop in a.loot_for(a._definition("core:weathered_chest", 1), "run01-chest/%d" % i):
			chest_books += 1 if str(drop.content_id).begins_with(NS + "book/") else 0
	check(chest_books > 40 and chest_books < 200, "Weathered chests sometimes hold Run 01 manuals (%d/300)" % chest_books)

func _give(a: RefCounted, id: String, quantity: int = 1) -> void:
	var award: Dictionary = Inventory.new().award(store.content, world.world_id, a.run.state.inventory, [{"content_id": id, "version": 1, "quantity": quantity}], "test:%s/%d" % [id, Time.get_ticks_usec()])
	a.run.state.inventory = award.inventory

func _has_status(actor: Dictionary, id: String) -> bool:
	return actor.get("statuses", []).any(func(s: Dictionary) -> bool: return s.get("id") == id)

func _skills_and_gear(a: RefCounted) -> void:
	# Gear: each piece equips through the normal slot/quality path.
	for id in ["mossback_mantle", "tideshell_helm", "lurkerhide_boots", "harefoot_charm", "duskfang_blade"]:
		_give(a, NS + id)
		var instance_id: String = a.run.state.inventory[NS + id].instances[0].instance_id
		if id == "duskfang_blade": a.gain_xp(200) # Level requirement 2.
		check(a.equip_item(NS + id, instance_id), "Equip " + id + ": " + a.last_error)
	check(int(a.combat_stats().defense) >= 6, "Gear raises defense (%d)" % int(a.combat_stats().defense))
	# Books: learn every skill through the normal book action (prerequisites respected).
	for id in ["hunters_mark", "verdant_pulse", "stoneskin", "windrunner", "tidal_lash"]:
		_give(a, NS + "book/" + id)
	_give(a, NS + "book/predators_instinct")
	check(not a.perform_action({"type": "learn", "content_id": NS + "book/predators_instinct"}), "Predator's Instinct needs Hunter's Mark first")
	for id in ["hunters_mark", "predators_instinct", "verdant_pulse", "stoneskin", "windrunner", "tidal_lash"]:
		check(a.perform_action({"type": "learn", "content_id": NS + "book/" + id}), "Learn " + id + ": " + a.last_error)
	_give(a, "core:book/swift_step")
	a.perform_action({"type": "learn", "content_id": "core:book/swift_step"})
	var step: Dictionary = a.skill_definition("core:skill/swift_step", 1)
	check(a.skills.reach(a, step) == int(step.payload.use.target.range) + 1 and int(a.skills.costs(a, step).energy) < int(step.payload.use.cost.energy), "Windrunner and the harefoot charm extend and cheapen movement skills")
	# Active skills on a creature: mark lowers defense, the instinct adds damage.
	var foe := _adjacent_foe(a)
	if foe.is_empty():
		check(false, "Place a creature next to the hero")
		return
	var real_max: int = foe.max_hp
	foe.hp = 999
	foe.max_hp = 999 # Test-only headroom; restored below (saves reject impossible HP).
	_refill(a)
	a.perform_action({"type": "attack", "target_id": foe.instance_id})
	var plain := 999 - int(foe.hp)
	foe.hp = 999
	var defense := int(a.roster.creature_stats(a, foe).defense)
	_refill(a)
	check(a.perform_action({"type": "skill", "skill_id": NS + "skill/hunters_mark", "target_id": foe.instance_id}) and _has_status(foe, NS + "status/marked") and int(a.roster.creature_stats(a, foe).defense) == defense - 2, "Hunter's Mark marks the creature (-2 defense)")
	foe.hp = 999
	a.perform_action({"type": "attack", "target_id": foe.instance_id})
	check(999 - int(foe.hp) > plain, "Marked prey takes more damage (%d > %d)" % [999 - int(foe.hp), plain])
	_refill(a)
	foe.hp = 999
	check(a.perform_action({"type": "skill", "skill_id": NS + "skill/tidal_lash", "target_id": foe.instance_id}) and int(foe.hp) < 999 and _has_status(foe, "core:status/slow"), "Tidal Lash strikes at range and slows")
	foe.max_hp = real_max
	foe.hp = real_max
	# Self skills.
	_refill(a)
	a.statuses.apply(a, {"content_id": "core:status/poison", "version": 1}, {"content_id": "test", "version": 1, "actor": "player"}, "player")
	a.stats().hp = 5
	check(a.perform_action({"type": "skill", "skill_id": NS + "skill/verdant_pulse"}) and int(a.stats().hp) > 5 and not _has_status(a.run.state.character, "core:status/poison"), "Verdant Pulse heals and purges poison")
	_refill(a)
	var guard := int(a.combat_stats().defense)
	check(a.perform_action({"type": "skill", "skill_id": NS + "skill/stoneskin"}) and int(a.combat_stats().defense) == guard + 4, "Stoneskin: +4 defense")
	# Item uses for creature trophies.
	_give(a, NS + "tide_pearl")
	check(a.use_item(NS + "tide_pearl") and _has_status(a.run.state.character, "core:status/ward"), "Swallowing a tide pearl grants ward")
	a.statuses.apply(a, {"content_id": "core:status/poison", "version": 1}, {"content_id": "test", "version": 1, "actor": "player"}, "player")
	_give(a, NS + "lurker_gland")
	check(a.use_item(NS + "lurker_gland") and not _has_status(a.run.state.character, "core:status/poison"), "A lurker gland cures poison")

func _refill(a: RefCounted) -> void:
	a.run.state.character.resources.energy.value = 99
	a.run.state.character.cooldowns = {}
	for key in a.run.state.character.get("skill_cooldowns", {}).keys(): a.run.state.character.skill_cooldowns.erase(key)

func _adjacent_foe(a: RefCounted) -> Dictionary:
	for creature in a.roster.creatures.values():
		if creature.dead or creature.definition.payload.disposition == "passive": continue
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var tile: Vector2i = a.position + direction
			if a.terrain.walkable(tile) and a.visible.has(tile) and a.roster.living_at(tile).is_empty():
				creature.position = tile
				return creature
	return {}

func _places(a: RefCounted) -> void:
	var places: Dictionary = a.get_meta("places")
	a.gain_xp(400) # Level 3+: the rune circle's sight condition.
	for id in ["whispering_well", "moon_altar", "hunters_camp", "spore_ring", "rune_circle", "pearl_grotto"]:
		var place: Dictionary = places.get(NS + "place/" + id, {})
		if place.is_empty(): continue
		var tile := Vector2i(int(place.position.x), int(place.position.y))
		var spot := _near(a, tile)
		a.relocate(spot)
		var instance: Dictionary = a.locations.find(place.instance_id)
		a.stats().hp = int(a.combat_stats().max_hp)
		match id:
			"whispering_well":
				_give(a, "core:coin", 3)
				a.wait_turn()
				check(a.interact(place.instance_id) and _outcome(a), "Whispering well: coins in, a random answer: " + a.last_error)
				check(a.places.state(a, instance) == "unavailable", "The well's other offering is forfeited (exclusive)")
			"moon_altar":
				a.wait_turn()
				check(a.interact(place.instance_id) and _outcome(a), "Moonlit altar: pray or bleed: " + a.last_error)
			"hunters_camp":
				a.wait_turn()
				check(not a.places.discovered(a, place.instance_id), "The hunters' camp is only found by searching")
				a.search()
				check(a.places.discovered(a, place.instance_id) and a.interact(place.instance_id), "Searching finds the camp; searching it pays: " + a.last_error)
				check(not a.interact(place.instance_id) and a.last_error.contains("needs"), "The ledger trade needs mossback hides")
				_give(a, NS + "mossback_hide", 2)
				check(a.interact(place.instance_id) and a.run.state.inventory.has(NS + "book/predators_instinct") and a.places.state(a, instance) == "resolved", "Trading two hides at the ledger completes the camp")
			"spore_ring":
				a.relocate(spot)
				a.try_move(tile - spot) if absi(tile.x - spot.x) + absi(tile.y - spot.y) == 1 else a.relocate(tile)
				if a.position != tile: a.relocate(tile); a.wait_turn()
				check(a.places.state(a, instance) == "resolved", "Stepping into the spore ring fires its random event once")
			"rune_circle":
				_give(a, NS + "glimmer_antler")
				a.wait_turn()
				check(a.places.discovered(a, place.instance_id) and a.interact(place.instance_id) and not a.run.state.inventory.has(NS + "glimmer_antler"), "Rune circle reveals itself at level 3 and consumes an antler shard: " + a.last_error)
			"pearl_grotto":
				a.wait_turn()
				check(a.interact(place.instance_id) and _outcome(a), "Pearl grotto: a dive with a random result: " + a.last_error)

func _outcome(a: RefCounted) -> bool:
	return a.last_events.any(func(e: Dictionary) -> bool: return e.type == "location")

func _near(a: RefCounted, tile: Vector2i) -> Vector2i:
	for d in range(1, 6):
		for dx in range(-d, d + 1):
			for sign in [1, -1]:
				var candidate := tile + Vector2i(dx, sign * (d - absi(dx)))
				if a.terrain.walkable(candidate) and a.line_clear(candidate, tile) and a.roster.living_at(candidate).is_empty():
					return candidate
	return tile

func _chance_rolls() -> void:
	## The chance outcome: fixed for one key (Run/place), varied across keys, near its odds.
	var outcomes := [{"type": "chance", "chance_per_10000": 3000, "outcomes": [{"type": "xp", "amount": 1}], "otherwise": [{"type": "heal", "amount": 1}], "message": "yes", "otherwise_message": "no"}]
	var hits := 0
	for i in 2000:
		var resolved: Dictionary = Events.effective(outcomes, "chance-test/%d" % i)
		hits += 1 if resolved.outcomes[0].type == "xp" else 0
	check(hits > 480 and hits < 720, "Chance branch follows its odds (%d/2000 at 30%%)" % hits)
	check(JSON.stringify(Events.effective(outcomes, "fixed")) == JSON.stringify(Events.effective(outcomes, "fixed")), "Chance branch is deterministic for one Run and place")
	var nested := {"payload": {"outcomes": [{"type": "chance", "chance_per_10000": 5000, "outcomes": [{"type": "chance", "chance_per_10000": 10, "outcomes": [{"type": "xp", "amount": 1}]}]}]}, "dependencies": []}
	var verdict := Events.classify(nested, store.content, world.world_id, {"stats": ["max_hp", "attack", "defense"], "needs": ["hunger", "thirst"], "slots": []}, null)
	check(verdict.problem.is_empty() and "event.outcome.chance.nested" in verdict.missing, "Nested chance is a named pending capability, never executed")
