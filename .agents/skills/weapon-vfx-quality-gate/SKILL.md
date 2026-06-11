---
name: weapon-vfx-quality-gate
description: Review and improve Ecliptica weapon attacks and VFX as a combined asset/runtime contract, especially axe swings, gunshots, hitboxes, hitstop, camera impulse, and production manifest wiring.
---

# Weapon VFX Quality Gate

Use this skill when a weapon or attack effect feels cheap, detached, weightless, or mismatched with its hitbox. Do not evaluate the image in isolation; the quality target is the complete in-game contract.

## Scope

- Player axe attack body sheet, axe accessory sheet, hitbox timing, hitbox position, hitstop, knockback, hit spark, and camera impulse.
- Player gunshot body pose, projectile VFX sheet, projectile collision size, focus cost, and hit feedback.
- `assets/manifest.yaml`, `assets/production/`, and release placeholder checks.

## Workflow

1. Capture the current behavior with `npm run verify:llm` and `npm run screenshot:showcase`.
2. Inspect active manifest entries before editing:
   - `player_axe_attack`
   - `player_shot_vfx`
   - `hit_spark`
3. Check runtime and asset together:
   - the weapon layer must use image frames, not debug shapes
   - startup frames must have no hitbox
   - active frames must put visible weapon or VFX mass inside the collision region
   - impact must trigger hitstop, enemy flash, knockback, hit spark, and a small camera impulse
4. If generating deterministic assets, write to `assets/production/` first and mirror to legacy root paths only for older tests.
5. Validate with focused checks before full tests:
   - `node test/playerAxeAssetCheck.mjs`
   - `node --test test/stageVisualAssetCheck.mjs`
   - `npm run release:check`
6. Finish with `npm run verify:llm`, `npm run screenshot:showcase`, and at least `npm run test:e2e`.

## Axe Rules

- Treat each combo step as 8 frames: anticipation, held weight, snap, impact, follow-through, recovery.
- Hitbox is allowed only on frames 4 and 5.
- Frame 4 should cover the descending/snap position; frame 5 should cover the impact position.
- Runtime `AxeSprite` position and scale must match the sheet contract. Avoid making weight by simply ballooning the layer.
- The axe image must overlap the active hitbox in world coordinates during frame 5.

## Gunshot Rules

- A gunshot VFX is a short event: bright muzzle core, ember/tracer, then smoke decay.
- Avoid X-shaped cartoon flashes, full-width bars, laser lines, and `ColorRect` projectiles.
- Collision may be compact, but the VFX should clearly show direction and dissipate within the configured lifetime.

## Failure Smells

- The player appears to swing at empty air while a hit registers elsewhere.
- The axe floats above or away from the hands during active frames.
- Hitbox is active during wind-up or recovery.
- Projectile art is a rectangle, line, or single static flash.
- Manifest points to `assets/placeholder/` or a root asset when a production asset exists.
