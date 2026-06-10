# Gunshot Redesign

## Problems

- The old ranged attack read as a short rectangular debug object rather than a gunshot.
- The projectile used a single static image, so it had no ignition, recoil, smoke decay, or timing.
- Runtime checks only proved that a projectile existed, not that it was an image-based animated effect.

## Extracted Direction

Real gunfire gives a side-view action game several readable ingredients:

- A bright muzzle flash that lasts only an instant.
- A pressure wave and smoke plume that expands after the flash.
- Small sparks and hot brass tones near the muzzle.
- Recoil in the shooter body, with the gun hand settling afterward.
- A compact hit volume; the visible smoke can be larger than the actual damaging bullet.

Classic 16-bit and later 2D action games usually exaggerate those ingredients:

- The first one or two frames carry the flash silhouette.
- Later frames remove most of the light and leave smoke/embers.
- The projectile should not be a full-width bar; direction comes from asymmetrical smoke and a short tracer.
- The collision shape remains simple, but it must not define the visible art.

## Asset Contract

- Projectile VFX: `assets/player-shot-sheet-6.png`
- Sheet layout: 6 horizontal frames, `160x72` each, total `960x72`
- Runtime node: `AnimatedSprite2D` named `Visual` with non-looping `fly` animation
- Visible design: early brass/white flash, mid-frame red ember/tracer, late dark smoke
- Collision: invisible `RectangleShape2D`, `54x18`, centered near the damaging bullet core

## Runtime Contract

- `Player.shoot()` consumes 1 FOCUS and spawns a projectile.
- The projectile visual must be animated image art, never a `ColorRect` or hand-drawn debug shape.
- The projectile can use a compact collision box while the VFX sheet remains wider for smoke and readability.
- Headless verification checks that the projectile has a `fly` animation, uses all 6 frames, and destroys a ranged enemy.

