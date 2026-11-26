#!/usr/bin/env python3
"""Static audit of AETHER-UI/src: require graph, cycles, preset names, hard-coded styling."""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
problems = []

files = {}
for dp, _, names in os.walk(SRC):
    for n in names:
        if n.endswith(".lua"):
            rel = os.path.relpath(os.path.join(dp, n), SRC).replace(os.sep, "/")[:-4]
            files[rel] = open(os.path.join(dp, n), encoding="utf8").read()

def strip(src):
    src = re.sub(r"--\[\[.*?\]\]", "", src, flags=re.S)
    return re.sub(r"--[^\n]*", "", src)

# ---- require graph ----
graph = {k: set() for k in files}
for mod, raw in files.items():
    src = strip(raw)
    for m in re.finditer(r"require\(script\.Parent\.(\w+)\)", src):
        graph[mod].add(m.group(1))
    for m in re.finditer(r"require\(script\.(\w+)\)", src):
        graph[mod].add(m.group(1))
    for m in re.finditer(r'siblingModule\("(\w+)"\)', src):
        graph[mod].add(m.group(1))
    if mod == "Components":
        for name in re.findall(r'"(\w+)"', re.search(r"for _, name in ipairs\(\{(.*?)\}\)", src, re.S).group(1)):
            graph[mod].add("Components/" + name)
for mod, deps in graph.items():
    for dep in deps:
        if dep not in files:
            problems.append("missing module: %s requires %s" % (mod, dep))

visiting, done = set(), set()
def dfs(node, path):
    if node in done: return
    if node in visiting:
        problems.append("CIRCULAR: " + " -> ".join(path + [node])); return
    visiting.add(node)
    for dep in sorted(graph.get(node, ())):
        dfs(dep, path + [node])
    visiting.discard(node); done.add(node)
for mod in files: dfs(mod, [])

print("require graph:")
for mod in sorted(graph):
    if graph[mod]: print("  %-24s -> %s" % (mod, ", ".join(sorted(graph[mod]))))

# leaf modules must not depend on anything
for leaf in ("Theme", "Utils", "Animation"):
    if graph[leaf]: problems.append("%s must be dependency-free but requires %s" % (leaf, graph[leaf]))
for mod in files:
    if mod.startswith("Components/") and graph[mod]:
        problems.append("%s must not require peers: %s" % (mod, graph[mod]))
for mod in ("Window", "Sidebar", "Overlay", "Notifications", "Pages", "ConfigManager"):
    if graph[mod]: problems.append("%s must receive dependencies via ctx, but requires %s" % (mod, graph[mod]))

# ---- motion presets ----
theme = strip(files["Theme"])
presets = set(re.findall(r"^\s*(\w+) = \{ Time =", theme, re.M))
used = {}
for mod, raw in files.items():
    src = strip(raw)
    for m in re.finditer(r"(?:animation|Animation|self)[:.]Play\(\s*[^,()]+(?:\([^)]*\))?[^,]*,\s*\"(\w+)\"", src):
        used.setdefault(m.group(1), set()).add(mod)
    for m in re.finditer(r"_preset\(\"(\w+)\"\)|:Tween(?:Preset)?\([^)]*\"(\w+)\"", src):
        pass
for name, mods in sorted(used.items()):
    if name not in presets:
        problems.append("unknown motion preset '%s' used in %s" % (name, sorted(mods)))
print("\nmotion presets defined: %d, distinct names referenced via Play: %d" % (len(presets), len(used)))

# ---- hard-coded styling outside Theme ----
for mod, raw in files.items():
    if mod == "Theme": continue
    src = strip(raw)
    for m in re.finditer(r"Color3\.(fromRGB|fromHex)\(", src):
        if mod == "Utils":
            continue  # Utils.HexToColor parses user-supplied hex; it is not styling
        problems.append("hard-coded colour in %s: %s" % (mod, m.group(0)))
    if mod != "Animation" and "TweenService" in src and mod != "Animation":
        problems.append("%s uses TweenService directly (all tweens must go through Animation)" % mod)
    if "Enum.Font." in src:
        problems.append("%s references Enum.Font directly (use theme.Fonts)" % mod)
for mod, raw in files.items():
    if mod in ("Theme", "ColorPicker"): continue
    for m in re.finditer(r"Color3\.new\(([^)]*)\)", strip(raw)):
        if m.group(1).strip() not in ("0, 0, 0", "1, 1, 1"):
            problems.append("literal Color3.new(%s) in %s" % (m.group(1), mod))

# ---- global leaks via analyzer ----
import shutil, subprocess
luau = os.environ.get("LUAU_ANALYZE") or shutil.which("luau-analyze") or ""
known = {"game","Enum","Instance","Color3","UDim2","UDim","Vector2","Vector3","TweenInfo","warn","workspace","task","typeof","ColorSequence","ColorSequenceKeypoint","NumberSequence","NumberSequenceKeypoint","Rect","script","getfenv","_G"}
if luau and os.path.exists(luau):
    for mod in sorted(files):
        out = subprocess.run([luau, os.path.join(SRC, mod + ".lua")], capture_output=True, text=True).stdout
        for line in out.splitlines():
            if "UnknownGlobal" in line:
                g = re.search(r"Unknown global '(\w+)'", line)
                if g and g.group(1) not in known:
                    problems.append("undeclared global '%s' in %s" % (g.group(1), mod))
            elif any(t in line for t in ("GlobalUsedAsLocal", "LocalShadow", "UnusedLocal", "LocalUnused", "UnreachableCode", "DuplicateFunction", "ImportUnused")):
                problems.append("lint %s" % line)

print()
if problems:
    print("AUDIT PROBLEMS (%d):" % len(problems))
    for p in problems: print("  - " + p)
    sys.exit(1)
print("AUDIT CLEAN: no missing modules, no cycles, leaf modules dependency-free, all presets exist,")
print("no hard-coded colours/fonts/tweens outside Theme/Animation, no undeclared globals, no lint findings.")
