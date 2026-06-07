---
name: pixel-action-animation
description: Design and refine 2D pixel/hi-bit action animations with classic game-art techniques such as anticipation, biased timing, smear frames, impact poses, follow-through, clusters, manual anti-aliasing, and Godot-ready sprite contracts.
---

# Pixel Action Animation

Use this skill when a 2D action sprite or effect feels cheap, weightless, too even-timed, or too much like early 8-bit placeholder art.

## Sources To Consult

- Pixnote animation guide: frame planning, keyframes, attack motion, impact expansion. https://pixnote.net/en/learn/animation/
- Pixel Parmesan anti-aliasing guide: manual AA, subpixel animation, avoiding tangents and edge blur. https://pixelparmesan.com/blog/anti-aliasing-fundamentals-for-pixel-artists
- Purloux antialiasing tutorial: sub-pixel accuracy and palette-conscious smoothing. https://purloux.com/artwork/tutorials/aa/
- Smear frame references: one-frame/few-frame motion blur for very fast motion. https://en.wikipedia.org/wiki/Smear_frame
- Classic animation principles: anticipation, follow-through, overlapping action. https://en.wikipedia.org/wiki/Anticipation_%28animation%29 and https://en.wikipedia.org/wiki/Follow_through_and_overlapping_action

## Heavy Attack Recipe

For axes, greatswords, hammers, and other heavy weapons, avoid evenly spaced rotations. Use a biased timing arc:

1. **Anticipation**: pull the torso and weapon opposite the hit direction. Keep feet planted.
2. **Held weight**: spend an extra pose/frame near the wind-up so the weapon reads as heavy.
3. **Snap/smear**: move the weapon a long distance in one frame; use a broad but readable smear or afterimage.
4. **Impact**: show the blade/head clearly, add metal highlight, dark contact arc, and optionally a compact flash.
5. **Follow-through**: overshoot past the target line; cloth/hair trails behind the torso.
6. **Recovery**: settle the torso and weapon with less motion than the strike.

## Pixel/Hi-Bit Rendering Rules

- Keep a stable canvas, foot baseline, and transparent gutter for every frame.
- Favor strong silhouettes over small internal detail.
- Use clusters of shadow/highlight rather than noisy single-pixel speckles.
- Use manual anti-aliasing only on important curves or metal edges; do not blur every outer edge.
- Use subpixel motion sparingly: shift highlights, shadows, or cloth pixels without moving the whole body.
- Smears should be short-lived and shaped along the attack arc. Too many smear frames reduce readability.

## Validation Checklist

- Wind-up to impact has a bigger visual delta than idle-to-wind-up.
- The impact frame has a readable weapon head, not just a colored streak.
- Body center of mass shifts into the hit direction.
- Feet remain visually planted during anticipation and contact.
- Cloth/hair/mantle shows delayed follow-through.
- The accessory/VFX layer can be retimed independently from the body layer.
