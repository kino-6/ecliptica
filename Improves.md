# Ecliptica 改善メモ

## 面白さの軸

Ecliptica は、暗い城内を読み、敵との間合いを取り、シジルを集めて封印ゲートを開く探索アクションとして成立させたい。

現状は素材や個別機能は揃いつつあるが、初回プレイヤーが「どこへ行くか」「いつ攻撃するか」「なぜ食らったか」を読めない。まずは最初の1ステージを、攻略以前に操作と目的が分かる状態へ戻す。

## 現状の読み

- `npm run verify:llm` は pass。
- `npm run playtest:ai` は pass。`adept` 以上はクリア、`novice` / `casual` は Boss で失敗。
- `npm run screenshot:showcase` は pass。`artifacts/showcase/showcase-room.png` を確認済み。
- `npm run test:window` は 90 秒以上戻らず中断。実ウィンドウ検証が信頼できない。

機械検証は「要素が存在する」「判定が動く」「勝利状態にできる」を確認している。一方で、人間が実際にプレイするときの認知負荷、間合い、攻撃タイミング、導線、被弾理由は十分に測れていない。

## 改善点

### 1. AI プレイテストが実戦の難しさを隠している

`scripts/ai_playtest.gd` は、近接テストで敵を攻撃判定の中心へ移動し、Boss テストでは `player._damage_attack_target(boss)` を直接呼んでいる。これでは、実配置で接近して、突進を避け、攻撃の active frame に合わせて当てる難しさが測れない。

改善方針:

- 敵/Boss を実配置または実戦に近い距離に置く。
- プレイヤー入力だけで接近、停止、攻撃、射撃、回避を行う。
- 被弾回数、空振り回数、撃破までの時間を route log に出す。
- `adept` が pass する前提を、直接ダメージではなく実操作で確認する。

### 2. 攻撃の当て感が初回プレイヤーに厳しい

`scripts/player.gd` の斧攻撃は 16fps / 8 frames で、active は frame 4-5 のみ。さらに攻撃中の移動は 18% に落ちる。敵の突進や接触ダメージと組み合わさると、プレイヤー視点では「押したのに当たらない」「なぜ被弾したか分からない」になりやすい。

改善方針:

- 1段目だけ active window を広げる。
- 1段目の前方 hitbox を少し広げる。
- 空振り硬直は軽く、命中時だけ hitstop と camera impulse で重くする。
- 敵に当たる距離を視覚的に読みやすくする。

### 3. ジャンプ/移動に基本救済がない

ジャンプは床上のみで、coyote time や jump buffer がない。着地硬直もあり、初回ステージの縦移動や段差で操作不能感が出やすい。

改善方針:

- coyote time を短く追加する。
- jump buffer を短く追加する。
- 着地硬直は残しても、最初は移動制限を少し弱める。

### 4. 目的地と進行条件が読みにくい

シジルは7個あり、枝道や縦部屋にも配置されている。HUD はピップと `SEALED` / `OPEN` の表示だけで、次に何をすればよいかが弱い。

改善方針:

- `Sigils 0/7` のような明示表示を追加する。
- 未回収シジルまたはゲート方向の簡易インジケータを追加する。
- ゲートが開いた瞬間に画面上で分かる feedback を追加する。
- 初回だけ操作と目的を短く表示する。

### 5. 敵/Boss の危険と状態が読みにくい

通常敵は近づくと突進するが、予備動作や危険範囲が薄い。Boss は HP 3 だが、HP 表示や行動フェーズがなく、何が進んでいるか分かりづらい。

改善方針:

- 通常敵に突進前の短い tell を入れる。
- Boss に HP バーを追加する。
- 被弾時と無敵時間の見た目を強める。
- 敵接触時の knockback と damage feedback を、画面上で理解しやすくする。

### 6. 視認性が雰囲気に負けている

showcase では素材自体は良いが、暗い背景、暗い敵、重い床が近い明度で並び、重要物の優先度が一目で分かりにくい。雰囲気は残しつつ、ゲームプレイに必要なものだけは少し浮かせたい。

改善方針:

- 床上面、敵輪郭、シジル、ゲートの明度差を上げる。
- 拾える物に小さな pulse / glow を入れる。
- 敵と背景が重なる箇所で silhouette を保つ。

### 7. 実ウィンドウ検証がハングする

`npm run test:window` が 90 秒以上戻らなかった。ログファイルも生成されなかったため、Godot ウィンドウ起動または test harness の待ち条件で詰まっている可能性がある。

改善方針:

- Node 側に timeout を入れて失敗理由を出す。
- Godot 起動直後の stdout/stderr を必ず残す。
- `window_e2e_runner.gd` が開始したことを早期に print する。

## 優先度

最初に直すべきは、AI プレイテストの盲点と最初の敵1体の手触り。ここが直らないままシジル導線やBossを足しても、プレイヤー体験の苦しさを測れない。

次に、目的表示と視認性を最小限足す。最後にBossと実ウィンドウ検証を安定させる。

## 実ウィンドウプレイ後の改善点 2026-06-13

実行証拠:

- Command: `npm run playtest:window-manual`
- Run: `artifacts/window-manual-play/20260613-223945-window-manual/summary.json`
- Display: `macOS`
- Screenshots:
  - `artifacts/window-manual-play/20260613-223945-window-manual/window-start.png`
  - `artifacts/window-manual-play/20260613-223945-window-manual/window-after_movement.png`
  - `artifacts/window-manual-play/20260613-223945-window-manual/window-after_attack.png`
- Route:
  - movement: `moved_by=180.95`
  - first enemy: `distance_x=86.32`
  - attack: `hit=true`, `enemy_destroyed=true`, `player_damage_taken=0`

ここで言えること:

- 実ウィンドウ上で、保持入力による右移動、最初の敵への接近、斧攻撃による撃破までは成立している。
- `Sigils 0/7` と `Collect 7 sigils. J: Attack / L: Shoot` は画面上で読める。
- 敵との間合いは、移動後スクリーンショットで確認できる距離まで詰められている。

まだ改善したいこと:

### 1. Boss HP が最初から出ていて情報の優先順位が悪い

開始直後から `BOSS 3/3` が画面上部に出ている。最初の部屋でプレイヤーが知りたいのは、移動、攻撃、シジル収集、目の前の敵の危険であり、Boss HP はまだ早い。

改善方針:

- Boss が画面内、または Boss 部屋付近に入るまで Boss HP を非表示にする。
- 最初の敵との戦闘中は、HUD の情報量を HP / Focus / Sigils / Gate に絞る。

### 2. 攻撃命中の瞬間がスクリーンショットに残っていない

JSON では `hit=true` だが、`window-after_attack.png` は攻撃後の静止状態で、ヒットストップ、火花、敵の消滅、斧の active frame が見えない。手触り評価としては「当たったこと」は分かるが、「当たった感」はまだ見えない。

改善方針:

- 実ウィンドウ manual play でも `attack-start`, `attack-active`, `hit-frame`, `after-hit` の連続フレームを保存する。
- 命中 frame の screenshot に、斧、敵、hit spark が同時に写るタイミングを狙う。

### 3. 敵の危険状態が背景と重なって読みにくい

移動後スクリーンショットでは、敵が焚き火と暗い背景に近い位置へ入り、輪郭と危険状態が少し埋もれる。`windup` の存在は headless timeline では確認できるが、実ウィンドウ静止画では「今危ない」がまだ弱い。

改善方針:

- `windup` 中の敵に輪郭光、足元予兆、または短い前傾ポーズを追加する。
- 焚き火や背景の明度と敵の輪郭が競合する場所では、敵側の rim light を強める。

### 4. 目的表示は読めるが、次の導線はまだない

`Collect 7 sigils` は読めるが、画面内のシジルや次に向かう方向までは案内していない。初回プレイヤーは最初の敵を倒した後、どちらへ進むべきか迷いやすい。

改善方針:

- 最寄り未回収シジルへの軽い方向 cue を追加する。
- Gate が閉じている間は、`Sigils 0/7` の横に「remaining objective」感を出す。

### 5. 実ウィンドウ検証は GUI 承認が必要

通常 sandbox では macOS window service 接続エラーで timeout する。GUI 承認つきなら `display_name=macOS` の実 viewport 証拠を保存できる。

改善方針:

- 実ウィンドウ系は `playtest:window-manual` と `test:window-manual` を明示コマンドとして維持する。
- CI/headless では `playtest:manual` を使い、ローカル QA では GUI 承認つき `playtest:window-manual` を使う運用に分ける。
