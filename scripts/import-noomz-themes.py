#!/usr/bin/env python3
"""Import overlay themes from ../noomz-themes into clipass.

Writes clipass/Models/NoomzThemes.swift and the ThemeID cases between the
noomz-themes markers in clipass/Models/Theme.swift. Re-run after noomz-themes changes:

    python3 scripts/import-noomz-themes.py [path/to/noomz-themes]

Role sources:
- background, text, selection, search field: kitty port (same schema in every file);
  gruvbox has no kitty port, so it uses its pi.dev vars.
- secondary text and placeholder: Claude port `subtle` / `inactive`, which
  noomz-themes repairs to 4.5:1 contrast on the background.
- light/dark: Claude port `base`.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT.parent / "noomz-themes"
THEMES = SRC / "themes"
OUT = ROOT / "clipass/Models/NoomzThemes.swift"
THEME_SWIFT = ROOT / "clipass/Models/Theme.swift"
BEGIN, END = "    // BEGIN noomz-themes (generated)", "    // END noomz-themes"


def hex_color(value: str) -> str:
    value = value.strip()
    if m := re.fullmatch(r"rgb\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)", value):
        return "#" + "".join(f"{int(c):02x}" for c in m.groups())
    if re.fullmatch(r"#[0-9a-fA-F]{6}", value):
        return value.lower()
    raise SystemExit(f"unsupported color {value!r}")


def luminance(color: str) -> float:
    channels = [int(color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    r, g, b = (c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4 for c in channels)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a: str, b: str) -> float:
    hi, lo = sorted((luminance(a), luminance(b)), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


def repair(color: str, background: str, target: float) -> str:
    """noomz-themes' repair: move HLS lightness in 0.004 steps away from the
    background until `target` contrast; hue and saturation stay."""
    import colorsys
    h, l, s = colorsys.rgb_to_hls(*(int(color[i:i + 2], 16) / 255 for i in (1, 3, 5)))
    step = -0.004 if luminance(background) > 0.18 else 0.004
    while contrast(color, background) < target and 0 <= l + step <= 1:
        l += step
        color = "#" + "".join(f"{round(c * 255):02x}" for c in colorsys.hls_to_rgb(h, l, s))
    return color


def kitty(slug: str) -> dict[str, str] | None:
    path = THEMES / "kitty" / f"{slug}.conf"
    if not path.exists():
        return None
    pairs = (line.split(None, 1) for line in path.read_text().splitlines()
             if line.strip() and not line.startswith("#"))
    return {k: v.strip() for k, v in pairs}


def palette(slug: str) -> dict[str, str]:
    claude = json.loads((THEMES / "claude" / f"{slug}.json").read_text())
    dim = claude["overrides"]
    if k := kitty(slug):
        roles = {
            "background": k["background"], "text": k["foreground"],
            "selection": k["selection_background"], "selectedText": k["selection_foreground"],
            "field": k["inactive_tab_background"], "divider": k["selection_background"],
            "accent": k["color4"],
        }
    else:
        v = json.loads((THEMES / "pi.dev" / f"{slug}.json").read_text())["vars"]
        fg = v.get("fg") or v["text"]
        roles = {
            "background": v.get("bg") or v["base"], "text": fg,
            "selection": v["selection"], "selectedText": fg,
            "field": v["raised"], "divider": v["border"], "accent": v["blue"],
        }
    roles["secondary"] = dim["subtle"]
    roles["placeholder"] = dim["inactive"]
    roles = {k: hex_color(v) for k, v in roles.items()}
    # Claude's dim roles were tuned against Claude's background, not kitty's.
    roles["secondary"] = repair(roles["secondary"], roles["background"], 4.5)
    roles["placeholder"] = repair(roles["placeholder"], roles["field"], 3.0)
    roles["name"] = claude["name"]
    roles["dark"] = not claude["base"].startswith("light")
    return roles


def case_name(slug: str) -> str:
    head, *rest = slug.split("-")
    return head + "".join(p.capitalize() for p in rest)


def main() -> None:
    slugs = sorted(p.stem for p in (THEMES / "claude").glob("*.json"))
    themes = [(s, palette(s)) for s in slugs]

    entries = []
    for slug, p in themes:
        appearance = ".darkAqua" if p["dark"] else ".aqua"
        entries.append(f"""        .{case_name(slug)}: Theme(
            id: .{case_name(slug)},
            name: "{p['name']}",
            overlayBackground: Color(hex: "{p['background']}"),
            itemBackground: Color(hex: "{p['selection']}"),
            selectedText: Color(hex: "{p['selectedText']}"),
            primaryText: Color(hex: "{p['text']}"),
            secondaryText: Color(hex: "{p['secondary']}"),
            dividerColor: Color(hex: "{p['divider']}"),
            searchFieldBackground: Color(hex: "{p['field']}"),
            searchFieldText: Color(hex: "{p['text']}"),
            searchFieldPlaceholder: Color(hex: "{p['placeholder']}"),
            accentColor: Color(hex: "{p['accent']}"),
            cornerRadius: 12,
            itemCornerRadius: 6,
            itemVerticalPadding: 6,
            dividerStyle: .standard,
            titleFontWeight: .regular,
            bodyFontSize: NSFont.systemFontSize,
            backgroundMode: .solid,
            forceAppearance: NSAppearance(named: {appearance})
        ),""")
    OUT.write_text(
        "// Generated by scripts/import-noomz-themes.py from noomz-themes. Do not edit by hand.\n"
        "import SwiftUI\nimport AppKit\n\n"
        "extension Theme {\n"
        "    static let noomzThemes: [ThemeID: Theme] = [\n"
        + "\n".join(entries) + "\n    ]\n}\n"
    )

    cases = "\n".join(f'    case {case_name(s)} = "{s}"' for s, _ in themes)
    source = THEME_SWIFT.read_text()
    pattern = re.compile(re.escape(BEGIN) + r".*?" + re.escape(END), re.S)
    if not pattern.search(source):
        raise SystemExit("ThemeID markers missing in Theme.swift")
    THEME_SWIFT.write_text(pattern.sub(lambda _: f"{BEGIN}\n{cases}\n{END}", source))
    print(f"imported {len(themes)} themes -> {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
