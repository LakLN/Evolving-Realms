"""Developer CLI: context -> provider -> persisted draft -> explicit approval.

No service startup needed: calls the same provider abstraction in-process. Native
Godot remains authoritative for database access, validation and activation.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import uuid

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))  # Supports python -I without relying on working directory.
from service.providers import Settings, GenerationError, generate


def godot(args, command, **options):
    executable = Path(args.godot).resolve()
    if not executable.is_file():
        raise GenerationError("Godot executable not found; set --godot")
    with tempfile.TemporaryDirectory(prefix="er-authoring-") as folder:
        output = Path(folder) / "result.json"
        argv = [str(executable), "--headless", "--path", str(ROOT), "--script",
                "res://src/content/authoring_cli.gd", "--", "--database=" + (str(Path(args.database).resolve()) if args.database else ""),
                "--command=" + command, "--output=" + str(output)]
        options.setdefault("world", getattr(args, "world", ""))
        argv.extend("--%s=%s" % (key, value) for key, value in options.items())
        try:
            process = subprocess.run(argv, cwd=ROOT, capture_output=True, timeout=90,
                                     creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
        except subprocess.TimeoutExpired as exc:
            raise GenerationError("Godot authoring timed out; inspect the proposal before retrying activation") from exc
        if not output.is_file():
            raise GenerationError("Godot authoring failed; run editor import and check script errors")
        result = json.loads(output.read_text(encoding="utf-8"))
        if process.returncode or "error" in result:
            raise GenerationError(result.get("error", "Godot authoring failed"))
        return result


def parser():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--database", help="Explicit database file (never implicit personal save); required except pack-check")
    p.add_argument("--godot", default=str(ROOT / ".tools/godot/Godot_v4.7.2-stable_win64.exe"))
    commands = p.add_subparsers(dest="command", required=True)
    init = commands.add_parser("init", help="Create a laboratory World and install existing packs")
    init.add_argument("--name", default="AI Field Laboratory")
    init.add_argument("--seed", type=int, default=1847)
    commands.add_parser("worlds")
    gen = commands.add_parser("generate", help="Generate a draft only, never activate")
    gen.add_argument("--world", required=True)
    gen.add_argument("--kind", choices=["item", "equipment", "skill", "talent", "creature", "location", "collection"], required=True)
    gen.add_argument("--prompt", required=True)
    gen.add_argument("--request-id", default=None)
    gen.add_argument("--related", default="")
    gen.add_argument("--region", default="")
    gen.add_argument("--allow-network", action="store_true")
    for command in ["review", "confirm", "activate", "reject"]:
        sub = commands.add_parser(command)
        sub.add_argument("--world", required=True)
        sub.add_argument("--proposal", required=True)
        if command == "reject":
            sub.add_argument("--reason", default="")
    pack_status = commands.add_parser("pack-status", help="Stage of every module of a content pack in one World")
    pack_status.add_argument("--world", required=True)
    pack_apply = commands.add_parser("pack-apply", help="Draft, confirm and activate a content pack into ONE World")
    target = pack_apply.add_mutually_exclusive_group(required=True)
    target.add_argument("--world")
    target.add_argument("--create-world", metavar="NAME", help="New World (random seed unless --seed)")
    pack_apply.add_argument("--seed", type=int)
    pack_apply.add_argument("--modules", default="", help="Comma-separated module IDs (default: all, in order)")
    commands.add_parser("pack-check", help="Dry run of a pack in a throwaway database")
    for sub in (pack_status, pack_apply, commands.choices["pack-check"]):
        sub.add_argument("--pack", default=str(ROOT / "content/ai_packs/run01"))
    for command, text in [("proposals", "Latest stage, validation and missing capabilities of every proposal"),
                          ("registered", "Active AI-generated definitions now visible to gameplay")]:
        commands.add_parser(command, help=text).add_argument("--world", required=True)
    return p


def main():
    args = parser().parse_args()
    if not args.database and args.command != "pack-check":
        print("Authoring failed: --database is required (an explicit file, never your personal save)", file=sys.stderr)
        return 1
    try:
        if args.command == "generate":
            settings = Settings.from_env()
            context = godot(args, "context", query=args.kind + " " + args.prompt, related=args.related, region=args.region)
            request = {"request_id": args.request_id or str(uuid.uuid4()), "kind": args.kind,
                       "prompt": args.prompt, "context": context}
            envelope = generate(request, settings, args.allow_network)
            with tempfile.TemporaryDirectory(prefix="er-response-") as folder:
                file = Path(folder) / "response.json"
                file.write_text(json.dumps(envelope, ensure_ascii=False), encoding="utf-8")
                result = godot(args, "draft", file=str(file))
        elif args.command in ("pack-status", "pack-apply", "pack-check"):
            options = {"pack": str(Path(args.pack).resolve())}
            if args.command == "pack-apply":
                if args.create_world:
                    options["create-world"] = args.create_world
                    options["world"] = ""
                if args.seed is not None:
                    options["seed"] = args.seed
                if args.modules:
                    options["modules"] = args.modules
            result = godot(args, args.command, **options)
        elif args.command == "init":
            result = godot(args, "init", name=args.name, seed=args.seed)
        elif args.command in ("review", "confirm", "activate"):
            result = godot(args, args.command, proposal=args.proposal)
        elif args.command == "reject":
            result = godot(args, "reject", proposal=args.proposal, reason=args.reason)
        else:
            result = godot(args, args.command)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except (GenerationError, OSError, ValueError) as exc:
        print("Authoring failed: " + str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
