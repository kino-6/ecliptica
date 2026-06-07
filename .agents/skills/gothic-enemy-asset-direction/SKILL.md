---
name: gothic-enemy-asset-direction
description: Refine dark gothic 2D enemy and boss sprites so they match a moody castle/action game scene, especially when assets look toy-like, too flat, too small, or visually disconnected from the background. Use with deterministic sprite generators and asset QA tests for enemy idle, walk, attack, and boss sheets.
---

# Gothic Enemy Asset Direction

Use this when enemy or boss sprites feel cheap, cartoony, toy-like, or disconnected from a dark gothic stage.

## Core Rule

Design the enemy for the in-game camera first, not for a zoomed-in asset viewer. At gameplay scale the sprite must read as:

- one strong dark silhouette
- one pale face or mask focal point
- one crimson or brass secondary accent
- one attack-readable limb, claw, weapon, or smear

Small horns, antenna-like rods, dots, and thin limb details often read as placeholder art against a dense dark background. Replace them with larger hood, cloak, mask, shoulder, and tattered-cloth shapes.

## Sprite Contract

For Ecliptica-style enemy sheets:

- Enemy frames: `96x96`, horizontal row.
- Boss frames: `192x160`, horizontal row.
- Keep at least 4 px transparent gutters.
- Avoid visible pixels in the top 8% of enemy frames unless the silhouette deliberately needs it.
- Put most visual mass in the central body region so the enemy remains readable over the stage.
- Preserve animation names and frame counts already wired in Godot.

## Visual Recipe

For standard enemies:

1. Start with a fixed back-cloak silhouette centered in the frame.
2. Add a hood or hunched shoulder mass.
3. Add a pale mask/skull face large enough to read at gameplay scale.
4. Add crimson inner cloth as one broad shape, not many tiny red pixels.
5. Add claws/arms only after the body reads.
6. Attack frames may stretch one arm or smear, but should not collapse the central silhouette.

For bosses:

1. Use a larger robe/torso mass before adding decorations.
2. Avoid long top-edge rods that read like antennae.
3. Put horns, collars, chains, or appendages below the top gutter and integrated with shoulders.
4. Keep the pale head/mask prominent and stable.

## Validation

Before accepting the asset:

- Run the asset contract test, especially `test/enemyBossAssetCheck.mjs`.
- View the actual PNG sheets at original size and ask whether the silhouette reads without explanation.
- Run the Godot headless verification or full `npm run test`.
- If a threshold fails, prefer adding/removing large silhouette shapes over loosening the test.

## Implementation Notes

In deterministic generators:

- Draw the back cloak before legs, arms, and face.
- Keep frame-center silhouette layers fixed across idle/walk/attack.
- Let walk/attack move limbs and cloth edges, not the whole body mass.
- Use dark navy/black cloak mass, aged bone highlights, restrained crimson, and brass accents.
