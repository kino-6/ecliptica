---
name: gorest-spritesheet-pilot
description: Use when evaluating, piloting, or routing NO6KIKO/gorest-2d-animation-spritesheet-generator outputs into Ecliptica 2D animation assets without bypassing the local Godot sprite contracts, normalization scripts, and playfeel evidence gates.
---

# Gorest Spritesheet Pilot

Use this skill when the user asks to try, adopt, pilot, or learn from `NO6KIKO/gorest-2d-animation-spritesheet-generator` for Ecliptica character, enemy, boss, or weapon animation work.

## Classification

Treat gorest as `PILOT`, not a default production dependency.

- Do not vendor the upstream repository into this project unless the user explicitly asks.
- Do not commit API keys, generated model caches, `.env` files, or upstream workspaces.
- Prefer an ignored sidecar clone or external checkout for experimentation.
- Import only reviewed source images or candidate sheets into this repo.
- Route all accepted outputs through Ecliptica's deterministic normalization and test gates.

Upstream reference:

- `https://github.com/NO6KIKO/gorest-2d-animation-spritesheet-generator`
- `https://github.com/NO6KIKO/gorest-2d-animation-spritesheet-generator/blob/main/SPRITESHEET_GENERATION_POLICY.md`

## Ecliptica Contract

Before using gorest, identify the target manifest entry in `assets/manifest.yaml`.

Common contracts:

- Player body: `192x384`, transparent gutter, stable feet, one row, body only.
- Player axe layer: `192x384`, accessory only, active frames 4/5 align with runtime hitbox.
- Enemy idle/walk/attack: `192x384`, hunched silhouette, grounded baseline.
- Boss idle: `256x384`, readable boss silhouette, no oversized placeholder.
- Hit spark: `64x64`, short-lived warm impact peak.

Never accept a gorest sheet directly as production just because it looks good in preview. Ecliptica cares about engine contract, not only image quality.

## Workflow

1. Read `assets/manifest.yaml`, the relevant generator in `tools/`, and the matching asset tests.
2. If using the upstream app, run it outside this repo or under an ignored scratch directory.
3. Generate or export candidate spritesheets as raw material.
4. Place raw source candidates under `assets/source/` only after reviewing license, identity, and style fit.
5. Normalize into `assets/production/` with local deterministic scripts, or add a local normalizer first.
6. Preserve body/accessory separation:
   - body sheets must not bake in axe arcs or handles;
   - weapon/accessory sheets must align to the body frame contract;
   - VFX sheets must remain their own short-lived animation.
7. Update tests before replacing active production assets when the contract changes.
8. Run the focused gate for the asset type.
9. For playfeel-sensitive changes, capture real-window evidence before claiming improvement.

## Gorest Policy To Reuse

Adopt these ideas from gorest's spritesheet policy:

- Generate a complete spritesheet first, then split or normalize.
- Use one global uniform scale across frames; reject per-frame scaling.
- Anchor by bottom-center/root, not by visual center.
- Detect grids from alpha/ink projection when possible; do not trust a visual 4x4 layout blindly.
- Reject identity drift, foot slide, frame-to-frame size jitter, and disappearing limbs.
- For walk/run/attack, require key pose structure rather than evenly-spaced morphing.

## Required Gates

Choose the narrowest useful set:

- Player body: `node test/playerActionAssetCheck.mjs`
- Player axe: `node test/playerAxeAssetCheck.mjs`
- Enemy/boss: `node test/enemyBossAssetCheck.mjs`
- Stage/VFX: `node --test test/stageVisualAssetCheck.mjs`
- Manifest/release: `npm run release:check`
- Full gameplay smoke: `npm run verify:llm`
- Real-window feel evidence: GUI-approved `npm run test:window-manual`

## Reporting

When reporting a gorest pilot result, separate:

- source used;
- target manifest contract;
- normalization path;
- tests passed/failed;
- screenshots or evidence artifacts;
- what can and cannot be claimed.

Good conclusion:

> gorest output is usable as raw source for `enemy_attack`, but only after normalization. The sheet is not accepted as production until baseline drift, gutter, and real-window readability pass.
