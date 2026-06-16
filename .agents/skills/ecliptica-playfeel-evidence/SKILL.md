---
name: ecliptica-playfeel-evidence
description: Use when asked to actually play Ecliptica, evaluate or improve game feel, capture real-window evidence, turn subjective play impressions into Tasks.md items, or avoid overclaiming playability without screenshots, JSON summaries, and focused tests.
---

# Ecliptica Playfeel Evidence

Use this skill when the user asks for playfeel review, hands-on playtesting, "actually play it", "手触り", "プレイ感", "実ウィンドウ", or game-feel improvements for Ecliptica.

## Prime Rule

Do not claim that the game feels better unless there is evidence from a run that can be inspected.

Acceptable claims:

- "The real-window harness captured the hit frame."
- "The first enemy was destroyed with real input and no player damage in this run."
- "This screenshot shows the windup tell is visible."

Avoid:

- "The hand-feel improved" without a run, screenshot, and specific observed change.
- "Playable" when only a headless or direct-damage test passed.
- Treating `hit=true` alone as proof of impact feel.

## Required Evidence Loop

1. Read `Improves.md`, `Tasks.md`, current diffs, and relevant scripts before judging.
2. Convert vague feel problems into observable questions:
   - What should the player see?
   - What input was used?
   - Which frame or state proves it?
   - What artifact path preserves it?
3. Add or update tests before production changes when behavior is changing.
4. Run a focused RED check and make sure it fails for the intended missing evidence or behavior.
5. Implement the smallest playable slice.
6. Run focused GREEN checks.
7. Capture fresh evidence:
   - `npm run playtest:manual`
   - GUI-approved `npm run playtest:window-manual` when judging visuals, readable danger, hit feel, or objective clarity
   - GUI-approved `npm run test:window-manual` when changing the window evidence contract
8. Open at least one key screenshot with `view_image` when judging visual readability.
9. Update `Tasks.md` with:
   - exact command results
   - summary path
   - screenshot path
   - relevant JSON fields
   - what can and cannot be honestly concluded

## Evidence Types

Use each evidence type for the right question:

- Headless tests: regressions, data shape, mechanics, route logs.
- `playtest:manual`: repeatable input/timeline evidence, scenario verdicts, state maps.
- `playtest:window-manual`: actual viewport screenshots and macOS display evidence.
- Screenshot inspection: readability, overlap, UI hierarchy, danger tells, hit moment.
- `Tasks.md`: current working contract and done log.
- `Improves.md`: longer-lived critique and future backlog.

## Ecliptica Checks

For first-room playfeel, prefer these signals:

- HUD priority: `boss_hp_visible=false` at start.
- Objective clarity: `Sigils x/y`, `NEXT >/<`, and sealed gate reason.
- Enemy danger: `windup_evidence.windup_frame_captured=true` plus inspected screenshot.
- Hit feel evidence: `window-attack-start`, `window-attack-active`, `window-hit-frame`, `window-after_attack`.
- Route outcome: real input, `direct_damage_used=false`, `hit=true`, `enemy_destroyed=true`, `player_damage_taken=0`.

## Reporting Contract

In final responses:

- Separate evidence from interpretation.
- Include artifact paths.
- State remaining uncertainty plainly.
- Do not say "I played it" unless a real-window or manual evidence run was actually executed in this turn or explicitly referenced from a fresh run.

Good wording:

> 実ウィンドウではこの run で最初の敵撃破までは成立しました。ただし、面白さ全体はまだ断言せず、今回言えるのは hit frame と windup tell を評価可能な証拠として残せるようになった、という範囲です。

## When Blocked

If GUI commands fail due to sandbox or macOS window-service restrictions:

- Say that real-window evidence could not be captured.
- Keep headless/manual evidence separate.
- Request GUI approval for the exact command.
- Do not replace real-window conclusions with headless-only conclusions.
