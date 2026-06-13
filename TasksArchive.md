# Ecliptica Tasks Archive

Archived on 2026-06-13 JST.

This file preserves the previous expanded task log. Active work is now tracked in
`Tasks.md`.

## 2026-06-12 / 2026-06-13 Previous Task Log

# Ecliptica 改善タスク

## Current Status

Not complete as a player-feel goal.

2026-06-12 の実装では、AI 計測、HUD、入力救済、敵 tell などのコード変更は入った。しかし、ユーザー実感として「ゲームの手触りは変わっていない」と報告されているため、`Tasks.md 完遂` とみなした前回判断は取り消す。

現時点で完了しているのは「改善のための計測と小変更」であり、「まともに遊べる」「手触りが良くなった」は未達。

## New Goal: Codex 実プレイ環境

Codex が `press_key` の短い tap だけに頼らず、ゲーム内で「右を押しっぱなし」「止まる」「攻撃」「ジャンプ」「射撃」のような連続入力を再現し、プレイ中の状態を JSON とスクリーンショットで確認できる環境を作る。

今回の完了条件:

- `npm run playtest:manual` で、実シーンをロードして scripted manual input を実行できる。
- probe は直接ダメージや直接勝利ではなく、`Player` の e2e 入力 API を使う。
- 少なくとも movement / first enemy / attack / screenshot capture のログを出す。
- 証拠画像を `artifacts/manual-play/` に保存する。
- この環境は「手触りが改善した証明」ではなく、「次に手触りを評価するための入力・観察基盤」として扱う。

### Manual Play Environment Tasks

- [x] `scripts/manual_play_probe.gd` を追加する。
  - 実シーン `scenes/main.tscn` をロードする。
  - `e2e_set_axis`, `e2e_jump`, `e2e_attack`, `e2e_shoot` だけで操作する。
  - `MANUAL_PLAY_JSON` を出力する。

- [x] `tools/manualPlayProbeRunner.mjs` を追加する。
  - Godot headless を起動する。
  - stdout から `MANUAL_PLAY_JSON` を取得できる。
  - stderr の macOS CA 証明書ノイズは既存 runner と同様に除去する。

- [x] `package.json` に `playtest:manual` を追加する。

- [x] Node テストを追加する。
  - package script、runner、Godot script が存在する。
  - probe が movement / first_enemy / screenshot を含む JSON を返す。
  - screenshot path が存在する。

- [x] `npm run playtest:manual` を実行し、結果を Done Log に残す。

Manual play environment result:

- `npm run playtest:manual`: pass。
- JSON prefix: `MANUAL_PLAY_JSON`。
- 入力モデル: `held_e2e_player_inputs`。
- 保存画像:
  - `artifacts/manual-play/manual-play-start.png`
  - `artifacts/manual-play/manual-play-after_movement.png`
  - `artifacts/manual-play/manual-play-after_attack.png`
- 取得ログ:
  - movement: `held_frames=54`, `moved_by=180.95`
  - first_enemy: `GeneratedEnemy1`, `distance_x=95.92`
  - attack: `enemy_destroyed=true`, `player_damage_taken=0`

Important limitation:

- 現在の画像は headless で確実に保存するための状態マップであり、実画面のアニメーションキャプチャではない。
- この環境は「保持入力で実シーンを進め、ログと証拠画像を出せる」段階。
- 「手触りが良くなった」証明には、実ウィンドウでの観察または動画/連続フレームキャプチャが別途必要。

## Goal

`Improves.md` の指摘をもとに、最初の1ステージが「初回プレイヤーでも目的と攻撃の当て方を読める」状態へ近づくまで改善する。

今回の完遂条件は、4時間タイムボックス内で以下を満たすこと:

- AI プレイテストが実戦の難しさを隠さない。
- 最初の敵1体との戦闘が、空振り・被弾理由を読みやすい。
- シジル収集とゲート解放の目的が HUD 上で分かる。
- 変更後の headless 検証が通る。
- 残った課題が明確に `Tasks.md` に残っている。

## Safety

- Timebox: 4h。
- 優先順位は「測れるようにする」から「手触りを直す」へ進む。
- 時間切れ時は未完了タスクを残し、最後に実行済み検証と未解決リスクを書く。
- 大きな新機能、広範囲なアセット差し替え、ステージ全面再設計は今回の範囲外。
- 既存のユーザー変更が出た場合は上書きしない。

## Phase 1: 測定の嘘を減らす

- [x] AI 近接テストを、敵ワープ命中から実操作ベースへ変更する。
  - 対象: `scripts/ai_playtest.gd`
  - 期待: プレイヤー入力で接近、停止、攻撃し、敵撃破までを見る。
  - Log: `approach_time`, `miss_count`, `damage_taken`, `enemy_destroyed`

- [x] AI Boss テストを、直接ダメージから実攻撃ベースへ変更する。
  - 対象: `scripts/ai_playtest.gd`
  - 期待: Boss へ3回攻撃を当てるまでの実操作を評価する。
  - Log: `hits_landed`, `miss_count`, `damage_taken`, `boss_destroyed`

- [x] AI route log の失敗理由を人間向けにする。
  - 例: `missed melee timing`, `took contact damage before first hit`, `boss not defeated within attempt window`

## Phase 2: 最初の敵1体を遊べるようにする

- [ ] 斧攻撃1段目の当てやすさを体感できる水準まで上げる。
  - 対象: `scripts/player.gd`
  - 実装済み: active frame は維持し、1段目 hitbox を少し拡大。
  - 未達: ユーザー実感として手触り改善が確認できていない。
  - 次の完了条件: 手動プレイで、最初の敵に対する空振り/理不尽被弾が明確に減る。

- [ ] 攻撃中の移動制限を体感できる水準まで見直す。
  - 対象: `scripts/player.gd`
  - 実装済み: `ATTACK_MOVE_SPEED_SCALE` を `0.18` から `0.24` に変更。
  - 未達: 変化量が小さく、手触り差として認識できない可能性が高い。
  - 次の完了条件: 攻撃入力後の硬直/前進/間合いが、手動プレイで明確に改善している。

- [ ] coyote time と jump buffer が実プレイで効いていることを確認する。
  - 対象: `scripts/player.gd`
  - 実装済み: 0.08s の coyote time / jump buffer を追加。
  - 未達: 手動プレイで段差/縦移動の失敗が減ったことを確認していない。
  - 次の完了条件: 実プレイまたは入力ログつき headless で、ジャンプ猶予が機能している証拠を残す。

- [ ] 通常敵の突進前 tell を視認できる水準まで強める。
  - 対象: `scripts/enemy.gd`
  - 実装済み: `windup` 状態と短い色変化を追加。
  - 未達: 実画面で「来る」と読める強さか確認できていない。
  - 次の完了条件: 手動プレイで突進前 tell が見える、またはスクリーンショット/動画で確認できる。

## Phase 3: 目的を読めるようにする

- [x] HUD に `Sigils x/y` 表示を追加する。
  - 対象: `scenes/main.tscn`, `scripts/game.gd`
  - 完了条件: 未回収数が一目で分かる。

- [x] ゲート開放 feedback を追加する。
  - 対象: `scripts/game.gd`
  - 候補: state label の一時表示、gate glow、camera impulse 小。
  - 完了条件: 最後のシジル回収時に「開いた」が分かる。

- [x] 最初の部屋だけ操作/目的の短い表示を追加する。
  - 対象: `scenes/main.tscn`, `scripts/game.gd`
  - 文言候補: `Collect 7 sigils. J: Attack / L: Shoot`
  - 完了条件: 画面を邪魔せず、初回目的が分かる。

## Phase 4: 視認性とBossの最低限

- [x] シジルの視認性を上げる。
  - 対象: `scripts/stage_generator.gd` または asset 表示設定。
  - 候補: pulse / glow / z_index 調整。
  - 完了条件: 暗い背景でも拾える物として目立つ。

- [x] Boss HP 表示を追加する。
  - 対象: `scenes/main.tscn`, `scripts/game.gd` または Boss node 生成。
  - 完了条件: Boss が何発で倒れるか分かる。

## Phase 5: 実ウィンドウ検証の復旧

- [x] `test:window` に timeout と診断出力を追加する。
  - 対象: `test/godotWindowE2E.test.mjs`
  - 完了条件: ハングせず、失敗時に stdout/stderr と起動段階が分かる。

- [x] `window_e2e_runner.gd` の開始ログを追加する。
  - 対象: `scripts/window_e2e_runner.gd`
  - 完了条件: runner 起動前/後のどちらで止まったか分かる。

## Verification

実装後に実行する:

- [x] `npm run verify:llm`
- [x] `npm run playtest:ai`
- [x] `npm run test:e2e`
- [x] `npm run screenshot:showcase`

可能なら実行する:

- [x] `npm run test:window`

`test:window` が環境依存で失敗する場合は、timeout つきで失敗理由を記録できていれば今回の最低条件は満たす。

## Out of Scope

- 新武器追加。
- 新敵追加。
- ステージ生成器の全面再設計。
- アセット一式の作り直し。
- 報酬選択 UI の本格実装。

## Done Log

- [x] 実装開始時に時刻を記録する。
  - Goal 作成: 2026-06-12 12:20 JST 頃。
- [x] 4h 到達前に完了/未完了を仕分ける。
  - 訂正: Phase 1、Phase 3、Phase 4、Phase 5 は実装ベースでは完了。
  - 訂正: Phase 2 はプレイヤー体験として未完了。前回の「完遂」判断は誤り。
  - 残リスク: 実ウィンドウ E2E は macOS window service 接続エラーで timeout。ハングはせず診断出力は得られる。
- [x] 最終検証結果を書く。
  - `npm run test`: pass。31 pass / 1 skipped。
  - `npm run verify:llm`: pass。
  - `npm run playtest:ai`: pass。
  - `npm run test:e2e`: pass。
  - `npm run screenshot:showcase`: pass。
  - `npm run test:window`: fail with timeout after 45000ms, diagnostic stderr captured.
  - 重要: 上記は自動検証であり、手動プレイの手触り改善を証明していない。
