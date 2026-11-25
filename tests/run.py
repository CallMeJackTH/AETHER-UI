#!/usr/bin/env python3
"""
Runs a test file against build/AetherUI.lua inside the stock Luau VM using the
Roblox API mock (tests/mock_roblox.luau). NOT a Roblox runtime test.

usage: python3 tests/run.py tests/smoke.luau [luau-binary]
"""
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read(path):
    with open(path, "r", encoding="utf8") as handle:
        return handle.read()


def main():
    test = sys.argv[1]
    luau = sys.argv[2] if len(sys.argv) > 2 else "luau"
    mock = read(os.path.join(ROOT, "tests", "mock_roblox.luau"))
    bundle = read(os.path.join(ROOT, "build", "AetherUI.lua"))
    body = read(os.path.join(ROOT, test) if not os.path.isabs(test) else test)

    touch = "--@touch" in body
    source = (
        ("MOCK_TOUCH = true\n" if touch else "")
        + mock
        + "\nlocal __bundle = function()\n" + bundle + "\nend\n"
        + "local Library = __bundle()\n"
        + body
    )
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf8") as handle:
        handle.write(source)
        path = handle.name
    try:
        result = subprocess.run([luau, path], capture_output=True, text=True, timeout=120)
    finally:
        os.unlink(path)
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    sys.exit(result.returncode)


if __name__ == "__main__":
    main()
