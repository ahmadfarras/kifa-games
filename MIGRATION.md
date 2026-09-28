# Migration Checklist: webapp-game-kifa → Godot

Source repo (vanilla JS, still live, do not remove): `/Users/farras/Documents/Project/webapp-game-kifa`

Each game below is a standalone HTML file with inline CSS/JS. No image assets — visuals are DOM/CSS elements and Unicode emoji used as sprites. All need replacement art in Godot (see asset plan below).

## Games to migrate

- [ ] **Runner** — "Run Run!"
  Source: `../webapp-game-kifa/runner.html`
  Mechanics: canvas-based endless runner, gravity/jump physics, obstacle spawning, score + best-score tracking, character select.
  Godot notes: closest fit to native Godot workflow — CharacterBody2D + gravity, Area2D/CollisionShape2D for obstacles, spawner timer, HUD score UI.
  Priority: **first** (start here).

- [ ] **Math** — "Math Fun!"
  Source: `../webapp-game-kifa/math.html`
  Mechanics: question prompt, multiple-choice answer buttons, correct/wrong feedback, difficulty/level progression.
  Godot notes: mostly UI/logic (Control nodes, Button, Label) — low physics need, straightforward port.

- [ ] **Match** — "Animal Match!"
  Source: `../webapp-game-kifa/match.html`
  Mechanics: memory/flip-card grid, card flip animation, pair matching, score tracking.
  Godot notes: Control-based grid, AnimationPlayer or Tween for flip, needs animal sprite set (currently emoji faces).

- [ ] **Coloring** — "Coloring Fun!"
  Source: `../webapp-game-kifa/coloring.html`
  Mechanics: SVG-region tap-to-fill coloring book (flood-fill-style paint by region), color picker palette.
  Godot notes: trickiest port — no direct flood-fill node; options are pre-segmented regions as separate Polygon2D/Sprite2D with shader-based recolor, or custom image flood-fill script. Needs line-art assets per picture.

- [ ] **Home / hub screen** — "Kifa Games"
  Source: `../webapp-game-kifa/index.html`
  Mechanics: landing menu linking to the 4 games.
  Godot notes: main menu scene, buttons to load each game scene.

## Asset plan

Current source has **zero image files** — everything renders via emoji + CSS. Godot needs real sprites/art:

- [ ] Runner: character sprite(s) + run/jump animation frames, background (parallax layers optional), obstacle sprites.
- [ ] Math: background/UI theme art (icons optional, mostly text/buttons).
- [ ] Match: animal card-face sprites (one per pair), card-back design.
- [ ] Coloring: line-art illustrations per coloring page (needs to be pre-segmented into fillable regions).
- [ ] Shared: app icon, menu/background art, SFX (tap, correct/wrong, jump, win) and background music.

Plan: start with a free CC0 pack (e.g. Kenney.nl) to unblock Runner prototype; revisit custom/commissioned art once mechanics are validated in Godot.

## Status

Not started — project scaffold only (`project.godot`, `.gitignore`) committed so far. See root `README` / repo history for scaffold details.
