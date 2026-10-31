extends SceneTree
## Milestone 02 Checkpoint C: quality tiers, equipment, modifiers, loot, progression.
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Data = preload("res://src/data/json_data.gd")
const Pack = preload("res://src/content/starter_pack.gd")
const ItemQuality = preload("res://src/core/item_quality.gd")
const CharacterStats = preload("res://src/core/character_stats.gd")
const Equipment = preload("res://src/core/equipment.gd")
const Combat = preload("res://src/core/combat.gd")
const Inventory = preload("res://src/core/inventory.gd")
const Loot = preload("res://src/core/loot_table.gd")
const Acceptance = preload("res://src/acceptance/standalone_check.gd")
const VI_NAMES := ["Phế Phẩm", "Phổ Thông", "Ưu Tú", "Hiếm Có", "Sử Thi", "Truyền Thuyết", "Thần Thoại", "Chí Tôn", "Thần Thánh", "Tối Thượng"]
var checks := 0
var failures := 0
var directory := ""

func _initialize() -> void:
	directory = ProjectSettings.globalize_path("user://m02c_tests/" + Data.uuid())
	DirAccess.make_dir_recursive_absolute(directory)
	print("Equipment artifacts: ", directory)
	_test_quality()
	_test_starting_kit_and_equip()
	_test_modifiers_and_combat()
	_test_loot()
	_test_progression()
	_test_persistence_and_compatibility()
	print("M02 CHECKPOINT C EQUIPMENT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(condition: bool, label: String) -> bool:
	checks += 1
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)
	return condition

func _session(store: RefCounted, name: String, biome: String = "meadow", seed_value: int = 101, mode: String = "normal") -> RefCounted:
	var world: Dictionary = store.create_world(name, 1847, 1, Pack.blueprint(1847))
	var session := Session.new(store)
	check(session.start_new(world.world_id, seed_value, biome, mode), "Start %s run" % name)
	session.autosave_interval = 0
	return session

func _give(session: RefCounted, content_id: String, tier: String, key: String) -> String:
	## Award one instance through the real inventory path; returns its instance ID.
	var award := Inventory.new().award(session.store.content, session.world.world_id, session.run.state.inventory, [{"content_id": content_id, "version": 1, "quantity": 1, "quality": tier}], "test:" + key)
	session.run.state.inventory = award.inventory
	return session.run.state.inventory[content_id].instances.back().instance_id

func _count(session: RefCounted, content_id: String) -> int:
	var total := int(session.run.state.inventory.get(content_id, {}).get("quantity", 0))
	for slot in session.run.state.character.equipment:
		total += 1 if session.run.state.character.equipment[slot].content_id == content_id else 0
	return total

func _all_ids(session: RefCounted) -> Array:
	var ids: Array = []
	for content_id in session.run.state.inventory:
		for record in session.run.state.inventory[content_id].get("instances", []):
			ids.append(record.instance_id)
	for slot in session.run.state.character.equipment:
		ids.append(session.run.state.character.equipment[slot].instance_id)
	ids.sort()
	return ids

func _test_quality() -> void:
	var tiers := ItemQuality.new()
	check(tiers.load_rules(), "Quality tiers load from central data")
	check(tiers.tiers.size() == 10 and tiers.tiers.map(func(t: Dictionary) -> String: return t.name) == VI_NAMES, "Exactly 10 tiers in the official order with Vietnamese names")
	var ranks: Array = tiers.tiers.map(func(t: Dictionary) -> int: return int(t.rank))
	check(ranks == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10] and tiers.rank("phe_pham") < tiers.rank("pho_thong") and tiers.rank("than_thanh") < tiers.rank("toi_thuong"), "Ranks are strictly ordered Scrap → Paramount")
	check(tiers.tier("chi_ton").style == "platinum" and tiers.tier("than_thanh").style == "black_gold" and tiers.tier("toi_thuong").style == "rainbow", "Supreme / Divine / Paramount have platinum, black-gold and rainbow styles")
	check(tiers.color("toi_thuong", 0.0) != tiers.color("toi_thuong", 1.0), "Rainbow tier color animates over time")
	check(not tiers.has("legendary_plus") and tiers.of({"payload": {"quality": "nope"}}) == "", "Unknown tier IDs are not accepted")
	check(tiers.of({"payload": {"quality": "pho_thong"}}, {"quality": "su_thi"}) == "su_thi" and tiers.of({"payload": {"quality": "pho_thong"}}) == "pho_thong", "Instance quality overrides the definition default (works for any item kind)")
	check(not tiers.tier("su_thi").has("weight") and not tiers.tier("su_thi").has("chance"), "Quality carries no drop chance: rarity lives in loot tables")

func _test_starting_kit_and_equip() -> void:
	var store := Store.new()
	store.open(directory + "/equip.sqlite")
	var session := _session(store, "Equip")
	var club: Dictionary = session.run.state.character.equipment.get("weapon", {})
	check(club.get("content_id") == "core:wooden_club" and club.metadata.quality == "pho_thong" and club.instance_id.begins_with("item:") and session.run.state.inventory.is_empty(), "New run starts with a Common wooden club equipped and an empty inventory")
	check(int(session.combat_stats().attack) == 7 and int(session.effective_stats().breakdown.attack.gear) == 2, "Effective ATK = 5 base + 2 club")
	var blade := _give(session, "core:traveler_blade", "uu_tu", "blade")
	var ids_before := _all_ids(session)
	var turn := int(session.run.state.turn)
	check(not session.equip_item("core:traveler_blade", "item:missing") and int(session.run.state.turn) == turn, "Unknown instance cannot be equipped; no turn")
	session.run.state.inventory = Inventory.new().award(store.content, session.world.world_id, session.run.state.inventory, [{"content_id": "core:berries", "version": 1, "quantity": 2}], "test:berries").inventory
	check(not session.equip_item("core:berries", "") and session.last_error.contains("cannot be equipped") and session.run.state.inventory["core:berries"].quantity == 2, "Non-equipment item cannot be equipped and is kept")
	check(session.equip_item("core:traveler_blade", blade) and int(session.run.state.turn) == turn + 1, "Equip blade spends one turn")
	check(session.run.state.character.equipment.weapon.instance_id == blade and session.run.state.character.equipment.weapon.metadata.quality == "uu_tu", "Blade sits in the weapon slot with its own ID and quality")
	check(session.run.state.inventory["core:wooden_club"].instances[0].instance_id == club.instance_id and session.run.state.inventory["core:wooden_club"].instances[0].metadata.quality == "pho_thong", "Replaced club returns to inventory with its ID and metadata")
	check(_all_ids(session) == ids_before and _count(session, "core:wooden_club") == 1 and _count(session, "core:traveler_blade") == 1, "Equip/replace conserves every item instance (no loss, no duplicate)")
	check(int(session.combat_stats().attack) == 5 + 4 * 115 / 100, "Fine (+15%%) blade: ATK 5 + 4 → %d" % int(session.combat_stats().attack))
	var sword := _give(session, "core:iron_sword", "hiem_co", "sword")
	turn = int(session.run.state.turn)
	check(not session.equip_item("core:iron_sword", sword) and session.last_error.contains("Requires level 3") and int(session.run.state.turn) == turn and session.run.state.character.equipment.weapon.instance_id == blade, "Level requirement enforced; nothing changes, no turn")
	check(session.unequip_slot("weapon") and not session.run.state.character.equipment.has("weapon") and session.run.state.inventory["core:traveler_blade"].quantity == 1 and int(session.combat_stats().attack) == 5, "Unequip returns the item and removes its stats")
	turn = int(session.run.state.turn)
	check(not session.unequip_slot("weapon") and not session.unequip_slot("tail") and int(session.run.state.turn) == turn, "Unequipping an empty or unknown slot is refused; no turn")
	# Pure layer: a slot can only take its own items.
	var direct := Equipment.equip(session.run.state.inventory, session.run.state.character.equipment, "core:traveler_blade", "item:nope", "weapon")
	check(direct.has("error"), "Pure equip refuses an instance that is not in the inventory")
	check(not session.character_rules.validate_equipment({"kind": "item", "payload": {"stackable": false, "stack_limit": 1, "equipment": {"slot": "tail", "stats": {}}}}).is_empty(), "Unknown slot is rejected by validation")
	check(not session.character_rules.validate_equipment({"kind": "item", "payload": {"stackable": true, "stack_limit": 5, "equipment": {"slot": "weapon", "stats": {}}}}).is_empty(), "Stackable items cannot be equipment")
	store.close()

func _test_modifiers_and_combat() -> void:
	var store := Store.new()
	store.open(directory + "/modifiers.sqlite")
	var session := _session(store, "Modifiers", "forest")
	var armor := _give(session, "core:hide_armor", "pho_thong", "armor")
	var charm := _give(session, "core:fang_charm", "pho_thong", "charm")
	check(session.equip_item("core:hide_armor", armor) and int(session.combat_stats().max_hp) == 35 and int(session.combat_stats().defense) == 3, "Armor adds DEF and max HP (35 max, DEF 3)")
	check(session.equip_item("core:fang_charm", charm) and int(session.combat_stats().attack) == (5 + 2 + 1) * 110 / 100, "Charm adds +1 ATK then +10%%: ATK %d" % int(session.combat_stats().attack))
	var before: Dictionary = session.effective_stats().duplicate(true)
	for _i in 3:
		session.refresh_stats()
	check(Acceptance.same(session.effective_stats(), before), "Recomputing stats never stacks modifiers")
	for _i in 2:
		session.unequip_slot("accessory")
		session.equip_item("core:fang_charm", charm)
	check(Acceptance.same(session.effective_stats(), before), "Equip/unequip cycles return exactly the same stats")
	session.stats().hp = 35
	check(session.unequip_slot("armor") and int(session.stats().hp) == 30, "Removing max HP gear clamps current HP to the new maximum")
	session.equip_item("core:hide_armor", armor)
	# Combat uses effective stats: compare a real attack with the same deterministic roll.
	var prey := Acceptance.nearest_creature(session, ["neutral"])
	var reached := false
	for _step in 200:
		if prey.is_empty() or session.is_dead():
			break
		var creature: Dictionary = session.roster.creatures[prey.instance_id]
		var step := Acceptance.step_toward_creature(session, creature)
		if step == Vector2i.ZERO and absi(creature.position.x - session.position.x) + absi(creature.position.y - session.position.y) == 1:
			reached = true
			break
		if step == Vector2i.ZERO or not session.try_move(step):
			session.wait_turn()
	if check(reached, "Reach a creature to fight"):
		var creature: Dictionary = session.roster.creatures[prey.instance_id]
		var key := "hit-v1/%d/%d/%s/%d" % [session.world.seed, session.run.seed, creature.instance_id, int(session.run.state.turn)]
		var expected := Combat.resolve(session.combat_stats(), {"hp": creature.hp, "defense": creature.definition.payload.stats.defense}, key)
		var unarmed := Combat.resolve({"attack": 5}, {"hp": creature.hp, "defense": creature.definition.payload.stats.defense}, key)
		session.attack_target(prey.instance_id)
		check(session.last_events[0].damage == expected.damage and expected.damage > unarmed.damage, "Player hit uses effective ATK from gear (%d vs %d unarmed)" % [expected.damage, unarmed.damage])
		var hits: Array = session.last_events.filter(func(event: Dictionary) -> bool: return event.type == "hit" and event.target == "player")
		if not hits.is_empty():
			check(hits[0].max_hp == 35, "Creature hits are resolved against effective max HP/defense")
	store.close()

func _test_loot() -> void:
	var store := Store.new()
	store.open(directory + "/loot.sqlite")
	var session := _session(store, "Loot")
	check(session.loot_extensions.has("core:wayfarer_cache@1") and session.loot_extensions.has("core:weathered_chest@1") and session.loot_extensions.has("core:wolf@1"), "Loot extensions attach equipment to chosen chests and creatures")
	var resource_sources := 0
	for key in session.loot_extensions:
		var source: Dictionary = store.content.load_definition(session.world.world_id, key.get_slice("@", 0), int(key.get_slice("@", 1)))
		resource_sources += 1 if source.kind == "resource" else 0
	check(resource_sources == 0, "Resources never drop equipment (not every source drops everything)")
	var cache := Acceptance.route_to_object(session, "open", [], "core:wayfarer_cache")
	var landmark: Dictionary = store.content.load_instance(session.world.world_id, "landmark:wayfarer_cache")
	var wolf: Dictionary = store.content.load_definition(session.world.world_id, "core:wolf", 1)
	var counts := {}
	var gear := 0
	for index in 400:
		var loot: Array = session.loot_for(wolf, "probe/%d" % index)
		for drop in loot:
			if drop.content_id == "core:fang_charm":
				gear += 1
				counts[drop.quality] = int(counts.get(drop.quality, 0)) + 1
	check(gear > 40 and gear < 130, "Wolf gear drop rate follows its configured chance (~20%%: %d/400)" % gear)
	var allowed := true
	for tier in counts:
		allowed = allowed and session.quality.rank(tier) <= session.quality.rank("hiem_co")
	check(allowed and counts.size() >= 3, "Wolf charms roll only their configured tiers, no high tiers (%s)" % str(counts))
	check(Acceptance.same(session.loot_for(wolf, "probe/7"), session.loot_for(wolf, "probe/7")), "Equipment loot is deterministic for the same seed key")
	var base_only := Loot.new().roll(wolf.payload.loot, "probe/7")
	check(Acceptance.same(session.loot_for(wolf, "probe/7").slice(0, base_only.size()), base_only), "Extensions append after the unchanged base table (old results not rerolled)")
	# Open the Wayfarer's cache through the real interaction path when it is close enough.
	if not cache.is_empty() and cache.route.size() < 400:
		for tile in cache.route:
			if not session.try_move(tile - session.position):
				session.wait_turn()
				break
		var preview: Array = session.preview_loot("landmark:wayfarer_cache")
		if session.interact("landmark:wayfarer_cache"):
			var blade: Dictionary = session.run.state.inventory.get("core:traveler_blade", {})
			check(not blade.is_empty() and blade.instances[0].metadata.quality == "uu_tu" and blade.instances[0].instance_id.begins_with("item:"), "Wayfarer's cache yields a Fine Traveler's blade as a unique instance")
			check(Acceptance.same(session.run.state.entity_mutations["landmark:wayfarer_cache"].loot, preview), "Received loot equals the deterministic preview (incl. quality)")
			session.save()
			var again := Session.new(store)
			check(again.resume(session.run.run_id) and not again.interact("landmark:wayfarer_cache") and Acceptance.same(again.run.state.inventory, session.run.state.inventory), "Reload keeps the same instance; no second payout")
	else:
		print("NOTE: Wayfarer's cache is far from this spawn; checking its table directly")
		var direct: Array = session.loot_for(store.content.load_definition(session.world.world_id, "core:wayfarer_cache", 1), "probe/cache")
		check(direct.any(func(drop: Dictionary) -> bool: return drop.content_id == "core:traveler_blade" and drop.quality == "uu_tu"), "Wayfarer's cache table yields a Fine Traveler's blade")
	check(not landmark.is_empty(), "Landmark exists")
	_test_chest_gear_through_interaction(store)
	store.close()

func _test_chest_gear_through_interaction(store: RefCounted) -> void:
	## Real path: find a weathered chest whose deterministic loot includes gear,
	## walk there, open it with the normal interact action, verify the instance.
	for seed_value in [101, 202, 303, 404, 505, 606, 707, 808]:
		var session := _session(store, "Chest gear %d" % seed_value, "forest", seed_value)
		for chunk in session.objects.chunks.values():
			for instance in chunk:
				if instance.content_id != "core:weathered_chest":
					continue
				var preview: Array = session.preview_loot(instance.instance_id)
				var gear: Array = preview.filter(func(drop: Dictionary) -> bool: return drop.has("quality"))
				if gear.is_empty():
					continue
				var found := Acceptance.route_to_object(session, "open", [], "core:weathered_chest")
				if found.is_empty() or found.instance.instance_id != instance.instance_id:
					continue
				for tile in found.route:
					if not session.try_move(tile - session.position):
						session.wait_turn()
				if not session.interact(instance.instance_id):
					continue
				var drop: Dictionary = gear[0]
				var records: Array = session.run.state.inventory.get(drop.content_id, {}).get("instances", [])
				check(not records.is_empty() and records.back().metadata.quality == drop.quality and records.back().instance_id.begins_with("item:"), "Opened chest gives %s [%s] as a unique instance" % [drop.content_id, drop.quality])
				check(Acceptance.same(session.run.state.entity_mutations[instance.instance_id].loot, preview), "Chest receipt equals its deterministic preview (base + gear)")
				check(session.save(), "Save chest gear")
				var again := Session.new(store)
				check(again.resume(session.run.run_id) and not again.interact(instance.instance_id) and Acceptance.same(again.run.state.inventory, session.run.state.inventory), "Reload: same gear instance, chest cannot pay twice")
				return
	check(false, "Find a reachable weathered chest with equipment in its loot")

func _test_progression() -> void:
	var tiers := ItemQuality.new()
	tiers.load_rules()
	var rules := CharacterStats.new()
	check(rules.load_rules(tiers), "Character rules load")
	check(int(rules.rules.tracks.adventurer.max_level) == 0, "No hard level cap (data: max_level 0)")
	check(rules.kill_xp({"max_hp": 14, "attack": 5, "defense": 1}) == 14 + 10 + 3, "Kill XP from creature stats via data weights")
	var character := rules.normalize({"stats": {}})
	var events := rules.gain_xp(character, rules.xp_to_next("adventurer", 1) + rules.xp_to_next("adventurer", 2))
	check(character.progression.adventurer.level == 3 and events.filter(func(e: Dictionary) -> bool: return e.type == "level_up").size() == 2, "Exact XP thresholds give level 3 with two level-up events")
	var effective := rules.effective({"max_hp": 30, "attack": 5, "defense": 1}, character, func(_r: Dictionary) -> Dictionary: return {})
	check(effective.stats.max_hp == 36 and effective.stats.attack == 7 and effective.stats.defense == 2 and effective.breakdown.attack.growth == 2, "Growth is separate from base and gear (L3: HP+6, ATK+2, DEF+1)")
	rules.gain_xp(character, 1000000)
	check(character.progression.adventurer.level > 20, "Large XP keeps leveling (no hidden cap): level %d" % character.progression.adventurer.level)
	var store := Store.new()
	store.open(directory + "/xp.sqlite")
	var session := _session(store, "XP", "forest")
	var prey := Acceptance.nearest_creature(session, ["neutral"])
	var killed := false
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
		var xp: int = session.run.state.character.progression.adventurer.xp + (0 if session.character_rules.level(session.run.state.character) == 1 else session.character_rules.xp_to_next("adventurer", 1))
		check(xp == session.character_rules.kill_xp(prey.definition.payload.stats), "Kill grants its XP exactly once (%d)" % xp)
		session.save()
		var resumed := Session.new(store)
		check(resumed.resume(session.run.run_id) and Acceptance.same(resumed.run.state.character.progression, session.run.state.character.progression) and Acceptance.same(resumed.effective_stats(), session.effective_stats()), "Progression and effective stats survive reload unchanged")
	store.close()

func _test_persistence_and_compatibility() -> void:
	var store := Store.new()
	store.open(directory + "/persist.sqlite")
	var a := _session(store, "Persist")
	var blade := _give(a, "core:traveler_blade", "su_thi", "persist")
	a.equip_item("core:traveler_blade", blade)
	var effective: Dictionary = a.effective_stats().duplicate(true)
	check(a.save(), "Save with equipped gear")
	var stored: Dictionary = store.load_run(a.run.run_id)
	check(stored.state.character.equipment.weapon.metadata.quality == "su_thi" and stored.state.character.equipment.weapon.instance_id == blade, "Quality tier ID and instance ID are serialized")
	var resumed := Session.new(store)
	check(resumed.resume(a.run.run_id) and Acceptance.same(resumed.effective_stats(), effective) and Acceptance.same(resumed.run.state.inventory, a.run.state.inventory), "Reload restores gear without stacking modifiers")
	var again := Session.new(store)
	again.resume(a.run.run_id)
	check(Acceptance.same(again.effective_stats(), effective), "Second reload: same stats again")
	var b := Session.new(store)
	check(b.start_new(a.world.world_id, 303, "meadow") and b.run.state.character.equipment.weapon.content_id == "core:wooden_club" and b.run.state.character.equipment.weapon.instance_id != a.run.state.inventory["core:wooden_club"].instances[0].instance_id and not b.run.state.inventory.has("core:traveler_blade"), "Run B has its own starter club; Run A's gear stays in Run A")
	check(Acceptance.same(store.load_world(a.world.world_id).blueprint, Pack.blueprint(1847)), "Equipment never changes the World Blueprint")
	# Corrupt save: the same instance both equipped and in the inventory is refused, untouched.
	var corrupt: Dictionary = store.load_run(a.run.run_id)
	corrupt.state.inventory["core:traveler_blade"] = {"version": 1, "quantity": 1, "instances": [corrupt.state.character.equipment.weapon.duplicate(true)]}
	corrupt.state.inventory["core:traveler_blade"].instances[0].erase("content_id")
	corrupt.state.inventory["core:traveler_blade"].instances[0].erase("version")
	store.save_run(a.run.run_id, int(corrupt.revision), corrupt.state)
	var refused := Session.new(store)
	check(not refused.resume(a.run.run_id) and refused.last_error.contains("both equipped"), "Duplicated item instance in a save is detected and refused")
	# Checkpoint B-era save: no equipment/progression keys at all.
	var legacy: Dictionary = store.load_run(b.run.run_id)
	legacy.state.character.erase("equipment")
	legacy.state.character.erase("progression")
	store.save_run(b.run.run_id, int(legacy.revision), legacy.state)
	var old := Session.new(store)
	check(old.resume(b.run.run_id) and old.run.state.character.equipment.is_empty() and old.character_rules.level(old.run.state.character) == 1 and int(old.combat_stats().attack) == 5, "Checkpoint B save loads: no gear, level 1, base stats (no starter kit added to old runs)")
	store.close()
