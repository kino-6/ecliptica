# Axe Attack Redesign

## Goal

The axe attack should read as a heavy gothic weapon swing, not a debug object or an evenly rotated prop. The player body, axe accessory sheet, timing, and hitbox must share one contract.

## Animation Contract

- Body sheet: `assets/production/player-attack-combo-sheet-24.png`, three combo steps, eight frames each.
- Axe sheet: `assets/production/player-axe-attack-combo-sheet-24.png`, same frame count and animation names as the body sheet.
- Visual layer: `Player/AxeSprite` only. `AttackArc` is removed so the attack cannot fall back to a separate drawn rectangle or arc object.
- Runtime attack scale: `Vector2(0.46, 0.46)`. The sheet carries the visual weight; the runtime layer should not balloon into a mismatched prop.
- Active timing: delayed until snap/impact frames, after anticipation and a held wind-up.
- Hitbox profiles:
  - combo 1 frame 4: center `(48, -82)`, size `(96, 78)`
  - combo 1 frame 5: center `(68, -50)`, size `(112, 86)`
  - combo 2 frame 4: center `(54, -90)`, size `(104, 86)`
  - combo 2 frame 5: center `(78, -56)`, size `(124, 96)`
  - combo 3 frame 4: center `(60, -78)`, size `(112, 82)`
  - combo 3 frame 5: center `(88, -46)`, size `(136, 92)`

## Animation Notes

- Frames 0-1: planted anticipation; the axe is pulled behind the body.
- Frames 2-3: held weight; feet stay planted while the weapon lingers overhead.
- Frame 4: snap; the weapon covers a large distance with source-image afterimages.
- Frame 5: impact; the blade mass enters the active hitbox.
- Frame 6: follow-through; cloth and weapon overshoot.
- Frame 7: recovery; the weapon settles without popping back instantly.

The smear uses ghosted versions of the axe image. It should support the motion, not replace the weapon silhouette with primitive shapes.

## Validation

`test/playerAxeAssetCheck.mjs` checks exact sheet dimensions, transparent gutters, material color groups, absence of long flat opaque runs, attack acceleration, and image mass inside the active hitbox on impact frames. `scripts/llm_verify.gd` confirms the runtime no longer has `AttackArc`, that `AxeSprite` uses the attack scale contract during the swing, and that the frame 4/5 hitbox profiles are active.
