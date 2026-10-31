ALTER TABLE runs ADD COLUMN revision INTEGER NOT NULL DEFAULT 0 CHECK(revision >= 0);
CREATE TABLE content_definitions (
    world_id TEXT NOT NULL REFERENCES worlds(world_id),
    content_id TEXT NOT NULL,
    version INTEGER NOT NULL CHECK(version > 0),
    kind TEXT NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('active', 'pending_capability', 'hidden', 'draft', 'invalid_conflicted')),
    definition_json TEXT NOT NULL CHECK(json_valid(definition_json)),
    PRIMARY KEY(world_id, content_id, version)
);
CREATE TABLE content_dependencies (
    world_id TEXT NOT NULL,
    content_id TEXT NOT NULL,
    version INTEGER NOT NULL,
    dependency_id TEXT NOT NULL,
    dependency_version INTEGER NOT NULL,
    PRIMARY KEY(world_id, content_id, version, dependency_id, dependency_version),
    FOREIGN KEY(world_id, content_id, version) REFERENCES content_definitions(world_id, content_id, version),
    FOREIGN KEY(world_id, dependency_id, dependency_version) REFERENCES content_definitions(world_id, content_id, version)
);
CREATE TABLE content_instances (
    world_id TEXT NOT NULL REFERENCES worlds(world_id),
    instance_id TEXT NOT NULL,
    content_id TEXT NOT NULL,
    version INTEGER NOT NULL,
    instance_json TEXT NOT NULL CHECK(json_valid(instance_json)),
    PRIMARY KEY(world_id, instance_id),
    FOREIGN KEY(world_id, content_id, version) REFERENCES content_definitions(world_id, content_id, version)
);
CREATE TABLE run_entity_states (
    run_id TEXT NOT NULL,
    world_id TEXT NOT NULL,
    instance_id TEXT NOT NULL,
    state_json TEXT NOT NULL CHECK(json_valid(state_json)),
    PRIMARY KEY(run_id, instance_id),
    FOREIGN KEY(run_id, world_id) REFERENCES runs(run_id, world_id),
    FOREIGN KEY(world_id, instance_id) REFERENCES content_instances(world_id, instance_id)
);
