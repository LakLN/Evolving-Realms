extends RefCounted
## One local connection, main-thread only. Repositories own domain validation.
const Data = preload("res://src/data/json_data.gd")
const SCHEMA_VERSION := 2
const MIGRATIONS := [
	"res://src/data/migrations/001_world_run.sql",
	"res://src/data/migrations/002_content.sql",
]
var last_error := ""
var last_backup_path := ""
var _connection: Object

func open(path: String = "user://realms.sqlite") -> bool:
	close()
	last_error = ""
	last_backup_path = ""
	if not ClassDB.class_exists("SQLite"):
		return fail("SQLite extension unavailable: install the pinned Windows x64 addon")
	if path.is_empty() or path.begins_with("res://"):
		return fail("Use a writable absolute path or user:// database path")
	var absolute := ProjectSettings.globalize_path(path)
	if not absolute.is_absolute_path():
		return fail("Database path must be absolute or user://")
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return fail("Cannot create database directory")
	_connection = ClassDB.instantiate("SQLite")
	_connection.path = absolute
	_connection.foreign_keys = true
	_connection.verbosity_level = 0
	if not _connection.open_db():
		return _open_failed("Cannot open database: " + str(_connection.error_message))
	var version_rows := rows("PRAGMA user_version")
	if version_rows.is_empty():
		return _open_failed(last_error)
	var version := int(version_rows[0].user_version)
	if version > SCHEMA_VERSION or version < 0:
		return _open_failed("Unsupported database schema version %d" % version)
	if version == 0 and not rows("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'").is_empty():
		return _open_failed("Unversioned non-empty database; migration refused")
	if not execute("PRAGMA busy_timeout=3000"):
		return _open_failed(last_error)
	if version > 0 and version < SCHEMA_VERSION:
		last_backup_path = absolute + ".before-v%d-%s.sqlite" % [SCHEMA_VERSION, Data.uuid()]
		if not execute("VACUUM INTO ?", [last_backup_path]):
			return _open_failed("Migration backup failed: " + last_error)
	if version < SCHEMA_VERSION:
		if not execute("BEGIN IMMEDIATE"):
			return _open_failed(last_error)
		for index in range(version, SCHEMA_VERSION):
			# Files contain only trusted DDL; user data always uses bindings.
			var sql := FileAccess.get_file_as_string(MIGRATIONS[index])
			if sql.is_empty() or not execute(sql):
				var reason := "Migration %d failed: %s" % [index + 1, last_error]
				rollback(reason)
				return _open_failed(reason)
		if not execute("PRAGMA user_version=%d" % SCHEMA_VERSION) or not execute("COMMIT"):
			var reason := last_error
			rollback(reason)
			return _open_failed(reason)
	return true

func close() -> void:
	if _connection != null:
		_connection.close_db()
		_connection = null

func _open_failed(message: String) -> bool:
	close()
	return fail(message)

func fail(message: String) -> bool:
	last_error = message
	return false

func execute(sql: String, bindings: Array = []) -> bool:
	if _connection == null:
		return fail("Database is not open")
	var success: bool
	if bindings.is_empty():
		success = _connection.query(sql)
	else:
		success = _connection.query_with_bindings(sql, bindings)
	if not success:
		return fail(str(_connection.error_message))
	last_error = ""
	return true

func rows(sql: String, bindings: Array = []) -> Array:
	if not execute(sql, bindings):
		return []
	return _connection.query_result.duplicate(true)

func rollback(reason: String) -> bool:
	execute("ROLLBACK")
	return fail(reason)
