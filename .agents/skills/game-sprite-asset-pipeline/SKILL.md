---
name: game-sprite-asset-pipeline
description: Create and refine 2D game character sprite sheets for Godot or similar engines. Use when generating, replacing, or QAing idle, walk, run, attack, or accessory-separated character assets; when frame counts, sprite dimensions, gutters, baselines, or animation stability need to be specified; or when AI-generated character images must be normalized into production-ready sprite sheets.
---

# Game Sprite Asset Pipeline

## Overview

Use this skill to turn concept art or AI-generated character images into stable, engine-ready sprite sheets. The key discipline is to decide the asset specification first, then generate or edit, then normalize frames deterministically, and finally test the sheet numerically and in-engine.

## Workflow

1. Define the sprite contract before making images:
   - frame size, frame count, animation names, and sheet layout
   - transparent gutter size
   - center line, foot baseline, and head/top tolerance
   - intended engine node setup, such as one `AnimatedSprite2D` with multiple animations
2. Generate source images only as raw material:
   - ask for side-view, full-body frames in one row
   - request a flat chroma-key background for removal
   - specify no weapon/accessory unless it is part of the body animation
   - preserve the same character identity across frames
3. Normalize generated images into the contract:
   - remove chroma-key background
   - cut frames by count
   - scale to the chosen body height
   - align center and foot baseline
   - enforce transparent gutters
   - keep source images separately from production sheets
4. Wire the engine to the contract:
   - prefer one sprite node for one character body
   - switch animation names on that node rather than swapping differently scaled nodes
   - build `SpriteFrames` from explicit frame size/count when possible
5. Validate both numerically and in-engine:
   - sheet dimensions are exact
   - every frame has transparent gutters
   - alpha center drift is small
   - foot baseline drift is near zero
   - head/top drift is small
   - idle core pixels are mostly fixed
   - movement animation activates in an E2E smoke test

## External Generator Routing

For `NO6KIKO/gorest-2d-animation-spritesheet-generator`, use the project-local `gorest-spritesheet-pilot` skill first. Treat gorest as a raw-material pilot, not as an automatic production asset source.

When a gorest candidate is involved:

- keep upstream workspaces, API keys, caches, and `.env` files outside this repo;
- import only reviewed raw candidates into `assets/source/`;
- normalize into this project's `assets/production/` contract with deterministic local scripts;
- run the relevant asset test and real-window evidence gate before claiming a playfeel improvement.

## Animation Rules

Idle animation should not make the whole character squirm, pulse, or slide. Use a fixed core body:

- keep face, torso, hips, armor, legs, and planted feet stable
- animate hair, cape, mantle, skirt tails, loose cloth, smoke, or small lights
- keep the motion subtle and cyclic
- use a low frame rate if the motion is only fabric/hair

Walk animation should be smooth but still stable:

- use enough frames for the visual style, such as 24 for semi-realistic assets
- keep the walk in-place unless the engine expects baked displacement
- keep the foot baseline stable even when feet alternate
- watch for torso center drift, because it reads as moonwalking or sliding

Accessories should be separate when they need independent timing:

- weapons, tools, capes with large physics-like motion, and VFX should not be baked into every body frame unless the animation is final
- separate layers make retiming and corrections cheaper

## Recommended Contract

For semi-realistic 2D platformer characters:

```text
frame size: 192x384
gutter: 12px transparent on every side
center: x = 96
foot baseline: y = 344
idle: 10 frames
walk: 24 frames
sheet layout: single horizontal row
engine: one AnimatedSprite2D with idle/walk animations
```

Adjust these numbers per project, but keep a single contract for all animations of the same character.

## Test Checklist

Add or update tests before replacing production assets:

- required sheet files exist
- width equals `frame_width * frame_count`
- height equals `frame_height`
- transparent gutters are empty
- alpha center drift stays below the project tolerance
- foot baseline drift stays within 1-2 pixels
- head/top drift stays within a small tolerance
- idle core-body pixel drift stays close to zero outside allowed hair/cape/cloth regions
- the engine uses one sprite node with one scale for all body animations

When a test fails because the generated source is inconsistent, fix it with deterministic normalization or regenerate. Do not hand-wave the failure by loosening tolerances unless the animation design intentionally requires the motion.
