---
name: headless-ai-playtest
description: Build or refine Godot headless AI playtest harnesses that evaluate 2D action stages with multiple human-limited player skill profiles, reaction delays, route logs, and JSON balance summaries.
---

# Headless AI Playtest

Use this skill when adding or tuning automated playtest coverage for Ecliptica or a similar Godot action game.

## Core Contract

Model playtest AI as a set of human-limited profiles rather than a perfect bot:

- Use 5 skill levels: novice, casual, adept, expert, master.
- Give every profile a plausible reaction delay, minimum action interval, execution error rate, and tactical score.
- Treat reaction speed as a constraint on when actions can happen, not just metadata.
- Keep the "target player" explicit. For Ecliptica's first stage, the target is an adept action player clearing in about 2 attempts.

## Workflow

1. Add or update a Node test that expects a machine-readable playtest script, runner, profiles, and outcome thresholds.
2. Run the test and confirm RED before editing production scripts.
3. Implement a Godot headless script that loads the real main scene and probes real mechanics:
   - movement through `e2e_set_axis`
   - melee through `attack`
   - ranged combat through `shoot`
   - boss durability through real target HP metadata
   - gate/win state through actual game methods
4. Output one JSON line with a stable prefix such as `AI_PLAYTEST_JSON`.
5. Include per-profile `route_log` entries so balance failures are explainable.
6. Parallelize profile execution when the runner can launch independent Godot processes.
7. Verify focused tests, then run the full test suite.

## Parallel Runner Pattern

For fastest iteration, run one Godot headless process per profile and aggregate in Node:

- detect local machine capacity with `availableParallelism()`, total/free memory, and profile count
- reserve at least one CPU core, two cores on larger machines
- cap worker count by profile count, CPU allowance, and a memory-per-worker estimate
- allow `AI_PLAYTEST_WORKERS=<n>` to override auto selection for debugging or thermal limits
- emit a `parallel` object in `AI_PLAYTEST_JSON` with selected worker count, CPU/memory inputs, total elapsed time, and per-profile elapsed time
- keep profile order stable in the final summary even when jobs finish out of order

## Balance Signals

Prefer stable, comparable signals over vague "fun" claims:

- target and predicted attempts to clear
- clear/fail per profile
- human reaction milliseconds
- action interval milliseconds
- route phase outcomes
- stage seed and balance metadata
- recommendation string for the current target player

## Cautions

Headless AI is a balance instrument, not proof that the stage is fun. Use it to catch regressions and compare tuning passes, then supplement it with manual play or visual review when animation readability, atmosphere, or enemy tells are being judged.
