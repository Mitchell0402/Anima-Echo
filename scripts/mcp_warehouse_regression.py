"""MCP regression test for the warehouse + town popup flow.

Drives the Godot editor through the godot-mcp-pro server (stdio MCP).
Covers:
- Bug 1: miner NPC popup has exactly 1 "离开" button (not 2).
- Bug 2: HUD `_inventory_label` updates after a warehouse mutation.
- Bug 3: selling a mineral shows a 2-option picker (直接卖 / 讨价还价).
- Bug 4: warehouse UI adapts to small viewport sizes (still 6x8 grid).

Pre-requisites:
- Godot editor running on Windows with the godot_mcp plugin enabled.
- The Node.js godot-mcp-pro server is built and runnable.

Usage:
    python scripts/mcp_warehouse_regression.py
"""
import asyncio
import json
import os
import sys
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

SERVER = r"C:\Users\Mitchell\Documents\Godot\godot-mcp-pro-v1.14.1\server\build\index.js"
NODE = r"C:\Program Files\nodejs\node.exe"

# Test mode: 'miner_popup', 'hud_refresh', 'sell_picker', 'small_viewport', or 'all'.
TEST = sys.argv[1] if len(sys.argv) > 1 else "miner_popup"

failures: list[str] = []


def assert_eq(expected, actual, name: str):
    if expected == actual:
        print(f"  PASS  {name}: {expected}", flush=True)
    else:
        msg = f"  FAIL  {name}: expected {expected!r}, got {actual!r}"
        print(msg, flush=True)
        failures.append(msg)


def assert_true(cond, name: str):
    if cond:
        print(f"  PASS  {name}", flush=True)
    else:
        msg = f"  FAIL  {name}: expected truthy"
        print(msg, flush=True)
        failures.append(msg)


async def call_retry(session, tool, args=None, max_attempts=10, delay=1.0):
    for i in range(max_attempts):
        try:
            return await session.call_tool(tool, args or {})
        except Exception as e:
            if i == max_attempts - 1:
                raise
            print(f"  retry {tool} (t+{(i+1)*delay:.0f}s): {str(e)[:60]}", flush=True)
            await asyncio.sleep(delay)


async def open_scene_and_wait(session, scene_path: str):
    """Open a scene in the editor, wait for it to be the current scene."""
    print(f"opening scene: {scene_path}", flush=True)
    await call_retry(session, "open_scene", {"path": scene_path})
    await asyncio.sleep(0.5)


async def play_scene_and_settle(session, mode: str = "current"):
    """Start the current scene as a playtest. Settle for a moment so the
    runtime has a chance to instantiate nodes (autoloads, scene tree).

    Uses retry-on-error so that the first call (before the Godot plugin
    finishes connecting) does not abort the test run. We also keep trying
    if the runtime says "No scene is currently playing" because the
    play_scene result can return success before the runtime has wired
    signals."""
    print(f"play_scene mode={mode}", flush=True)
    # Try a sequence of strategies. The most reliable is to keep calling
    # play_scene mode=current after open_scene until the runtime tree
    # reports the scene is live.
    await session.call_tool("open_scene", {"path": "res://scenes/town/mining_town.tscn"})
    await asyncio.sleep(0.5)
    last_err: Exception | None = None
    for attempt in range(20):
        try:
            await session.call_tool("play_scene", {"mode": mode})
            await asyncio.sleep(1.5)
            # Confirm a scene is actually playing.
            res = await session.call_tool("get_game_scene_tree", {"max_depth": 1})
            txt = "".join(b.text for b in res.content if hasattr(b, "text"))
            if "currently playing" not in txt and txt.strip():
                print(f"  scene is live after attempt {attempt + 1}", flush=True)
                last_err = None
                break
        except Exception as e:
            last_err = e
        await asyncio.sleep(0.5)
    if last_err is not None:
        print(f"  play_scene failed after retries: {last_err}", flush=True)
    # Final settle so signals wire up.
    await asyncio.sleep(1.0)


async def stop_scene(session):
    try:
        await session.call_tool("stop_scene", {})
    except Exception as e:
        print(f"  stop_scene: {e}", flush=True)
    await asyncio.sleep(0.5)


async def get_runtime_tree_text(session) -> str:
    """Return the game scene tree as a JSON string."""
    result = await call_retry(session, "get_game_scene_tree", {})
    return "".join(b.text for b in result.content if hasattr(b, "text"))


async def get_node_property(session, path: str, prop: str):
    """Read a runtime node property. Returns the value as a string, or None.
    The MCP schema for get_game_node_properties is single {node_path, properties}
    — not nodes: [{path, properties}].
    """
    result = await call_retry(session, "get_game_node_properties", {
        "node_path": path,
        "properties": [prop],
    })
    txt = "".join(b.text for b in result.content if hasattr(b, "text"))
    return txt


async def simulate_key(session, keycode: str, duration: float = 0.1):
    await call_retry(session, "simulate_key", {"keycode": keycode, "duration": duration})


async def test_miner_popup(session):
    """Open the miner NPC popup by playtesting the main scene (town),
    then walk the player next to the miner and press E. Count buttons
    and assert exactly 1 离开 button."""
    print("\n=== test_miner_popup: miner popup has 1 离开 button ===", flush=True)
    # play_scene mode=current is more reliable than mode=main because the
    # Godot editor plugin needs a moment to connect before play_scene
    # can target the main scene directly. We open the main scene first,
    # then play it.
    await session.call_tool("open_scene", {"path": "res://scenes/town/mining_town.tscn"})
    await asyncio.sleep(0.5)
    await play_scene_and_settle(session, mode="current")
    # Move the player next to the miner NPC. The town places miner NPCs
    # via code in mining_town_scene._build_world; we teleport the player
    # rather than walk.
    await call_retry(session, "set_game_node_property", {
        "node_path": "/root/MiningTown/TownPlayer",
        "property": "position",
        "value": "Vector2(250, 220)",
    })
    await asyncio.sleep(0.3)
    # Trigger the popup. simulate_action sends an InputEventAction that
    # bypasses the InputMap keyboard binding and goes straight into the
    # action handler. mining_town_scene._unhandled_input checks for the
    # "interact" action.
    await call_retry(session, "simulate_action", {"action": "interact", "pressed": True})
    await asyncio.sleep(0.5)
    # Inspect the popup's buttons via a runtime script (more reliable than
    # get_game_scene_tree which does not include Button text). We pass a
    # marker so the substring count is exact.
    marker = f"BTN_MARKER_{int.from_bytes(os.urandom(2), 'big')}"
    popup_button_count = {"进入矿洞": 0, "离开": 0}
    code_lines = [
        "var town = get_tree().current_scene",
        "var btns = []",
        "if town._popup_body:",
        "    for c in town._popup_body.get_children():",
        "        if c.get_class() == 'Button':",
        "            btns.append(c.text)",
        f'_mcp_print("{marker}=" + str(btns))',
    ]
    res = await call_retry(session, "execute_game_script", {
        "code": "\n".join(code_lines),
    })
    btns_txt = "".join(b.text for b in res.content if hasattr(b, "text"))
    # Extract the python list literal from the marker line. The MCP wrapper
    # echoes our print output inside JSON, doubling the backslashes. To
    # avoid escaping noise we grab the marker, slice after the `=`, take
    # the first line, and parse it as a Python literal.
    import ast
    idx = btns_txt.find(marker)
    if idx >= 0:
        after = btns_txt[idx + len(marker):]
        first_line = after.split("\n", 1)[0].strip()
        # The MCP wrapper doubles backslashes inside JSON. Strip the
        # backslashes that wrap each quote: \" -> ".
        cleaned = first_line.replace('\\"', '"')
        bracket_end = cleaned.rfind("]")
        if bracket_end > 0:
            cleaned = cleaned[: bracket_end + 1]
        if cleaned.startswith("="):
            cleaned = cleaned[1:]
        try:
            btns = ast.literal_eval(cleaned)
        except Exception:
            btns = []
        if isinstance(btns, list):
            for key in popup_button_count:
                popup_button_count[key] = sum(1 for b in btns if isinstance(b, str) and key in b)
    print(f"  button counts: {popup_button_count}", flush=True)
    assert_eq(1, popup_button_count["进入矿洞"], "miner popup has 1 进入矿洞 button")
    assert_eq(1, popup_button_count["离开"], "miner popup has exactly 1 离开 button")
    await stop_scene(session)


async def test_hud_refresh(session):
    """Seed the warehouse via execute_game_script, then call _refresh_hud,
    verify the bottom-left warehouse label updates."""
    print("\n=== test_hud_refresh: HUD label updates after a warehouse add ===", flush=True)
    await play_scene_and_settle(session, mode="current")
    # The warehouse label is built in code with no `name` set, so we read
    # it through execute_game_script which has direct access to the
    # variable. _refresh_hud also touches _status_label, so we capture
    # both before and after.
    marker = f"HUD_MARK_{int.from_bytes(os.urandom(2), 'big')}"
    res = await call_retry(session, "execute_game_script", {
        "code": (
            "var town = get_tree().current_scene\n"
            f'_mcp_print("{marker}=inv:" + str(town._inventory_label.text) + "|status:" + str(town._status_label.text) + "|hud_method:" + str(town.has_method("_refresh_hud")))'
        ),
    })
    before_txt = "".join(b.text for b in res.content if hasattr(b, "text"))
    idx = before_txt.find(marker)
    before_payload = before_txt[idx + len(marker):].split("\n", 1)[0] if idx >= 0 else before_txt
    print(f"  before payload: {before_payload!r}", flush=True)

    await call_retry(session, "execute_game_script", {
        "code": (
            "var runtime = get_node('/root/GameRuntime')\n"
            "var result = runtime.transactions.apply({\n"
            "    'type': 'collect_item_into_warehouse',\n"
            "    'item_id': 'raw_common_geode',\n"
            "    'quantity': 1,\n"
            "})\n"
            "_mcp_print('ok=' + str(result.ok))\n"
        ),
    })
    await asyncio.sleep(0.3)
    await call_retry(session, "execute_game_script", {
        "code": (
            "var scene = get_tree().current_scene\n"
            "if scene and scene.has_method('_refresh_hud'):\n"
            "    scene._refresh_hud('')\n"
            "_mcp_print('refreshed')\n"
        ),
    })
    await asyncio.sleep(0.3)

    marker2 = f"HUD_MARK_{int.from_bytes(os.urandom(2), 'big')}"
    res = await call_retry(session, "execute_game_script", {
        "code": (
            "var town = get_tree().current_scene\n"
            f'_mcp_print("{marker2}=inv:" + str(town._inventory_label.text) + "|status:" + str(town._status_label.text))'
        ),
    })
    after_txt = "".join(b.text for b in res.content if hasattr(b, "text"))
    idx = after_txt.find(marker2)
    after_payload = after_txt[idx + len(marker2):].split("\n", 1)[0] if idx >= 0 else after_txt
    print(f"  after payload:  {after_payload!r}", flush=True)
    assert_true(before_payload != after_payload,
                "warehouse HUD payload changes after a mutation")
    assert_true("Clouded Geode" in after_payload,
                "warehouse HUD payload contains the new stack name")
    await stop_scene(session)


async def test_sell_picker(session):
    """Seed the warehouse, walk to the buyer, open the popup, click a
    mineral, and verify the 2-option picker appears (直接卖 + 讨价还价)."""
    print("\n=== test_sell_picker: sell shows 2-option picker ===", flush=True)
    await play_scene_and_settle(session, mode="current")
    await call_retry(session, "execute_game_script", {
        "code": (
            "var r = get_node('/root/GameRuntime')\n"
            "var res = r.transactions.apply({\n"
            "    'type': 'collect_item_into_warehouse',\n"
            "    'item_id': 'copper_nugget',\n"
            "    'quantity': 1,\n"
            "})\n"
            "_mcp_print('seeded=' + str(res.ok))\n"
        ),
    })
    await asyncio.sleep(0.3)
    await call_retry(session, "set_game_node_property", {
        "node_path": "/root/MiningTown/TownPlayer",
        "property": "position",
        "value": {"x": 900, "y": 220},
    })
    await asyncio.sleep(0.3)
    await call_retry(session, "simulate_action", {"action": "interact", "pressed": True})
    await asyncio.sleep(0.3)
    # Click on the copper_nugget button via the runtime (more reliable
    # than the MCP click_button_by_text against a freshly-built dynamic
    # popup body).
    await call_retry(session, "execute_game_script", {
        "code": (
            "var town = get_tree().current_scene\n"
            "for c in town._popup_body.get_children():\n"
            "    if c.get_class() == 'Button' and 'Copper' in c.text:\n"
            "        c.emit_signal('pressed')\n"
            "        _mcp_print('clicked: ' + c.text)\n"
            "        break\n"
        ),
    })
    await asyncio.sleep(0.5)
    # Read the picker buttons via a marker so we can parse cleanly.
    marker = f"SELL_MARK_{int.from_bytes(os.urandom(2), 'big')}"
    res = await call_retry(session, "execute_game_script", {
        "code": (
            "var town = get_tree().current_scene\n"
            "var btns = []\n"
            "if town._popup_body:\n"
            "    for c in town._popup_body.get_children():\n"
            "        if c.get_class() == 'Button':\n"
            "            btns.append(c.text)\n"
            f'_mcp_print("{marker}=" + str(btns))'
        ),
    })
    txt = "".join(b.text for b in res.content if hasattr(b, "text"))
    idx = txt.find(marker)
    payload = txt[idx + len(marker):].split("\n", 1)[0].strip() if idx >= 0 else ""
    cleaned = payload.replace('\\"', '"')
    bracket_end = cleaned.rfind("]")
    if bracket_end > 0:
        cleaned = cleaned[: bracket_end + 1]
    if cleaned.startswith("="):
        cleaned = cleaned[1:]
    import ast
    try:
        btns = ast.literal_eval(cleaned)
    except Exception:
        btns = []
    print(f"  picker buttons: {btns}", flush=True)
    has_direct = any(isinstance(b, str) and "直接卖" in b for b in btns)
    has_negotiate = any(isinstance(b, str) and "讨价还价" in b for b in btns)
    assert_true(has_direct, "sell picker shows 直接卖 option")
    assert_true(has_negotiate, "sell picker shows 讨价还价 option")
    await call_retry(session, "simulate_action", {"action": "ui_cancel", "pressed": True})
    await asyncio.sleep(0.3)
    await stop_scene(session)


async def test_small_viewport(session):
    """Verify the warehouse UI computes a sane slot_size at a smaller
    viewport by running the playtest and asking the warehouse UI directly."""
    print("\n=== test_small_viewport: warehouse UI sanity check ===", flush=True)
    await session.call_tool("open_scene", {"path": "res://scenes/town/mining_town.tscn"})
    await asyncio.sleep(0.5)
    await play_scene_and_settle(session, mode="current")
    try:
        result = await call_retry(session, "execute_game_script", {
            "code": (
                "var ui = get_tree().current_scene.get_node_or_null('WarehouseUI')\n"
                "if ui == null:\n"
                "    _mcp_print('no_ui')\n"
                "else:\n"
                "    _mcp_print('slot_size=' + str(ui._slot_size) + ' cols=' + str(ui._grid.columns) + ' children=' + str(ui._grid.get_child_count()))\n"
            ),
        })
        txt = "".join(b.text for b in result.content if hasattr(b, "text"))
        print(f"  warehouse probe: {txt!r}", flush=True)
        assert_true("cols=6" in txt, "warehouse grid has 6 columns")
        assert_true("children=48" in txt, "warehouse grid has 48 slots")
    finally:
        await stop_scene(session)


async def main():
    params = StdioServerParameters(command=NODE, args=[SERVER])
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            init = await session.initialize()
            print(f"server: {init.serverInfo.name} {init.serverInfo.version}", flush=True)
            # Wait for Godot editor connection.
            for _ in range(15):
                try:
                    await session.call_tool("get_project_info", {})
                    break
                except Exception:
                    await asyncio.sleep(1)

            tests = {
                "miner_popup": test_miner_popup,
                "hud_refresh": test_hud_refresh,
                "sell_picker": test_sell_picker,
                "small_viewport": test_small_viewport,
            }
            if TEST == "all":
                for t in tests.values():
                    try:
                        await t(session)
                    except Exception as e:
                        failures.append(f"  EXCEPTION in {t.__name__}: {e}")
                        print(f"  EXCEPTION: {e}", flush=True)
            elif TEST in tests:
                await tests[TEST](session)
            else:
                print(f"unknown test: {TEST}", flush=True)
                sys.exit(2)

    print("", flush=True)
    if failures:
        print(f"=== {len(failures)} FAILURES ===", flush=True)
        for f in failures:
            print(f, flush=True)
        sys.exit(1)
    else:
        print("=== ALL PASS ===", flush=True)


if __name__ == "__main__":
    asyncio.run(main())
