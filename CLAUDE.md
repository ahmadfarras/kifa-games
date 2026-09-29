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
- **Dependencies and assets**: only from official sources, pinned to a version (e.g. GUT 9.7.1 in `addons/gut/`), with a compatible license file kept next to them. Review a third-party addon's code before adding it.

## Commands

```sh
godot --headless --import                    # import project, register class_names, catch parse errors
godot --headless -s addons/gut/gut_cmdln.gd  # run all unit tests (GUT 9.7.1, settings in .gutconfig.json)
godot --path .                               # run the game
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
- **Obstacle** — object scrolling toward the runner; touching it ends the run.
- **Run** — one play session from start to crash. Has elapsed time, speed, score.
- **Speed** — world scroll speed; grows with elapsed time, capped.
- **Gap** — distance until the next obstacle spawns; scales with speed so it stays jumpable.
- **Score** — stars earned, 2 per second of running. **Best score** — highest score, persisted.

## Conventions

- Code, identifiers and commit messages in English.
- `class_name` for every domain/application/infrastructure class; typed GDScript everywhere.
- Input only via InputMap actions (e.g. `jump`: Space, Up, click/tap), never raw keycodes.
- Renderer is `gl_compatibility` (the only one the Web export supports). Base viewport 720×720 + stretch `canvas_items`/`expand`, so UI sizes follow the shortest screen side in both portrait and landscape.
- Runner characters are `AnimatedSprite2D` + a `SpriteFrames` resource (`assets/runner/characters/<name>.tres`) with animations `idle`, `run`, `jump`, `dead`. Add a character = new `.tres` + a `CharacterButton` in `runner_ui.tscn` (duplicate an existing one: it must keep `toggle_mode` and the shared `characters` ButtonGroup). `RunnerSprite` sizes and anchors (feet) from the visible pixels of each animation's first frame, so differently padded packs line up without manual offsets. Match animation durations across characters via each animation's fps (e.g. run cycle ≈ 0.7 s). Obstacles, sun and flowers are still emoji placeholders. Art changes touch only `presentation/` and `assets/`.
- Large sprite frames: set the texture import option **Process → Size Limit** so the character's visible body is ~193 px tall (same for every character), using the **same scale factor for every frame of a character** (else animations change size). Keeps VRAM low on Web/mobile.
- Every function has GUT tests (> 90% coverage). Domain and application layers must be fully tested without the scene tree.
