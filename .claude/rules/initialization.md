# Deterministic Manual Initialization Architecture

This document defines the architecture, rationale, and API contracts for the manual initialization sequence inside BetterBags.

## Architectural Guidelines

### 1. The Rationale: Why Manual Initialization?
Historically, BetterBags relied on the standard Ace3 module lifecycle. When the client loaded the addon, Ace3 automatically looped over every registered module using a blind `pairs()` iteration and called `OnInitialize()` on each one. 
This introduction of random and unordered initialization had critical limitations:
- **Circular & Unordered Dependencies:** A module (e.g. `BagFrame`) trying to access `database` or `themes` during `OnInitialize` would crash with nil-reference errors because `database:OnInitialize()` might not have executed yet.
- **Micro-Stutters & Script Timeouts:** On World of Warcraft clients (especially on Hardcore where script execution limits are extremely strict), initializing heavy visual structures in the random order during `PLAYER_LOGIN` / `OnEnable` caused framerate stutters and addon-loading script timeouts of up to 200ms.
- **Lack of Control:** Without topological sorting, maintaining correct loading orders was a fragile, hard-to-maintain process of manual `:Enable()` gates.

### 2. The Solution: Bypassing Ace3 Auto-Initialization
We decouple our module initialization from Ace3's automatic loading loops.
- **Rule:** Every registered Ace3 module in BetterBags must define `Init()` instead of `OnInitialize()`.
- **Isolation:** Because Ace3 only automatically invokes `OnInitialize` and does not know about our custom `Init()` method, Ace3's blind initialization loop is completely bypassed for our modules.

### 3. Grand Orchestration in `core/init.lua`
All module initialization is explicitly, synchronously, and deterministically orchestrated at the very beginning of `addon:OnInitialize()` in `core/init.lua`.

The deterministic loading order is rigorously divided into 5 distinct phases:

```
ADDON_LOADED (core/init.lua: OnInitialize)
  ├── 1. Core & Utilities (events, debug, async, bucket)
  ├── 2. Database (DB - loaded before downstream queries)
  ├── 3. Data Models & Scanners (tooltipScanner, itemLoader, categories, groups, equipmentSets, search, items, refresh)
  ├── 4. Themes & Presentation Frames (themes, itemFrame, sectionFrame, contextMenu, bagButton, itemRowFrame)
  └── 5. Integrations (consoleport)
```

#### Exact Loading Code Block:
```lua
  -- 1. Core and Utilities
  events:Init()
  debug:Init()
  async:Init()
  addon:GetModule('Bucket'):Init()

  -- 2. Database (DB must be initialized before other data/UI modules read config)
  database:Init()

  -- 3. Data Models and Scanners
  addon:GetModule('TooltipScanner'):Init()
  itemLoader:Init()
  categories:Init()
  addon:GetModule('Groups'):Init()
  addon:GetModule('EquipmentSets'):Init()
  search:Init()
  items:Init()
  refresh:Init()

  -- 4. Themes and Presentation Frames
  themes:Init()
  itemFrame:Init()
  sectionFrame:Init()
  contextMenu:Init()
  addon:GetModule('BagButton'):Init()
  addon:GetModule('ItemRowFrame'):Init()

  -- 5. Integrations
  consoleport:Init()
```

### 4. Shifting Heavy UI Frame Creation to ADDON_LOADED
To completely avoid script timeout errors (up to 200ms) during the enter-world sequences (`PLAYER_LOGIN`) on World of Warcraft (especially in Hardcore environments), the heavy structural UI creation is shifted entirely to the `ADDON_LOADED` phase inside `addon:OnInitialize()`.
- **Phase Split:** Building physical bag and bank containers (`BagFrame:Create`), applying structural and theme textures (`themes:Enable`), setting up backpack titles, and registering frames to `UISpecialFrames` are performed under `addon:OnInitialize()`. This phase is immune to the engine's standard script execution timers.
- **Data Decoupling:** Absolutely no data-api queries, `C_Container` scans, search engine indexing, or items harvesting are permitted during this phase. The UI frames must remain empty structural shells.
- **OnEnable Login-Only Sweep:** The first data harvest/sweep and actual UI rendering (`RequestUpdate`) are triggered synchronously inside `OnEnable()`, ensuring that heavy visual rendering only happens when the game data is fully ready.

### 5. Safecall-Resilient Ordering: Establish Invariants Before Fallible Frame/Theme Creation
Ace3 runs `addon:OnInitialize()` inside a `safecall` (`xpcall`, `libs/AceAddon-3.0/AceAddon-3.0.lua:494`). If any statement in `OnInitialize` throws, the error is reported to `geterrorhandler()` but execution is **not** aborted at the addon level: Ace3 still proceeds to `EnableAddon` → `OnEnable`, which installs the `ToggleAllBags`/`CloseSpecialWindows` secure hooks. The addon is therefore left **enabled but only partially initialized** — anything assigned after the throw point never exists, yet the bag open/close path is live.
- **Rule:** Any state that the always-live bag open/close path depends on must be assigned **before** the first fallible frame/theme/bank creation call in `OnInitialize`. Concretely, the keybinding frame (`addon._bindingFrame`) and the highlight-button list (`addon._buttons`, consumed by `addon:UpdateButtonHighlight` on every `bags/OpenClose`) are set up immediately after `addon.Bags.Backpack` is created (so `UpdateButtonHighlight`'s `addon.Bags.Backpack:IsShown()` is valid) and before the bank frame, `themes:Enable`, `SetTitle`, `UISpecialFrames`, and CVar calls — any of which can throw on a given client/patch/config.
- **Regression context (issue #1076):** The manual-init refactor (#1047) moved the `_buttons`/`_bindingFrame`/OnClick-hook block to the **end** of `OnInitialize`, after bank creation and theme application. On a client where one of those later calls threw (e.g. a bank/theme code path, or `themes:SetTitle` indexing an unregistered saved theme), `OnInitialize` aborted before `_buttons` was assigned, and every bag toggle then crashed at `core/init.lua` `UpdateButtonHighlight` with `bad argument #1 to 'pairs' (table expected, got nil)`. The fix restores the pre-#1047 invariant (button/binding setup runs early). Coverage: `spec/core/init_spec.lua` ("populates addon._buttons even if a later OnInitialize step throws", "UpdateButtonHighlight does not error after a partial OnInitialize").
- **Theme accessors must self-heal to Default.** `themes:SetTitle` (and any accessor callable during `OnInitialize`, before `themes:OnEnable` has resolved the fallback) must resolve the active theme through `themes:GetCurrentTheme()`, which falls back to `Default` when the saved theme key is unregistered or unavailable — matching `GetFlatHeaderHeight`/`GetItemButton`. Never index `self.themes[db:GetTheme()]` directly, since a third-party theme's addon may not have loaded yet at `ADDON_LOADED`. Coverage: `spec/themes_spec.lua` ("SetTitle fallback").

## API Contracts and Maintenance

- **Adding a New Module:** When creating a new module, do **not** use `OnInitialize()`. Use `Init()`, and explicitly register/call it inside `addon:OnInitialize()` in `core/init.lua` in its correct dependency position.
- **Double-Initialization Safety:** Because we bypass Ace3's loop entirely, modules are initialized exactly once in a predictable environment.
- **Unit and Integration Testing:** Test setup blocks in the `spec/` suite must mimic this sequence. If a test loads or stubs a module, it must manually invoke `:Init()` to establish the module's baseline states instead of relying on Ace3 mock hooks.
