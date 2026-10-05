# Kifa Games

Collection of simple kids' games built with **Godot 4.7** (GDScript), exported to Web, mobile and desktop. Ported from the vanilla JS repo `../webapp-game-kifa` (kept alive separately — never modify or merge it). Port progress and asset plan: [MIGRATION.md](MIGRATION.md).

Always follow the global `godot-senior-engineer` skill. This file adds project-specific rules; **the folder layout below replaces the layout in the skill's "Clean architecture" section.**

## Non-negotiables: performance, file size and security

These rules (performance, file size, security) come first. They are **not negotiable**: they win over convenience, speed of delivery and KISS. If a requirement conflicts with them, stop and ask instead of working around them.

### Performance (target: 60 FPS on low-end phones and the Web export)
- Nothing runs when it isn't needed. Every `_process`/`_physics_process` must be switched off (`set_process(false)`) when the node is hidden, idle or not selected. Examples: the game world only processes during a run, and only the *selected* character button animates.
- Per-frame work is O(n) or better in the number of on-screen objects; no nested loops over entities, no allocation, no `get_node()`, no string building in hot paths (cache with `@onready`, reuse objects).
- Expensive work (image reads, layout, resource loading) runs once and is cached, never per frame.
- Keep memory small: downscale large textures on import (see Conventions), no unused assets loaded at runtime.
- Any change touching a hot path must state its Big-O and what stops it from running when idle.

### File size (the game must stay small and its size must be checkable)
- Always optimize for **both runtime performance and file size**. Every change that adds or changes assets states its size impact (before → after) in the summary/PR.
- **Only ship what the game uses.** Unused frames, drafts and source files must not end up in the export: use export filters (export only resources used by scenes) or keep sources outside `res://` / in a folder with a `.gdignore`.
- **Images:** downscale on import to the size actually drawn (Process → Size Limit), crop empty padding where possible, prefer sprite sheets/atlases over hundreds of loose PNGs for new assets, and use lossy/VRAM compression when it doesn't visibly hurt the art.
- **Audio:** Ogg Vorbis for music and longer sounds, short WAV only for tiny SFX; mono unless stereo is audible; sample rate no higher than needed.
- **Fonts:** only the fonts and weights in use; subset large (e.g. emoji/CJK) fonts.
- **Code/addons:** test-only addons (GUT) and `tests/` are excluded from release exports.
- Verify with a real export: check the size of the `.pck` / Web build after asset changes, not just the source folder.

### Security
- **All external data is untrusted**: save files in `user://` (editable by anyone with the device), anything from the network, the clipboard or JavaScript. Validate type, range and shape on load, and fall back to safe defaults on anything invalid.
- **Never deserialize Godot Variant/Object syntax from untrusted data**: no `ConfigFile`, `str_to_var`, `bytes_to_var(_with_objects)`, `ResourceLoader.load()`/`load()` on files in `user://` or downloaded files. These can instantiate objects and attach scripts, which means running code. Use JSON (`JSON.parse`) for saves and settings.
- **No secrets in the repo**: keystores, service accounts, API keys and export credentials stay git-ignored (see `.gitignore`; Godot keeps export passwords in `.godot/export_credentials.cfg`).
- **This is a kids' app**: collect no personal data, add no analytics, ads, accounts or network calls without an explicit decision by the owner (COPPA / GDPR-K). No external links without a parental gate. **Decided so far (2026-10-05):** optional accounts (nickname + password, no email) and cloud saves on Firebase Auth + Firestore; nothing else. A guest never causes a network request. Anything the server stores must be listed in the in-game Privacy page (`account_screen.tscn`) and removed by Delete account.
- **Server access is decided on the server**: `firestore.rules` (owner-only documents, shape and range checks, default deny), never by the client. Change the rules together with `tools/test_firestore_rules.py`. The Firebase Web API key in `src/app/firebase_config.gd` is public by design; service account files stay out of the repo.
- **Network code**: only through `JsonHttp` (timeout, response size cap, no redirects, nothing logged) to the three hosts allowed by the CSP in `firebase.json`. Responses are untrusted like save files: validate before use. Only validated letters/digits go into a URL path. Never log, store or keep passwords; the refresh token in `user://account.json` is the only credential on the device.
- **Web export**: serve over HTTPS only; never pass untrusted strings to `JavaScriptBridge.eval()`.
- **Dependencies and assets**: only from official sources, pinned to a version (e.g. GUT 9.7.1 in `addons/gut/`), with a compatible license recorded: for art, add a row (author, source URL, license, date checked) to `assets/<game>/CREDITS.md`. Review a third-party addon's code before adding it.

## Commands

```sh
godot --headless --import                    # import project, register class_names, catch parse errors
godot --headless -s addons/gut/gut_cmdln.gd  # run all unit tests (GUT 9.7.1, settings in .gutconfig.json)
godot --path .                               # run the game
godot --headless -s tools/prepare_runner_assets.gd  # regenerate Runner art from the raw packs
python3 tools/subset_emoji_font.py <NotoColorEmoji.ttf>  # rebuild the emoji font after adding/removing emoji in src/

# Firestore access rules (firestore.rules): check in the local emulator, then deploy (owner only)
JAVA_HOME=/opt/homebrew/opt/openjdk@21 PATH=/opt/homebrew/opt/openjdk@21/bin:$PATH \
  firebase emulators:exec --only firestore --project kifa-games "python3 tools/test_firestore_rules.py"
firebase deploy --only firestore:rules

# Web build + Firebase Hosting (project "kifa-games", see firebase.json)
godot --headless --export-release "Web" build/web/index.html
firebase hosting:channel:deploy preview      # temporary preview URL, live site untouched
firebase deploy --only hosting               # replace the live site (only after the preview is checked)
```

## Architecture: DDD + Clean Architecture

Each game is a **bounded context**. Code is split into four layers; dependencies point **inward only**:

```
presentation ──▶ application ──▶ domain
infrastructure ─────────────────▶ domain (implements its ports)
```

### Folder layout

```
src/
  app/                       # composition root: main menu, scene switching, autoloads, wiring of dependencies
  account/                   # accounts (register, log in, log out, delete): a bounded context that is not a game
    domain/ application/ infrastructure/ presentation/
  shared/                    # shared kernel — only code genuinely used by 2+ contexts
    domain/                  # GateQuestion (parental gate)
    infrastructure/          # JsonFile (atomic JSON in user://), JsonHttp, FirestoreDocuments
    presentation/            # reusable UI pieces (StarProgress, WinScreen, ParentGate) and styles/*.tres
  games/
    <game>/                  # runner, math, match, coloring — one bounded context each
      domain/                # entities, value objects, domain services, ports. Pure GDScript.
      application/           # use cases: orchestrate domain objects for one user action
      infrastructure/        # adapters for ports: save files (user://), audio, RNG
      presentation/          # .tscn scenes + Node scripts: input, visuals, UI
assets/<game>/               # sprites, audio, fonts (CC0/licensed only)
tests/unit/                  # mirrors src/, e.g. tests/unit/games/runner/domain/test_obstacle.gd
```

### Layer rules

| Layer | May depend on | Rules |
|---|---|---|
| **domain** | nothing (only other domain code in the same context or `shared/domain`) | `extends RefCounted` or `Resource`. No `Node`, no scene tree, no `Input`, no `FileAccess`, no autoloads. Time (`delta`) and randomness (`RandomNumberGenerator`) are passed in. |
| **application** | domain | Use cases as methods on one small service per game (e.g. `RunnerSession.start_run/jump/tick`). Split into one class per use case only when a use case grows beyond simple delegation. No Node APIs. Receives ports via `_init(...)`. |
| **infrastructure** | domain (ports) | Implements ports, e.g. `JsonBestScoreRepository`. The only place that touches `user://`, `FileAccess`, `AudioStreamPlayer` setup, etc. |
| **presentation** | application, domain (read-only) | Thin Node scripts: map input actions to use cases, render domain state, emit signals. No game rules here. |
| **app** | everything | Builds concrete infrastructure, injects it into use cases, hands them to scenes. The only place that knows all layers. |

- **Bounded contexts don't import each other.** Share only through `src/shared/`, and only when a second game actually needs it (KISS — don't pre-share).
- **Ports** (interfaces) live in the domain as `@abstract` classes, e.g. `@abstract class_name BestScoreRepository extends RefCounted` with `@abstract func load_best() -> int`. Tests use in-memory fakes.
- **Entities** have identity and change over time (`Run`, `Runner`, `Obstacle`). Introduce a **value object** (immutable, compared by value) only when a plain `int`/`float` stops being enough.
- Domain objects keep their invariants: state changes only through their methods; other layers treat domain fields as read-only (tests may set fields to arrange a scenario).
- Domain values use **screen-independent units** (Runner: 1.0 = shortest screen side). Presentation converts to pixels.

### Keep it simple

DDD and clean architecture serve readability and testability, not ceremony:

- Create a layer folder only when it has code. A game with no persistence has no `infrastructure/`.
- No repositories, factories, events or aggregates "just in case". A use case can be a single `execute()` method.
- Math/UI-only games (e.g. Math) may be mostly domain + presentation — that's fine.

## Ubiquitous language

Use these names in code, tests and conversation. Add terms when a game is ported.

**Runner** (`src/games/runner`)
- **Runner** — the player character the kid picks (currently: Little Girl, Little Boy, Cat). Jumps; can't jump in mid-air.
- **Obstacle** — object scrolling toward the runner; touching it ends the run. Has a **variant** (which art) and a **footprint** (width × height in units, taken from the art), which sets its hitbox.
- **Decoration** — trees, grass and flowers placed at random along the ground. Purely visual: no collision, no effect on the game.
- **Parallax layer** — a background strip (clouds, hills, far trees, ground) that scrolls slower the further away it is.
- **Run** — one play session from start to crash. Has elapsed time, speed, score.
- **Speed** — world scroll speed; grows with elapsed time, capped.
- **Gap** — distance until the next obstacle spawns; scales with speed so it stays jumpable.
- **Score** — stars earned, 2 per second of running. **Best score** — highest score, persisted.
- **Coins** — currency earned from runs: 1 coin per star of score, added when the run ends. Never negative.
- **Wallet** — the kid's coin balance.
- **Character** — a runner the kid can play as; has an id, a price (0 = free) and art (`CharacterCatalog`).
- **Owned** — a character the kid can play with (free or unlocked). Only owned characters can start a run.
- **Unlock / Buy** — spend a character's price from the wallet to own it (always after a Yes/No confirmation).
- **Shop** — screen listing characters with their price and owned state (`ShopScreen`, opened from the start screen).
- **Progress** — everything saved for Runner: best score, coins, owned characters (`Progress`).

**Match** (`src/games/match`)
- **Card** — shows a **face** (which animal; an index into the pictures); face up or down; matched once its pair is found.
- **Round** (`MatchRound`) — one board dealt for a level; the kid flips two cards at a time.
- **Match / Mismatch** — two flipped cards with the same face stay open and light a star; different faces wobble and flip back after a short pause (taps are ignored meanwhile).
- **Level** — number of pairs: 3 (⭐), 6 (⭐⭐), 8 (⭐⭐⭐).

**Math** (`src/games/math`)
- **Question** — one kid-sized sum (`a` op `b`) with an answer and three **choices** (the answer + two close wrong ones). Numbers stay small; answers are always whole and never negative.
- **Mode** — which operation the quiz asks: add, subtract, multiply, divide, or mix (random each question).
- **Quiz** — one play session of `Quiz.GOAL` (5) right answers. A wrong choice turns grey and the kid tries again; a right one lights a star and the next question follows after a short pause.

**Coloring** (`src/games/coloring`)
- **Page** (`ColoringPage`) — one picture being colored: a colour per **region**, or BLANK (unpainted / erased).
- **Brush** — the picked colour (palette index, or BLANK = eraser). Tapping a region paints it with the brush.
- **Complete** — no region is BLANK; celebrates once per page (until cleared). ✨ **Magic** fills every region with random colours; 🧽 **clear** blanks the page.
- **Picture** — line art in a 400×320 space (`PictureLibrary`): paintable regions + fixed decorations, ported from the original SVG.

**Account** (`src/account`)
- **Guest** — playing without an account; progress lives only on this device.
- **Account** — a username + password that owns the cloud saves. Optional; created by a grown-up.
- **Username** — picked by the kid: 3–16 plain letters and digits; upper/lower case is the same name. Sent to Firebase as `name@kifa-games.invalid` (no real email anywhere).
- **Session** (`AccountSession`) — who is logged in on this device (uid, username, refresh token).
- **Parental gate** (`ParentGate`, `GateQuestion`) — a multiplication (factors 6–9) asked before creating or deleting an account.
- **Account card** — the page shown once after registering: the username and "write down your password" (there is no password reset).

**App** (`src/app`)
- **Hub** — the main menu where the kid picks a game.
- **Cloud save** — the server copy of one game's progress for one account (`saves/{uid}/games/{game}` in Firestore).
- **Sync** — pull the cloud save, **merge** it into the device's progress, save on the device, push the result (`ProgressSync`, `CloudSaves`).
- **Merge** (`Progress.absorb`) — best score = highest; owned = both sets; coins = highest lifetime earnings minus the price of everything owned. Same result in any order, safe to repeat.

## Conventions

- Code, identifiers and commit messages in English.
- **Navigation:** `src/app/main.gd` is the router and composition root. It shows the Hub, builds a game (with its dependencies) when picked and frees it on the game's `exit_requested` signal. Scenes are `load()`ed on demand, never `preload()`ed in main, so only the running game's art is in memory.
- **Shared UI:** `StarProgress` (row of stars lit one by one) and `WinScreen` ("You did it!" overlay with confetti) live in `src/shared/presentation/` together with common button styles (`styles/*.tres`); Match, Math and Coloring use them (WinScreen texts are per game). Reuse them for new games instead of copying.
- **Coloring pictures** are polygons built by `PictureLibrary` (rect / circle / ellipse with SVG-style rotation / `path()` for SVG `M L Q Z` strings). `ColoringCanvas` draws the whole picture in one `_draw()` and redraws only when a colour changes; taps use point-in-polygon from the top shape down. Add a picture = id + icon + builder in `PictureLibrary` (keep regions as closed shapes).
- **Emoji:** Web builds have no system emoji font, so `main.gd` adds a bundled Noto Color Emoji subset (`assets/shared/fonts/`) as fallback of the default font. After adding a new emoji anywhere in `src/`, re-run `tools/subset_emoji_font.py` or it shows as an empty box on Web.
- **Export:** `export_presets.cfg` is committed (Godot keeps passwords in `.godot/export_credentials.cfg`). The Web preset excludes `addons/gut`, `tests/`, `tools/` and is single-threaded (no special COOP/COEP headers needed on hosting). No Godot logo: `boot_splash/show_image=false` (sky colour background) and the Web loading screen ("Loading…" on the Hub gradient) is plain CSS in the preset's `html/head_include`, so it adds no image. `build/` holds a tracked `.gdignore` so Godot never imports a previous build back into the next `.pck`. Hosting headers (CSP, `X-Frame-Options`, etc.) live in `firebase.json`: the CSP allows only same-origin resources, so loading anything from another origin needs a CSP change (and an owner decision).
- Games are event driven where possible (signals, `Timer`, `Tween`); Match, Math and Coloring have no `_process` at all. Animation speed is exposed (e.g. `CardView.animation_speed`) so tests run animations in a few frames instead of waiting real time.
- `class_name` for every domain/application/infrastructure class; typed GDScript everywhere.
- Input only via InputMap actions (e.g. `jump`: Space, Up, click/tap), never raw keycodes.
- Renderer is `gl_compatibility` (the only one the Web export supports). Base viewport 720×720 + stretch `canvas_items`/`expand`, so UI sizes follow the shortest screen side in both portrait and landscape.
- Runner characters are `AnimatedSprite2D` + a generated `SpriteFrames` (`assets/runner/characters/<name>.tres`) with animations `idle`, `run`, `jump`, `dead`. **Add a character** = raw frames in `assets/runner/characters/raw/<name>/` + an entry in `CHARACTERS` in the asset tool (animation → raw prefixes played in order, e.g. Cat `jump` = `Jump` + `Fall`; fps so durations match other characters, e.g. run cycle ≈ 0.7 s) + re-run the tool + an entry in `CharacterCatalog.ENTRIES` (price: previous × ~1.7, rounded to 100; next ones 900, 1500, 2500) + a `CharacterButton` in `runner_ui.tscn` with `character_id` set (duplicate an existing one: it must keep `toggle_mode` and the shared `characters` ButtonGroup). The shop builds its cards from those buttons, so it needs no change. Credit the art in `assets/runner/CREDITS.md`. `RunnerSprite` sizes and anchors the feet from `metadata/bodies` written by the tool, so no pixels are read at runtime. Art changes touch only `presentation/`, `assets/` and the tool. Emoji remain only in UI text and as Match card faces (placeholder: swap to textures in `match/presentation` only).
- **Textures import as lossy WebP (quality 0.8) by default** (`[importer_defaults]` in `project.godot`): small downloads, same VRAM. Switch a single texture to lossless only if lossy visibly hurts it.
- **Character sheets:** the tool scales every character so its standing body is `BODY_HEIGHT` (193) px, crops each frame to its visible pixels and shelf-packs one sheet per animation (≤ 2048 px wide); `AtlasTexture.margin` restores the common frame box so frames stay aligned. Unused raw frames (e.g. Walk) never reach the export.
- **Art pipeline:** raw asset packs stay in git but inside folders with a `.gdignore` (never imported or exported). `tools/prepare_runner_assets.gd` crops padding, merges/crops parallax layers to the rows that can be visible, halves their size, cuts trees out of the tree layer, and writes game-ready PNGs to `assets/runner/backgrounds/{layers,trees,decorations}/` and `assets/runner/obstacles/`. Change the tool and re-run it instead of editing generated files by hand.
- **Obstacles:** one texture per variant in `RunnerGame.obstacle_textures`; footprint = texture size × `OBSTACLE_UNITS_PER_PIXEL`. Leave out art too small to see (e.g. pebbles). Obstacle sprites are pooled and share one `obstacle_outline.gdshader` material (red outline) so kids can tell what to jump over. **Decorations must never get this outline**, and decoration art must not look like an obstacle (or float above the ground).
- **Runner save file** (`user://runner_save.json`, `JsonProgressRepository`): v2 = `{"version": 2, "best_score", "coins", "owned": [ids]}`. A file without `version` is v1 (`{"best_score": N}`) and loads with 0 coins + the free characters; a newer `version` loads fresh and the file is left untouched until the next save. Everything is validated (whole numbers in range, only known ids, `owned` capped at 2 × catalog size) and rebuilt through `Progress.restore()`, which keeps the invariants. Saves are atomic (write `.tmp`, then rename) and happen only on run end and a successful purchase. Progress is per device/browser only (no accounts or cloud save).
- **Shop:** locked `CharacterButton`s turn off `toggle_mode` (so they can't be selected), dim the art and show `🔒 🪙 price`; a tap emits `shop_requested(id)`. `ShopScreen` duplicates its `CardTemplate` once per catalog id; each `ShopCard`'s art is a `CharacterButton` in a shop-only ButtonGroup, so only the focused card animates and nothing processes while the shop is hidden. After a purchase `RunnerGame` refreshes the start screen and shop from `RunnerSession.progress`, pops the card and selects the new character.
- **Background:** `RunnerBackground` fits the art to the screen height; layers are `ScrollingLayer`s (one draw call each, `texture_repeat` MIRROR for art whose edges don't match), decorations are `DecorationStrip`s (fixed sprite pool, recycled left → right with random texture/gap/size/flip; O(1) amortized per frame). The ground layer scrolls at factor 1.0 so it stays locked to obstacles.
- **Accounts and cloud saves:** `main.gd` builds the services once (`_build_services`): `AccountService` (Firebase Auth over REST via `FirebaseAuthGateway`), one shared `JsonProgressRepository`, `ProgressSync` + `FirestoreProgressCloud`, and `CloudSaves`, which owns *when* to sync: app start, login, purchase, leaving Runner, and run end at most once per 60 s. Device first, cloud second: a failed sync loses nothing and the next one catches up. Logging out syncs, then resets the device to fresh progress (so the next kid does not inherit coins); deleting an account asks the gate and the password, deletes the cloud saves, then the account. Tests inject in-memory services with `main.setup(...)` (`tests/unit/app/fake_services.gd`); no unit test touches the network.
- **Add a cloud save for another game:** a port + adapter like `ProgressCloud` / `FirestoreProgressCloud` (its own fields, codec validation and merge rule), a `match /saves/{uid}/games/<game>` block in `firestore.rules` + cases in `tools/test_firestore_rules.py`, the game id in `CloudSaves.GAMES`, and the wiring in `main.gd`. Accounts need no change.
- **Text fields on Web:** phones need `html/experimental_virtual_keyboard=true` (export preset). While the on-screen keyboard is open Godot draws no caret unless `caret_force_displayed` is set (done per focused field in `AccountScreen`), and the default caret colour is near-white, so set `caret_color` on light fields. `HTTPRequest.accept_gzip` must stay off (`JsonHttp.new_request()`): the browser already unpacks gzip. Check Web changes in a browser, not only on desktop.
- Every function has GUT tests (> 90% coverage). Domain and application layers must be fully tested without the scene tree.
