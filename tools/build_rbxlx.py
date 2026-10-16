#!/usr/bin/env python3
"""Builds build/CookieDistributor.rbxlx from src/ with the same layout as default.project.json.

Open the result in Roblox Studio (File > Open from File). No Rojo needed.
Usage: python3 tools/build_rbxlx.py
"""
import itertools
import os
import sys
from xml.sax.saxutils import escape

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import map_gen  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
OUT = os.path.join(ROOT, "build", "CookieDistributor.rbxlx")

_ids = itertools.count(1)


def ref() -> str:
    return f"RBX{next(_ids)}"


def cdata(text: str) -> str:
    if "]]>" in text:
        sys.exit("source contains ']]>', cannot embed in CDATA")
    return f"<![CDATA[{text}]]>"


def item(cls: str, name: str, props: str = "", children: str = "") -> str:
    return (
        f'<Item class="{cls}" referent="{ref()}"><Properties>'
        f'<string name="Name">{escape(name)}</string>{props}</Properties>{children}</Item>'
    )


def script_item(cls: str, name: str, path: str, children: str = "") -> str:
    with open(path, encoding="utf-8") as f:
        source = f.read()
    return item(cls, name, f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>', children)


def script_kind(filename: str):
    """Returns (class, instance name) for a source file name, or None."""
    for suffix, cls in ((".server.luau", "Script"), (".client.luau", "LocalScript"), (".luau", "ModuleScript")):
        if filename.endswith(suffix):
            return cls, filename[: -len(suffix)]
    return None


def build_dir(path: str, name: str) -> str:
    """Folder -> Folder, unless it has an init file, in which case it becomes that script (Rojo rules)."""
    entries = sorted(os.listdir(path))
    init = next((e for e in entries if e.startswith("init.") and script_kind(e)), None)
    children = ""
    for e in entries:
        full = os.path.join(path, e)
        if e == init:
            continue
        if os.path.isdir(full):
            children += build_dir(full, e)
        elif script_kind(e):
            cls, stem = script_kind(e)
            children += script_item(cls, stem, full)
    if init:
        cls, _ = script_kind(init)
        return script_item(cls, name, os.path.join(path, init), children)
    return item("Folder", name, "", children)


def main() -> None:
    shared = build_dir(os.path.join(SRC, "shared"), "Shared")
    server = build_dir(os.path.join(SRC, "server"), "Server")
    client = build_dir(os.path.join(SRC, "client"), "Client")

    workspace = item("Workspace", "Workspace", "", "".join(map_gen.build_world()))
    xml = (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
        + workspace
        + item("ReplicatedStorage", "ReplicatedStorage", "", shared)
        + item("ServerScriptService", "ServerScriptService", "", server)
        + item("StarterPlayer", "StarterPlayer", "", item("StarterPlayerScripts", "StarterPlayerScripts", "", client))
        + "</roblox>"
    )
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(xml)
    print(f"wrote {OUT} ({len(xml) // 1024} KB)")


if __name__ == "__main__":
    main()
