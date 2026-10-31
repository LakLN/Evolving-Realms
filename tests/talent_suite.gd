extends SceneTree
## Milestone 02 Checkpoint D: talent ranks, awakening, effects, triggers, persistence.
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Data = preload("res://src/data/json_data.gd")
const Pack = preload("res://src/content/starter_pack.gd")
const Talents = preload("res://src/core/talents.gd")
const TalentText = preload("res://src/core/talent_text.gd")
const Combat = preload("res://src/core/combat.gd")
const Inventory = preload("res://src/core/inventory.gd")
const Acceptance = preload("res://src/acceptance/standalone_check.gd")
const Helpers = preload("res://tests/interaction_helpers.gd")
const RANK_IDS := ["F", "E", "D", "C", "B", "A", "S", "SS", "SSS"]
const RANK_NAMES := ["Phàm Tục", "Sơ Đẳng", "Phổ Thông", "Ưu Tú", "Tinh Anh", "Trác Việt", "Siêu Phàm", "Truyền Kỳ", "Nghịch Thiên"]
var checks := 0
var failures := 0
var directory := ""

func _initialize() -> void:
	directory = ProjectSettings.globalize_path("user://m02d_tests/" + Data.uuid())
	DirAccess.make_dir_recursive_absolute(directory)
	print("Talent artifacts: ", directory)
	_test_ranks()
	_test_catalog_and_pending()
	_test_awakening_weights()
	_test_run_awakening()
	_test_stat_and_survival_effects()
	_test_gathering_and_exploration()
	_test_combat_effects()
	_test_hit_taken_and_limits()
	_test_growth_and_no_stacking()
	_test_persistence_and_compatibility()
	print("M02 CHECKPOINT D TALENTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(condition: bool, label: String) -> bool:
	checks += 1
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)
	return condition

func _store(name: String) -> RefCounted:
	var store := Store.new()
	store.open(directory + "/" + name + ".sqlite")
	return store

func _session(store: RefCounted, name: String, biome: String = "meadow", seed_value: int = 101, mode: String = "normal", world_seed: int = 1847) -> RefCounted:
	var world: Dictionary = store.create_world(name, world_seed, 1, Pack.blueprint(world_seed))
	return _run(store, world.world_id, seed_value, biome, mode)

func _run(store: RefCounted, world_id: String, seed_value: int, biome: String = "meadow", mode: String = "normal") -> RefCounted:
	var session := Session.new(store)
	check(session.start_new(world_id, seed_value, biome, mode), "Start run seed %d: %s" % [seed_value, session.last_error])
	session.autosave_interval = 0
	return session

func _force(session: RefCounted, content_id: String) -> Dictionary:
	## Replace the awakened talent with a chosen one (tests only), through the same
	## record format and runtime reload a real awakening uses.
	var held: Array = []
	if not content_id.is_empty():
		held.append(session.talent_rules.record(session.talent_definition(content_id, 1), 0, int(session.run.state.turn)))
	session.run.state.character.talents = held
	session.reload_talents()
	session.dirty = true
	return {} if held.is_empty() else session.run.state.character.talents[0]

func _creature(session: RefCounted, content_id: String, hp: int, id: String = "crt:test/1") -> Dictionary:
	var definition: Dictionary = session.store.content.load_definition(session.world.world_id, content_id, 1)
	return {"instance_id": id, "content_id": content_id, "version": 1, "hp": hp, "max_hp": int(definition.payload.stats.max_hp), "definition": definition}

func _give(session: RefCounted, content_id: String, quantity: int) -> void:
	var award := Inventory.new().award(session.store.content, session.world.world_id, session.run.state.inventory, [{"content_id": content_id, "version": 1, "quantity": quantity}], "test:%s/%d" % [content_id, randi()])
	session.run.state.inventory = award.inventory

func _talent_events(session: RefCounted, content_id: String = "") -> Array:
	return session.last_events.filter(func(event: Dictionary) -> bool: return event.type == "talent" and (content_id.is_empty() or event.talent == content_id))

func _test_ranks() -> void:
	var rules := Talents.new()
	check(rules.load_rules(), "Talent rank rules load")
	check(rules.ranks.map(func(rank: Dictionary) -> String: return rank.id) == RANK_IDS, "Exactly nine ranks in official order F → SSS")
	check(rules.ranks.map(func(rank: Dictionary) -> String: return rank.name) == RANK_NAMES, "Official Vietnamese titles Phàm Tục → Nghịch Thiên")
	var ordered := true
	for index in range(1, RANK_IDS.size()):
		ordered = ordered and rules.order(RANK_IDS[index - 1]) < rules.order(RANK_IDS[index])
	check(ordered and rules.order("F") == 1 and rules.order("SSS") == 9, "Rank order is strictly increasing (F=1 … SSS=9)")
	check(rules.rank("SS").style == "black_gold" and rules.rank("SSS").style == "rainbow" and rules.color("SSS", 0.0) != rules.color("SSS", 1.5), "SS uses black-gold, SSS an animated rainbow")
	var weights: Dictionary = rules.awakening.rank_weights
	check(weights.keys().size() == 9 and int(weights.F) > int(weights.SSS) and int(rules.awakening.talents_per_run) == 1, "Awakening weights are configurable data (one talent per run)")
	var record := {"content_id": "core:talent/fate_reversal", "version": 1, "rank": "SSS", "slot": 0, "awakened_turn": 0, "awakening_version": 1, "state": {}}
	check(Acceptance.same(JSON.parse_string(JSON.stringify(record)), record) and JSON.stringify(record).contains("\"rank\":\"SSS\""), "Rank serializes as its stable ID string")
	var definition_for := func(_id: String, _version: int) -> Dictionary: return {"kind": "talent", "payload": {"rank": "SSS", "unique": true, "abilities": []}}
	check(rules.validate_records([record], definition_for).is_empty(), "A valid stored record is accepted")
	var wrong: Dictionary = record.duplicate(true)
	wrong.rank = "SSSS"
	check(not rules.validate_records([wrong], definition_for).is_empty(), "Unknown rank in a save is rejected")
	wrong = record.duplicate(true)
	wrong.awakening_version = 2
	check(rules.validate_records([wrong], definition_for).contains("Unsupported talent awakening version"), "Unknown awakening version is rejected explicitly")
	check(not rules.validate_records([record, record.duplicate(true)], definition_for).is_empty(), "A unique talent held twice in one run is rejected")

func _test_catalog_and_pending() -> void:
	var store := _store("catalog")
	var session := _session(store, "Catalog")
	var pool: Array = session.talent_catalog.pool
	var ranks := {}
	for definition in pool:
		ranks[definition.payload.rank] = int(ranks.get(definition.payload.rank, 0)) + 1
	check(pool.size() == 14 and ranks.keys().size() == 9, "Sample packs: 13 playable talents (12 + Ngộ Tính from the skill pack) across all 9 ranks (%s)" % str(ranks))
	check(pool.filter(func(definition: Dictionary) -> bool: return definition.payload.get("unique", false)).size() == 3 and pool.any(func(definition: Dictionary) -> bool: return definition.payload.rank == "C" and definition.payload.unique), "Unique is a separate flag (C, SS and SSS examples), not tied to rank")
	var tamer: Dictionary = store.content.load_definition(session.world.world_id, "core:talent/beast_tamer", 1)
	var pending: Array = session.talent_catalog.pending
	check(tamer.status == "pending_capability" and "mechanic.pet_contract" in tamer.missing_capabilities, "Beast Tamer needs an unsupported capability: kept as pending_capability")
	check(pending.size() == 1 and pending[0].content_id == "core:talent/beast_tamer" and not pool.any(func(definition: Dictionary) -> bool: return definition.content_id == "core:talent/beast_tamer"), "Pending talents are listed but never in the awakening pool")
	# Data an engine does not understand is preserved as pending, never executed.
	var world_id: String = session.world.world_id
	var odd := {"content_id": "test:talent/dream_walker", "version": 1, "schema_version": 1, "kind": "talent", "name": "Dream walker", "payload": {"rank": "SSS", "unique": false, "abilities": [{"id": "dream", "trigger": "on_dream", "effects": [{"type": "heal", "amount": 5}]}]}}
	var summoner := {"content_id": "test:talent/summoner", "version": 1, "schema_version": 1, "kind": "talent", "name": "Summoner", "payload": {"rank": "SSS", "unique": false, "abilities": [{"id": "call", "trigger": "on_kill", "conditions": [{"type": "moon_phase", "values": ["full"]}], "effects": [{"type": "summon_spirit", "power": 9}]}]}}
	check(not store.content.register_definition(world_id, odd).is_empty() and not store.content.register_definition(world_id, summoner).is_empty(), "Registry stores talents with unknown mechanics (data only)")
	var next := _run(store, world_id, 202)
	var missing := {}
	for entry in next.talent_catalog.pending:
		missing[entry.content_id] = entry.missing
	check("talent.trigger.on_dream" in missing.get("test:talent/dream_walker", []) and "talent.effect.on_kill.summon_spirit" in missing.get("test:talent/summoner", []) and "talent.condition.moon_phase" in missing.get("test:talent/summoner", []), "Unknown trigger, effect and condition types become pending capabilities")
	var rules: RefCounted = next.talent_rules
	rules.awakening = {"talents_per_run": 1, "rank_weights": {"SSS": 1}}
	var picks := {}
	for index in 300:
		for definition in rules.awaken(next.talent_catalog.pool, {"mode": "normal", "spawn_biome": "meadow"}, [], "probe/sss/%d" % index):
			picks[definition.content_id] = true
	check(picks.keys() == ["core:talent/fate_reversal"], "Even when only SSS can roll, pending SSS talents are never awakened")
	# A dormant record (talent whose capability is missing) loads but never acts.
	next.run.state.character.talents = [rules.record(next.talent_definition("test:talent/summoner", 1), 0, 0)]
	next.reload_talents()
	var held: Dictionary = next.talents.held[0]
	check(not held.active and next.talents.modifiers().flat.is_empty() and next.talents.fire("on_kill", {"turn": 1, "hp": 30, "max_hp": 30, "key": "x"}).is_empty(), "A held talent with an unsupported capability stays dormant (no effect executed)")
	check(TalentText.details(next.talent_rules, held.definition, held.record, 0, {}, func(_id: String, _v: int) -> String: return "", false)[0].begins_with("Dormant"), "UI marks a dormant talent as needing a missing capability")
	# Structurally invalid data stops the session explicitly instead of guessing.
	var bad_world: Dictionary = store.create_world("Invalid talent", 77, 1, Pack.blueprint(77))
	var broken := {"content_id": "test:talent/broken", "version": 1, "schema_version": 1, "kind": "talent", "name": "Broken", "payload": {"rank": "Z", "abilities": [{"id": "x", "trigger": "on_turn", "effects": [{"type": "heal", "amount": 1}]}]}}
	var refused := Session.new(store)
	store.content.register_definition(bad_world.world_id, broken)
	check(not refused.start_new(bad_world.world_id, 5) and refused.last_error.contains("Unknown talent rank"), "Invalid talent data is refused with an explicit error")
	store.close()

func _test_awakening_weights() -> void:
	var store := _store("weights")
	var session := _session(store, "Weights")
	var rules: RefCounted = session.talent_rules
	var pool: Array = session.talent_catalog.pool
	var counts := {}
	var talents := {}
	var draws := 20000
	for index in draws:
		var picked: Array = rules.awaken(pool, {"mode": "normal", "spawn_biome": "forest"}, [], "weights/%d" % index)
		counts[picked[0].payload.rank] = int(counts.get(picked[0].payload.rank, 0)) + 1
		talents[picked[0].content_id] = int(talents.get(picked[0].content_id, 0)) + 1
	var total := 0
	for rank_id in RANK_IDS:
		total += int(rules.awakening.rank_weights[rank_id])
	var within := true
	var report := PackedStringArray()
	for rank_id in RANK_IDS:
		var expected := float(draws) * int(rules.awakening.rank_weights[rank_id]) / total
		var observed := int(counts.get(rank_id, 0))
		within = within and absf(observed - expected) <= 4.0 * sqrt(expected) + 5.0
		report.append("%s %d/%d" % [rank_id, observed, int(expected)])
	check(within, "Rank frequencies follow the weight table over %d awakenings (%s)" % [draws, ", ".join(report)])
	var f_a := int(talents.get("core:talent/iron_stomach", 0))
	var f_b := int(talents.get("core:talent/thick_skin", 0))
	check(absi(f_a - f_b) <= 4.0 * sqrt(f_a + f_b), "Talents of one rank share it by their own weights (F: %d vs %d)" % [f_a, f_b])
	var beach := {}
	for index in 4000:
		for definition in rules.awaken(pool, {"mode": "normal", "spawn_biome": "beach"}, [], "beach/%d" % index):
			beach[definition.content_id] = true
	check(talents.has("core:talent/forager") and not beach.has("core:talent/forager") and beach.has("core:talent/wayfarer"), "Awakening conditions: Forager only for forest/meadow starts")
	check(Acceptance.same(rules.awaken(pool, {"mode": "normal", "spawn_biome": "forest"}, [], "same"), rules.awaken(pool, {"mode": "normal", "spawn_biome": "forest"}, [], "same")), "The same key always awakens the same talent")
	var saved_weights: Dictionary = rules.awakening
	rules.awakening = {"talents_per_run": 3, "rank_weights": {"F": 1, "SS": 1}}
	var duplicates := 0
	var multi_ok := true
	for index in 400:
		var picked: Array = rules.awaken(pool, {"mode": "normal", "spawn_biome": "forest"}, [], "multi/%d" % index)
		multi_ok = multi_ok and picked.size() == 3 and picked.all(func(definition: Dictionary) -> bool: return definition.payload.rank in ["F", "SS"])
		duplicates += picked.filter(func(definition: Dictionary) -> bool: return definition.content_id == "core:talent/undying").size() / 2
		var held: Array = rules.awaken(pool, {"mode": "normal", "spawn_biome": "forest"}, ["core:talent/undying"], "held/%d" % index, 1)
		multi_ok = multi_ok and held[0].content_id != "core:talent/undying"
	check(multi_ok and duplicates == 0, "Configurable count/weights; a unique talent is never awakened twice in one run")
	rules.awakening = {"talents_per_run": 1, "rank_weights": {"F": 0, "E": 0, "D": 0, "C": 0, "B": 0, "A": 0, "S": 1, "SS": 0, "SSS": 0}}
	check(rules.awaken(pool, {"mode": "normal", "spawn_biome": "forest"}, [], "only-s")[0].payload.rank == "S", "A rank weight of 0 removes that rank from awakening")
	rules.awakening = saved_weights
	store.close()

func _test_run_awakening() -> void:
	var store := _store("runs")
	var session := _session(store, "Awakening")
	var held: Array = session.run.state.character.talents
	var expected: Array = session.talent_rules.awaken(session.talent_catalog.pool, {"mode": "normal", "spawn_biome": session.run.spawn.biome}, [], "talent-awakening-v1/%d/1/%d" % [int(session.world.seed), int(session.run.seed)])
	check(held.size() == 1 and held[0].content_id == expected[0].content_id and held[0].rank == expected[0].payload.rank and held[0].awakening_version == 1, "A new run awakens one talent with the deterministic weighted draw (%s, %s)" % [held[0].content_id, held[0].rank])
	check(not session.awakened_now.is_empty() and not session.dirty, "Awakening is revealed once and saved with the new run")
	var stored: Dictionary = store.load_run(session.run.run_id)
	check(Acceptance.same(stored.state.character.talents, held), "The talent is stored in the Run State")
	var same := true
	for _i in 3:
		var again := Session.new(store)
		same = same and again.resume(session.run.run_id) and Acceptance.same(again.run.state.character.talents, held) and again.awakened_now.is_empty() and not again.dirty
	check(same, "Loading three times never rerolls or re-reveals the talent")
	var world_id: String = session.world.world_id
	var seen := {}
	var ranks := {}
	for seed_value in range(300, 340):
		var awakening: Array = session.talent_rules.awaken(session.talent_catalog.pool, {"mode": "normal", "spawn_biome": "meadow"}, [], "talent-awakening-v1/1847/1/%d" % seed_value)
		seen[awakening[0].content_id] = int(seen.get(awakening[0].content_id, 0)) + 1
		ranks[awakening[0].payload.rank] = true
	check(seen.size() >= 6 and ranks.size() >= 4, "Different runs awaken different talents (%d talents, %d ranks over 40 run seeds)" % [seen.size(), ranks.size()])
	# A unique talent is unique per Run, not per World: independent runs may share it.
	var unique_seed := -1
	for seed_value in range(1, 3000):
		var draw: Array = session.talent_rules.awaken(session.talent_catalog.pool, {"mode": "normal", "spawn_biome": "meadow"}, [], "talent-awakening-v1/1847/1/%d" % seed_value)
		if draw[0].payload.unique:
			unique_seed = seed_value
			break
	var a := _run(store, world_id, unique_seed)
	var b := _run(store, world_id, unique_seed)
	check(a.run.run_id != b.run.run_id and a.run.state.character.talents[0].content_id == b.run.state.character.talents[0].content_id and a.talent_definition(a.run.state.character.talents[0].content_id, 1).payload.unique, "The same unique talent can awaken in two independent runs (%s)" % a.run.state.character.talents[0].content_id)
	_force(a, "core:talent/wayfarer")
	a.run.state.character.talents[0].state["trail_berries"] = {"used": 3, "cooldown_until": 0, "progress": 17}
	check(a.save(), "Save Run A with talent state")
	var b_stored: Dictionary = store.load_run(b.run.run_id)
	check(Acceptance.same(b_stored.state.character.talents, b.run.state.character.talents) and b_stored.state.character.talents[0].state.is_empty(), "Run B's talent and state are independent of Run A")
	check(Acceptance.same(store.load_world(world_id).blueprint, Pack.blueprint(1847)), "Talents never change the World Blueprint")
	store.close()

func _test_stat_and_survival_effects() -> void:
	var store := _store("stats")
	var session := _session(store, "Stats")
	_force(session, "")
	var base_max := int(session.combat_stats().max_hp)
	_force(session, "core:talent/thick_skin")
	check(int(session.combat_stats().max_hp) == base_max + 4 and int(session.effective_stats().breakdown.max_hp.talent) == 4 and int(session.effective_stats().breakdown.max_hp.gear) == 0, "Thick Skin: passive +4 max HP shown as a talent source, not gear")
	_force(session, "core:talent/berserker")
	check(int(session.combat_stats().defense) == 0, "Berserker trade-off: defense -1 at all times")
	_force(session, "core:talent/undying")
	check(int(session.combat_stats().max_hp) == base_max * 85 / 100 and int(session.stats().hp) <= int(session.combat_stats().max_hp), "Undying trade-off: max HP -15%% (%d), current HP clamped" % int(session.combat_stats().max_hp))
	# Hunger over 20 waits: control vs Iron Stomach in identical runs.
	var control := _run(store, session.world.world_id, 909)
	_force(control, "")
	var stomach := _run(store, session.world.world_id, 909)
	var record := _force(stomach, "core:talent/iron_stomach")
	for _i in 20:
		control.wait_turn()
		stomach.wait_turn()
	check(int(control.stats().hunger) - int(stomach.stats().hunger) == 4, "Iron Stomach: every 5th turn hunger -1 (20 turns: %d vs %d)" % [int(stomach.stats().hunger), int(control.stats().hunger)])
	check(TalentText.status(stomach.talent_definition("core:talent/iron_stomach", 1).payload.abilities[0], record, 20).is_empty() and int(record.state.slow_hunger.used) == 4, "Trigger counters are stored per ability (4 activations)")
	stomach.stats().hunger = 500
	_give(stomach, "core:berries", 2)
	check(stomach.use_item("core:berries") and int(stomach.stats().hunger) == 500 + 1 - 150 and not _talent_events(stomach, "core:talent/iron_stomach").is_empty(), "Iron Stomach: food sates +25% (120 → 150) and reports the talent")
	# Fate Reversal's toll: hunger and thirst grow faster.
	var toll := _run(store, session.world.world_id, 909)
	_force(toll, "core:talent/fate_reversal")
	for _i in 8:
		toll.wait_turn()
	check(int(toll.stats().hunger) == 8 + 2 and int(toll.stats().thirst) == 16 + 2, "Heaven's toll: +1 hunger/thirst every 4 turns (hunger %d, thirst %d after 8)" % [int(toll.stats().hunger), int(toll.stats().thirst)])
	# Bloodthirst: healing items are halved; refused uses spend nothing.
	var blood := _run(store, session.world.world_id, 910)
	_force(blood, "core:talent/bloodthirst")
	_give(blood, "core:herb", 2)
	blood.stats().hp = 10
	check(blood.use_item("core:herb") and int(blood.stats().hp) == 12 and int(blood.run.state.inventory["core:herb"].quantity) == 1, "Bloodthirst trade-off: a herb heals 2 instead of 5")
	blood.stats().hp = int(blood.combat_stats().max_hp)
	var before: Dictionary = blood.run.state.character.talents[0].state.duplicate(true)
	check(not blood.use_item("core:herb") and Acceptance.same(blood.run.state.character.talents[0].state, before), "A refused item use spends no talent activation")
	store.close()

func _test_gathering_and_exploration() -> void:
	var store := _store("gather")
	var session := _session(store, "Gather", "forest", 101)
	_force(session, "core:talent/forager")
	var found := Helpers.route_to_object(session, "gather")
	if check(not found.is_empty() and Helpers.walk(session, found.route), "Reach a resource to gather"):
		var instance: Dictionary = found.instance
		var definition: Dictionary = session.objects.definition_for(instance)
		var key := "loot-v1/%d/%d/%d/%s@%d/%s" % [session.world.seed, session.world.generation_version, session.run.seed, instance.content_id, instance.version, instance.instance_id]
		var base: Array = session.loot_for(definition, key)
		var preview: Array = session.preview_loot(instance.instance_id)
		var base_total := 0
		var bonus_total := 0
		for drop in base:
			base_total += int(drop.quantity)
		for drop in preview:
			bonus_total += int(drop.quantity)
		check(session.interact(instance.instance_id) and bonus_total == base_total + maxi(1, base_total / 2), "Forager: +50%% yield (%d → %d)" % [base_total, bonus_total])
		check(Acceptance.same(session.run.state.entity_mutations[instance.instance_id].loot, preview) and not _talent_events(session, "core:talent/forager").is_empty(), "Receipt equals the talent-aware preview; activation reported")
	# Lucky Star: a chest gives its base roll plus one extra roll, exactly once.
	var lucky := _session(store, "Lucky", "forest", 202)
	_force(lucky, "core:talent/lucky_star")
	var chest := Helpers.route_to_object(lucky, "open")
	if check(not chest.is_empty() and Helpers.walk(lucky, chest.route), "Reach a chest"):
		var instance: Dictionary = chest.instance
		var definition: Dictionary = lucky.objects.definition_for(instance)
		var key := "loot-v1/%d/%d/%d/%s@%d/%s" % [lucky.world.seed, lucky.world.generation_version, lucky.run.seed, instance.content_id, instance.version, instance.instance_id]
		var base: Array = lucky.loot_for(definition, key)
		var preview: Array = lucky.preview_loot(instance.instance_id)
		check(preview.size() > base.size() and Acceptance.same(preview.slice(0, base.size()), base), "Lucky Star: chest preview = unchanged base loot + an extra roll")
		check(lucky.interact(instance.instance_id) and Acceptance.same(lucky.run.state.entity_mutations[instance.instance_id].loot, preview), "Opening pays the talent-aware preview")
		lucky.save()
		var again := Session.new(store)
		check(again.resume(lucky.run.run_id) and not again.interact(instance.instance_id) and Acceptance.same(again.run.state.inventory, lucky.run.state.inventory), "Reload cannot pay the chest (or its talent bonus) twice")
	# Spirit Eye: hidden caches are invisible and unusable without perception.
	var hunted := {}
	var seer: RefCounted = null
	var path: Array = []
	for seed_value in [101, 202, 303, 404, 505, 606]:
		seer = _session(store, "Seer %d" % seed_value, "meadow", seed_value)
		_force(seer, "")
		var caches: Array = []
		for chunk in seer.objects.chunks.values():
			caches.append_array(chunk.filter(func(instance: Dictionary) -> bool: return instance.content_id == "core:buried_cache"))
		caches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return absi(int(a.position.x) - seer.position.x) + absi(int(a.position.y) - seer.position.y) < absi(int(b.position.x) - seer.position.x) + absi(int(b.position.y) - seer.position.y))
		for instance in caches.slice(0, 3):
			path = Acceptance.route(seer, func(tile: Vector2i) -> bool: return absi(tile.x - int(instance.position.x)) + absi(tile.y - int(instance.position.y)) <= 1)
			if not path.is_empty() and path.size() < 120:
				hunted = instance
				break
		if not hunted.is_empty():
			break
	if check(not hunted.is_empty(), "A reachable buried cache exists in the loaded chunks"):
		check(not seer.perceives(hunted) and not seer.nearby_objects().has(hunted) and Helpers.route_to_object(seer, "pickup").get("instance", {}).get("instance_id") != hunted.instance_id, "Without perception the cache is not visible or targetable")
		var reached := Helpers.walk(seer, path)
		if check(reached, "Walk next to the hidden cache"):
			var turn := int(seer.run.state.turn)
			check(not seer.interact(hunted.instance_id) and int(seer.run.state.turn) == turn and not seer.is_consumed(hunted.instance_id), "Interacting with an unperceived cache is refused (no turn)")
			_force(seer, "core:talent/spirit_eye")
			check(seer.perceives(hunted) and seer.senses(Vector2i(int(hunted.position.x), int(hunted.position.y))) and seer.nearby_objects().any(func(instance: Dictionary) -> bool: return instance.instance_id == hunted.instance_id), "Spirit Eye: the cache becomes visible and sensed")
			var coins := int(seer.run.state.inventory.get("core:coin", {}).get("quantity", 0))
			check(seer.interact(hunted.instance_id) and int(seer.run.state.inventory.get("core:coin", {}).get("quantity", 0)) >= coins + 4, "Spirit Eye: the hidden cache can be dug up for its loot")
	# Wayfarer: newly explored tiles add progress; every 60 grant berries, stored exactly.
	var walker := _session(store, "Wayfarer", "meadow", 404)
	var record := _force(walker, "core:talent/wayfarer")
	var start: Vector2i = walker.position
	var far: Array = Acceptance.route(walker, func(tile: Vector2i) -> bool: return absi(tile.x - start.x) + absi(tile.y - start.y) >= 45)
	var granted := 0
	for tile in far:
		if not walker.try_move(tile - walker.position):
			walker.wait_turn()
			break
		for event in _talent_events(walker, "core:talent/wayfarer"):
			granted += event.received.size()
		if int(TalentRuntime_state(record, "trail_berries").used) >= 1:
			break
	var state := TalentRuntime_state(record, "trail_berries")
	check(granted >= 1 and state.used >= 1 and int(walker.run.state.inventory.get("core:berries", {}).get("quantity", 0)) >= 2 and state.progress < 60, "Wayfarer: exploring 60 new tiles finds berries (progress %d/60 carried)" % state.progress)
	check(walker.save(), "Save exploration progress")
	var resumed := Session.new(store)
	check(resumed.resume(walker.run.run_id) and Acceptance.same(resumed.run.state.character.talents, walker.run.state.character.talents) and Acceptance.same(resumed.run.state.inventory, walker.run.state.inventory), "Exploration progress and granted items reload exactly")
	var berries := int(resumed.run.state.inventory.get("core:berries", {}).get("quantity", 0))
	resumed.wait_turn()
	check(int(resumed.run.state.inventory.get("core:berries", {}).get("quantity", 0)) == berries, "Waiting (no new tiles) grants nothing; a reload never re-grants")
	store.close()

static func _total_xp(session: RefCounted) -> int:
	var track: Dictionary = session.run.state.character.progression.adventurer
	var total := int(track.xp)
	for at_level in range(1, int(track.level)):
		total += session.character_rules.xp_to_next("adventurer", at_level)
	return total

static func TalentRuntime_state(record: Dictionary, ability_id: String) -> Dictionary:
	return preload("res://src/core/talent_runtime.gd").state(record, ability_id)

func _test_combat_effects() -> void:
	var store := _store("combat")
	var session := _session(store, "Combat", "forest", 101)
	_force(session, "core:talent/beast_hunter")
	var wolf := _creature(session, "core:wolf", 14)
	var rabbit := _creature(session, "core:rabbit", 6)
	var base := Combat.resolve(session.combat_stats(), {"hp": 14, "defense": 1}, "probe")
	check(int(session.talent_strike(wolf, base).result.damage) == int(base.damage) + 2 and int(session.talent_strike(rabbit, base).result.damage) == int(base.damage), "Beast Hunter: +2 damage against beasts only (condition)")
	var finishing: Dictionary = session.talent_strike(_creature(session, "core:rabbit", 1), base)
	check(finishing.result.killed and finishing.kill.size() == 1 and finishing.kill[0].ability.id == "hunters_lore", "Beast Hunter: kills of beasts/herbivores trigger the XP bonus")
	# A real fight: XP of the kill includes the +50% bonus exactly once.
	var prey := Acceptance.nearest_creature(session, ["neutral"])
	var killed := false
	var xp_before := _total_xp(session)
	for _step in 300:
		if prey.is_empty() or session.is_dead():
			break
		var creature: Dictionary = session.roster.creatures[prey.instance_id]
		if creature.dead:
			killed = true
			break
		var step := Acceptance.step_toward_creature(session, creature)
		if step == Vector2i.ZERO and absi(creature.position.x - session.position.x) + absi(creature.position.y - session.position.y) == 1:
			session.attack_target(prey.instance_id)
		elif step == Vector2i.ZERO or not session.try_move(step):
			session.wait_turn()
	if check(killed, "Kill a creature in a real fight"):
		var category: String = prey.definition.metadata.category
		var expected: int = session.character_rules.kill_xp(prey.definition.payload.stats) * (150 if category in ["beast", "herbivore"] else 100) / 100
		var gained := _total_xp(session) - xp_before
		check(gained == expected, "Real kill XP uses the talent bonus (%s: %d XP)" % [category, gained])
	# Berserker only rages below half HP.
	_force(session, "core:talent/berserker")
	session.stats().hp = int(session.combat_stats().max_hp)
	var calm: Dictionary = session.talent_strike(wolf, base)
	session.stats().hp = int(session.combat_stats().max_hp) / 2 - 1
	var furious: Dictionary = session.talent_strike(wolf, base)
	check(int(calm.result.damage) == int(base.damage) and int(furious.result.damage) == int(base.damage) + 1 + int(base.damage) * 60 / 100, "Berserker: +60%% damage +1 only while HP is below half (%d → %d)" % [int(base.damage), int(furious.result.damage)])
	# Bloodthirst lifesteal and kill heal go through the accepted strike only.
	_force(session, "core:talent/bloodthirst")
	session.stats().hp = 10
	var strike: Dictionary = session.talent_strike(_creature(session, "core:wolf", 3), {"damage": 10, "variance": 0, "hp": 0, "killed": true})
	var result := {"events": [], "talent": strike}
	session._apply_strike(result)
	check(int(session.stats().hp) == 10 + 1 + 3 and result.events.size() == 2, "Bloodthirst: lifesteal 35% of the 3 damage dealt (+1 HP) and +3 HP on a kill")
	# Lucky Star: a kill gets an extra roll with a deterministic 35% chance per creature.
	_force(session, "core:talent/lucky_star")
	var lucky := 0
	for index in 400:
		lucky += session.talent_strike(_creature(session, "core:wolf", 1, "crt:test/%d" % index), base).kill.size()
	check(lucky > 100 and lucky < 180 and session.talent_strike(_creature(session, "core:wolf", 1, "crt:test/7"), base).kill.size() == session.talent_strike(_creature(session, "core:wolf", 1, "crt:test/7"), base).kill.size(), "Lucky Star: extra kill loot about 35%% of the time, fixed per creature (%d/400)" % lucky)
	store.close()

func _test_hit_taken_and_limits() -> void:
	var store := _store("guard")
	var session := _session(store, "Guard", "forest", 101)
	var wolf := _creature(session, "core:wolf", 14)
	var record := _force(session, "core:talent/second_wind")
	var player := {"hp": 20, "max_hp": 30, "attack": 5, "defense": 1}
	var guarded: Dictionary = session.talent_guard(wolf, player, {"damage": 12, "hp": 8, "killed": false})
	check(int(guarded.hp) == 8 + 9 and int(record.state.second_wind.cooldown_until) == int(session.run.state.turn) + 40, "Second Wind: below 35%% HP after a hit, heal 30%% of max; 40-turn cooldown starts")
	var cooling: Dictionary = session.talent_guard(wolf, player, {"damage": 12, "hp": 8, "killed": false})
	check(int(cooling.hp) == 8 and cooling.events.is_empty(), "Cooldown blocks the next activation")
	check(int(session.talent_guard(wolf, {"hp": 30, "max_hp": 30}, {"damage": 5, "hp": 25, "killed": false}).hp) == 25, "Condition not met (HP above 35%): no heal")
	session.save()
	var resumed := Session.new(store)
	check(resumed.resume(session.run.run_id) and int(resumed.run.state.character.talents[0].state.second_wind.cooldown_until) == int(record.state.second_wind.cooldown_until) and resumed.talent_guard(wolf, player, {"damage": 12, "hp": 8, "killed": false}).events.is_empty(), "Cooldown state survives reload (no reset by save/load)")
	# Undying: two escapes per run, 60-turn cooldown, recovery after the escape.
	var undying := _force(session, "core:talent/undying")
	var max_hp := int(session.combat_stats().max_hp)
	var lethal: Dictionary = session.talent_guard(wolf, {"hp": 4, "max_hp": max_hp}, {"damage": 9, "hp": 0, "killed": true})
	check(int(lethal.hp) == 1 + max_hp * 20 / 100 and int(undying.state.refuse_death.used) == 1, "Undying: a killing blow leaves 1 HP, then recovery heals 20%% (HP %d)" % int(lethal.hp))
	check(int(session.talent_guard(wolf, {"hp": 4, "max_hp": max_hp}, {"damage": 9, "hp": 0, "killed": true}).hp) == 0, "Undying: during its cooldown a killing blow kills")
	session.run.state.turn = int(session.run.state.turn) + 61
	check(int(session.talent_guard(wolf, {"hp": 4, "max_hp": max_hp}, {"damage": 9, "hp": 0, "killed": true}).hp) > 0 and int(undying.state.refuse_death.used) == 2, "Undying: second escape after the cooldown")
	session.run.state.turn = int(session.run.state.turn) + 61
	check(int(session.talent_guard(wolf, {"hp": 4, "max_hp": max_hp}, {"damage": 9, "hp": 0, "killed": true}).hp) == 0, "Undying: charges spent (2 per run), the third killing blow kills")
	# Fate Reversal negates about 20% of hits, fixed per creature and turn.
	_force(session, "core:talent/fate_reversal")
	var negated := 0
	for index in 400:
		var outcome: Dictionary = session.talent_guard(_creature(session, "core:wolf", 14, "crt:test/%d" % index), {"hp": 20, "max_hp": 30}, {"damage": 6, "hp": 14, "killed": false})
		negated += 1 if int(outcome.damage) == 0 and int(outcome.hp) == 20 else 0
	check(negated > 50 and negated < 115, "Fate Reversal: about 20%% of blows never happened (%d/400)" % negated)
	# Real path: a hostile creature's hit goes through the talent before death is decided.
	var fighter := _session(store, "Undying fight", "forest", 303)
	_force(fighter, "core:talent/undying")
	var wolf_live := Acceptance.nearest_creature(fighter, ["hostile"])
	var saved := false
	for _step in 250:
		if wolf_live.is_empty() or fighter.is_dead():
			break
		var creature: Dictionary = fighter.roster.creatures[wolf_live.instance_id]
		var step := Acceptance.step_toward_creature(fighter, creature)
		if step == Vector2i.ZERO and absi(creature.position.x - fighter.position.x) + absi(creature.position.y - fighter.position.y) == 1:
			fighter.stats().hp = 1
			fighter.wait_turn()
			if not _talent_events(fighter, "core:talent/undying").is_empty():
				saved = true
				break
		elif step == Vector2i.ZERO or not fighter.try_move(step):
			fighter.wait_turn()
	check(saved and not fighter.is_dead() and int(fighter.stats().hp) > 0, "Real creature hit at 1 HP: Undying keeps the player alive")
	store.close()

func _test_growth_and_no_stacking() -> void:
	var store := _store("growth")
	var session := _session(store, "Growth", "forest", 101)
	var record := _force(session, "core:talent/fate_reversal")
	var before: Dictionary = session.combat_stats().duplicate()
	var base := Combat.resolve(session.combat_stats(), {"hp": 1, "defense": 0}, "grow")
	var passive_kill: Dictionary = session.talent_strike(_creature(session, "core:rabbit", 1), base)
	check(passive_kill.kill.is_empty(), "Fate Reversal grows only from hostile or neutral foes (condition)")
	for index in 3:
		var result := {"events": [], "talent": session.talent_strike(_creature(session, "core:wolf", 1, "crt:grow/%d" % index), base)}
		session._apply_strike(result)
	check(int(session.combat_stats().max_hp) == int(before.max_hp) + 6 and int(session.combat_stats().attack) == int(before.attack) + 3 and int(record.state.devour_fate.used) == 3, "Three kills: +6 max HP, +3 attack, derived from a stored counter")
	check(int(session.stats().max_hp) == int(Combat.PLAYER_DEFAULTS.max_hp) and not session.run.state.character.stats.has("talent"), "Growth is never written into base stats")
	for index in range(3, 40):
		session._apply_strike({"events": [], "talent": session.talent_strike(_creature(session, "core:wolf", 1, "crt:grow/%d" % index), base)})
	check(int(session.combat_stats().max_hp) == int(before.max_hp) + 50 and int(session.combat_stats().attack) == int(before.attack) + 15, "Growth stops at its data caps (25 / 15 stacks)")
	var effective: Dictionary = session.effective_stats().duplicate(true)
	for _i in 3:
		session.refresh_stats()
		session.reload_talents()
	check(Acceptance.same(session.effective_stats(), effective), "Recomputing never stacks talent modifiers")
	check(session.save(), "Save grown talent")
	var loads := true
	for _i in 3:
		var again := Session.new(store)
		loads = loads and again.resume(session.run.run_id) and Acceptance.same(again.effective_stats(), effective) and Acceptance.same(again.run.state.character.talents, session.run.state.character.talents)
	check(loads, "Three reloads: identical stats and talent counters (no duplicated effects)")
	var unsaved := Session.new(store)
	unsaved.resume(session.run.run_id)
	unsaved.run.state.character.talents[0].state.devour_fate.used = 0
	unsaved.reload_talents()
	var reloaded := Session.new(store)
	check(reloaded.resume(session.run.run_id) and Acceptance.same(reloaded.effective_stats(), effective), "Unsaved talent changes do not leak into the saved run")
	store.close()

func _test_persistence_and_compatibility() -> void:
	var store := _store("compat")
	var session := _session(store, "Compat", "meadow", 515)
	var world_id: String = session.world.world_id
	var expected: Array = session.run.state.character.talents.duplicate(true)
	# A Checkpoint C-era save: no talents key at all.
	var legacy: Dictionary = store.load_run(session.run.run_id)
	legacy.state.character.erase("talents")
	store.save_run(session.run.run_id, int(legacy.revision), legacy.state)
	var old := Session.new(store)
	check(old.resume(session.run.run_id) and old.awakened_now.size() == 1 and old.dirty and old.run.state.character.talents[0].content_id == expected[0].content_id, "A save from before talents awakens once on load, with the same deterministic draw")
	check(old.save(), "Save the awakened legacy run")
	var again := Session.new(store)
	check(again.resume(session.run.run_id) and again.awakened_now.is_empty() and Acceptance.same(again.run.state.character.talents, old.run.state.character.talents), "After its first save the legacy run keeps that talent")
	# Checkpoint B-era save: also no equipment/progression.
	var b_era := _run(store, world_id, 616)
	var stored: Dictionary = store.load_run(b_era.run.run_id)
	for key in ["talents", "equipment", "progression"]:
		stored.state.character.erase(key)
	store.save_run(b_era.run.run_id, int(stored.revision), stored.state)
	var b_load := Session.new(store)
	check(b_load.resume(b_era.run.run_id) and b_load.run.state.character.talents.size() == 1 and b_load.run.state.character.equipment.is_empty() and b_load.character_rules.level(b_load.run.state.character) == 1, "A Checkpoint B save loads: level 1, no gear, one awakened talent")
	# An explicitly empty talent list is respected (no awakening).
	var empty := _run(store, world_id, 717)
	_force(empty, "")
	empty.save()
	var empty_load := Session.new(store)
	check(empty_load.resume(empty.run.run_id) and empty_load.run.state.character.talents.is_empty() and empty_load.awakened_now.is_empty(), "A run that holds no talent stays without one")
	# Corrupt talent records are refused and the save is left unchanged.
	var corruptions := {
		"unknown talent": func(state: Dictionary) -> void: state.character.talents[0].content_id = "core:talent/nope",
		"rank mismatch": func(state: Dictionary) -> void: state.character.talents[0].rank = "SSS" if state.character.talents[0].rank != "SSS" else "F",
		"future version": func(state: Dictionary) -> void: state.character.talents[0].awakening_version = 9,
		"unknown ability state": func(state: Dictionary) -> void: state.character.talents[0].state["ghost"] = {"used": 1},
		"not a list": func(state: Dictionary) -> void: state.character.talents = {"F": 1},
	}
	for label in corruptions:
		var victim := _run(store, world_id, 800 + label.length())
		var saved: Dictionary = store.load_run(victim.run.run_id)
		corruptions[label].call(saved.state)
		store.save_run(victim.run.run_id, int(saved.revision), saved.state)
		var snapshot: Dictionary = store.load_run(victim.run.run_id)
		var refused := Session.new(store)
		check(not refused.resume(victim.run.run_id) and refused.last_error.contains("save was not changed") and Acceptance.same(store.load_run(victim.run.run_id), snapshot), "Corrupt talent record refused (%s): %s" % [label, refused.last_error])
	# Permadeath: Undying's spent charge is committed with the risky turn.
	var hardcore := _run(store, world_id, 818, "forest", "permadeath")
	var undying := _force(hardcore, "core:talent/undying")
	hardcore.save()
	var wolf := _creature(hardcore, "core:wolf", 14)
	hardcore.stats().hp = int(hardcore.talent_guard(wolf, {"hp": 2, "max_hp": int(hardcore.combat_stats().max_hp)}, {"damage": 9, "hp": 0, "killed": true}).hp)
	hardcore.wait_turn()
	var committed: Dictionary = store.load_run(hardcore.run.run_id)
	check(int(committed.state.character.talents[0].state.refuse_death.used) == 1 and int(undying.state.refuse_death.used) == 1, "Permadeath commits the spent escape on the next (risky) turn")
	store.close()
