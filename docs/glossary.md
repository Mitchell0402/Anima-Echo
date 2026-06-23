# Glossary

- Anima Echo: Godot 2D mining prototype in this repository.
- Town: Main hub scene at `res://scenes/town/mining_town.tscn`.
- Mine: Current playable mine route at `res://scenes/mine/test_scene.tscn`.
- MinecartExit: Mine scene node that returns the player to the town.
- GameRuntime: Autoload that owns current session state and runtime services.
- GameCatalog: Runtime loader/index for `data/game/catalog.json`.
- GameTransactionService: Central mutation boundary for inventory and currency changes.
- GameInventory: Runtime inventory model owned by `GameRuntime`.
- GameWallet: Runtime currency model owned by `GameRuntime`.
- ItemDatabase: Compatibility helper for hotbar item icons, stack keys, display names, and stack limits.
- Raw geode: Unidentified mine pickup item, such as `raw_common_geode`.
- Mineral: Identified sellable item, such as `copper_nugget` or `silver_vein`.
- Identification: Economy service action that converts a raw geode into a mineral.
- Customer: Catalog-defined buyer used by negotiation and shop services.
- Task: Catalog-defined objective/reward entry managed by `TaskService`.
- NoiseSystem: Shared event system used to communicate player noise to enemy AI.
- WeightSystem: Autoload that calculates total backpack weight from raw geodes in GameRuntime.inventory and determines encumbrance tier (Light/Heavy/Overload), affecting speed and noise.
- Godot MCP: Editor/runtime helper addon under `addons/godot_mcp`.
