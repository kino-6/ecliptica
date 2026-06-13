# Ecliptica Active Tasks

## Current Truth

手触り評価ループは完遂。

`playtest:manual` は、実シーン、保持入力、複数シナリオ、timeline、state-map、連続フレーム、UI evidence、capture diagnostics を保存できる。

実ウィンドウ evidence も取得済み。通常 sandbox では macOS window service 接続エラーで timeout するが、GUI 承認つきの `playtest:window-manual` では `display_name=macOS` の非 headless viewport screenshot を保存できる。

過去の詳細ログは `TasksArchive.md` に退避済み。

## Goal: 手触り評価ループを作る

`Improves.md` の「攻撃の当て感」「移動/ジャンプ救済」「敵 tell」「目的の読みやすさ」を、実プレイに近い証拠で評価できる状態にする。

完了条件:

- `npm run playtest:manual` が、実シーン、保持入力、攻撃、敵接触、ジャンプ系シナリオを machine-readable に記録する。
- 直接ダメージ、敵ワープ命中、直接勝利で手触りを判定しない。
- 各シナリオで、入力、位置、速度、攻撃 frame、hitbox 判定、敵 state、被弾、命中/空振り理由を JSON に残す。
- `artifacts/manual-play/<run-id>/summary.json` と scenario 別ログを保存する。
- 可能な限り実画面に近い連続フレーム、スクリーンショット、または動画 evidence を残す。
- 手触り改善の主張は、上記 evidence を見てから行う。

## Safety

- Timebox: 4h。
- 目的はまず「評価可能にする」こと。数値 tuning は評価基盤が出てから行う。
- 実ウィンドウが環境依存で不安定な場合は、headless で取れるログと状態マップを残し、実画面 evidence 不足を明記する。
- `test:window` の failure を pass 扱いにしない。診断が取れた場合だけ「診断は成功」と書く。
- 既存のユーザー変更は上書きしない。

## Slice 1: Manual Probe を評価ログ化する

- [x] `manual_play_probe` の出力先を run-id ディレクトリへ変更する。
  - 例: `artifacts/manual-play/20260613-<scenario>/summary.json`
  - 既存の固定ファイル名 screenshot は上書きしない。

- [x] frame timeline を JSON で保存する。
  - player: `position`, `velocity`, `facing`, `health`, `state`
  - input: `axis`, `jump`, `attack`, `shoot`
  - attack: `combo_step`, `attack_frame`, `active`, `hitbox_rect`
  - enemy: `name`, `position`, `state`, `health`, `distance_to_player`
  - result: `hit`, `miss`, `damage_taken`, `destroyed`, `reason`

- [x] scenario 結果に human-readable verdict を入れる。
  - 例: `hit_landed_after_approach`, `missed_due_to_range`, `took_contact_before_active_frame`

- [x] Node runner が summary path を stdout に出す。
  - `MANUAL_PLAY_JSON` には evidence path 一式を含める。

## Slice 2: 評価シナリオを分ける

- [x] `first_enemy_approach_attack`
  - 最初の敵に歩いて接近し、停止して斧1段目を振る。
  - 評価: 空振り理由、命中 frame、被弾タイミング。

- [x] `attack_while_moving`
  - 右入力を保持したまま攻撃する。
  - 評価: 攻撃中の減速、前進距離、間合いの変化。

- [x] `jump_buffer_or_coyote`
  - 足場端または着地直前入力でジャンプする。
  - 評価: buffer/coyote が実際に発火したか。
  - 最新結果: Slice 4 の修正後、着地直前入力の buffered jump は `buffered_jump_triggered=true`。

- [x] `enemy_lunge_tell`
  - 敵の突進前 tell から接触までを観察する。
  - 評価: windup state の duration、被弾理由、回避余地。

- [x] `boss_three_hits`
  - Boss に直接ダメージを入れず、実攻撃で3hitを狙う。
  - 評価: hit/miss、被弾、HP 表示更新。

## Slice 3: 画面 evidence を強くする

- [x] headless state-map の凡例を追加する。
  - player / enemy / attack / sigil / gate / boss が一目で分かる色にする。

- [x] 連続フレームを保存する。
  - 少なくとも approach、attack active、hit/miss、damage の前後。

- [x] 実ウィンドウ capture の可否を再確認する。
  - できる場合: scenario 実行中のスクリーンショットまたは短い動画を保存する。
  - できない場合: macOS window service / sandbox の失敗ログを artifact に残す。
  - 最新結果: `test:window` は timeout。stderr に `Connection Invalid error for service com.apple.hiservices-xpcservice` を記録。

## Slice 4: 評価後に tuning する

- [x] 斧1段目の active window / hitbox / attack movement を evidence に基づいて調整する。
  - 最新 evidence: `first_enemy_approach_attack` と `attack_while_moving` は実攻撃で命中、被弾なし。追加 tuning は今回は保留。
- [x] jump buffer / coyote time の値を evidence に基づいて調整する。
  - 修正: 着地直後に buffered jump を消費できるようにした。
  - 最新 evidence: `buffered_jump_triggered=true`, `jump_velocity_after_input=-620`。
- [x] enemy windup tell の視認性と回避猶予を evidence に基づいて調整する。
  - 最新 evidence: `enemy_lunge_tell` で `windup_state_seen_before_lunge` を確認。追加 tuning は今回は保留。
- [x] HUD / objective 表示が実画面で読めるか確認する。
  - 最新 evidence: `objective_text="Collect 7 sigils. J: Attack / L: Shoot"`, `sigil_text="Sigils 0/7"`。

## Verification

実装ごとに最低限実行する:

- [x] `npm run playtest:manual`
- [x] `npm run test`

関係する変更がある場合に実行する:

- [x] `npm run playtest:ai`
- [x] `npm run verify:llm`
- [x] `npm run test:e2e`
- [x] `npm run screenshot:showcase`
- [x] `npm run test:window`
  - 実行済みだが fail。macOS window service 接続エラーで timeout。

実ウィンドウ証拠:

- [x] `playtest:window-manual` を追加する。
  - Godot を `--headless` なしで起動する。
  - `e2e_set_axis` と `e2e_attack` で移動/攻撃する。
  - `root.get_texture().get_image()` で実 viewport screenshot を保存する。
  - `WINDOW_MANUAL_PLAY_JSON` に `display_name`, `summary_path`, `evidence_dir` を出す。
- [x] `test:window-manual` を追加する。
  - 通常の `npm run test` では skip。
  - `RUN_GODOT_WINDOW_MANUAL=1` つきで実ウィンドウ evidence を検証する。
- [x] 実ウィンドウ evidence を取得する。
  - 最新確認 run: `artifacts/window-manual-play/20260613-202500-window-manual/summary.json`。
  - `display_name`: `macOS`。
  - screenshot:
    - `artifacts/window-manual-play/20260613-202500-window-manual/window-start.png`
    - `artifacts/window-manual-play/20260613-202500-window-manual/window-after_movement.png`
    - `artifacts/window-manual-play/20260613-202500-window-manual/window-after_attack.png`
  - route: movement `moved_by=180.95`, attack `hit=true`, `player_damage_taken=0`。

## Done Log

- [x] `Tasks.md` を active goal だけに slim 化した。
- [x] 過去の実装ログを `TasksArchive.md` に退避した。
- [x] Slice 1 完了: `manual_play_probe` が run-id evidence dir、`summary.json`、`timeline.json`、timeline 配列、human-readable verdict を出すようになった。
  - `npm run playtest:manual`: pass。
  - 最新確認 run: `artifacts/manual-play/20260613-110945-manual-play/summary.json`。
  - Verdict: `hit_landed_after_approach`。
  - 重要: これは評価ログ基盤の改善であり、手触り改善の証明ではない。
- [x] `npm run test`: pass。33 pass / 1 skipped。
- [x] Slice 2 完了: `playtest:manual` が5つの scenario を別々の実シーンで評価するようになった。
  - 最新確認 run: `artifacts/manual-play/20260613-112825-manual-play/summary.json`。
  - `first_enemy_approach_attack`: `hit_landed_after_approach`。
  - `attack_while_moving`: `hit_landed_after_approach`。
  - `jump_buffer_or_coyote`: `jump_buffer_did_not_trigger`。これは未解決の手触り課題。
  - `enemy_lunge_tell`: `windup_state_seen_before_lunge`。
  - `boss_three_hits`: `hits_landed=3`, `boss_destroyed=true`。
  - `npm run playtest:manual`: pass。
  - `npm run test`: pass。33 pass / 1 skipped。
- [x] Slice 3 完了: state-map 凡例、連続フレーム、capture diagnostics、UI evidence を `summary.json` に保存するようになった。
  - 最新確認 run: `artifacts/manual-play/20260613-113350-manual-play/summary.json`。
  - `frame_sequence`: 22 frames。
  - `capture_diagnostics.status`: `unavailable`。
  - 理由: `manual play probe runs in Godot --headless, so real window capture is not available from this command`。
- [x] Slice 4 完了: evidence に基づき jump buffer を修正し、他項目は現状維持判断を記録した。
  - `jump_buffer_or_coyote`: `buffered_jump_triggered=true`, `jump_velocity_after_input=-620`。
  - `first_enemy_approach_attack`: `hit_landed_after_approach`。
  - `attack_while_moving`: `hit_landed_after_approach`。
  - `enemy_lunge_tell`: `windup_state_seen_before_lunge`。
  - `boss_three_hits`: `hits_landed=3`, `boss_destroyed=true`。
- [x] 最終検証。
  - `npm run playtest:manual`: pass。
  - `npm run test`: pass。33 pass / 1 skipped。
  - `npm run playtest:ai`: pass。
  - `npm run verify:llm`: pass。
  - `npm run test:e2e`: pass。
  - `npm run screenshot:showcase`: pass。
  - `npm run test:window`: fail。`Connection Invalid error for service com.apple.hiservices-xpcservice` の後、45000ms timeout。
- [x] 実ウィンドウ検証を追加実行。
  - 通常 sandbox: `npm run playtest:window-manual` は macOS window service 接続エラーで timeout。
  - GUI 承認つき: `npm run playtest:window-manual`: pass。
  - GUI 承認つき: `npm run test:window-manual`: pass。2 pass。
  - `npm run test`: pass。34 pass / 2 skipped。
