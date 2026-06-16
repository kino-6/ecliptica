# Ecliptica 改善メモ

## 高品質な斧攻撃の定義

ユーザー定義: 視覚的に納得感があり、重量物を振り回しているアニメーション、威力、人間の動きの緩急がある状態。

このPJでは次の状態を目標にする。

- 斧のサイズを伸縮させてごまかさない。
- 足場、腰、肩、肘、手、斧頭が一つの運動連鎖として見える。
- windup で重さを溜め、held frame で支え、active frame で急加速し、impact で刃と敵と spark が同じ接触点を示す。
- follow-through で斧と布/髪/身体が遅れて流れ、recovery で自然に減速して戻る。
- hitbox、hitstop、camera impulse、敵リアクションがアニメーション上の接触点と一致する。
- 実ウィンドウ screenshot と JSON evidence なしに「高品質」と言わない。

NG:

- 斧や身体を適当に伸び縮みさせる。
- 手元と斧頭が離れている。
- 均等な回転で、溜め/急加速/衝突/余韻がない。
- `hit=true` だけで手触りを肯定する。

参考軸:

- Animation principles: anticipation, arcs, slow-in/slow-out, follow-through。
- Realistic heavy swing: 腕単体ではなく、身体全体の連鎖で重量物を加速させる。

2026-06-15 PDCA:

- `test/playerAxeAssetCheck.mjs` に scale abuse gate を追加。
- `tools/generatePlayerAxeSheets.py` の attack pose scale を `0.97..1.05` に抑え、斧の伸縮で威力を作らないようにした。
- Evidence: `artifacts/window-manual-play/20260615-183902-window-manual/summary.json`。
- まだ未達: 腰/肩から斧頭へ力が伝わる運動連鎖、follow-through の迫力、Boss 戦中の斧視認性。次は body/axe を同じ kinematic definition から生成する。

2026-06-15 follow-through PDCA:

- `tools/attack_motion_contract.py` を共有モーション契約として使い、body/axe の frame 6/7 を同じ follow-through drive から生成するようにした。
- `test/playerActionAssetCheck.mjs` に frame 6 でも肩、手、grip が接続される契約を追加した。
- `scripts/window_manual_play_probe.gd` / `test/godotWindowManualPlay.test.mjs` で `window-attack-follow-through.png` を実ウィンドウ evidence として必須にした。
- Evidence: `artifacts/window-manual-play/20260615-191330-window-manual/summary.json`。
- Screenshots:
  - `artifacts/window-manual-play/20260615-191330-window-manual/window-attack-active.png`
  - `artifacts/window-manual-play/20260615-191330-window-manual/window-hit-spark.png`
  - `artifacts/window-manual-play/20260615-191330-window-manual/window-attack-follow-through.png`
- 言えること: 斧の伸縮ごまかしは gate 化され、命中後 frame 6 の手元接続と follow-through evidence は改善した。
- まだ言えないこと: 身体全体の踏み込み、腰の回り込み、held weight の視覚的説得力は弱く、斧攻撃が高品質に達したとはまだ断言しない。

## 斧アニメーションそのものの修正案 2026-06-17

前回の評価は、身体側の踏み込み、腰、肩、held weight に寄りすぎていた。より根本には、斧レイヤー自体が「手に持った重量物」ではなく、別画像が回転・移動しているように見える問題がある。

### 現状のおかしい点

- 斧の pivot が握り手ではなく画像中心寄りに見え、手元から力が伝わっていない。
- grip、柄、斧頭、刃先、重心がアニメーション上で設計されておらず、フレームごとの位置合わせに見える。
- 斧頭の軌道が連続した弧ではなく、frame 間でテレポート/ポーズ切替に見える。
- active frame の刃の向きと敵への接触点が直感的に一致しない場面がある。
- smear/afterimage が「高速な振り抜き」ではなく、多重化した斧画像やノイズに見える。
- follow-through で斧頭が慣性を持って流れず、身体の横や後ろへ急に収まる。
- 現在の generator は既存の斧画像を回転・拡大縮小して帳尻を合わせており、武器アニメとしての rig がない。

### 修正方針

次の改善は、身体側の微修正ではなく、斧攻撃アニメを作り直す。

1. Diagnostic overlay を作る
   - 8 frame contact sheet に `grip point`, `blade edge`, `axe head center`, `hitbox`, `spark origin` を描く。
   - 実ウィンドウ screenshot だけではなく、sheet 上でも破綻を確認できるようにする。

2. 斧を rig として再定義する
   - grip anchor、柄の向き、斧頭中心、刃先、重心を metadata として持つ。
   - grip は player hand に常時一致させる。
   - scale は固定し、威力は弧、タイミング、smear、impact pose で表現する。

3. 8 frame timeline を作り直す
   - frame 0: 構え。
   - frame 1: 後方/上方へ引き始める。
   - frame 2: 重さを支える windup。
   - frame 3: held weight。ほぼ止めて重さを読む。
   - frame 4: snap/smear。長い移動量だが刃の方向は読める。
   - frame 5: impact。刃、敵、spark、hitbox が一致する。
   - frame 6: overshoot。斧頭がまだ前方/下方へ流れる。
   - frame 7: recovery。重量を戻す減速。

4. 見た目の gate を追加する
   - grip から blade edge までの距離が frame 間で不自然に変わらない。
   - blade edge path が連続した弧を描く。
   - active frame 4/5 の blade edge が runtime hitbox の前方接触帯に入る。
   - frame 6 は impact より少し前方/下方へ overshoot する。
   - smear は frame 4/5 のみに限定し、full axe の多重残像にしない。

5. 実ウィンドウで判定する
   - `window-attack-windup`, `window-attack-active`, `window-hit-spark`, `window-attack-follow-through` を取り直す。
   - ここで見た目がまだ変なら、変と記録する。
   - `hit=true` や asset test pass だけで高品質とは言わない。

## ユーザー実プレイRED 2026-06-15

前回の改善評価は甘かった。ユーザー実プレイでは、斧攻撃の手触りはまだ改善として感じられず、敵接触時の knockback はコースアウトするほど暴れていた。

### 追加改善点

1. 被弾 knockback が制御不能になる

原因:

- `scripts/player.gd` で knockback を通常速度に重ねる際、前フレームの寄与が残ったまま次フレームにも加算され、速度が蓄積していた。
- RED evidence では `max_abs_velocity_x=3005.83`, `max_displacement_x=1196.32`, `control_recovery_frames=-1` まで悪化していた。

改善方針:

- knockback は「短い怯み」として扱い、通常速度と分離して合成する。
- `max_displacement_x <= 72`, `control_recovery_frames <= 18` を gate にする。
- 実装後の GREEN は `max_abs_velocity_x=155`, `max_displacement_x=9.12`, `control_recovery_frames=4`。
- 実ウィンドウ Boss 接触でも `contact_knockback_max_velocity_x=105.08`, `contact_knockback_max_displacement_x=12.69`, `contact_knockback_control_recovery_frames=1` を確認した。

2. 斧攻撃の改善が実プレイに届いていない

原因:

- 前回の改善は hitbox/axe overlap と spark evidence に寄っていて、body が重い武器を振っている読みやすさを十分に gate していなかった。
- `player_attack_body` の production 出力導線も generator 側で明示されておらず、更新事故を起こしやすかった。

改善方針:

- `player_attack_body` の generator を production/root 両方へ出力する。
- attack body に cloth follow-through と impact smear を入れ、実ゲーム上のシルエット変化を増やす。
- `player_axe_attack` の active frame wake を強め、frame 4/5 の振り抜きを読みやすくする。
- `playerActionAssetCheck` / `playerAxeAssetCheck` で継続検証する。
- ただし、実ウィンドウ目視ではまだ「高品質な重い斧モーション」とは言い切らない。次は手元/肩/斧頭の接続、振り抜き後の余韻、Boss戦中の視認性を改善対象にする。

追加PDCA結果:

- `draw_attack_hand_bridge` を追加し、frame 4/5 で肩、肘、手、握りが斧レイヤーへつながるようにした。
- `playerActionAssetCheck` に active frame の grip bridge pixel gate を追加した。
- 実ウィンドウ evidence: `artifacts/window-manual-play/20260615-160431-window-manual/summary.json`。
- 目視では手元接続は前回より改善。ただし、刃の位置がやや低く、Boss戦の激しい場面で斧軌道が十分に読めるかは未評価。次は axe layer の active pose と recovery follow-through を詰める。

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
