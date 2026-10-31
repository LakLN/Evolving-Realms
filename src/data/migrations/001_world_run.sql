CREATE TABLE worlds (
    world_id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    seed INTEGER NOT NULL CHECK(seed BETWEEN -2147483648 AND 2147483647),
    generation_version INTEGER NOT NULL CHECK(generation_version = 1),
    schema_version INTEGER NOT NULL CHECK(schema_version = 1),
    blueprint_json TEXT NOT NULL CHECK(json_valid(blueprint_json)),
    created_at TEXT NOT NULL
);
CREATE TABLE runs (
    run_id TEXT PRIMARY KEY NOT NULL,
    world_id TEXT NOT NULL REFERENCES worlds(world_id),
    seed INTEGER NOT NULL CHECK(seed BETWEEN -2147483648 AND 2147483647),
    schema_version INTEGER NOT NULL CHECK(schema_version = 1),
    mode TEXT NOT NULL CHECK(mode IN ('normal', 'permadeath')),
    spawn_json TEXT NOT NULL CHECK(json_valid(spawn_json)),
    state_json TEXT NOT NULL CHECK(json_valid(state_json)),
    created_at TEXT NOT NULL,
    UNIQUE(run_id, world_id)
);
CREATE INDEX runs_by_world ON runs(world_id);
