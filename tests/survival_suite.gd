extends SceneTree
## Milestone 02 Checkpoint B: survival needs, item use, rest, autosave and
## permadeath durability. Real SQLite, real sessions, separate killed processes.
const Store = preload("res://src/data/game_store.gd")
const Session = preload("res://src/run/exploration_session.gd")
const Data = preload("res://src/data/json_data.gd")
const Pack = preload("res://src/content/starter_pack.gd")
const Survival = preload("res://src/core/survival.gd")
const ItemEffects = preload("res://src/core/item_effects.gd")
const Inventory = preload("res://src/core/inventory.gd")
const Acceptance = preload("res://src/acceptance/standalone_check.gd")
const CHILD_FRAME_LIMIT := "30000"
var checks := 0
var failures := 0
var directory := ""

func _initialize() -> void:
	directory = ProjectSettings.globalize_path("user://m02b_tests/" + Data.uuid())
	DirAccess.make_dir_recursive_absolute(directory)
	print("Survival artifacts: ", directory)
	_test_rules()
	_test_needs_and_recovery()
	_test_item_use()
	_test_rest()
	_test_autosave()
	_test_permadeath_durability()
	_test_permadeath_risk_commits()
	_test_independence_and_legacy()
	print("M02 CHECKPOINT B SURVIVAL: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(condition: bool, label: String) -> bool:
	checks += 1
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		printerr("FAIL: ", label)
	return condition

func _session(store: RefCounted, name: String, biome: String = "meadow", mode: String = "normal", seed_value: int = 101) -> RefCounted:
	var world: Dictionary = store.create_world(name, 1847, 1, Pack.blueprint(1847))
	var session := Session.new(store)
	check(session.start_new(world.world_id, seed_value, biome, mode), "Start %s %s run" % [mode, biome])
	return session

func _give(session: RefCounted, content_id: String, quantity: int) -> void:
	# Test setup through the real inventory award path (stack rules apply).
	var award := Inventory.new().award(session.store.content, session.world.world_id, session.run.state.inventory, [{"content_id": content_id, "version": 1, "quantity": quantity}], "test:" + content_id)
	session.run.state.inventory = award.inventory

func _test_rules() -> void:
	var survival := Survival.new()
	check(survival.load_rules(), "Survival rules load and validate from data")
	var stats := survival.normalize({"hp": 10, "max_hp": 30})
	check(stats.hunger == 0 and stats.thirst == 0 and stats.recovery == 0 and survival.valid_stats(stats), "Older stats get fed/watered survival defaults")
	var broken := survival.rules.duplicate(true)
	broken.needs.hunger.warning = 900
	var file := FileAccess.open(directory + "/bad_rules.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(broken))
	file.close()
	check(not Survival.new().load_rules(directory + "/bad_rules.json"), "Invalid thresholds (warning >= danger) rejected")
	check(ItemEffects.validate([{"type": "teleport", "amount": 1}]) != "" and ItemEffects.validate([{"type": "heal", "amount": 0}]) != "" and ItemEffects.validate([{"type": "heal", "amount": 3}]) == "", "Effect validation accepts only known types and positive amounts")
	var target := {"hp": 28, "max_hp": 30, "hunger": 50, "thirst": 0}
	var changes := ItemEffects.apply(target, [{"type": "heal", "amount": 5}, {"type": "sate", "amount": 120}, {"type": "quench", "amount": 400}])
	check(target.hp == 30 and target.hunger == 0 and changes.size() == 2, "Effects clamp at max HP / zero need; no-op effects are not reported")

func _test_needs_and_recovery() -> void:
	var store := Store.new()
	store.open(directory + "/needs.sqlite")
	var session := _session(store, "Needs")
	session.autosave_interval = 0
	var rules: Dictionary = session.survival.rules
	var stats: Dictionary = session.stats()
	var hunger := int(stats.hunger)
	var thirst := int(stats.thirst)
	session.wait_turn()
	check(stats.hunger == hunger + int(rules.needs.hunger.per_action.default) and stats.thirst == thirst + int(rules.needs.thirst.per_action.default), "One wait turn adds the configured default hunger/thirst")
	var turn := int(session.run.state.turn)
	hunger = int(stats.hunger)
	check(not session.attack_target() and not session.use_item("core:wood") and int(session.run.state.turn) == turn and stats.hunger == hunger, "Refused actions spend no turn and no needs")
	stats.hp = 20
	stats.recovery = 0
	for _turn in 10:
		session.wait_turn()
	check(stats.hp == 21, "Fed character recovers 1 HP per 10 turns (got %d)" % stats.hp)
	stats.hp = int(stats.max_hp) - 1
	stats.recovery = 99
	session.wait_turn()
	session.wait_turn()
	check(stats.hp == stats.max_hp and stats.recovery == 0, "Recovery never exceeds max HP")
	stats.hp = 20
	stats.hunger = int(rules.needs.hunger.warning)
	for _turn in 20:
		session.wait_turn()
	check(stats.hp == 20, "Hungry character does not recover")
	stats.hunger = int(rules.needs.hunger.warning) - 1
	stats.recovery = 0
	session.last_events = []
	session.wait_turn()
	check(session.last_events.any(func(event: Dictionary) -> bool: return event.type == "survival" and event.need == "hunger" and event.level == "warning"), "Crossing a threshold emits a clear warning event")
	stats.thirst = int(rules.scale)
	stats.starvation = 0
	var hp := int(stats.hp)
	for _turn in 5:
		session.wait_turn()
	check(stats.hp == hp - 1 and stats.thirst == rules.scale, "Depleted thirst costs 1 HP every 5 turns, capped at scale")
	check(session.save(), "Save survival state")
	var resumed := Session.new(store)
	check(resumed.resume(session.run.run_id) and Acceptance.same(resumed.stats(), stats), "HP, hunger, thirst, recovery and starvation progress survive reload")
	# Early game cannot kill quickly: 300 turns from a fresh start keeps the player healthy.
	var fresh := _session(store, "Early game")
	fresh.autosave_interval = 0
	for _turn in 300:
		fresh.wait_turn()
	check(not fresh.is_dead() and int(fresh.stats().hp) == int(fresh.stats().max_hp) and fresh.survival.worst_level(fresh.stats()) <= 1, "300 idle turns from a fresh start: no damage, at most a warning")
	store.close()

func _test_item_use() -> void:
	var store := Store.new()
	store.open(directory + "/items.sqlite")
	var session := _session(store, "Items")
	session.autosave_interval = 0
	check(session.uses.has("core:berries@1") and session.uses.has("core:raw_meat@1") and session.uses.has("core:herb@1") and session.uses.has("core:fresh_water@1"), "Item uses come from Content Registry data (incl. existing v1 meat/herb)")
	_give(session, "core:berries", 3)
	_give(session, "core:wood", 2)
	var stats: Dictionary = session.stats()
	var turn := int(session.run.state.turn)
	check(not session.use_item("core:berries") and session.run.state.inventory["core:berries"].quantity == 3 and int(session.run.state.turn) == turn, "Eating while not hungry is refused: nothing consumed, no turn")
	check(not session.use_item("core:wood") and session.run.state.inventory["core:wood"].quantity == 2 and session.last_error.contains("no use"), "Item without a use is refused and kept")
	check(not session.use_item("core:fresh_water") and not session.use_item("core:nonexistent"), "Missing items cannot be used")
	stats.hunger = 500
	turn = int(session.run.state.turn)
	check(session.use_item("core:berries"), "Eat berries when hungry")
	var after_use := int(stats.hunger)
	check(after_use == 500 - 120 + int(session.survival.rules.needs.hunger.per_action.use if session.survival.rules.needs.hunger.per_action.has("use") else session.survival.rules.needs.hunger.per_action.default), "Sate effect applied exactly once, then the turn's hunger cost")
	check(session.run.state.inventory["core:berries"].quantity == 2 and session.run.state.inventory["core:berries"].stacks == [2] and int(session.run.state.turn) == turn + 1, "Exactly one berry consumed; stacks consistent; one turn spent")
	check(session.last_events[0].type == "use" and session.last_events[0].changes[0].stat == "hunger", "Use reports its effect")
	stats.hp = 10
	_give(session, "core:herb", 1)
	check(session.use_item("core:herb") and not session.run.state.inventory.has("core:herb") and stats.hp >= 15, "Herb heals; last unit removes the entry")
	check(session.save(), "Save after using items")
	var inventory: Dictionary = session.run.state.inventory.duplicate(true)
	var reloaded := Session.new(store)
	check(reloaded.resume(session.run.run_id) and Acceptance.same(reloaded.run.state.inventory, inventory) and Acceptance.same(reloaded.stats(), stats), "Reload neither restores used items nor re-applies effects")
	# Unsaved use + reload: the use never happened (both item and effect roll back together).
	reloaded.stats().hunger = 700
	reloaded.use_item("core:berries")
	var again := Session.new(store)
	check(again.resume(session.run.run_id) and again.run.state.inventory["core:berries"].quantity == 2 and int(again.stats().hunger) == int(stats.hunger), "Unsaved use is rolled back atomically on reload")
	# New usable item purely through data, no code change.
	var world_id: String = session.world.world_id
	store.content.register_definition(world_id, {"content_id": "test:tea", "version": 1, "schema_version": 1, "kind": "item", "name": "Herbal tea", "payload": {"stackable": true, "stack_limit": 5}})
	store.content.register_definition(world_id, {"content_id": "test:use/tea", "version": 1, "schema_version": 1, "kind": "item_use", "name": "Drink tea", "dependencies": [{"content_id": "test:tea", "version": 1}], "payload": {"item": {"content_id": "test:tea", "version": 1}, "verb": "Drink", "effects": [{"type": "quench", "amount": 100}, {"type": "heal", "amount": 1}]}})
	var data_driven := Session.new(store)
	check(data_driven.resume(session.run.run_id) and data_driven.uses.has("test:tea@1"), "New consumable registered as data becomes usable after reload")
	store.content.register_definition(world_id, {"content_id": "test:use/bad", "version": 1, "schema_version": 1, "kind": "item_use", "name": "Bad", "dependencies": [{"content_id": "test:tea", "version": 1}], "payload": {"item": {"content_id": "test:tea", "version": 1}, "effects": [{"type": "explode", "amount": 1}]}})
	var refused := Session.new(store)
	check(not refused.resume(session.run.run_id) and refused.last_error.contains("Unsupported item effect"), "Unknown effect types are refused explicitly; no code runs")
	store.close()

func _test_rest() -> void:
	var store := Store.new()
	store.open(directory + "/rest.sqlite")
	var session := _session(store, "Rest", "forest")
	session.autosave_interval = 0
	var stats: Dictionary = session.stats()
	stats.hp = 20
	var turn := int(session.run.state.turn)
	var thirst := int(stats.thirst)
	if not session.threatened():
		check(session.rest(8), "Rest when safe")
		var summary: Dictionary = session.last_result
		check(int(session.run.state.turn) == turn + summary.turns and summary.turns >= 1, "Each rested turn is a real turn (%d)" % summary.turns)
		check(stats.thirst == thirst + summary.turns * int(session.survival.rules.needs.thirst.per_action.rest), "Needs keep changing while resting")
		check(summary.turns < 8 or summary.hp_gained == 2, "Rest recovers faster: +2 HP over 8 turns (%d)" % summary.hp_gained)
	# Walk towards a hostile wolf; once one is in sight resting must be refused.
	var wolf := Acceptance.nearest_creature(session, ["hostile"])
	var moved_creatures := false
	for _step in 120:
		if session.threatened() or wolf.is_empty() or session.is_dead():
			break
		var before: Dictionary = {}
		for id in session.roster.creatures:
			before[id] = session.roster.creatures[id].position
		var step := Acceptance.step_toward_creature(session, wolf)
		if step == Vector2i.ZERO or not session.try_move(step):
			if not session.rest(1):
				session.wait_turn()
		for id in before:
			moved_creatures = moved_creatures or (session.roster.creatures.has(id) and session.roster.creatures[id].position != before[id])
	check(moved_creatures, "Creatures keep acting on the turns the player walks/rests")
	if check(session.threatened(), "A hostile creature comes into sight"):
		turn = int(session.run.state.turn)
		check(not session.rest() and int(session.run.state.turn) == turn and session.last_error.contains("cannot rest"), "Resting with a hostile in sight is refused (no turn)")
	store.close()

func _test_autosave() -> void:
	var store := Store.new()
	store.open(directory + "/autosave.sqlite")
	var session := _session(store, "Autosave")
	var interval := int(session.survival.rules.autosave.normal_interval)
	check(session.save() and not session.dirty, "Manual save")
	var revision := int(store.load_run(session.run.run_id).revision)
	var saved_events := 0
	for _turn in interval:
		session.wait_turn()
		saved_events += session.last_events.filter(func(event: Dictionary) -> bool: return event.type == "autosave").size()
	var stored: Dictionary = store.load_run(session.run.run_id)
	check(saved_events == 1 and not session.dirty and int(stored.revision) == revision + 1 and int(stored.state.turn) == int(session.run.state.turn), "Normal mode autosaves after %d safe turns with a complete state" % interval)
	check(Acceptance.same(stored.state.character, session.run.state.character) and Acceptance.same(stored.state.inventory, session.run.state.inventory), "Autosave wrote the full character and inventory")
	session.wait_turn()
	check(session.save() and int(store.load_run(session.run.run_id).revision) == revision + 2, "Manual save still works after an autosave (revisions consistent)")
	session.stats().hp = 5
	var turn := int(session.run.state.turn)
	for _turn in interval + 2:
		session.wait_turn()
	check(session.dirty and int(store.load_run(session.run.run_id).state.turn) == turn, "No autosave while HP is critical (a reload never starts in a lost position)")
	store.close()

func _child(args: Array) -> String:
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--quit-after", CHILD_FRAME_LIMIT, "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/permadeath_probe.gd", "--"] + args, output, true)
	print("Probe ", args.slice(2), " exit ", code, ": ", str(output).right(200))
	return str(output)

func _test_permadeath_durability() -> void:
	var path := directory + "/permadeath.sqlite"
	var store := Store.new()
	store.open(path)
	var session := _session(store, "Permadeath", "forest", "permadeath")
	var run_id: String = session.run.run_id
	var turn := int(session.run.state.turn)
	store.close()
	var interval := int(session.survival.rules.autosave.permadeath_safe_interval)
	var log := _child([path, run_id, "act", str(interval + 2)])
	store.open(path)
	var stored: Dictionary = store.load_run(run_id)
	check(log.contains("PROBE acted") and int(stored.state.turn) >= turn + interval and int(stored.state.turn) <= turn + interval + 2, "Safe permadeath turns are committed every %d actions; a kill loses at most %d safe turns (stored %d)" % [interval, interval - 1, int(stored.state.turn)])
	store.close()
	log = _child([path, run_id, "die", "0"])
	store.open(path)
	stored = store.load_run(run_id)
	if check(log.contains("dead=true"), "Child process dies in combat, then is killed abruptly"):
		check(stored.state.status == "dead", "Death is durable after abrupt termination")
		var resume := Session.new(store)
		check(not resume.resume(run_id), "Dead permadeath run cannot be loaded again")
		var world: Dictionary = store.load_world(stored.world_id)
		check(Acceptance.same(world.blueprint, Pack.blueprint(1847)), "Permadeath leaves the World Blueprint unchanged")
	var integrity: Array = store._db.rows("PRAGMA integrity_check")
	check(integrity[0].integrity_check == "ok" and store._db.rows("PRAGMA foreign_key_check").is_empty(), "SQLite intact after repeated abrupt kills")
	store.close()

func _test_permadeath_risk_commits() -> void:
	var store := Store.new()
	store.open(directory + "/risk.sqlite")
	var session := _session(store, "Risk", "forest", "permadeath")
	var committed := 0
	var risky := 0
	for _step in 150:
		if session.is_dead():
			break
		var wolf := Acceptance.nearest_creature(session, ["hostile"])
		var direction := Vector2i.ZERO if wolf.is_empty() else Acceptance.step_toward_creature(session, wolf)
		if direction == Vector2i.ZERO or not session.try_move(direction):
			session.wait_turn()
		if session.at_risk() and not session.is_dead():
			risky += 1
			committed += 1 if (not session.dirty and int(store.load_run(session.run.run_id).state.turn) == int(session.run.state.turn)) else 0
	check(risky > 0 and committed == risky, "Every at-risk permadeath action is committed immediately (%d/%d)" % [committed, risky])
	session.stats().hp = 10
	var turn := int(session.run.state.turn)
	if not session.is_dead() and session.wait_turn():
		check(not session.dirty and int(store.load_run(session.run.run_id).state.turn) == turn + 1, "Low HP counts as risk: committed at once")
	store.close()

func _test_independence_and_legacy() -> void:
	var store := Store.new()
	store.open(directory + "/independence.sqlite")
	var a := _session(store, "Shared")
	a.autosave_interval = 0
	a.stats().hunger = 700
	_give(a, "core:berries", 2)
	a.use_item("core:berries")
	a.save()
	var b := Session.new(store)
	check(b.start_new(a.world.world_id, 202, "meadow") and b.stats().hunger == 0 and not b.run.state.inventory.has("core:berries"), "Run B starts fed with its own inventory")
	b.wait_turn()
	b.save()
	check(int(store.load_run(a.run.run_id).state.character.stats.hunger) == int(a.stats().hunger), "Run B does not change Run A survival state")
	# Checkpoint A-era state: combat stats but no survival keys.
	var legacy: Dictionary = store.load_run(a.run.run_id)
	for key in ["hunger", "thirst", "recovery", "starvation"]:
		legacy.state.character.stats.erase(key)
	check(store.save_run(a.run.run_id, int(legacy.revision), legacy.state), "Prepare a Checkpoint A-style save without survival stats")
	var resumed := Session.new(store)
	check(resumed.resume(a.run.run_id) and resumed.stats().hunger == 0 and resumed.stats().thirst == 0 and Acceptance.same(resumed.run.state.inventory, legacy.state.inventory), "Checkpoint A save loads with survival defaults and intact inventory")
	store.close()
