#!/usr/bin/env python3
"""Create a deterministic preview ZIP and verify its bytes and folder layout."""
import hashlib
import re
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

ROOT = Path(__file__).resolve().parents[1]
toc = ROOT / "ForeverPlates.toc"
text = toc.read_text()
version = re.search(r"^## Version: ([0-9]+\.[0-9]+\.[0-9]+)$", text, re.MULTILINE).group(1)
runtime = [line.strip() for line in text.splitlines() if line.strip() and not line.startswith("#")]
files = [toc.name, *runtime, "README.md", "LICENSE", "docs/COMPATIBILITY.md", "docs/IN_GAME_TESTING.md"]
assert all((ROOT / name).is_file() for name in files)
output = ROOT / "dist" / f"ForeverPlates-{version}-preview.zip"
output.parent.mkdir(exist_ok=True)
with ZipFile(output, "w", compression=ZIP_DEFLATED) as archive:
    for name in files:
        entry = ZipInfo("ForeverPlates/" + name, date_time=(1980, 1, 1, 0, 0, 0))
        entry.compress_type = ZIP_DEFLATED
        entry.external_attr = 0o100644 << 16
        archive.writestr(entry, (ROOT / name).read_bytes())
with ZipFile(output) as archive:
    assert archive.testzip() is None
    assert set(archive.namelist()) == {"ForeverPlates/" + name for name in files}
    for name in files:
        assert archive.read("ForeverPlates/" + name) == (ROOT / name).read_bytes()
print(output)
print(f"Verified {len(files)} files under one ForeverPlates/ directory.")
print("SHA256 " + hashlib.sha256(output.read_bytes()).hexdigest())
