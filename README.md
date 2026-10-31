# Evolving Realms

AI-Evolving Sandbox RPG — Godot / GDScript, Windows first.
Current state: **Milestone 01, Checkpoint A**. This is a tested bootstrap screen;
map, playable character, persistence and content generation are still pending.

## Run

Open `project.godot` with `.tools/godot/Godot_v4.7.2-stable_win64.exe`, then press F6
on `scenes/main.tscn` or F5 to run the project. No Python/server/network is needed.

PowerShell commands from the repository root:

```powershell
.\scripts\godot.ps1 --headless --editor --import
.\scripts\godot.ps1 --headless --quit-after 5
.\scripts\godot.ps1 --editor
```

The wrapper waits for Godot and prints logs after it exits. It uses a hidden
startup window; launch the executable directly for interactive editor use.

## Local toolchain

Git 2.46.2 was already installed. Project-local Godot 4.7.2 standard Windows x64
comes from the [official release](https://github.com/godotengine/godot/releases/tag/4.7.2-stable),
also accessible through the [Godot Windows download page](https://godotengine.org/download/windows/).
Extract the official win64 ZIP into `.tools/godot` on a fresh checkout.

The existing `D:/Python` installation lacks encodings; it was not modified.
Python 3.13.7 portable is the [Python NuGet package](https://www.nuget.org/packages/python/3.13.7)
from the Python Software Foundation. Extract its package ZIP into
`.tools/python-portable` so the interpreter is at `tools/python.exe`.
Tools and venv are ignored by Git. No machine PATH changes are required.

```powershell
.\.tools\python-portable\tools\python.exe -I -m venv .venv
.\.venv\Scripts\python.exe -I -m pip install -r service/requirements-lock.txt
.\.venv\Scripts\python.exe -E scripts/check_service.py
.\.venv\Scripts\python.exe -E -m uvicorn service.app:app --host 127.0.0.1 --port 8765
```

`-I` / `-E` isolate the interpreter from unrelated inherited PYTHONPATH settings.
The optional service currently exposes only `/health`; it is not an AI provider.
No API key or paid service is used. SQLite driver integration is Checkpoint B.

## Handoff

Read [progress](docs/PROGRESS.md), [architecture](docs/ARCHITECTURE.md) and
[roadmap](docs/ROADMAP.md). No Windows export exists at Checkpoint A; install
matching export templates and verify a standalone executable in Checkpoint E.
