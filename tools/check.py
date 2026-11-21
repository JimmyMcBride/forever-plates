#!/usr/bin/env python3
"""Syntax, behavior, integration, documentation, and source-boundary checks."""
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
runtime = sorted(path.name for path in ROOT.glob("*.lua"))
subprocess.run(["luac5.1", "-p", *runtime, "tests/run.lua"], cwd=ROOT, check=True)
subprocess.run(["lua5.1", "tests/run.lua"], cwd=ROOT, check=True)

toc = (ROOT / "ForeverPlates.toc").read_text()
loaded = [line.strip() for line in toc.splitlines() if line.strip() and not line.startswith("#")]
assert loaded == ["Config.lua", "Capabilities.lua", "Model.lua", "Client.lua", "Plates.lua", "Options.lua", "Core.lua"]
assert set(loaded) == set(runtime)
assert "## Interface: 16001" in toc
for path in [*ROOT.glob("*.lua"), *ROOT.glob("*.toc"), *ROOT.glob("*.md"),
             *ROOT.glob("docs/*.md"), *ROOT.glob("tests/*.lua"), *ROOT.glob("tools/*.py")]:
    text = path.read_text(encoding="utf-8")
    assert text.endswith("\n"), f"Missing final newline: {path}"
    assert all(line == line.rstrip() for line in text.splitlines()), f"Trailing whitespace: {path}"
    if path.suffix == ".md":
        for link in re.findall(r"\]\(([^)]+)\)", text):
            if "://" not in link and not link.startswith("#"):
                assert (path.parent / link.split("#")[0]).exists(), f"Broken local link: {link}"
for name in runtime:
    text = (ROOT / name).read_text()
    for forbidden in [r"\bSetCVar\s*\(", r"\bSetCVarBitfield\s*\(", r"\bSetNamePlateSize\s*\(",
                      r"\bCastSpellBy", r"\bTargetUnit\s*\("]:
        assert not re.search(forbidden, text), f"Unexpected game-setting/action mutation in {name}"
print("Lua syntax, behavior, integration, manifest, links, whitespace, and action/settings boundaries passed.")
