# Kifa Games

Collection of simple kids' games built with **Godot 4.7** (GDScript), exported to Web, mobile and desktop. Ported from the vanilla JS repo `../webapp-game-kifa` (kept alive separately — never modify or merge it). Port progress and asset plan: [MIGRATION.md](MIGRATION.md).

Always follow the global `godot-senior-engineer` skill. This file adds project-specific rules; **the folder layout below replaces the layout in the skill's "Clean architecture" section.**

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
| **infrastructure** | domain (ports) | Implements ports, e.g. `ConfigFileBestScoreRepository`. The only place that touches `user://`, `FileAccess`, `AudioStreamPlayer` setup, etc. |
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
- **Runner** — the player character the kid picks (currently: Little Girl). Jumps; can't jump in mid-air.
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
- Runner characters are `AnimatedSprite2D` + a `SpriteFrames` resource (`assets/runner/characters/<name>.tres`) with animations `idle`, `run`, `jump`, `dead`. Add a character = new `.tres` + a `CharacterButton` in `runner_ui.tscn`. Obstacles, sun and flowers are still emoji placeholders. Art changes touch only `presentation/` and `assets/`.
- Large sprite frames: set the texture import option **Process → Size Limit** so frames render ~200 px tall, using the **same scale factor for every frame of a character** (else animations change size). Keeps VRAM low on Web/mobile.
- Every function has GUT tests (> 90% coverage). Domain and application layers must be fully tested without the scene tree.
