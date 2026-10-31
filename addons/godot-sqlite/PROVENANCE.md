# Vendored dependency

godot-sqlite v4.9 by Piet Bronders & Jeroen De Geeter, MIT (see LICENSE.md).
Source: https://github.com/2shady4u/godot-sqlite/tree/v4.9
Asset: https://github.com/2shady4u/godot-sqlite/releases/download/v4.9/addons.zip
Downloaded 2026-10-31. Built upstream for Godot 4.7.1; tested here with 4.7.2.
Only unmodified Windows x64 debug/release DLLs and license are vendored.
gdsqlite.gdextension is reduced to Windows x64 entries; no editor plugin required.
Other platforms require their matching upstream libraries before use.

SHA256:

```text
addons.zip 95e91b72fe32984a84edaf6357a78753661f37a170cb362f5b948e0ede7c2cb0
bin/libgdsqlite.windows.template_debug.x86_64.dll e3ae3b46b59eadcd513f8d7d6e7c0c15e173696e145594094d7f4f3cc96c7fe7
bin/libgdsqlite.windows.template_release.x86_64.dll ba79b9bbf916c4ed2eb22ac719051c4a4258e460c4a354590b071beb9a87fedb
```

Windows export must include the GDExtension and appropriate DLL. No Python,
separate SQLite installation or HTTP process is needed. Export verification stays
in Checkpoint E; this checkpoint verifies editor/headless native loading only.
