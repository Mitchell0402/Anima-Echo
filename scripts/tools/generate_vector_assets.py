from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import hashlib
import math
import re
from typing import Callable

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
TODAY = "2026-06-26"

OUTLINE = "#2d1d18"
SHADOW = "#00000055"
WOOD = "#7a4a2a"
WOOD_DARK = "#4a2c1d"
WOOD_LIGHT = "#b8793a"
PARCHMENT = "#f0dca3"
PARCHMENT_DARK = "#b8874a"
STONE = "#6f6863"
STONE_DARK = "#3f3938"
STONE_LIGHT = "#a79b8f"
MOSS = "#557a43"
MOSS_LIGHT = "#7da35b"
BRASS = "#c99a3e"
GOLD = "#e0b64b"
COPPER = "#b7653c"
IRON = "#9ba3a1"
SILVER = "#d5d7ce"
CRYSTAL = "#70d6d1"
CRYSTAL_DARK = "#326c7a"
CRYSTAL_PINK = "#db83c6"
OXYGEN = "#4bb7d8"
HEALTH = "#d95c47"
GRASS = "#7aa35a"
GRASS_DARK = "#456a3b"
PATH = "#c49a5a"
WATER = "#467c9b"


@dataclass(frozen=True)
class AssetSpec:
    png: str
    width: int
    height: int
    category: str
    sub_category: str
    kind: str
    description: str
    palette: str
    used_by: str = "pending art review/runtime wiring"

    @property
    def stem(self) -> str:
        return Path(self.png).stem

    @property
    def svg(self) -> str:
        return str(Path(self.png).with_suffix(".svg")).replace("\\", "/")

    @property
    def meta(self) -> str:
        return f"{self.png}.meta.md"


def xml_escape(value: str) -> str:
    return (
        value.replace("&", "&amp;")
        .replace('"', "&quot;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


def svg_doc(width: int, height: int, shapes: list[str]) -> str:
    body = "\n  ".join(shapes)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}" shape-rendering="crispEdges">\n'
        f"  {body}\n"
        "</svg>\n"
    )


def rect(x: float, y: float, w: float, h: float, fill: str, stroke: str | None = None, sw: int = 1) -> str:
    s = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
    return f'<rect x="{x:.2f}" y="{y:.2f}" width="{w:.2f}" height="{h:.2f}" fill="{fill}"{s}/>'


def ellipse(x: float, y: float, w: float, h: float, fill: str, stroke: str | None = None, sw: int = 1) -> str:
    s = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
    return f'<ellipse cx="{x + w / 2:.2f}" cy="{y + h / 2:.2f}" rx="{w / 2:.2f}" ry="{h / 2:.2f}" fill="{fill}"{s}/>'


def polygon(points: list[tuple[float, float]], fill: str, stroke: str | None = None, sw: int = 1) -> str:
    pts = " ".join(f"{x:.2f},{y:.2f}" for x, y in points)
    s = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
    return f'<polygon points="{pts}" fill="{fill}"{s}/>'


def line(x1: float, y1: float, x2: float, y2: float, stroke: str, sw: int = 1) -> str:
    return f'<line x1="{x1:.2f}" y1="{y1:.2f}" x2="{x2:.2f}" y2="{y2:.2f}" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="square"/>'


def draw_poly(draw: ImageDraw.ImageDraw, pts: list[tuple[float, float]], fill: str, outline: str | None = None, width: int = 1) -> None:
    draw.polygon([(int(x), int(y)) for x, y in pts], fill=fill, outline=outline)
    if outline and width > 1:
        for offset in range(1, width):
            shifted = [(int(x) + offset, int(y)) for x, y in pts]
            draw.line(shifted + [shifted[0]], fill=outline, width=1)


def stable_seed(text: str) -> int:
    return int(hashlib.sha256(text.encode("utf-8")).hexdigest()[:8], 16)


def jitter(seed: int, index: int, limit: int) -> int:
    return ((seed >> (index % 16)) + index * 17) % limit


def draw_ui_skin(spec: AssetSpec, draw: ImageDraw.ImageDraw) -> list[str]:
    w, h = spec.width, spec.height
    name = spec.stem
    shapes: list[str] = []
    bg = PARCHMENT if "parchment" in name or "tooltip" in name or "toast" in name else WOOD
    edge = PARCHMENT_DARK if bg == PARCHMENT else WOOD_DARK
    if "button_hover" in name:
        bg = "#eac06b"
    if "button_pressed" in name:
        bg = "#9d6331"
    if "button_disabled" in name:
        bg = "#8b8274"
        edge = "#5d554d"
    if "slot" in name:
        bg = "#d8b878"
        edge = WOOD_DARK
    if "bar_fill_health" in name:
        draw.rectangle([0, 0, w - 1, h - 1], fill=HEALTH)
        draw.rectangle([0, 0, w - 1, h - 1], outline=OUTLINE, width=2)
        shapes += [rect(0, 0, w, h, HEALTH, OUTLINE, 2), rect(4, 3, w - 8, 4, "#f18f72")]
        return shapes
    if "bar_fill_oxygen" in name:
        draw.rectangle([0, 0, w - 1, h - 1], fill=OXYGEN)
        draw.rectangle([0, 0, w - 1, h - 1], outline=OUTLINE, width=2)
        shapes += [rect(0, 0, w, h, OXYGEN, OUTLINE, 2), rect(4, 3, w - 8, 4, "#92def0")]
        return shapes
    if "bar_fill_progress" in name:
        draw.rectangle([0, 0, w - 1, h - 1], fill=GOLD)
        draw.rectangle([0, 0, w - 1, h - 1], outline=OUTLINE, width=2)
        shapes += [rect(0, 0, w, h, GOLD, OUTLINE, 2), rect(4, 3, w - 8, 4, "#f1d277")]
        return shapes
    if "qte_ring" in name:
        draw.ellipse([6, 6, w - 7, h - 7], fill=WOOD_DARK, outline=OUTLINE, width=4)
        draw.ellipse([24, 24, w - 25, h - 25], fill=(0, 0, 0, 0), outline=BRASS, width=8)
        draw.arc([24, 24, w - 25, h - 25], 210, 310, fill=OXYGEN, width=10)
        shapes += [
            ellipse(6, 6, w - 12, h - 12, WOOD_DARK, OUTLINE, 4),
            ellipse(24, 24, w - 48, h - 48, "none", BRASS, 8),
            f'<path d="M {w * .21:.1f} {h * .72:.1f} A {w * .30:.1f} {h * .30:.1f} 0 0 1 {w * .68:.1f} {h * .75:.1f}" fill="none" stroke="{OXYGEN}" stroke-width="10"/>',
        ]
        return shapes
    draw.rounded_rectangle([0, 0, w - 1, h - 1], radius=max(2, min(w, h) // 10), fill=edge, outline=OUTLINE, width=2)
    draw.rounded_rectangle([4, 4, w - 5, h - 5], radius=max(2, min(w, h) // 12), fill=bg, outline="#f6e6b7" if bg == PARCHMENT else WOOD_LIGHT, width=1)
    shapes += [
        rect(0, 0, w, h, edge, OUTLINE, 2),
        rect(4, 4, w - 8, h - 8, bg, "#f6e6b7" if bg == PARCHMENT else WOOD_LIGHT),
    ]
    if "slot_locked" in name:
        draw.rectangle([w * 0.28, h * 0.42, w * 0.72, h * 0.75], fill=STONE_DARK, outline=OUTLINE, width=2)
        draw.arc([w * 0.34, h * 0.22, w * 0.66, h * 0.58], 180, 360, fill=OUTLINE, width=3)
        shapes += [rect(w * .28, h * .42, w * .44, h * .33, STONE_DARK, OUTLINE, 2), ellipse(w * .34, h * .22, w * .32, h * .36, "none", OUTLINE, 3)]
    elif "slot_filled" in name:
        draw.rectangle([8, 8, w - 9, h - 9], outline=GOLD, width=3)
        shapes.append(rect(8, 8, w - 16, h - 16, "none", GOLD, 3))
    elif "bar_frame" in name or "weight_frame" in name:
        draw.rectangle([8, 8, w - 9, h - 9], fill="#2f2621", outline=BRASS, width=2)
        shapes.append(rect(8, 8, w - 16, h - 16, "#2f2621", BRASS, 2))
    elif "nameplate" in name:
        draw.rectangle([8, 8, w - 9, h - 9], fill=PARCHMENT, outline=BRASS, width=2)
        shapes.append(rect(8, 8, w - 16, h - 16, PARCHMENT, BRASS, 2))
    return shapes


def draw_icon(spec: AssetSpec, draw: ImageDraw.ImageDraw) -> list[str]:
    w, h = spec.width, spec.height
    name = spec.stem
    shapes = [ellipse(w * .14, h * .72, w * .72, h * .16, SHADOW)]
    draw.ellipse([w * .14, h * .72, w * .86, h * .88], fill=(0, 0, 0, 55))
    if "coin" in name:
        draw.ellipse([8, 8, w - 8, h - 8], fill=GOLD, outline=OUTLINE, width=3)
        draw.ellipse([15, 15, w - 15, h - 15], outline="#f2d770", width=3)
        shapes += [ellipse(8, 8, w - 16, h - 16, GOLD, OUTLINE, 3), ellipse(15, 15, w - 30, h - 30, "none", "#f2d770", 3)]
    elif "oxygen" in name:
        draw.rounded_rectangle([15, 6, 33, 39], radius=5, fill=OXYGEN, outline=OUTLINE, width=3)
        draw.rectangle([19, 2, 29, 8], fill=STONE_LIGHT, outline=OUTLINE)
        shapes += [rect(15, 6, 18, 33, OXYGEN, OUTLINE, 3), rect(19, 2, 10, 6, STONE_LIGHT, OUTLINE)]
    elif "weight" in name:
        draw.polygon([(24, 7), (38, 18), (34, 39), (14, 39), (10, 18)], fill=IRON, outline=OUTLINE)
        draw.arc([16, 3, 32, 19], 190, 350, fill=OUTLINE, width=3)
        shapes += [polygon([(24, 7), (38, 18), (34, 39), (14, 39), (10, 18)], IRON, OUTLINE, 2), ellipse(16, 3, 16, 16, "none", OUTLINE, 3)]
    elif "health" in name:
        pts = [(24, 40), (9, 25), (9, 14), (17, 9), (24, 15), (31, 9), (39, 14), (39, 25)]
        draw_poly(draw, pts, HEALTH, OUTLINE, 2)
        shapes.append(polygon(pts, HEALTH, OUTLINE, 2))
    elif "warehouse" in name:
        draw.rectangle([9, 17, 39, 39], fill=WOOD, outline=OUTLINE, width=2)
        draw.polygon([(7, 18), (24, 7), (41, 18)], fill=WOOD_LIGHT, outline=OUTLINE)
        draw.rectangle([19, 27, 29, 39], fill=WOOD_DARK, outline=OUTLINE)
        shapes += [rect(9, 17, 30, 22, WOOD, OUTLINE, 2), polygon([(7, 18), (24, 7), (41, 18)], WOOD_LIGHT, OUTLINE), rect(19, 27, 10, 12, WOOD_DARK, OUTLINE)]
    else:
        color = CRYSTAL
        if "copper" in name:
            color = COPPER
        elif "iron" in name:
            color = IRON
        elif "silver" in name:
            color = SILVER
        elif "gold" in name:
            color = GOLD
        elif "moonlit" in name:
            color = "#93a8ff"
        elif "star" in name:
            color = "#f4d25f"
        elif "memory" in name:
            color = "#7ed7b3"
        elif "rare" in name:
            color = CRYSTAL_PINK
        elif "fine" in name:
            color = "#7db7ec"
        elif "anomalous" in name:
            color = "#b17cf0"
        base = [(w * .5, 6), (w - 10, h * .35), (w * .68, h - 8), (w * .28, h - 8), (10, h * .35)]
        draw_poly(draw, base, color, OUTLINE, 2)
        draw.line([(w * .5, 8), (w * .5, h - 10)], fill="#ffffff99", width=2)
        draw.line([(12, h * .35), (w - 12, h * .35)], fill=CRYSTAL_DARK, width=2)
        shapes += [polygon(base, color, OUTLINE, 2), line(w * .5, 8, w * .5, h - 10, "#ffffff99", 2), line(12, h * .35, w - 12, h * .35, CRYSTAL_DARK, 2)]
    return shapes


def draw_npc(spec: AssetSpec, draw: ImageDraw.ImageDraw) -> list[str]:
    name = spec.stem
    w, h = spec.width, spec.height
    coat = "#5a6c43"
    hair = "#5b341f"
    hat = "#8b5a2b"
    if "buyer" in name:
        coat, hair, hat = "#8b5735", "#2c1b14", "#b98232"
    elif "identifier" in name:
        coat, hair, hat = "#456f7a", "#dad0a8", "#4b6070"
    elif "task" in name:
        coat, hair, hat = "#745486", "#3a2520", "#835f31"
    shapes = [ellipse(12, 50, 40, 10, SHADOW)]
    draw.ellipse([12, 50, 52, 60], fill=(0, 0, 0, 55))
    draw.rectangle([22, 25, 42, 52], fill=coat, outline=OUTLINE, width=2)
    draw.ellipse([20, 12, 44, 36], fill="#d49b69", outline=OUTLINE, width=2)
    draw.rectangle([15, 10, 49, 18], fill=hat, outline=OUTLINE, width=2)
    draw.rectangle([20, 5, 44, 13], fill=hat, outline=OUTLINE, width=2)
    draw.rectangle([20, 31, 25, 48], fill=WOOD_DARK, outline=OUTLINE)
    draw.rectangle([39, 31, 44, 48], fill=WOOD_DARK, outline=OUTLINE)
    draw.rectangle([25, 52, 31, 58], fill=WOOD_DARK)
    draw.rectangle([35, 52, 41, 58], fill=WOOD_DARK)
    draw.rectangle([24, 20, 29, 24], fill=hair)
    shapes += [
        rect(22, 25, 20, 27, coat, OUTLINE, 2),
        ellipse(20, 12, 24, 24, "#d49b69", OUTLINE, 2),
        rect(15, 10, 34, 8, hat, OUTLINE, 2),
        rect(20, 5, 24, 8, hat, OUTLINE, 2),
        rect(20, 31, 5, 17, WOOD_DARK, OUTLINE),
        rect(39, 31, 5, 17, WOOD_DARK, OUTLINE),
        rect(25, 52, 6, 6, WOOD_DARK),
        rect(35, 52, 6, 6, WOOD_DARK),
        rect(24, 20, 5, 4, hair),
    ]
    return shapes


def draw_prop(spec: AssetSpec, draw: ImageDraw.ImageDraw) -> list[str]:
    w, h = spec.width, spec.height
    name = spec.stem
    shapes = [ellipse(8, h - 13, w - 16, 8, SHADOW)]
    draw.ellipse([8, h - 13, w - 8, h - 5], fill=(0, 0, 0, 55))
    if "minecart" in name:
        draw.polygon([(9, 25), (55, 25), (48, 46), (16, 46)], fill=WOOD, outline=OUTLINE)
        draw.rectangle([13, 19, 51, 28], fill=WOOD_LIGHT, outline=OUTLINE)
        for x in (19, 45):
            draw.ellipse([x - 6, 43, x + 6, 55], fill=STONE_DARK, outline=OUTLINE, width=2)
        shapes += [
            polygon([(9, 25), (55, 25), (48, 46), (16, 46)], WOOD, OUTLINE, 2),
            rect(13, 19, 38, 9, WOOD_LIGHT, OUTLINE),
            ellipse(13, 43, 12, 12, STONE_DARK, OUTLINE, 2),
            ellipse(39, 43, 12, 12, STONE_DARK, OUTLINE, 2),
        ]
    elif "oxygen_pump" in name:
        draw.rounded_rectangle([22, 8, 42, 45], radius=5, fill=OXYGEN, outline=OUTLINE, width=3)
        draw.rectangle([17, 43, 47, 54], fill=STONE, outline=OUTLINE, width=2)
        draw.line([42, 21, 53, 28, 50, 38], fill=OUTLINE, width=3)
        shapes += [rect(22, 8, 20, 37, OXYGEN, OUTLINE, 3), rect(17, 43, 30, 11, STONE, OUTLINE, 2), line(42, 21, 53, 28, OUTLINE, 3), line(53, 28, 50, 38, OUTLINE, 3)]
    else:
        return draw_world_sprite(spec, draw)
    return shapes


def draw_town_map(spec: AssetSpec, draw: ImageDraw.ImageDraw) -> list[str]:
    w, h = spec.width, spec.height
    shapes = [rect(0, 0, w, h, GRASS)]
    draw.rectangle([0, 0, w, h], fill=GRASS)
    seed = stable_seed(spec.png)
    for i in range(120):
        x = jitter(seed, i, max(1, w - 20))
        y = jitter(seed, i + 200, max(1, h - 20))
        color = MOSS_LIGHT if i % 3 else GRASS_DARK
        draw.rectangle([x, y, x + 6, y + 3], fill=color)
        if i < 45:
            shapes.append(rect(x, y, 6, 3, color))
    paths = [
        [(w * .08, h * .72), (w * .33, h * .58), (w * .52, h * .55), (w * .78, h * .43), (w * .96, h * .42)],
        [(w * .52, h * .55), (w * .50, h * .24)],
        [(w * .33, h * .58), (w * .25, h * .28)],
        [(w * .65, h * .50), (w * .72, h * .78)],
    ]
    for pts in paths:
        for a, b in zip(pts, pts[1:]):
            draw.line([a, b], fill=PATH, width=max(24, w // 38))
            shapes.append(line(a[0], a[1], b[0], b[1], PATH, max(24, w // 38)))
            draw.line([a, b], fill="#d6b777", width=max(12, w // 70))
            shapes.append(line(a[0], a[1], b[0], b[1], "#d6b777", max(12, w // 70)))
    buildings = [
        (w * .17, h * .20, w * .14, h * .14, "identifier"),
        (w * .39, h * .13, w * .16, h * .15, "warehouse"),
        (w * .65, h * .28, w * .13, h * .12, "buyer"),
        (w * .70, h * .68, w * .13, h * .11, "task"),
    ]
    for x, y, bw, bh, label in buildings:
        draw.rectangle([x, y + bh * .35, x + bw, y + bh], fill=WOOD, outline=OUTLINE, width=3)
        draw.polygon([(x - bw * .08, y + bh * .38), (x + bw * .5, y), (x + bw * 1.08, y + bh * .38)], fill=WOOD_LIGHT, outline=OUTLINE)
        shapes += [rect(x, y + bh * .35, bw, bh * .65, WOOD, OUTLINE, 3), polygon([(x - bw * .08, y + bh * .38), (x + bw * .5, y), (x + bw * 1.08, y + bh * .38)], WOOD_LIGHT, OUTLINE)]
    cave = [(w * .82, h * .14), (w * .95, h * .24), (w * .91, h * .38), (w * .78, h * .38), (w * .74, h * .25)]
    draw_poly(draw, cave, STONE_DARK, OUTLINE, 4)
    draw.ellipse([w * .81, h * .22, w * .91, h * .38], fill="#171514", outline=OUTLINE, width=3)
    shapes += [polygon(cave, STONE_DARK, OUTLINE, 4), ellipse(w * .81, h * .22, w * .10, h * .16, "#171514", OUTLINE, 3)]
    for i in range(30):
        x = jitter(seed, i + 400, max(1, w - 50))
        y = jitter(seed, i + 600, max(1, h - 60))
        draw.ellipse([x, y, x + 24, y + 20], fill=GRASS_DARK, outline=OUTLINE)
        draw.rectangle([x + 10, y + 16, x + 14, y + 30], fill=WOOD_DARK)
        if i < 12:
            shapes += [ellipse(x, y, 24, 20, GRASS_DARK, OUTLINE), rect(x + 10, y + 16, 4, 14, WOOD_DARK)]
    return shapes


def draw_tile_texture(spec: AssetSpec, draw: ImageDraw.ImageDraw) -> list[str]:
    w, h = spec.width, spec.height
    name = spec.stem
    if "lake" in name:
        base, alt = WATER, "#5ca8bf"
    elif "wall" in name:
        base, alt = STONE_DARK, STONE
    elif "Tileset" in name:
        base, alt = "#554b43", "#746a60"
    else:
        base, alt = "#5b5148", "#6c6258"
    draw.rectangle([0, 0, w, h], fill=base)
    shapes = [rect(0, 0, w, h, base)]
    seed = stable_seed(spec.png)
    cell = 32 if w >= 512 or h >= 512 else 16
    count = 0
    for y in range(0, h, cell):
        for x in range(0, w, cell):
            c = alt if ((x // cell + y // cell + seed) % 3 == 0) else base
            draw.rectangle([x, y, min(w, x + cell) - 1, min(h, y + cell) - 1], fill=c)
            draw.rectangle([x, y, min(w, x + cell) - 1, min(h, y + cell) - 1], outline="#2d2927")
            if count < 220:
                shapes.append(rect(x, y, min(cell, w - x), min(cell, h - y), c, "#2d2927"))
            count += 1
            if "lake" in name and (x // cell + y // cell) % 4 == 0:
                draw.line([x + 4, y + cell // 2, min(w - 1, x + cell - 4), y + cell // 2], fill="#9ed7df", width=2)
    return shapes


def draw_world_sprite(spec: AssetSpec, draw: ImageDraw.ImageDraw) -> list[str]:
    w, h = spec.width, spec.height
    name = spec.stem
    shapes = [ellipse(w * .12, h * .80, w * .76, max(4, h * .14), SHADOW)]
    draw.ellipse([w * .12, h * .80, w * .88, h * .94], fill=(0, 0, 0, 55))
    seed = stable_seed(spec.png)
    if "bone" in name:
        for i in range(3):
            y = h * (.35 + i * .10)
            x1 = w * (.18 + i * .08)
            x2 = w * (.78 - i * .04)
            draw.line([x1, y, x2, y + h * .08], fill="#d6c9a0", width=max(3, min(w, h) // 12))
            shapes.append(line(x1, y, x2, y + h * .08, "#d6c9a0", max(3, min(w, h) // 12)))
        return shapes
    if "crystal" in name or "geode" in name:
        colors = [CRYSTAL, CRYSTAL_PINK, "#93a8ff", "#75d27d"]
        for i in range(3):
            cx = w * (.32 + i * .18)
            top = h * (.14 + (i % 2) * .08)
            col = colors[(i + seed) % len(colors)]
            pts = [(cx, top), (cx + w * .12, h * .58), (cx, h * .86), (cx - w * .12, h * .58)]
            draw_poly(draw, pts, col, OUTLINE, 2)
            shapes.append(polygon(pts, col, OUTLINE, 2))
        return shapes
    if "greenery" in name:
        for i in range(5):
            x = w * (.18 + i * .14)
            y = h * (.70 - (i % 3) * .12)
            col = MOSS_LIGHT if i % 2 else MOSS
            draw.ellipse([x - w * .08, y - h * .18, x + w * .08, y + h * .10], fill=col, outline=OUTLINE)
            shapes.append(ellipse(x - w * .08, y - h * .18, w * .16, h * .28, col, OUTLINE))
        return shapes
    if "rune" in name:
        pts = [(w * .22, h * .18), (w * .78, h * .22), (w * .70, h * .82), (w * .28, h * .78)]
        draw_poly(draw, pts, STONE, OUTLINE, 2)
        draw.line([w * .38, h * .36, w * .60, h * .62], fill=GOLD, width=max(2, min(w, h) // 14))
        draw.line([w * .60, h * .36, w * .38, h * .62], fill=GOLD, width=max(2, min(w, h) // 14))
        shapes += [polygon(pts, STONE, OUTLINE, 2), line(w * .38, h * .36, w * .60, h * .62, GOLD, max(2, min(w, h) // 14)), line(w * .60, h * .36, w * .38, h * .62, GOLD, max(2, min(w, h) // 14))]
        return shapes
    if "stone" in name or "stones" in name:
        for i in range(4):
            x = w * (.18 + (i % 2) * .26 + jitter(seed, i, 8) / 100)
            y = h * (.45 + (i // 2) * .14)
            pts = [(x, y), (x + w * .22, y - h * .08), (x + w * .34, y + h * .10), (x + w * .18, y + h * .25), (x - w * .02, y + h * .18)]
            draw_poly(draw, pts, STONE if i % 2 else STONE_LIGHT, OUTLINE, 2)
            shapes.append(polygon(pts, STONE if i % 2 else STONE_LIGHT, OUTLINE, 2))
        return shapes
    if "decor" in name:
        variant = int(re.findall(r"\d+", name)[0]) if re.findall(r"\d+", name) else 0
        if variant % 5 == 0:
            draw.rectangle([w * .25, h * .30, w * .75, h * .78], fill=WOOD, outline=OUTLINE, width=3)
            draw.line([w * .25, h * .48, w * .75, h * .48], fill=WOOD_DARK, width=3)
            shapes += [rect(w * .25, h * .30, w * .50, h * .48, WOOD, OUTLINE, 3), line(w * .25, h * .48, w * .75, h * .48, WOOD_DARK, 3)]
        elif variant % 5 == 1:
            draw.polygon([(w * .20, h * .75), (w * .45, h * .25), (w * .65, h * .75)], fill=WOOD_LIGHT, outline=OUTLINE)
            draw.polygon([(w * .42, h * .75), (w * .68, h * .25), (w * .86, h * .75)], fill=WOOD, outline=OUTLINE)
            shapes += [polygon([(w * .20, h * .75), (w * .45, h * .25), (w * .65, h * .75)], WOOD_LIGHT, OUTLINE), polygon([(w * .42, h * .75), (w * .68, h * .25), (w * .86, h * .75)], WOOD, OUTLINE)]
        elif variant % 5 == 2:
            draw.ellipse([w * .22, h * .28, w * .78, h * .80], fill="#bda072", outline=OUTLINE, width=3)
            shapes.append(ellipse(w * .22, h * .28, w * .56, h * .52, "#bda072", OUTLINE, 3))
        elif variant % 5 == 3:
            draw.rectangle([w * .18, h * .52, w * .82, h * .68], fill=WOOD_LIGHT, outline=OUTLINE, width=2)
            draw.rectangle([w * .28, h * .38, w * .72, h * .54], fill=WOOD, outline=OUTLINE, width=2)
            shapes += [rect(w * .18, h * .52, w * .64, h * .16, WOOD_LIGHT, OUTLINE, 2), rect(w * .28, h * .38, w * .44, h * .16, WOOD, OUTLINE, 2)]
        else:
            for i in range(4):
                x = w * (.22 + i * .14)
                draw.ellipse([x, h * .42, x + w * .18, h * .72], fill=BRASS if i % 2 else STONE, outline=OUTLINE)
                shapes.append(ellipse(x, h * .42, w * .18, h * .30, BRASS if i % 2 else STONE, OUTLINE))
        return shapes
    pts = [(w * .20, h * .32), (w * .68, h * .24), (w * .82, h * .62), (w * .55, h * .84), (w * .22, h * .70)]
    draw_poly(draw, pts, STONE, OUTLINE, 2)
    shapes.append(polygon(pts, STONE, OUTLINE, 2))
    return shapes


DRAWERS: dict[str, Callable[[AssetSpec, ImageDraw.ImageDraw], list[str]]] = {
    "ui_skin": draw_ui_skin,
    "ui_icon": draw_icon,
    "npc": draw_npc,
    "prop": draw_prop,
    "town_map": draw_town_map,
    "tile": draw_tile_texture,
    "world": draw_world_sprite,
}


def spec_for(path: str, width: int, height: int, kind: str, description: str, used_by: str = "pending art review/runtime wiring") -> AssetSpec:
    parts = Path(path).parts
    category = parts[1] if len(parts) > 1 else "assets"
    sub = parts[2] if len(parts) > 2 else "general"
    palette = "ui/default" if category == "ui" else "town/default" if category == "town" else "mine/default" if category == "mine" else "props/default"
    return AssetSpec(path.replace("\\", "/"), width, height, category, sub, kind, description, palette, used_by)


ENV_DIMS = {
    "2D_Top_Down_Cave_Tileset": (3072, 2048), "bone_1": (270, 183), "bone_10": (76, 54), "bone_2": (54, 55),
    "bone_3": (83, 63), "bone_4": (204, 132), "bone_5": (186, 137), "bone_6": (119, 67), "bone_7": (115, 42),
    "bone_8": (72, 86), "bone_9": (74, 59), "crystal_1": (93, 110), "crystal_10": (90, 95),
    "crystal_2": (105, 111), "crystal_3": (152, 153), "crystal_4": (103, 177), "crystal_5": (70, 78),
    "crystal_6": (148, 115), "crystal_7": (137, 224), "crystal_8": (110, 158), "crystal_9": (93, 149),
    "decor_1": (71, 47), "decor_10": (255, 234), "decor_11": (227, 209), "decor_12": (101, 62),
    "decor_13": (414, 552), "decor_14": (97, 69), "decor_15": (62, 42), "decor_16": (285, 388),
    "decor_17": (485, 412), "decor_18": (592, 358), "decor_19": (403, 407), "decor_2": (53, 87),
    "decor_20": (556, 472), "decor_3": (390, 221), "decor_4": (287, 223), "decor_5": (170, 169),
    "decor_6": (248, 188), "decor_7": (90, 82), "decor_8": (87, 107), "decor_9": (274, 124),
    "greenery_1": (236, 218), "greenery_10": (102, 83), "greenery_2": (90, 127), "greenery_3": (28, 46),
    "greenery_4": (92, 116), "greenery_5": (76, 159), "greenery_6": (104, 164), "greenery_7": (85, 156),
    "greenery_8": (120, 86), "greenery_9": (115, 78), "lake": (256, 256), "land": (256, 256),
    "rune_1": (89, 96), "rune_2": (72, 92), "rune_3": (84, 83), "rune_4": (79, 68), "rune_5": (85, 88),
    "rune_6": (67, 82), "rune_7": (76, 82), "stones_1": (206, 269), "stones_10": (41, 38),
    "stones_2": (117, 194), "stones_3": (85, 174), "stones_4": (156, 111), "stones_5": (107, 113),
    "stones_6": (100, 78), "stones_7": (73, 70), "stones_8": (93, 45), "stones_9": (36, 39),
    "wall_1": (256, 256), "wall_10": (64, 64), "wall_11": (256, 256), "wall_12": (256, 256),
    "wall_13": (32, 128), "wall_14": (32, 128), "wall_2": (64, 256), "wall_3": (64, 256),
    "wall_4": (256, 64), "wall_5": (256, 256), "wall_6": (256, 256), "wall_7": (64, 256),
    "wall_8": (256, 256), "wall_9": (256, 128), "raw_anomalous_geode_pickup": (64, 64),
}

UI_ICONS = [
    "raw_common_geode", "raw_fine_geode", "raw_rare_geode", "raw_anomalous_geode",
    "copper_nugget", "iron_shard", "silver_vein", "gold_vein",
    "crystal_bloom", "moonlit_crystal", "star_fragment", "memory_core",
    "warehouse", "coin", "oxygen", "weight", "health",
]

UI_SKIN = {
    "panel_parchment_9slice": (96, 96), "panel_wood_9slice": (96, 96),
    "button_normal_9slice": (48, 24), "button_hover_9slice": (48, 24),
    "button_pressed_9slice": (48, 24), "button_disabled_9slice": (48, 24),
    "slot_empty": (64, 64), "slot_filled": (64, 64), "slot_locked": (64, 64),
    "tooltip_9slice": (48, 48), "toast_9slice": (64, 32),
    "bar_frame_horizontal": (128, 24), "bar_fill_health": (64, 16),
    "bar_fill_oxygen": (64, 16), "bar_fill_progress": (64, 16),
    "weight_frame_vertical": (64, 80), "qte_ring": (160, 160),
    "dialog_nameplate": (160, 32),
}


def build_specs() -> list[AssetSpec]:
    specs: list[AssetSpec] = []
    for name, (w, h) in ENV_DIMS.items():
        kind = "tile" if name in {"2D_Top_Down_Cave_Tileset", "land", "lake"} or name.startswith("wall_") else "world"
        specs.append(spec_for(f"assets/mine/environment/{name}.png", w, h, kind, f"First-pass vector mine environment asset for {name}."))
    specs.extend([
        spec_for("assets/props/minecart_return_to_town.png", 64, 64, "prop", "First-pass vector minecart return prop.", "mine exit affordance"),
        spec_for("assets/props/oxygen_pump.png", 64, 64, "prop", "First-pass vector oxygen pump prop.", "pending oxygen pump Sprite2D wiring"),
        spec_for("assets/town/map/town_map.png", 1672, 941, "town_map", "First-pass vector-authored town map preserving the current runtime texture dimensions.", "town background texture"),
    ])
    for npc in ("npc_miner_sprites", "npc_buyer_sprites", "npc_identifier_sprites", "npc_task_clerk_sprites"):
        specs.append(spec_for(f"assets/town/npcs/{npc}.png", 64, 64, "npc", f"First-pass vector static town NPC sprite for {npc}.", "scripts/town/mining_town_scene.gd"))
    for icon in UI_ICONS:
        specs.append(spec_for(f"assets/ui/icons/{icon}.png", 48, 48, "ui_icon", f"First-pass vector UI icon for {icon}."))
    for name, (w, h) in UI_SKIN.items():
        specs.append(spec_for(f"assets/ui/skin/{name}.png", w, h, "ui_skin", f"First-pass vector UI skin texture for {name}."))
    return specs


def write_asset(spec: AssetSpec) -> None:
    png_path = ROOT / spec.png
    svg_path = ROOT / spec.svg
    meta_path = ROOT / spec.meta
    png_path.parent.mkdir(parents=True, exist_ok=True)
    img = Image.new("RGBA", (spec.width, spec.height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    shapes = DRAWERS[spec.kind](spec, draw)
    img.save(png_path)
    svg_path.write_text(svg_doc(spec.width, spec.height, shapes), encoding="utf-8")
    meta_path.write_text(sidecar(spec), encoding="utf-8")


def sidecar(spec: AssetSpec) -> str:
    return "\n".join([
        f"id: {spec.stem}",
        f"category: {spec.category}",
        f"sub-category: {spec.sub_category}",
        "source: authored-original",
        f"vector-source: {spec.svg}",
        f"runtime-export: {spec.png}",
        "license: project-internal",
        "status: placeholder",
        f"width: {spec.width}",
        f"height: {spec.height}",
        f"palette: {spec.palette}",
        f"description: {spec.description}",
        "style-notes: Generated as a first-pass cozy top-down vector placeholder with hard-edged shapes, dark outline, limited warm palette, and PNG export kept beside the SVG source. Needs human art review before final implemented status.",
        "created-by: Codex vector asset batch generator",
        "last-reviewed-by: Codex",
        f"last-reviewed-on: {TODAY}",
        f"replacement: pending final art review for {spec.png}",
        "",
    ])


def validate_specs(specs: list[AssetSpec]) -> None:
    seen = set()
    for spec in specs:
        if spec.png in seen:
            raise ValueError(f"duplicate asset spec: {spec.png}")
        seen.add(spec.png)
        if "characters/player" in spec.png or "enemies/gnoll" in spec.png:
            raise ValueError(f"animated sheet included by mistake: {spec.png}")


def main() -> None:
    specs = build_specs()
    validate_specs(specs)
    for spec in specs:
        write_asset(spec)
    print(f"generated {len(specs)} vector assets")


if __name__ == "__main__":
    main()
