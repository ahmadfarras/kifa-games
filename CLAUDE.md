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
- **This is a kids' app**: collect no personal data, add no analytics, ads, accounts or network calls without an explicit decision by the owner (COPPA / GDPR-K). No external links without a parental gate.
- **Web export**: serve over HTTPS only; never pass untrusted strings to `JavaScriptBridge.eval()`.
- **Dependencies and assets**: only from official sources, pinned to a version (e.g. GUT 9.7.1 in `addons/gut/`), with a compatible license recorded: for art, add a row (author, source URL, license, date checked) to `assets/<game>/CREDITS.md`. Review a third-party addon's code before adding it.

## Commands

```sh
godot --headless --import                    # import project, register class_names, catch parse errors
godot --headless -s addons/gut/gut_cmdln.gd  # run all unit tests (GUT 9.7.1, settings in .gutconfig.json)
godot --path .                               # run the game
godot --headless -s tools/prepare_runner_assets.gd  # regenerate Runner art from the raw packs
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
  shared/                    # shared kernel — only code genuinely used by 2+ games
    domain/
    infrastructure/
    presentation/            # reusable UI pieces (StarProgress, WinScreen) and styles/*.tres
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
- **Runner** — the player character the kid picks (currently: Little Girl, Little Boy). Jumps; can't jump in mid-air.
- **Obstacle** — object scrolling toward the runner; touching it ends the run. Has a **variant** (which art) and a **footprint** (width × height in units, taken from the art), which sets its hitbox.
- **Decoration** — trees, grass and flowers placed at random along the ground. Purely visual: no collision, no effect on the game.
- **Parallax layer** — a background strip (clouds, hills, far trees, ground) that scrolls slower the further away it is.
- **Run** — one play session from start to crash. Has elapsed time, speed, score.
- **Speed** — world scroll speed; grows with elapsed time, capped.
- **Gap** — distance until the next obstacle spawns; scales with speed so it stays jumpable.
- **Score** — stars earned, 2 per second of running. **Best score** — highest score, persisted.

**Match** (`src/games/match`)
- **Card** — shows a **face** (which animal; an index into the pictures); face up or down; matched once its pair is found.
- **Round** (`MatchRound`) — one board dealt for a level; the kid flips two cards at a time.
- **Match / Mismatch** — two flipped cards with the same face stay open and light a star; different faces wobble and flip back after a short pause (taps are ignored meanwhile).
- **Level** — number of pairs: 3 (⭐), 6 (⭐⭐), 8 (⭐⭐⭐).

**Math** (`src/games/math`)
- **Question** — one kid-sized sum (`a` op `b`) with an answer and three **choices** (the answer + two close wrong ones). Numbers stay small; answers are always whole and never negative.
- **Mode** — which operation the quiz asks: add, subtract, multiply, divide, or mix (random each question).
- **Quiz** — one play session of `Quiz.GOAL` (5) right answers. A wrong choice turns grey and the kid tries again; a right one lights a star and the next question follows after a short pause.

**App** (`src/app`)
- **Hub** — the main menu where the kid picks a game.

## Conventions

- Code, identifiers and commit messages in English.
- **Navigation:** `src/app/main.gd` is the router and composition root. It shows the Hub, builds a game (with its dependencies) when picked and frees it on the game's `exit_requested` signal. Scenes are `load()`ed on demand, never `preload()`ed in main, so only the running game's art is in memory.
- **Shared UI:** `StarProgress` (row of stars lit one by one) and `WinScreen` ("You did it!" overlay with confetti) live in `src/shared/presentation/` together with common button styles (`styles/*.tres`); Match and Math use them. Reuse them for new games instead of copying.
- Games are event driven where possible (signals, `Timer`, `Tween`); Match and Math have no `_process` at all. Animation speed is exposed (e.g. `CardView.animation_speed`) so tests run animations in a few frames instead of waiting real time.
- `class_name` for every domain/application/infrastructure class; typed GDScript everywhere.
- Input only via InputMap actions (e.g. `jump`: Space, Up, click/tap), never raw keycodes.
- Renderer is `gl_compatibility` (the only one the Web export supports). Base viewport 720×720 + stretch `canvas_items`/`expand`, so UI sizes follow the shortest screen side in both portrait and landscape.
- Runner characters are `AnimatedSprite2D` + a generated `SpriteFrames` (`assets/runner/characters/<name>.tres`) with animations `idle`, `run`, `jump`, `dead`. **Add a character** = raw frames in `assets/runner/characters/raw/<name>/` + an entry in `CHARACTERS` in the asset tool (with fps so durations match other characters, e.g. run cycle ≈ 0.7 s) + re-run the tool + a `CharacterButton` in `runner_ui.tscn` (duplicate an existing one: it must keep `toggle_mode` and the shared `characters` ButtonGroup). `RunnerSprite` sizes and anchors the feet from `metadata/bodies` written by the tool, so no pixels are read at runtime. Art changes touch only `presentation/`, `assets/` and the tool. Emoji remain only in UI text and as Match card faces (placeholder: swap to textures in `match/presentation` only).
- **Textures import as lossy WebP (quality 0.8) by default** (`[importer_defaults]` in `project.godot`): small downloads, same VRAM. Switch a single texture to lossless only if lossy visibly hurts it.
- **Character sheets:** the tool scales every character so its standing body is `BODY_HEIGHT` (193) px, crops each frame to its visible pixels and shelf-packs one sheet per animation (≤ 2048 px wide); `AtlasTexture.margin` restores the common frame box so frames stay aligned. Unused raw frames (e.g. Walk) never reach the export.
- **Art pipeline:** raw asset packs stay in git but inside folders with a `.gdignore` (never imported or exported). `tools/prepare_runner_assets.gd` crops padding, merges/crops parallax layers to the rows that can be visible, halves their size, cuts trees out of the tree layer, and writes game-ready PNGs to `assets/runner/backgrounds/{layers,trees,decorations}/` and `assets/runner/obstacles/`. Change the tool and re-run it instead of editing generated files by hand.
- **Obstacles:** one texture per variant in `RunnerGame.obstacle_textures`; footprint = texture size × `OBSTACLE_UNITS_PER_PIXEL`. Leave out art too small to see (e.g. pebbles). Obstacle sprites are pooled and share one `obstacle_outline.gdshader` material (red outline) so kids can tell what to jump over. **Decorations must never get this outline**, and decoration art must not look like an obstacle (or float above the ground).
- **Background:** `RunnerBackground` fits the art to the screen height; layers are `ScrollingLayer`s (one draw call each, `texture_repeat` MIRROR for art whose edges don't match), decorations are `DecorationStrip`s (fixed sprite pool, recycled left → right with random texture/gap/size/flip; O(1) amortized per frame). The ground layer scrolls at factor 1.0 so it stays locked to obstacles.
- Every function has GUT tests (> 90% coverage). Domain and application layers must be fully tested without the scene tree.
