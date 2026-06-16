# Ecliptica Active Tasks

## Definition - High Quality Axe Attack

「斧攻撃が高品質」と言える条件を、視覚的な納得感として定義する。

高品質な斧攻撃は、単に斧画像が大きい/伸びる/当たり判定に重なる状態ではない。重量物を人間が振る動きとして、次の条件を満たす必要がある。

- [ ] Anticipation: 攻撃前に、身体と斧が打撃方向と逆へ入り、重さを溜めていることが読める。
- [ ] Held weight: windup の終端で一瞬保持され、重量物を支えている間がある。
- [ ] Human kinetic chain: 腕だけではなく、足場、腰、肩、肘、手、斧頭が同じ運動の連鎖として見える。
- [x] Stable weapon mass: 斧のサイズを不自然に伸縮させず、位置、角度、弧、タイミングで力を表現する。
- [ ] Snap: 予備動作から active frame へ、均等回転ではなく急加速がある。
- [x] Impact: active frame 4/5 で、刃、敵、hit spark、hitstop、camera impulse、敵リアクションが同じ接触点を示す。
- [ ] Follow-through: 命中後に斧と布/髪/身体が遅れて流れ、重量物が止まりきらない余韻がある。
- [ ] Recovery: 回復フレームは硬直ではなく、次入力へ戻る人間らしい減速として読める。
- [x] Real-window evidence: `window-attack-active.png` と `window-hit-spark.png` を目視し、上記を言える範囲/言えない範囲に分けて記録する。

明確にNG:

- 斧や身体を適当に伸縮して威力があるように見せる。
- 手元と斧頭が離れている。
- hitbox だけ当たって、刃や身体の運動が追いついていない。
- 全フレームが均等な回転で、溜め、急加速、衝突、余韻がない。
- Headless の `hit=true` だけで「高品質」と言う。

参考にする原則:

- Animation: anticipation, slow-in/slow-out, follow-through, arcs。
- Real motion: 重量物は腕だけではなく、足場、体幹、肩、腕、手首へ力が伝わる運動として扱う。

## PDCA Board - High Quality Axe Attack Definition 2026-06-15

- [x] Plan: ユーザー定義を受け、`高品質な斧攻撃` を視覚的納得感、重量、威力、人間の緩急として再定義する。
- [x] Research: animation principle と重量物スイングの考え方を確認し、伸縮ではなく弧、溜め、連鎖、余韻を評価軸にする。
- [x] Do RED: `test/playerAxeAssetCheck.mjs` に scale abuse gate を追加する。
- [x] Check RED: `node test/playerAxeAssetCheck.mjs` が `axe attack should not fake wind-up weight by shrinking the weapon` で失敗。
- [x] Do: `tools/generatePlayerAxeSheets.py` の attack pose scale を `0.97..1.05` に抑え、source幅と pose arc で重さを表現する。
- [x] Check GREEN:
  - `node test/playerAxeAssetCheck.mjs`: pass。
  - `node test/playerActionAssetCheck.mjs`: pass。
- [x] Check: `npm run verify:llm`, `node --test test/manualPlayProbe.test.mjs`, `node --test test/godotE2E.test.mjs`。
- [x] Check: GUI 承認つき `npm run test:window-manual` で実ウィンドウ evidence を更新する。
- [x] Act: 実ウィンドウ目視で、定義に照らして何が達成/未達かを記録する。

Evidence:

- Window run: `artifacts/window-manual-play/20260615-183902-window-manual/summary.json`
- Screenshots:
  - `artifacts/window-manual-play/20260615-183902-window-manual/window-attack-active.png`
  - `artifacts/window-manual-play/20260615-183902-window-manual/window-hit-spark.png`
  - `artifacts/window-manual-play/20260615-183902-window-manual/window-after_attack.png`

Act result:

- 達成: 「斧のサイズを不自然に伸縮させて重さを作る」状態は RED/GREEN 化し、scale range を `0.97..1.05` に抑えた。
- 達成: active/hit の実ウィンドウ evidence は更新できた。
- 未達: 腰/肩から斧頭へ力が伝わる人間の運動連鎖、follow-through の迫力、Boss 戦中の斧視認性はまだ高品質と断言しない。
- 次PDCA: body の腰/肩回転と axe layer の blade path を同じキネマティック定義から生成し、frame 6/7 の余韻を強化する。

## PDCA Board - Axe Follow-through Connection 2026-06-15

- [x] Plan: `frame 6/7 の余韻が弱く、斧だけ戻って見える` を次のREDとして扱う。
- [x] Do RED: `test/playerActionAssetCheck.mjs` に frame 6 follow-through でも肩、手、grip が接続される契約を追加する。
- [x] Check RED: `node test/playerActionAssetCheck.mjs` が `player body attack should keep shoulder, hands, and grip connected into frame 6 follow-through` で失敗。
- [x] Do: `tools/attack_motion_contract.py` の frame 6/7 に follow-through drive を追加し、手元、肘、肩、斧頭の位置を同じ共有poseから前方へ流す。
- [x] Do: `tools/generatePlayerActionSheets.py` で frame 6 も `draw_attack_hand_bridge` を描く。
- [x] Do: `assets/player-attack-combo-sheet-24.png`, `assets/production/player-attack-combo-sheet-24.png`, `assets/player-axe-attack-combo-sheet-24.png`, `assets/production/player-axe-attack-combo-sheet-24.png` を再生成する。
- [x] Check GREEN:
  - `node test/playerActionAssetCheck.mjs`: pass。
  - `node test/playerAxeAssetCheck.mjs`: pass。
  - GUI 承認つき `npm run test:window-manual`: pass。
  - `npm run test`: pass。
- [x] Evidence:
  - Window run: `artifacts/window-manual-play/20260615-191330-window-manual/summary.json`
  - Screenshots:
    - `artifacts/window-manual-play/20260615-191330-window-manual/window-attack-active.png`
    - `artifacts/window-manual-play/20260615-191330-window-manual/window-hit-spark.png`
    - `artifacts/window-manual-play/20260615-191330-window-manual/window-attack-follow-through.png`
- [x] Act: frame 6 の手元接続と follow-through capture は改善した。実ウィンドウでは hit spark と敵リアクション、命中後の斧の残りは見える。ただし、身体全体の踏み込み、腰の回り込み、重量物を支える held frame の説得力はまだ弱く、高品質達成とは言わない。

Next RED:

- [ ] Anticipation/held weight を目視できるように、`window-attack-start.png` だけでなく windup frame 2/3 の screenshot gate を追加する。
- [ ] 腰/肩/足場の運動連鎖を、単なる上半身 warp ではなく silhouette 上の明確な踏み込みとして見えるようにする。
- [ ] Boss 戦距離でも斧の刃、敵接触点、spark が読めるかを実ウィンドウ evidence 化する。

## Next Plan - Rebuild Axe Animation Itself 2026-06-17

前回の Act は身体側の踏み込み、腰、肩、held weight に寄りすぎていた。次は、斧レイヤーそのものが「手に持った重量物」ではなく「別画像の回転」に見える問題を主対象にする。

Problem statement:

- [ ] 斧の pivot が握り手ではなく画像中心寄りに見える。
- [ ] grip、柄、斧頭、刃先、重心が明示されておらず、フレームごとの位置合わせに見える。
- [ ] 斧頭の軌道が連続した弧ではなく、テレポート/ポーズ切替に見える。
- [ ] active frame の刃の向きと敵への接触点が直感的に一致しない。
- [ ] smear/afterimage が振り抜きではなく、多重化した斧画像やノイズに見える。
- [ ] follow-through で斧頭が慣性を持って流れず、急に身体の横/後ろへ収まる。

Implementation slices:

- [ ] Slice A: Diagnostic overlay sheet
  - `grip point`, `blade edge`, `axe head center`, `hitbox`, `spark origin` を 8 frame contact sheet に描く。
  - 現状の破綻を screenshot ではなく sheet 上でも確認できるようにする。

- [ ] Slice B: Axe rig contract
  - 斧を `grip anchor`, `handle vector`, `axe head center`, `blade edge`, `center of mass` を持つ rig として定義する。
  - body の hand pose と axe の grip anchor を同じ contract から生成する。
  - scale は固定し、weight は arc、timing、smear、impact pose で表現する。

- [ ] Slice C: 8 frame heavy axe timeline
  - frame 0: 構え。
  - frame 1: 後方/上方へ引き始める。
  - frame 2: 重さを支える windup。
  - frame 3: held weight。ほぼ止めて重量を読む。
  - frame 4: snap/smear。刃の方向は読める。
  - frame 5: impact。刃、敵、spark、hitbox を一致させる。
  - frame 6: overshoot。斧頭がまだ前方/下方へ流れる。
  - frame 7: recovery。重量を戻す減速。

- [ ] Slice D: Visual quality gates
  - grip から blade edge までの距離が frame 間で不自然に変わらない。
  - blade edge path が連続した弧を描く。
  - active frame 4/5 の blade edge が runtime hitbox の前方接触帯に入る。
  - frame 6 は impact より少し前方/下方へ overshoot する。
  - smear は frame 4/5 のみに限定し、full axe 多重残像を禁止する。

- [ ] Slice E: Real-window judgement
  - `window-attack-windup`, `window-attack-active`, `window-hit-spark`, `window-attack-follow-through` を取り直す。
  - 見た目がまだ変なら変と記録する。
  - `hit=true` や asset test pass だけで高品質とは言わない。

## Current Truth - User Play RED 2026-06-15

ユーザー実プレイで、前回の「改善できた」という評価は不足だった。

- 斧攻撃は、実プレイ上まだ「重い武器を振った」手触りとして読めていなかった。
- 敵接触時の knockback は、プレイヤーがコースアウトするほど暴れていた。
- 既存 evidence は「命中/接触/表示が発生した」ことに偏り、「どれだけ吹き飛ぶか」「何フレームで制御が戻るか」「body sheet が実ゲームで読みやすいか」を gate にしていなかった。

今回追加した RED:

- Manual probe: `enemy_contact_recovery` scenario。
- RED evidence: `artifacts/manual-play/20260615-154556-manual-play/summary.json`
- RED values: `max_abs_velocity_x=3005.83`, `max_displacement_x=1196.32`, `control_recovery_frames=-1`

今回の GREEN:

- Manual probe: `artifacts/manual-play/20260615-154956-manual-play/summary.json`
- GREEN values: `max_abs_velocity_x=155`, `max_displacement_x=9.12`, `control_recovery_frames=4`
- LLM verify: `damage_knockback_max_displacement_x=9.09`, `damage_knockback_max_velocity_x=155`, `damage_knockback_control_recovery_frames=4`
- Window manual: `artifacts/window-manual-play/20260615-155522-window-manual/summary.json`
- Window Boss contact values: `contact_knockback_max_velocity_x=105.08`, `contact_knockback_max_displacement_x=12.69`, `contact_knockback_control_recovery_frames=1`

言えること:

- Headless evidence 上、敵接触 knockback の暴走は再現でき、上限つきの短い怯みに直した。
- Body/axe asset contract は、production 出力も含めて更新・検証した。

まだ言えないこと:

- 実ウィンドウで長時間遊んで Boss 戦全体が楽しい、まではまだ断言しない。
- 斧アニメの主観的な気持ちよさは、次の実ウィンドウ play evidence と目視で再評価する。

## PDCA Board - User Play RED

- [x] Plan: ユーザー指摘を RED として、斧アニメ未改善・敵接触 knockback 暴走を改善対象にする。
- [x] Do: `enemy_contact_recovery` scenario を manual probe に追加し、暴走値を再現する。
- [x] Do: `scripts/player.gd` の knockback を蓄積しない速度寄与に変更し、短い被弾怯みにする。
- [x] Do: `tools/generatePlayerActionSheets.py` を production 出力対応にし、attack body に cloth follow-through と impact smear を追加する。
- [x] Do: `tools/generatePlayerAxeSheets.py` の active frame motion wake を強める。
- [x] Check: `node --test test/manualPlayProbe.test.mjs` で knockback 上限と制御復帰を検証する。
- [x] Check: `node test/playerActionAssetCheck.mjs` / `node test/playerAxeAssetCheck.mjs` で body/axe contract を検証する。
- [x] Check: `npm run verify:llm`, `node --test test/godotE2E.test.mjs`, `npm run release:check` を通す。
- [x] Check: GUI 承認つき `npm run test:window-manual` で実ウィンドウ evidence を更新する。
- [x] Act: 実ウィンドウ evidence を見て、斧の読みやすさと被弾 feedback の次スライスを決める。

Act result:

- 被弾 knockback は headless / window とも暴走が止まったため、今回の主修正は GREEN。
- 斧は active frame と hit spark は読めるようになったが、目視では body の振り切り品質はまだ「高品質」と断言しない。次サイクルでは手元/肩/斧頭の接続、attack recovery の余韻、Boss戦中の斧視認性を対象にする。

## PDCA Board - Axe Hand Connection 2026-06-15

- [x] Plan: 前サイクルActの「手元/肩/斧頭の接続が弱い」をREDにする。
- [x] Do: `test/playerActionAssetCheck.mjs` に `draw_attack_hand_bridge` と active frame の grip bridge pixel gate を追加する。
- [x] Check RED: `node test/playerActionAssetCheck.mjs` が `player body attack should visibly connect shoulder, hands, and axe grip during active frames` で失敗。
- [x] Do: `tools/generatePlayerActionSheets.py` に `draw_attack_hand_bridge` を追加し、frame 4/5 で肩、肘、手、握りを描く。
- [x] Do: `assets/player-attack-combo-sheet-24.png` と `assets/production/player-attack-combo-sheet-24.png` を再生成し、hash 一致を確認。
- [x] Check GREEN:
  - `node test/playerActionAssetCheck.mjs`: pass。
  - `node test/playerAxeAssetCheck.mjs`: pass。
  - `npm run release:check`: pass。
  - `npm run verify:llm`: pass。
  - `node --test test/manualPlayProbe.test.mjs`: pass。
  - `node --test test/godotE2E.test.mjs`: pass。
  - GUI 承認つき `npm run test:window-manual`: pass。
- [x] Evidence:
  - Window run: `artifacts/window-manual-play/20260615-160431-window-manual/summary.json`
  - Screenshots:
    - `artifacts/window-manual-play/20260615-160431-window-manual/window-attack-active.png`
    - `artifacts/window-manual-play/20260615-160431-window-manual/window-hit-spark.png`
    - `artifacts/window-manual-play/20260615-160431-window-manual/window-boss-contact-damage.png`
- [x] Act: 手元接続は前回より読めるようになった。ただし、刃の位置と振り抜きの美しさ、Boss戦中の視認性はまだ「高品質」と断言しない。次PDCAでは axe layer の active frame pose と recovery follow-through を対象にする。

## Current Truth

2026-06-15 に `ecliptica-playfeel-evidence` の手順で evidence を取り直し、Tasks.md の Active Task Board を完了した。

- Manual run: `artifacts/manual-play/20260615-130521-manual-play/summary.json`
- Window test run: `artifacts/window-manual-play/20260615-131057-window-manual/summary.json`
- Window playtest run: `artifacts/window-manual-play/20260615-131232-window-manual/summary.json`
- Display: `macOS`
- Route: movement `moved_by=184.45`, first enemy attack `hit=true`, `enemy_destroyed=true`, `player_damage_taken=0`
- HUD evidence: `boss_hp_visible=false`, `sigil_text="Sigils 0/7 / NEXT >"`, `state_text="RUN 1 / SEALED 7 SIGILS"`
- Windup evidence: `windup_frame_captured=true`, `tell_visible=true`, `windup_direction="left"`, `frame=23`
- Hit evidence: `attack_active_captured=true`, `hit_frame_captured=true`, `hit_spark_visible=true`, `enemy_reaction_visible=true`, `hit_frame=7`
- Sigil evidence: `next_sigil_visible=true`, `pickup_captured=true`, `sigils_collected_after=1`, `sigil_text_after="Sigils 1/7 / NEXT >"`
- Boss evidence: `boss_hp_visible=true`, `boss_text="BOSS 3/3"`, `contact_damage_captured=true`, `player_damage_taken=1`
- Screenshots:
  - `artifacts/window-manual-play/20260615-131057-window-manual/window-enemy-windup.png`
  - `artifacts/window-manual-play/20260615-131057-window-manual/window-attack-active.png`
  - `artifacts/window-manual-play/20260615-131057-window-manual/window-hit-spark.png`
  - `artifacts/window-manual-play/20260615-131057-window-manual/window-next-sigil-visible.png`
  - `artifacts/window-manual-play/20260615-131057-window-manual/window-after_sigil_pickup.png`
  - `artifacts/window-manual-play/20260615-131057-window-manual/window-boss-hp-visible.png`
  - `artifacts/window-manual-play/20260615-131057-window-manual/window-boss-contact-damage.png`

ここで言えること:

- 実ウィンドウで、開始、敵 windup、接近、攻撃 active、命中/spark、最初のシジル、Boss HP reveal、Boss接触ダメージの証拠は保存できている。
- 最初の敵撃破と最初のシジル pickup は実入力で成立している。
- Boss HP reveal は `positioned_near_boss_for_window_evidence` セットアップで確認し、その後の接触ダメージは実入力で確認している。
- ただし、全ステージの面白さや全Boss戦の完成度まではまだ言わない。

## Evidence-Based Findings

- [x] Finding 1: Hit frame は取れているが、命中の手応えはまだ弱い

`window-hit-frame.png` では敵がすでに消えており、斧の接触、敵の hit reaction、hit spark が同時に読みにくい。JSON の `hit=true` は成立しているが、画面上の「当たった感」はまだ評価しづらい。

- [x] Finding 2: 斧攻撃の body / axe / hitbox / VFX の整合が弱い

`window-attack-active.png` では、斧が敵に届いているか、身体が重い武器を振っているか、active hitbox がどこにあるかを画面だけで判断しづらい。現行実装は `player_attack_body`, `player_axe_attack`, hitbox timing, hit spark が別々に成立しているが、手触りとして一つの攻撃に見える契約が弱い。

- Runtime: `scripts/player.gd` の active frames は `4,5`、hitbox は step 別 offset/size、axe layer は `AXE_ATTACK_POSITION` と `AXE_ATTACK_SCALE` で同期。
- Asset contract: `assets/manifest.yaml` の `player_attack_body`, `player_axe_attack`, `hit_spark`。
- Skill: `weapon-vfx-quality-gate` と `pixel-action-animation` を使って、アセットと runtime を同時に直す必要がある。

- [x] Finding 3: Windup tell は見えるが、危険予告としての意味はまだ弱い

`window-enemy-windup.png` では足元線と rim は表示されている。ただし、線がやや debug-like で、焚き火や背景の明るさとも競合している。初見プレイヤーが「このあと突進が来る」と読むには、敵本体の姿勢、危険方向、攻撃範囲とのつながりがまだ薄い。

- [x] Finding 4: `NEXT >` は読めるが、目的物そのものの誘導は弱い

HUD の `Sigils 0/7 / NEXT >` は読める。一方で、画面内のシジルやルートはまだ視覚的に強く誘導されていない。最初の敵撃破後に「何を拾うか」「どこへ進むか」をスクリーンショットだけで判断するには弱い。

- [x] Finding 5: Boss/被弾まわりは実ウィンドウ証拠が不足している

manual run の `boss_three_hits` は `hits_landed=3`, `boss_destroyed=true` だが、途中で `reason="took_contact_before_or_during_attack"`, `player_damage_taken=1` が出ている。Boss 接触、被弾、HP 表示、Boss 近辺での readable danger は実ウィンドウ screenshot でまだ確認できていない。

- [x] Finding 6: Window manual harness が最初の敵までに偏っている

現行 `playtest:window-manual` は最初の敵の評価には有効。ただし、シジル pickup、Gate 状態変化、Boss HP reveal、Boss 接触/撃破を実ウィンドウで評価できないため、次の改善判断がまた headless 寄りになる。

## Goal

「最初の敵を倒せる」から一段進めて、初回プレイヤーが実ウィンドウ上で「当たった」「危ない」「次に拾う」「Boss が危険」を読める状態へ近づける。

完了条件:

- [x] 斧攻撃が、body pose、axe layer、hitbox、hit spark、enemy reaction の一体の動きとして読める。
- [x] 命中 frame で、斧、敵、hit spark または hit reaction が同時に見える。
- [x] enemy windup が debug line ではなく、敵本体と危険方向に結びついた tell として読める。
- [x] 最初の敵撃破後、次のシジルまたは進行方向が画面上でも分かる。
- [x] Boss 接近、Boss HP reveal、Boss 接触/被弾、Boss 撃破のうち少なくとも1つを実ウィンドウ evidence に追加する。
- [x] `Tasks.md` には各 Slice の RED/GREEN、summary path、screenshot path、言えること/言えないことを残す。

## Safety

- 手触り改善を主張する前に、必ず新しい evidence を取る。
- 実ウィンドウ系は GUI 承認つきで実行する。
- Headless pass と実ウィンドウ視認性を混同しない。
- 新しい広大なステージや武器追加は今回の範囲外。
- 既存の gothic mood は残し、gameplay 情報だけを浮かせる。

## Active Task Board

- [x] Slice 1: 斧攻撃の asset / animation / hitbox contract を再整備する。
- [x] Slice 2: 命中の手応えを画面で読めるようにする。
- [x] Slice 3: Enemy windup を gameplay tell として読みやすくする。
- [x] Slice 4: 最初の敵撃破後のシジル導線を実画面で評価する。
- [x] Slice 5: Boss/被弾の実ウィンドウ evidence を追加する。
- [x] Slice 6: Playfeel evidence harness を次の実装に耐える形へ拡張する。

## Slice 1: 斧攻撃の asset / animation / hitbox contract を再整備する

- [x] 現行の斧攻撃を runtime と asset の両方から診断する。
  - 対象: `scripts/player.gd`, `assets/manifest.yaml`, `assets/production/player-attack-combo-sheet-24.png`, `assets/production/player-axe-attack-combo-sheet-24.png`, `assets/production/hit-spark-sheet-4.png`
  - 確認: active frame 4/5 で、body pose、axe head、hitbox、enemy body、spark が同じ接触点を指しているか。
  - Evidence: `window-attack-active.png`, `window-hit-frame.png`, asset check outputs。

- [x] `player_attack_body` の heavy attack pose を作り直す。
  - 期待: 8 frames / combo step の中で anticipation、held weight、snap/smear、impact、follow-through、recovery が読める。
  - 注意: 足 baseline と transparent gutter を維持する。
  - Skill: `pixel-action-animation`。

- [x] `player_axe_attack` の accessory layer を body pose と再同期する。
  - 期待: axe head が active frame 4/5 で hitbox 中心と敵接触点に重なる。
  - 注意: 大きくするだけで重さを出さない。手元と斧頭の関係を優先する。
  - Skill: `weapon-vfx-quality-gate`。

- [x] hitbox offset/size を新しい attack sheet に合わせて再調整する。
  - 対象: `scripts/player.gd`
  - 期待: startup/recovery では hitbox inactive、frame 4/5 のみ visible weapon mass と overlap。

- [x] hit spark の位置とサイズを weapon impact に合わせる。
  - 対象: `scripts/player.gd`, `assets/production/hit-spark-sheet-4.png`
  - 期待: spark が敵中心ではなく、斧刃と敵の接触点に出る。

- [x] focused RED/GREEN を追加する。
  - RED: 現状の screenshot/asset contract で「active frame の axe/body/hitbox/spark が一体に見えない」ことを test または evidence summary で表現。
  - GREEN: `node test/playerAxeAssetCheck.mjs`, `node --test test/stageVisualAssetCheck.mjs`, `npm run release:check`, GUI 承認つき `npm run test:window-manual` が通る。

## Slice 2: 命中の手応えを画面で読めるようにする

- [x] `window-hit-frame.png` で敵が即消滅せず、hit reaction または death hold が残るようにする。
  - 対象候補: `scripts/enemy.gd`, `scripts/player.gd`
  - 期待: 命中 frame に斧、敵、hit spark/flash が同時に見える。

- [x] hit spark の表示タイミングと実ウィンドウ capture を合わせる。
  - 対象候補: `scripts/window_manual_play_probe.gd`, hit spark runtime
  - 期待: `hit_evidence` に `hit_spark_visible=true` または同等の evidence を残す。

- [x] focused RED/GREEN を追加する。
  - RED: 現状 `window-hit-frame.png` では敵 reaction/spark が同時に読めないことを test または summary で表現。
  - GREEN: `npm run test:window-manual` が hit visual evidence を検証する。

## Slice 3: Enemy windup を gameplay tell として読みやすくする

- [x] 足元線だけでなく、敵本体の posture/flash/方向性で windup を示す。
  - 対象候補: `scripts/enemy.gd`
  - 期待: `window-enemy-windup.png` を目視したとき、敵の次行動が右/左どちらへ来るか分かる。

- [x] windup tell を背景や焚き火と競合しにくい見た目にする。
  - 候補: 本体 rim を敵輪郭に寄せる、足元 tell を短く太くする、危険方向に低い arc を出す。
  - 注意: debug shape っぽさを減らす。

- [x] evidence contract を追加する。
  - 期待: `windup_evidence.tell_visible=true` に加えて `windup_direction`, `tell_frame`, screenshot path を summary に残す。

## Slice 4: 最初の敵撃破後のシジル導線を実画面で評価する

- [x] window manual scenario を「最初の敵撃破後、最初のシジル pickup」まで伸ばす。
  - 対象候補: `scripts/window_manual_play_probe.gd`
  - 保存候補: `window-after_first_enemy.png`, `window-next-sigil-visible.png`, `window-after_sigil_pickup.png`
  - 期待: `sigils_collected=1`, `sigil_text="Sigils 1/7 / NEXT ..."` を実ウィンドウ summary に残す。

- [x] 画面内/画面外シジルへの cue を HUD だけでなく world 側にも出す。
  - 対象候補: `scripts/game.gd`
  - 候補: nearest sigil pulse、画面端 indicator、短い glint。
  - 期待: `window-after_first_enemy.png` で次の目的が読める。

- [x] Gate sealed 表示とシジル導線の情報量を整理する。
  - 現状: `Sigils 0/7 / NEXT >` と `RUN 1 / SEALED 7 SIGILS` は読めるが文字情報が増えている。
  - 期待: HUD は短く、world cue で補う。

## Slice 5: Boss/被弾の実ウィンドウ evidence を追加する

- [x] window manual に Boss 接近または Boss HP reveal scenario を追加する。
  - 対象候補: `scripts/window_manual_play_probe.gd`
  - 保存候補: `window-boss-approach.png`, `window-boss-hp-visible.png`
  - 期待: `boss_hp_visible=true` が Boss 近辺でのみ記録される。

- [x] Boss hit/contact の route log を実ウィンドウで残す。
  - 背景: manual `boss_three_hits` では1回 `player_damage_taken=1` が発生している。
  - 期待: Boss 接触時の player damage feedback と knockback が screenshot/timeline で読める。

- [x] 被弾理由を画面上で分かるようにする。
  - 候補: player flash を強める、短い damage number/edge flash、contact impulse。
  - 期待: `took_contact_before_or_during_attack` が起きた時に、なぜ減ったかが分かる。

## Slice 6: Playfeel evidence harness を次の実装に耐える形へ拡張する

- [x] `playtest:window-manual` の summary に scenario 名を導入する。
  - 期待: `first_enemy`, `first_sigil`, `boss_reveal` のように分けて比較できる。

- [x] screenshot label と JSON field を test で固定する。
  - 対象: `test/godotWindowManualPlay.test.mjs`
  - 期待: 新しい screenshot が欠けたら fail。

- [x] `Tasks.md` 更新ルールを守る。
  - 各実装 Slice の後に RED, GREEN, evidence path, screenshot path, 残る不確実性を Done Log に追記する。

## Verification Plan

- [x] `node --test test/manualPlayProbe.test.mjs`
- [x] `npm run playtest:manual`
- [x] GUI 承認つき `npm run test:window-manual`
- [x] GUI 承認つき `npm run playtest:window-manual`
- [x] `node test/playerAxeAssetCheck.mjs`
- [x] `node --test test/stageVisualAssetCheck.mjs`
- [x] `npm run release:check`
- [x] `npm run verify:llm`
- [x] `npm run screenshot:showcase`
- [x] 変更範囲が広い場合: `npm run test`

## Latest Evidence Log

- [x] 2026-06-15 gorest spritesheet pilot を導入。
  - Skill: `.agents/skills/gorest-spritesheet-pilot/SKILL.md`。
  - UI metadata: `.agents/skills/gorest-spritesheet-pilot/agents/openai.yaml`。
  - Routing: `.agents/skills/game-sprite-asset-pipeline/SKILL.md` から gorest pilot へ誘導。
  - Classification: `PILOT`。上流repoをこのPJへvendorせず、必要時だけ ignored sidecar / 外部checkout で試す。
  - Source:
    - `https://github.com/NO6KIKO/gorest-2d-animation-spritesheet-generator`
    - `https://github.com/NO6KIKO/gorest-2d-animation-spritesheet-generator/blob/main/SPRITESHEET_GENERATION_POLICY.md`
  - Ecliptica rule: gorest 出力は raw material 扱い。`assets/source/` へ入れる前にレビューし、`assets/production/` へは既存の deterministic normalizer と asset tests を通して入れる。
  - Required gates:
    - player body: `node test/playerActionAssetCheck.mjs`
    - player axe: `node test/playerAxeAssetCheck.mjs`
    - enemy/boss: `node test/enemyBossAssetCheck.mjs`
    - VFX/stage: `node --test test/stageVisualAssetCheck.mjs`
    - release: `npm run release:check`
    - feel evidence: GUI 承認つき `npm run test:window-manual`

- [x] 2026-06-15 Tasks.md completion run。
  - RED 1: `node test/playerAxeAssetCheck.mjs` failed with `attack frame 4 should put visible axe pixels in the runtime hitbox's contact band, got 0`。原因は runtime hitbox が斧画像の見える到達範囲より前に出ていたこと。
  - RED 2: GUI 承認つき `npm run test:window-manual` failed because `scenario_names`, `sigil_evidence`, `boss_evidence` が未実装だった。
  - RED 3: Boss接触 evidence 追加前は `contact_damage_captured` と `window-boss-contact-damage` が未実装だった。
  - GREEN:
    - `node test/playerAxeAssetCheck.mjs`: pass。
    - `node test/playerActionAssetCheck.mjs`: pass。
    - `node --test test/stageVisualAssetCheck.mjs`: pass。
    - `npm run release:check`: pass。
    - `node --test test/manualPlayProbe.test.mjs`: pass。
    - `npm run playtest:manual`: pass。Summary: `artifacts/manual-play/20260615-130521-manual-play/summary.json`。
    - GUI 承認つき `npm run test:window-manual`: pass。Summary: `artifacts/window-manual-play/20260615-131057-window-manual/summary.json`。
    - `npm run verify:llm`: pass。
    - `npm run screenshot:showcase`: pass。Screenshot: `artifacts/showcase/showcase-room.png`。
    - `npm run test`: pass, 34 passed, 2 skipped。
    - GUI 承認つき `npm run playtest:window-manual`: pass。Summary: `artifacts/window-manual-play/20260615-131232-window-manual/summary.json`。
  - 実装:
    - `scripts/player.gd`: attack hitbox を visible axe mass に合わせて再調整し、hit spark を敵中心ではなく接触側に出すよう変更。
    - `tools/generatePlayerAxeSheets.py`: snap/impact frame に motion wake と小さな impact sparks を追加し、`assets/production/player-axe-attack-combo-sheet-24.png` と legacy root sheet を再生成。
    - `scripts/enemy.gd`: death hold を延長し、windup tell を短く低い方向tellへ調整し、`windup_direction` を meta に出す。
    - `scripts/game.gd`: nearest sigil の world glow cue を追加。
    - `scripts/window_manual_play_probe.gd`: `first_enemy`, `first_sigil`, `boss_reveal` scenario、hit spark/reaction、sigil pickup、Boss HP reveal、Boss contact damage evidence を保存。
    - `test/godotWindowManualPlay.test.mjs`, `test/playerAxeAssetCheck.mjs`, `test/godotMigration.test.mjs`, `test/llmVerify.test.mjs`: 新しい evidence / hitbox contract に更新。
  - 主要 screenshot:
    - `artifacts/window-manual-play/20260615-131057-window-manual/window-attack-active.png`
    - `artifacts/window-manual-play/20260615-131057-window-manual/window-hit-spark.png`
    - `artifacts/window-manual-play/20260615-131057-window-manual/window-next-sigil-visible.png`
    - `artifacts/window-manual-play/20260615-131057-window-manual/window-after_sigil_pickup.png`
    - `artifacts/window-manual-play/20260615-131057-window-manual/window-boss-hp-visible.png`
    - `artifacts/window-manual-play/20260615-131057-window-manual/window-boss-contact-damage.png`
  - 言えること: 実ウィンドウ evidence 上、最初の敵撃破、命中spark/敵リアクション、最初のシジルpickup、Boss HP reveal、Boss接触ダメージは保存・検証できている。斧hitboxは画像上の斧massと重なる契約でテスト化できた。
  - まだ言えないこと: 全ステージを初見で迷わず遊べる、Boss戦全体が十分楽しい、複数seed/長時間プレイで品質が安定している、とはまだ断言しない。

- [x] 2026-06-15 evidence refresh。
  - `npm run playtest:manual`: pass。
  - Summary: `artifacts/manual-play/20260615-121030-manual-play/summary.json`。
  - GUI 承認つき `npm run playtest:window-manual`: pass。
  - Summary: `artifacts/window-manual-play/20260615-121055-window-manual/summary.json`。
  - Window screenshots inspected:
    - `window-start.png`
    - `window-enemy-windup.png`
    - `window-after_movement.png`
    - `window-attack-active.png`
    - `window-hit-frame.png`
    - `window-after_attack.png`
  - Asset/animation inspection:
    - `scripts/player.gd`: attack active frames are `4,5`; axe layer uses `AXE_ATTACK_POSITION` / `AXE_ATTACK_SCALE`; hit spark currently spawns from target position plus offset.
    - `assets/manifest.yaml`: `player_attack_body`, `player_axe_attack`, `hit_spark` are separate production contracts.
  - 言えること: 最初の敵までは実ウィンドウで実入力撃破できる。HUD の Boss HP 非表示、NEXT cue、windup/hit screenshots は保存できている。
  - まだ言えないこと: 斧攻撃の body/axe/VFX が一体の攻撃として読める、命中の手応えが十分、windup が初見で危険として読める、シジル導線が十分、Boss/被弾が読みやすい、とはまだ言えない。

## Completed Baseline

- [x] Boss HP は開始直後に非表示。
- [x] HUD evidence に `boss_hp_visible`, `sigil_text`, `objective_text`, `state_text` を保存。
- [x] 実ウィンドウで attack start/active/hit frame/after attack を保存。
- [x] 通常敵 windup screenshot を保存。
- [x] 最寄り未回収シジルへの `NEXT >/<` 表示を追加。
- [x] Gate sealed 条件を `SEALED n SIGILS` として表示。
- [x] `ecliptica-playfeel-evidence` Skill を作成し、`Skill is valid!` を確認。
- [x] `weapon-vfx-quality-gate` / `pixel-action-animation` を参照し、斧攻撃 asset / animation 整備を Active Task Board に追加。
