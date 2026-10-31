extends SceneTree
## Milestone 02 Checkpoint E: skill definitions, books, learning, resources, active /
## passive / triggered skills, targeting, talent and gear interplay, persistence.
## Talents stay ON (real awakening); tests that need a known talent set one explicitly.
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Data = preload("res://src/data/json_data.gd")
const Pack = preload("res://src/content/starter_pack.gd")
const Combat = preload("res://src/core/combat.gd")
const Inventory = preload("res://src/core/inventory.gd")
const Terrain = preload("res://src/world/terrain_v1.gd")
const Acceptance = preload("res://src/acceptance/standalone_check.gd")
const Helpers = preload("res://tests/interaction_helpers.gd")
const SKILLS := ["core:skill/power_strike", "core:skill/stone_throw", "core:skill/mend", "core:skill/iron_guard", "core:skill/binding", "core:skill/swift_step", "core:skill/body_tempering", "core:skill/opening_strike", "core:skill/blood_rite"]
var checks := 0
var failures := 0
var directory := ""

func _initialize() -> void:
	directory = ProjectSettings.globalize_path("user://m02e_tests/" + Data.uuid())
	DirAccess.make_dir_recursive_absolute(directory)
	print("Skill artifacts: ", directory)
	_test_catalog()
	_test_learning()
	_test_active_skills()
	_test_targeting_and_creatures()
	_test_passive_triggered_and_modifiers()
	_test_talent_integration()
	_test_loot()
	_test_persistence_and_compatibility()
	print("M02 CHECKPOINT E SKILLS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(condition: bool, label: String) -> bool:
	checks += 1
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)
	return condition

func _session(store: RefCounted, name: String, biome: String = "forest", seed_value: int = 101) -> RefCounted:
	var world: Dictionary = store.create_world(name, 1847, 1, Pack.blueprint(1847))
	return _run(store, world.world_id, seed_value, biome)

func _run(store: RefCounted, world_id: String, seed_value: int, biome: String = "forest", mode: String = "normal") -> RefCounted:
	var session := Session.new(store)
	check(session.start_new(world_id, seed_value, biome, mode), "Start run seed %d: %s" % [seed_value, session.last_error])
	session.autosave_interval = 0
	return session

func _talent(session: RefCounted, content_id: String) -> void:
	## Pin the awakened talent (real record format) so numbers are predictable.
	session.run.state.character.talents = [] if content_id.is_empty() else [session.talent_rules.record(session.talent_definition(content_id, 1), 0, int(session.run.state.turn))]
	session.reload_talents()
	session.dirty = true

func _give(session: RefCounted, content_id: String, quantity: int = 1) -> void:
	var award := Inventory.new().award(session.store.content, session.world.world_id, session.run.state.inventory, [{"content_id": content_id, "version": 1, "quantity": quantity}], "test:%s/%d" % [content_id, randi()])
	session.run.state.inventory = award.inventory

func _learn(session: RefCounted, skill_id: String) -> bool:
	## Learn through the real book path.
	var book := "core:book/" + skill_id.get_slice("/", 1)
	_give(session, book)
	return session.perform_action({"type": "learn", "content_id": book})

func _count(session: RefCounted, content_id: String) -> int:
	return int(session.run.state.inventory.get(content_id, {}).get("quantity", 0))

func _energy(session: RefCounted) -> int:
	return session.skills.resource(session, "energy")

func _skill_def(session: RefCounted, content_id: String) -> Dictionary:
	return session.skill_definition(content_id, 1)

func _place(session: RefCounted, dispositions: Array, distance: int) -> Dictionary:
	## Put the nearest living creature of these dispositions on a free, visible tile
	## `distance` steps away in a straight clear line (test setup for exact checks).
	var creature := Acceptance.nearest_creature(session, dispositions)
	if creature.is_empty():
		return {}
	for direction in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var clear := true
		for step in range(1, distance + 1):
			var tile: Vector2i = session.position + direction * step
			clear = clear and session.terrain.walkable(tile) and session.visible.has(tile) and (session.roster.living_at(tile).is_empty() or session.roster.living_at(tile).instance_id == creature.instance_id)
		if clear:
			creature.position = session.position + direction * distance
			return creature
	return {}

func _test_catalog() -> void:
	var store := Store.new()
	store.open(directory + "/catalog.sqlite")
	var session := _session(store, "Catalog")
	var catalog: Dictionary = session.skill_catalog
	check(SKILLS.all(func(id: String) -> bool: return catalog.supported.has(id + "@1")), "Nine sample skills register and load as supported definitions")
	var types := {}
	for id in SKILLS:
		types[_skill_def(session, id).payload.type] = true
	check(types.keys().size() == 3, "Active, passive and triggered skill types are all represented")
	var summon: Dictionary = store.content.load_definition(session.world.world_id, "core:skill/summon_wolf", 1)
	check(summon.status == "pending_capability" and catalog.pending.size() == 1 and "skill.effect.tile.summon" in catalog.pending[0].missing and "mechanic.summon" in catalog.pending[0].missing, "Summon Wolf is kept pending with its missing capabilities (%s)" % str(catalog.pending[0].missing if not catalog.pending.is_empty() else []))
	var linked := true
	for id in SKILLS:
		var book_id: String = "core:book/" + id.get_slice("/", 1)
		var book: Dictionary = catalog.books.get(book_id + "@1", {})
		var item: Dictionary = store.content.load_definition(session.world.world_id, book_id, 1)
		linked = linked and book.get("skill", {}).get("content_id") == id and item.kind == "item" and item.dependencies.any(func(d: Dictionary) -> bool: return d.content_id == id)
	check(linked and catalog.books.size() == 9, "Each book is a separate item that pins and teaches exactly its skill")
	check(_skill_def(session, "core:book/power_strike").is_empty() and store.content.load_definition(session.world.world_id, "core:skill/power_strike", 1).kind == "skill", "Skill definitions and books are different entities")
	check(not session.skill_rules.met({"type": "bloodline", "values": ["dragon"]}, session.skills.character_view(session)) and session.skill_rules.evaluate([{"type": "realm", "min": 1}], session.skills.character_view(session))[0].begins_with("unsupported requirement"), "Unsupported conditions are never treated as met")
	var world_id: String = session.world.world_id
	var odd := {"content_id": "test:skill/qi_burst", "version": 1, "schema_version": 1, "kind": "skill", "name": "Qi burst", "payload": {"type": "active", "learn": {"conditions": [{"type": "cultivation_realm", "min": 2}]}, "use": {"cost": {"qi": 5}, "target": {"kind": "area", "range": 2}}, "effects": [{"type": "shockwave"}]}}
	check(not store.content.register_definition(world_id, odd).is_empty(), "A skill with unknown mechanics registers as data")
	var next := _run(store, world_id, 202)
	var missing: Array = next.skill_catalog.pending.filter(func(entry: Dictionary) -> bool: return entry.content_id == "test:skill/qi_burst")[0].missing
	check("skill.condition.cultivation_realm" in missing and "skill.resource.qi" in missing and "skill.target.area" in missing, "Unknown condition / resource / target become pending capabilities (%s)" % str(missing))
	check(next.skills.learn(next, _skill_def(next, "test:skill/qi_burst"), {"kind": "test"}).contains("unsupported capability") and next.run.state.character.skills.is_empty(), "A pending skill can never be learned")
	var bad_world: Dictionary = store.create_world("Invalid skill", 77, 1, Pack.blueprint(77))
	store.content.register_definition(bad_world.world_id, {"content_id": "test:skill/broken", "version": 1, "schema_version": 1, "kind": "skill", "name": "Broken", "payload": {"type": "active", "use": {"cost": {}, "target": {"kind": "creature", "range": 99}}, "effects": [{"type": "strike"}]}})
	var refused := Session.new(store)
	check(not refused.start_new(bad_world.world_id, 5) and refused.last_error.contains("range"), "Invalid skill data is refused with an explicit error")
	check(next.talent_catalog.pool.any(func(definition: Dictionary) -> bool: return definition.content_id == "core:talent/comprehension"), "Ngộ Tính (skill-boosting talent) joins the awakening pool")
	store.close()

func _test_learning() -> void:
	var store := Store.new()
	store.open(directory + "/learn.sqlite")
	var session := _session(store, "Learning")
	_talent(session, "")
	_give(session, "core:book/power_strike")
	var club: Dictionary = session.run.state.character.equipment.weapon
	session.unequip_slot("weapon")
	var turn := int(session.run.state.turn)
	check(not session.perform_action({"type": "learn", "content_id": "core:book/power_strike"}) and session.last_error.contains("weapon equipped") and session.last_error.contains("Attack 6+") and _count(session, "core:book/power_strike") == 1 and int(session.run.state.turn) == turn, "Unmet learn conditions (no weapon, ATK 5): refused, book kept, no turn")
	session.equip_item("core:wooden_club", club.instance_id)
	turn = int(session.run.state.turn)
	check(session.perform_action({"type": "learn", "content_id": "core:book/power_strike"}) and int(session.run.state.turn) == turn + 1 and _count(session, "core:book/power_strike") == 0, "With the club equipped (ATK 7) Power Strike is learned: one turn, book used up (data rule)")
	var record: Dictionary = session.skills.record_of(session, "core:skill/power_strike")
	check(record.get("source", {}).get("kind") == "book" and record.source.content_id == "core:book/power_strike" and int(record.learned_turn) == turn, "The learned record keeps its source and turn")
	_give(session, "core:book/power_strike")
	turn = int(session.run.state.turn)
	check(not session.perform_action({"type": "learn", "content_id": "core:book/power_strike"}) and session.last_error.contains("already known") and _count(session, "core:book/power_strike") == 1 and session.run.state.character.skills.size() == 1 and int(session.run.state.turn) == turn, "Learning a known skill again is refused; book and turn kept")
	_give(session, "core:book/mend")
	check(not session.perform_action({"type": "learn", "content_id": "core:book/mend"}) and session.last_error.contains("level 2"), "Level requirement blocks Mend at level 1")
	session.gain_xp(session.character_rules.xp_to_next("adventurer", 1))
	check(session.perform_action({"type": "learn", "content_id": "core:book/mend"}), "At level 2 Mend is learned")
	var max_before := int(session.combat_stats().max_hp)
	_give(session, "core:book/body_tempering")
	check(session.perform_action({"type": "learn", "content_id": "core:book/body_tempering"}) and _count(session, "core:book/body_tempering") == 1 and int(session.combat_stats().max_hp) == max_before + 5, "Body Tempering: book kept by its data rule; passive +5 max HP applies at once")
	# Blood Rite: prerequisite skill + one of (blood talent, level 4).
	var other := _run(store, session.world.world_id, 303)
	_talent(other, "")
	_give(other, "core:book/blood_rite")
	check(not other.perform_action({"type": "learn", "content_id": "core:book/blood_rite"}) and other.last_error.contains("requires skill Power Strike") and other.last_error.contains("one of ("), "Blood Rite lists both the missing prerequisite and the talent/level alternative")
	_learn(other, "core:skill/power_strike")
	check(not other.perform_action({"type": "learn", "content_id": "core:book/blood_rite"}), "Prerequisite alone is not enough without the talent or level 4")
	_talent(other, "core:talent/berserker")
	check(other.perform_action({"type": "learn", "content_id": "core:book/blood_rite"}), "A blood-marked talent (Berserker) satisfies the special condition")
	var teacher := _run(store, session.world.world_id, 404)
	check(teacher.skills.learn(teacher, _skill_def(teacher, "core:skill/iron_guard"), {"kind": "teacher", "id": "test:npc"}).is_empty() and teacher.skills.record_of(teacher, "core:skill/iron_guard").source.kind == "teacher" and teacher.run.state.inventory.is_empty(), "Learning is not tied to books: the generic path records another source")
	check(Acceptance.same(store.load_world(session.world.world_id).blueprint, Pack.blueprint(1847)), "Learning never changes the World Blueprint")
	store.close()

func _test_active_skills() -> void:
	var store := Store.new()
	store.open(directory + "/active.sqlite")
	var session := _session(store, "Active", "meadow", 515)
	_talent(session, "")
	for id in ["core:skill/iron_guard", "core:skill/swift_step"]:
		_learn(session, id)
	session.gain_xp(session.character_rules.xp_to_next("adventurer", 1))
	check(session.skills.learn(session, _skill_def(session, "core:skill/mend"), {"kind": "test"}).is_empty(), "Learn Mend at level 2")
	var energy := _energy(session)
	var defense := int(session.combat_stats().defense)
	var turn := int(session.run.state.turn)
	check(session.perform_action({"type": "skill", "skill_id": "core:skill/iron_guard"}) and int(session.combat_stats().defense) == defense + 3 and _energy(session) == energy - 5 and int(session.run.state.turn) == turn + 1, "Iron Guard: DEF +3, costs 5 energy, spends one turn")
	var status: Dictionary = session.run.state.character.statuses[0]
	check(status.id == "guard" and int(status.until_turn) == turn + 6, "The timed status is stored with its end turn")
	energy = _energy(session)
	turn = int(session.run.state.turn)
	check(not session.perform_action({"type": "skill", "skill_id": "core:skill/iron_guard"}) and session.last_error.contains("recharging") and _energy(session) == energy and int(session.run.state.turn) == turn, "During its cooldown the skill is refused: no energy, no turn")
	var ended := false
	for _i in 5:
		session.wait_turn()
		ended = ended or session.last_events.any(func(event: Dictionary) -> bool: return event.type == "status_end")
	check(ended and int(session.combat_stats().defense) == defense and session.run.state.character.statuses.is_empty(), "After 5 turns the buff wears off (event) and DEF returns")
	energy = _energy(session)
	check(not session.perform_action({"type": "skill", "skill_id": "core:skill/mend"}) and session.last_error.contains("no effect") and _energy(session) == energy, "Mend at full HP is refused without cost")
	session.stats().hp = 10
	check(session.perform_action({"type": "skill", "skill_id": "core:skill/mend"}) and int(session.stats().hp) >= 10 + int(session.combat_stats().max_hp) * 30 / 100 and _energy(session) == energy - 6, "Mend heals 30%% of max HP for 6 energy (HP %d)" % int(session.stats().hp))
	# Swift Step: a straight, clear, visible tile within 3.
	var options: Array = session.skills.targets(session, _skill_def(session, "core:skill/swift_step"))
	var valid := true
	for option in options:
		var distance := absi(option.tile.x - session.position.x) + absi(option.tile.y - session.position.y)
		valid = valid and distance >= 1 and distance <= 3 and session.terrain.walkable(option.tile) and session.visible.has(option.tile)
	if check(not options.is_empty() and valid, "Swift Step offers only free visible tiles within 3 in straight lines (%d)" % options.size()):
		var far: Vector2i = session.position + Vector2i(9, 0)
		turn = int(session.run.state.turn)
		check(not session.perform_action({"type": "skill", "skill_id": "core:skill/swift_step", "target": {"x": far.x, "y": far.y}}) and int(session.run.state.turn) == turn, "An invalid tile is refused (no turn, no cost)")
		var goal: Vector2i = options[0].tile
		check(session.perform_action({"type": "skill", "skill_id": "core:skill/swift_step", "target": {"x": goal.x, "y": goal.y}}) and session.position == goal and session.run.state.character.position.x == goal.x, "Swift Step moves the player to the chosen tile")
	# Blood Rite: pays HP, restores energy; refused at full energy.
	session.skills.learn(session, _skill_def(session, "core:skill/power_strike"), {"kind": "test"})
	_talent(session, "core:talent/undying")
	check(session.skills.learn(session, _skill_def(session, "core:skill/blood_rite"), {"kind": "test"}).is_empty(), "Learn Blood Rite (Undying talent)")
	session.stats().hp = int(session.combat_stats().max_hp)
	session.run.state.character.resources.energy.value = session.skills.resource_max(session, "energy")
	check(not session.perform_action({"type": "skill", "skill_id": "core:skill/blood_rite"}) and session.last_error.contains("no effect"), "Blood Rite at full energy is refused (no HP paid)")
	session.run.state.character.resources.energy.value = 2
	var hp := int(session.stats().hp)
	check(session.perform_action({"type": "skill", "skill_id": "core:skill/blood_rite"}) and _energy(session) >= 14 and int(session.stats().hp) <= hp - 6 + 1, "Blood Rite: -6 HP, +12 energy (HP and energy are different cost types)")
	store.close()

func _test_targeting_and_creatures() -> void:
	var store := Store.new()
	store.open(directory + "/targets.sqlite")
	var session := _session(store, "Targets", "forest", 101)
	_talent(session, "")
	for id in ["core:skill/power_strike", "core:skill/stone_throw"]:
		check(_learn(session, id), "Learn " + id)
	var throw := _skill_def(session, "core:skill/stone_throw")
	# The target rule: every creature is valid exactly when in range, visible and in line of sight.
	var rule_ok := true
	var valid_ids: Array = session.skills.targets(session, throw).map(func(creature: Dictionary) -> String: return creature.instance_id)
	for creature in session.roster.creatures.values():
		var distance: int = absi(creature.position.x - session.position.x) + absi(creature.position.y - session.position.y)
		var expected: bool = not creature.dead and distance >= 1 and distance <= 5 and session.visible.has(creature.position) and (distance == 1 or session.line_clear(session.position, creature.position))
		rule_ok = rule_ok and (creature.instance_id in valid_ids) == expected
	check(rule_ok, "Stone Throw targets = living creatures within 5, visible, in line of sight")
	var target := _place(session, ["neutral", "hostile"], 3)
	if not check(not target.is_empty(), "Place a creature 3 tiles away in a clear line"):
		return
	var energy := _energy(session)
	var turn := int(session.run.state.turn)
	check(not session.perform_action({"type": "skill", "skill_id": "core:skill/stone_throw", "target_id": target.instance_id}) and session.last_error.contains("needs Small stone") and _energy(session) == energy and int(session.run.state.turn) == turn, "Without stones Stone Throw is refused; nothing spent")
	check(not session.perform_action({"type": "skill", "skill_id": "core:skill/power_strike", "target_id": target.instance_id}) and int(session.run.state.turn) == turn and _energy(session) == energy, "Power Strike (range 1) cannot reach a creature 3 tiles away")
	_give(session, "core:stone", 2)
	var hp_before := int(target.hp)
	var key := "hit-v1/%d/%d/%s/%d/skill/core:skill/stone_throw" % [session.world.seed, session.run.seed, target.instance_id, int(session.run.state.turn)]
	var expected := Combat.resolve({"attack": int(session.combat_stats().attack) * 70 / 100 + 1}, {"hp": hp_before, "defense": target.definition.payload.stats.defense}, key)
	check(session.perform_action({"type": "skill", "skill_id": "core:skill/stone_throw", "target_id": target.instance_id}) and _count(session, "core:stone") == 1 and _energy(session) == energy - 2, "Stone Throw hits at range 3: one stone and 2 energy used")
	var hit: Array = session.last_events.filter(func(event: Dictionary) -> bool: return event.type == "hit" and event.attacker == "player")
	check(not hit.is_empty() and int(hit[0].damage) == int(expected.damage), "Skill damage goes through the combat formula (70%% ATK +1 → %d)" % int(expected.damage))
	# Binding: the creature loses its next 2 decisions; saved in its mutation.
	var binder := _run(store, session.world.world_id, 102)
	_talent(binder, "")
	binder.gain_xp(binder.character_rules.xp_to_next("adventurer", 1))
	_learn(binder, "core:skill/binding")
	var bound := _place(binder, ["hostile", "neutral"], 2)
	if check(not bound.is_empty(), "Place a creature for Binding"):
		check(binder.perform_action({"type": "skill", "skill_id": "core:skill/binding", "target_id": bound.instance_id}) and int(binder.run.state.entity_mutations[bound.instance_id].stunned_until) == int(binder.run.state.turn) + 2, "Binding stores the creature's stun end turn")
		var where: Vector2i = binder.roster.creatures[bound.instance_id].position
		var skipped: bool = binder.last_events.any(func(event: Dictionary) -> bool: return event.type == "stunned" and event.target == bound.instance_id)
		binder.wait_turn()
		skipped = skipped and binder.last_events.any(func(event: Dictionary) -> bool: return event.type == "stunned" and event.target == bound.instance_id)
		check(skipped and binder.roster.creatures[bound.instance_id].position == where, "The bound creature skips two turns and does not move")
		check(binder.save(), "Save with a bound creature")
		var again := Session.new(store)
		check(again.resume(binder.run.run_id) and int(again.roster.creatures[bound.instance_id].stunned_until) == int(binder.roster.creatures[bound.instance_id].stunned_until), "The stun survives reload exactly")
	# Power Strike: shared kill path (loot + XP) and the weapon use condition.
	var striker := _run(store, session.world.world_id, 103)
	_talent(striker, "")
	_learn(striker, "core:skill/power_strike")
	var foe := _place(striker, ["neutral", "hostile", "passive"], 1)
	if check(not foe.is_empty(), "Place an adjacent creature"):
		foe.hp = 1
		var xp_before := int(striker.run.state.character.progression.adventurer.xp) + int(striker.run.state.character.progression.adventurer.level) * 1000
		check(striker.perform_action({"type": "skill", "skill_id": "core:skill/power_strike", "target_id": foe.instance_id}) and striker.roster.creatures[foe.instance_id].dead and striker.last_events.any(func(event: Dictionary) -> bool: return event.type == "creature_death") and int(striker.run.state.character.progression.adventurer.xp) + int(striker.run.state.character.progression.adventurer.level) * 1000 > xp_before, "A skill kill grants loot and XP through the shared strike path")
		var club: Dictionary = striker.run.state.character.equipment.weapon
		striker.unequip_slot("weapon")
		striker.run.state.character.skills[0].cooldown_until = 0
		var other := _place(striker, ["neutral", "hostile", "passive"], 1)
		var energy_now := _energy(striker)
		check(not other.is_empty() and not striker.perform_action({"type": "skill", "skill_id": "core:skill/power_strike", "target_id": other.instance_id}) and striker.last_error.contains("weapon equipped") and _energy(striker) == energy_now, "Power Strike's use condition (weapon equipped) blocks it without cost")
		striker.equip_item("core:wooden_club", club.instance_id)
	store.close()

func _test_passive_triggered_and_modifiers() -> void:
	var store := Store.new()
	store.open(directory + "/modifiers.sqlite")
	var session := _session(store, "Modifiers")
	_talent(session, "")
	_learn(session, "core:skill/opening_strike")
	var wolf := {"instance_id": "crt:test/1", "content_id": "core:wolf", "version": 1, "hp": 14, "max_hp": 14, "definition": store.content.load_definition(session.world.world_id, "core:wolf", 1)}
	var base := Combat.resolve(session.combat_stats(), {"hp": 14, "defense": 1}, "probe")
	var strike: Dictionary = session.talent_strike(wolf, base)
	check(int(strike.result.damage) == int(base.damage) + 2 and strike.attack[0].talent.source == "skill", "Triggered skill runs on the shared engine: +2 damage while healthy (source: skill)")
	session.stats().hp = 5
	check(int(session.talent_strike(wolf, base).result.damage) == int(base.damage), "Its condition (HP >= 80%) is checked: no bonus when hurt")
	session.stats().hp = int(session.combat_stats().max_hp)
	# Energy regeneration: +34 per turn (rest 100), every 100 = 1 point.
	session.run.state.character.resources.energy = {"value": 10, "progress": 0}
	for _i in 3:
		session.wait_turn()
	check(_energy(session) == 11 and int(session.run.state.character.resources.energy.progress) == 2, "Energy regenerates 1 point per ~3 turns (progress stored)")
	# Gear and talents change skills: cost, range, power.
	_learn(session, "core:skill/stone_throw")
	_learn(session, "core:skill/power_strike")
	var throw := _skill_def(session, "core:skill/stone_throw")
	var power := _skill_def(session, "core:skill/power_strike")
	check(session.skills.reach(session, throw) == 5 and int(session.skills.costs(session, throw).energy) == 2 and int(session.skills.costs(session, power).energy) == 4, "Base: Stone Throw range 5 / 2 energy, Power Strike 4 energy")
	var award := Inventory.new().award(store.content, session.world.world_id, session.run.state.inventory, [{"content_id": "core:focus_ring", "version": 1, "quantity": 1, "quality": "pho_thong"}], "test:ring")
	session.run.state.inventory = award.inventory
	session.equip_item("core:focus_ring", session.run.state.inventory["core:focus_ring"].instances[0].instance_id)
	check(session.skills.reach(session, throw) == 6 and int(session.skills.costs(session, throw).energy) == 1 and session.skills.reach(session, power) == 1 and int(session.skills.costs(session, power).energy) == 3, "Focus ring: ranged skills +1 range, all skills -25% energy (melee range unchanged)")
	check(int(session.skills.costs(session, throw).items[0].quantity) == 1, "Item costs are not reduced by energy modifiers")
	_talent(session, "core:talent/comprehension")
	check(int(session.skills.costs(session, power).energy) == 2 and int(session.skills.modifiers(session, power).power_percent) == 25, "Ngộ Tính talent stacks with the ring: -50% energy, +25% power")
	store.close()

func _test_talent_integration() -> void:
	## Real awakening is on; these check that skills drive talent triggers once, with no chains.
	var store := Store.new()
	store.open(directory + "/integration.sqlite")
	var session := _session(store, "Integration")
	check(session.run.state.character.talents.size() == 1, "Run has its awakened talent (talents on)")
	_talent(session, "core:talent/bloodthirst")
	_learn(session, "core:skill/power_strike")
	_learn(session, "core:skill/opening_strike")
	var foe := _place(session, ["neutral", "hostile", "passive"], 1)
	if check(not foe.is_empty(), "Place an adjacent creature"):
		foe.hp = 2
		session.stats().hp = int(session.combat_stats().max_hp) - 6
		check(session.perform_action({"type": "skill", "skill_id": "core:skill/power_strike", "target_id": foe.instance_id}), "Power Strike kills with Bloodthirst and Opening Strike active")
		var talent_events: Array = session.last_events.filter(func(event: Dictionary) -> bool: return event.type == "talent")
		var by_ability := {}
		for event in talent_events:
			by_ability[event.ability] = int(by_ability.get(event.ability, 0)) + 1
		check(by_ability.get("drain", 0) == 1 and by_ability.get("feast", 0) == 1 and by_ability.get("first_blood", 0) == 1 and talent_events.size() == 3, "Each trigger fires exactly once for one skill kill (lifesteal, kill heal, skill bonus): %s" % str(by_ability))
	check(session.talents.resolving == false and session.talents.blocked_reentry == 0, "No trigger was re-entered while effects resolved")
	session.talents.resolving = true
	check(session.talents.fire("on_attack", {"turn": 1, "hp": 30, "max_hp": 30, "key": "x"}).is_empty() and session.talents.blocked_reentry == 1, "While effects resolve, a nested trigger is blocked (no recursion, no endless loop)")
	session.talents.resolving = false
	# Fate Reversal grows from a skill kill too; Beast Hunter adds damage to a ranged skill.
	var hunter := _run(store, session.world.world_id, 141)
	_talent(hunter, "core:talent/beast_hunter")
	_learn(hunter, "core:skill/stone_throw")
	_give(hunter, "core:stone", 3)
	var prey := Acceptance.nearest_creature(hunter, ["hostile"])
	if not prey.is_empty():
		prey = _place(hunter, ["hostile"], 3)
	if check(not prey.is_empty() and prey.definition.metadata.category == "beast", "Place a wolf at range 3"):
		var key := "hit-v1/%d/%d/%s/%d/skill/core:skill/stone_throw" % [hunter.world.seed, hunter.run.seed, prey.instance_id, int(hunter.run.state.turn)]
		var expected := Combat.resolve({"attack": int(hunter.combat_stats().attack) * 70 / 100 + 1}, {"hp": int(prey.hp), "defense": prey.definition.payload.stats.defense}, key)
		hunter.perform_action({"type": "skill", "skill_id": "core:skill/stone_throw", "target_id": prey.instance_id})
		var hit: Array = hunter.last_events.filter(func(event: Dictionary) -> bool: return event.type == "hit" and event.attacker == "player")
		check(not hit.is_empty() and int(hit[0].damage) == int(expected.damage) + 2, "Beast Hunter's +2 applies to a ranged skill strike (%d)" % (int(hit[0].damage) if not hit.is_empty() else -1))
	store.close()

func _test_loot() -> void:
	var store := Store.new()
	store.open(directory + "/loot.sqlite")
	var session := _session(store, "Loot")
	_talent(session, "")
	var cache: Dictionary = store.content.load_definition(session.world.world_id, "core:wayfarer_cache", 1)
	check(session.loot_for(cache, "probe/cache").any(func(drop: Dictionary) -> bool: return drop.content_id == "core:book/power_strike"), "The Wayfarer's cache always holds the Power Strike manual")
	var chest: Dictionary = store.content.load_definition(session.world.world_id, "core:weathered_chest", 1)
	var books := 0
	for index in 400:
		books += session.loot_for(chest, "probe/%d" % index).filter(func(drop: Dictionary) -> bool: return str(drop.content_id).begins_with("core:book/") or drop.content_id == "core:focus_ring").size()
	check(books > 130 and books < 230, "Weathered chests hold a manual or focus ring about 45%% of the time (%d/400)" % books)
	# A real chest with a manual: open it, learn from it, reload without a second payout.
	for seed_value in [101, 202, 303, 404, 505, 606, 707, 808, 909]:
		var run := _run(store, session.world.world_id, seed_value)
		_talent(run, "")
		for chunk in run.objects.chunks.values():
			for instance in chunk:
				if instance.content_id != "core:weathered_chest":
					continue
				var preview: Array = run.preview_loot(instance.instance_id)
				var book: Array = preview.filter(func(drop: Dictionary) -> bool: return str(drop.content_id).begins_with("core:book/"))
				if book.is_empty():
					continue
				var path: Array = Acceptance.route(run, func(tile: Vector2i) -> bool: return absi(tile.x - int(instance.position.x)) + absi(tile.y - int(instance.position.y)) <= 1)
				if path.is_empty() or path.size() > 150 or not Helpers.walk(run, path) or not run.interact(instance.instance_id):
					continue
				check(_count(run, book[0].content_id) >= 1, "Opened chest gives %s through its loot table" % book[0].content_id)
				check(run.save(), "Save the found manual")
				var again := Session.new(store)
				check(again.resume(run.run.run_id) and not again.interact(instance.instance_id) and Acceptance.same(again.run.state.inventory, run.run.state.inventory), "Reload: same manual, the chest cannot pay twice")
				store.close()
				return
	check(false, "Find a reachable chest with a manual")
	store.close()

func _test_persistence_and_compatibility() -> void:
	var store := Store.new()
	store.open(directory + "/persist.sqlite")
	var session := _session(store, "Persist", "meadow", 515)
	_talent(session, "")
	session.gain_xp(session.character_rules.xp_to_next("adventurer", 1))
	for id in ["core:skill/iron_guard", "core:skill/body_tempering", "core:skill/opening_strike"]:
		_learn(session, id)
	session.perform_action({"type": "skill", "skill_id": "core:skill/iron_guard"})
	var snapshot := {"skills": session.run.state.character.skills.duplicate(true), "resources": session.run.state.character.resources.duplicate(true), "statuses": session.run.state.character.statuses.duplicate(true), "effective": session.effective_stats().duplicate(true), "inventory": session.run.state.inventory.duplicate(true)}
	check(session.save(), "Save learned skills, cooldown, energy and an active buff")
	var same := true
	for _i in 3:
		var again := Session.new(store)
		same = same and again.resume(session.run.run_id) and Acceptance.same(again.run.state.character.skills, snapshot.skills) and Acceptance.same(again.run.state.character.resources, snapshot.resources) and Acceptance.same(again.run.state.character.statuses, snapshot.statuses) and Acceptance.same(again.effective_stats(), snapshot.effective) and Acceptance.same(again.run.state.inventory, snapshot.inventory)
	check(same, "Three reloads: identical skills, cooldowns, energy, buffs, stats and books (no duplication)")
	var resumed := Session.new(store)
	resumed.resume(session.run.run_id)
	check(not resumed.perform_action({"type": "skill", "skill_id": "core:skill/iron_guard"}) and resumed.last_error.contains("recharging"), "The cooldown is not reset by loading")
	var unsaved := Session.new(store)
	unsaved.resume(session.run.run_id)
	_learn(unsaved, "core:skill/stone_throw")
	var reloaded := Session.new(store)
	check(reloaded.resume(session.run.run_id) and reloaded.skills.record_of(reloaded, "core:skill/stone_throw").is_empty(), "An unsaved learn does not leak into the save")
	var b := _run(store, session.world.world_id, 616)
	check(b.run.state.character.skills.is_empty() and b.run.state.character.statuses.is_empty() and _energy(b) == b.skills.resource_max(b, "energy"), "Run B starts with no skills, full energy: independent of Run A")
	# Saves from before skills: no skills / resources / statuses keys (and C/B era keys).
	var legacy: Dictionary = store.load_run(b.run.run_id)
	for key in ["skills", "resources", "statuses"]:
		legacy.state.character.erase(key)
	store.save_run(b.run.run_id, int(legacy.revision), legacy.state)
	var old := Session.new(store)
	check(old.resume(b.run.run_id) and old.run.state.character.skills.is_empty() and _energy(old) == old.skills.resource_max(old, "energy") and not old.dirty, "A Checkpoint D save loads: no skills, full energy, nothing rewritten")
	var b_era := _run(store, session.world.world_id, 617)
	var stored: Dictionary = store.load_run(b_era.run.run_id)
	for key in ["skills", "resources", "statuses", "talents", "equipment", "progression"]:
		stored.state.character.erase(key)
	store.save_run(b_era.run.run_id, int(stored.revision), stored.state)
	var b_load := Session.new(store)
	check(b_load.resume(b_era.run.run_id) and b_load.run.state.character.skills.is_empty() and b_load.run.state.character.talents.size() == 1, "A Checkpoint B save loads with defaults (and awakens its talent)")
	var corruptions := {
		"duplicate skill": func(state: Dictionary) -> void: state.character.skills.append(state.character.skills[0].duplicate(true)),
		"unknown skill": func(state: Dictionary) -> void: state.character.skills[0].content_id = "core:skill/nope",
		"unknown resource": func(state: Dictionary) -> void: state.character.resources["mana"] = {"value": 3, "progress": 0},
		"bad status": func(state: Dictionary) -> void: state.character.statuses.append({"id": "x", "source": "core:skill/iron_guard", "stat": "luck", "add": 1, "until_turn": 9}),
	}
	for label in corruptions:
		var victim := _run(store, session.world.world_id, 900 + label.length())
		_talent(victim, "")
		_learn(victim, "core:skill/iron_guard")
		victim.save()
		var saved: Dictionary = store.load_run(victim.run.run_id)
		corruptions[label].call(saved.state)
		store.save_run(victim.run.run_id, int(saved.revision), saved.state)
		var before: Dictionary = store.load_run(victim.run.run_id)
		var refused := Session.new(store)
		check(not refused.resume(victim.run.run_id) and refused.last_error.contains("save was not changed") and Acceptance.same(store.load_run(victim.run.run_id), before), "Corrupt skill state refused (%s): %s" % [label, refused.last_error])
	store.close()
