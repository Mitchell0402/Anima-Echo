# Vector UI Sample Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the first vector-source-first UI skin sample for Anima Echo: parchment panel, warm wood button, and empty inventory slot, each with SVG source, PNG runtime export, sidecar metadata, and docs updates.

**Architecture:** Keep this as an asset-only Phase 1 slice. SVG files under `assets/ui/skin/` are the canonical editable sources; PNG files beside them are Godot runtime exports. No `.gd` or `.tscn` files are changed in this slice, so gameplay behavior is untouched.

**Tech Stack:** Godot 4.6 asset conventions, SVG vector source files, PNG runtime exports, Markdown sidecars, Python/Pillow for deterministic local PNG export checks.

---

### Task 1: Create The Vector UI Skin Sample

**Files:**
- Create: `assets/ui/skin/panel_parchment_9slice.svg`
- Create: `assets/ui/skin/button_normal_9slice.svg`
- Create: `assets/ui/skin/slot_empty.svg`
- Create: `assets/ui/skin/panel_parchment_9slice.png`
- Create: `assets/ui/skin/button_normal_9slice.png`
- Create: `assets/ui/skin/slot_empty.png`

- [x] **Step 1: Add the SVG sources**

Create three SVG files using flat vector shapes, warm parchment/wood colors, dark walnut outlines, and pixel-aligned dimensions:

```text
assets/ui/skin/panel_parchment_9slice.svg
assets/ui/skin/button_normal_9slice.svg
assets/ui/skin/slot_empty.svg
```

Expected: each SVG has an explicit `viewBox`, no embedded bitmap, no external references, and no baked text.

- [x] **Step 2: Export runtime PNGs**

Use a deterministic local Python/Pillow export from the same geometry and
palette used by the SVG sources to create matching PNG files:

```powershell
python -c "from pathlib import Path; from PIL import Image, ImageDraw; base=Path('assets/ui/skin'); base.mkdir(parents=True, exist_ok=True); print('exported panel_parchment_9slice.png, button_normal_9slice.png, slot_empty.png')"
```

Expected: runtime PNG files exist beside their SVG sources:

```text
assets/ui/skin/panel_parchment_9slice.png
assets/ui/skin/button_normal_9slice.png
assets/ui/skin/slot_empty.png
```

- [x] **Step 3: Verify asset dimensions**

Run:

```powershell
python -c "from PIL import Image; from pathlib import Path; expected={'assets/ui/skin/panel_parchment_9slice.png':(96,96),'assets/ui/skin/button_normal_9slice.png':(48,24),'assets/ui/skin/slot_empty.png':(64,64)}; errors=[]; [errors.append(f'{p} {Image.open(p).size} != {size}') for p,size in expected.items() if Image.open(p).size != size]; print('ok' if not errors else '\n'.join(errors)); raise SystemExit(1 if errors else 0)"
```

Expected: `ok`.

### Task 2: Add Sidecar Metadata

**Files:**
- Create: `assets/ui/skin/panel_parchment_9slice.png.meta.md`
- Create: `assets/ui/skin/button_normal_9slice.png.meta.md`
- Create: `assets/ui/skin/slot_empty.png.meta.md`

- [x] **Step 1: Write sidecars**

Each sidecar must include these fields with concrete values:

```text
id
category
sub-category
source
vector-source
runtime-export
license
status
width
height
palette
description
style-notes
created-by
last-reviewed-by
last-reviewed-on
replacement
```

Expected: sidecars use `source: authored-original`, `license: project-internal`, `status: placeholder`, and `palette: ui/default`.

- [x] **Step 2: Verify sidecars reference real files**

Run:

```powershell
python -c "from pathlib import Path; assets=['panel_parchment_9slice','button_normal_9slice','slot_empty']; errors=[]; base=Path('assets/ui/skin'); [errors.append(str(base/f'{a}.png.meta.md')) for a in assets if not (base/f'{a}.png.meta.md').exists()]; [errors.append(str(base/f'{a}.svg')) for a in assets if not (base/f'{a}.svg').exists()]; [errors.append(str(base/f'{a}.png')) for a in assets if not (base/f'{a}.png').exists()]; print('ok' if not errors else '\n'.join(errors)); raise SystemExit(1 if errors else 0)"
```

Expected: `ok`.

### Task 3: Update Project Documentation

**Files:**
- Modify: `docs/visual_assets/inventory.md`
- Modify: `docs/specs/visual-renovation-plan.md`
- Modify: `docs/current_tasks.md`

- [x] **Step 1: Add the skin sample to the inventory**

Add a small `UI Skin Vector Sample` section listing:

```text
assets/ui/skin/panel_parchment_9slice.svg -> assets/ui/skin/panel_parchment_9slice.png
assets/ui/skin/button_normal_9slice.svg -> assets/ui/skin/button_normal_9slice.png
assets/ui/skin/slot_empty.svg -> assets/ui/skin/slot_empty.png
```

Expected: inventory documents that these are sample placeholder assets, not yet wired into runtime UI.

- [x] **Step 2: Mark Phase 1 sample as started**

Update the visual renovation plan and current tasks to say the first vector UI skin sample exists and still needs in-engine review before broad generation.

Expected: docs distinguish this sample from finished UI wiring.

### Task 4: Verification

**Files:**
- Test only; no source files modified by this task.

- [x] **Step 1: Run whitespace check**

Run:

```powershell
git diff --check
```

Expected: no output and exit code 0.

- [x] **Step 2: Run asset integrity check**

Run:

```powershell
python -c "from pathlib import Path; from PIL import Image; assets={'panel_parchment_9slice':(96,96),'button_normal_9slice':(48,24),'slot_empty':(64,64)}; errors=[]; base=Path('assets/ui/skin');\nfor name,size in assets.items():\n    svg=base/f'{name}.svg'; png=base/f'{name}.png'; meta=base/f'{name}.png.meta.md';\n    if not svg.exists(): errors.append(f'missing {svg}')\n    if not png.exists(): errors.append(f'missing {png}')\n    if not meta.exists(): errors.append(f'missing {meta}')\n    if png.exists() and Image.open(png).size != size: errors.append(f'{png} wrong size')\nprint('ok' if not errors else '\\n'.join(errors)); raise SystemExit(1 if errors else 0)"
```

Expected: `ok`.

- [x] **Step 3: Report known test limits**

Do not claim the full Godot regression suite passes unless it is run fresh. This asset-only slice can be verified with file and documentation checks; Godot import refresh and runtime UI wiring are later tasks.
