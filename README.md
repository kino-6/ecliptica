# Ecliptica

Ecliptica は、ローグライク要素を持つ悪魔城ドラキュラ風の 2D 探索アクションゲームです。暗い森と聖堂跡を進み、区画ごとに変化する足場、報酬、危険、封印を読みながら出口を目指します。

現在の主対象は Godot 4.6 版です。旧 HTML/Canvas 版もプロトタイプとして残しています。

## 現在の状態

- Godot 4.6 で起動する 2D 横スクロール探索アクション
- シード付き `StageGenerator` による悪魔城風の 1 ステージ生成
- 1920x1080 の既定ビューポート、起動時は全画面
- 10 フレーム Idle、24 フレーム Walk の主人公スプライト
- 24 フレームの 3 段斧攻撃本体アニメーション、画像ベースの重量斧レイヤー、前方攻撃判定、訓練用ターゲット破壊
- 8 フレームの射撃本体アニメーション、6 フレーム画像ベース銃撃 VFX、時間回復する FOCUS 消費、遠距離の敵破壊
- 専用スプライトの通常敵、巡回/突進 Enemy AI、複数ヒットで倒す Boss
- クリア報酬、最大 HP 強化、次 seed/variant ステージへ進むローグライク run loop
- 初回ステージは「中級以上のアクションゲーム経験者が 2 回前後のトライでクリア」想定のバランス指標つき
- 5 段階の人間反応速度つき AI プロファイルによる headless プレイテスト
- 読みやすい寄りカメラ、HP/FOCUS バー、シジルピップ、敵接触ダメージ、被弾時ノックバックと短い無敵時間
- Godot headless E2E による起動、移動、近接/遠隔攻撃、被弾、収集、ゲート開放、勝利確認

## 必要なもの

- Godot 4.6.x
- Node.js 26.x 以上
- Python 3.14.x 以上

この環境では `godot --version` が `4.6.3.stable.official` で動作確認済みです。

## セットアップ

Node.js の依存関係はありません。Python は、プロジェクト内の YAML メタデータを読む周辺ツール用に PyYAML を使います。

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
```

この作業環境では、素の `python3` からも `import yaml` できるようにユーザー領域へ PyYAML 6.0.3 を入れています。

## 起動

標準起動は次の 1 つに統一しています。

```bash
npm run start
```

内部では `tools/runGodotGame.mjs` が `GODOT_BIN`、`godot`、`godot4`、macOS の Godot.app を順に探し、見つかった Godot 4.6.x で `--path .` を実行します。以後、手元確認の通知でもこのコマンドを標準として扱います。

Godot の場所を明示したい場合:

```bash
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot npm run start
```

ゲーム内部の論理ビューポートは既定で 1920x1080 です。起動時は全画面になり、カメラは悪魔城寄りの近い構図で、キャラクターや敵のディテールを読める倍率に寄せています。HUD の HP と FOCUS はバー、シジルはピップで表示します。画面右上には `GAME REV` と `SEED` を表示し、スクリーンショットや Headless 検証結果から同じステージを再現しやすくしています。

## 操作

- 移動: `A/D` または `←/→`
- ジャンプ: `W`、`↑`、または `Space`
- 攻撃: `J`、`K`、または `X`
- 射撃: `L`、`C`、または `V`
- リトライ: Game Over 後に `R` または `Enter`
- 次ステージ: クリア後に `N` または `Enter`

赤いシジルをすべて集めるとゲートが開きます。ステージ上の敵と訓練用ターゲットは斧攻撃や銃撃で壊せます。通常敵は巡回し、プレイヤーが近づくと短く突進します。Boss は複数回攻撃すると倒せます。銃撃は FOCUS を 1 消費し、FOCUS は時間経過で最大 3 まで回復します。敵に触れると HP が減り、短い無敵時間とノックバックが入ります。

ステージをクリアすると `blood_vial` などの run 報酬を獲得します。現在の最小実装では報酬は deterministic に選ばれ、`blood_vial` は最大 HP を 1 増やします。クリア後に次ステージへ進むと stage index、seed、variant が変わり、2 ステージ目は `moonlit_cloister` になります。

## 生成ステージ

`scripts/stage_generator.gd` が `DEFAULT_STAGE_SEED := 1337` から 1 ステージ分の城内区画、7 個のシジル、3 体の通常敵、1 体の Boss、ゴール位置を生成します。`scenes/main.tscn` には固定配置の足場や収集物を置かず、`Platforms`、`Collectibles`、`Enemies` の空コンテナへ実行時に生成します。

現在のレイアウトは `sanctuary_rogue_wing` です。入口聖域、門番ホール、下層回廊、礼拝堂枝道、納骨堂、地下下降、鐘塔ショートカット、Boss 前室、封印された nave を部屋グラフとしてつなぎます。横長の謎足場ではなく、各 room shell が床、壁、背面、扉/ショートカットの connector を持ちます。

## 初回ステージのバランス目安

現在の `DEFAULT_STAGE_SEED := 1337` は、初見で 1 回つまずいても 2 回目で突破できる程度の初回ステージを目標にしています。

- 目標クリア試行回数: 2
- リスクスコア: 8 / 10
- HP 余裕: 2 被弾分
- FOCUS 初期射撃余裕: 3 発
- 戦闘遭遇: 通常敵 3 体 + Boss 1 体
- Boss HP: 3
- 分岐チャレンジ: 2
- 縦部屋: 3
- ショートカット: 1
- 封印門: 1
- クリティカルパス部屋: 6
- 立て直し区間: 2

## Vertical Slice 操作感

今回の品質改善では、新しい武器や敵を足さず、最初の 1 部屋、通常敵 1 体、移動、ジャンプ、斧攻撃、被弾、カメラだけに絞って手触りを調整しています。

- 移動最大速度: `210 px/s`
- 地上加速 / 減速: `1180 px/s^2` / `1560 px/s^2`
- 空中加速 / 減速: `620 px/s^2` / `430 px/s^2`
- ジャンプ初速: `-620 px/s`
- 着地硬直: `0.10s`、硬直中の移動倍率 `0.42`
- 斧攻撃中の移動倍率: `0.18`
- 斧攻撃: 8 frames at `16 fps`
- Startup: frames `0-3`
- Active: frames `4-5` のみ
- Recovery: frames `6-7`
- Hitstop: 通常接触 `3 frames`、強い impact `5 frames`
- Hit feedback: 敵ノックバック、短い白フラッシュ、4 フレーム hit spark、小さな camera impulse
- Camera: 進行方向 `96 px` look-ahead、上下追従 deadzone `74 px`、hit 時 impulse `10 px`

斧攻撃の見える表現は `AxeSprite` の画像アニメーションだけで行います。`AttackArc`、`ColorRect`、単色矩形のようなデバッグ用視覚表現は、ゲーム画面上の攻撃アートとして使いません。

## ローグライク Run Loop

現在の最小 loop は `docs/roguelike-plan.md` に沿って実装しています。

- run stage index: 1 から開始し、クリア後に次ステージへ進むと増える
- run seed: 初回は `1337`、次ステージ以降は stage index に応じて変化する
- 報酬: クリア時に deterministic に 1 つ獲得する
- 能力変化: `blood_vial` で最大 HP が 3 から 4 に増える
- variant: 2 ステージ目は `moonlit_cloister`
- 今後: 手動報酬選択、呪い付き報酬、部屋パーツ差し替え、death 時の新 run を追加予定

## キャラクターアセット規格

アセットの受け入れ規格は `assets/style-bible.md`、実際に Godot が読む配置は `assets/manifest.yaml` で管理します。画像を差し替えるときは scene を直接編集せず、`assets/production/` に置いた画像と manifest entry を更新します。

- フレームサイズ: `192x384`
- ガター: 各フレーム上下左右 `12px` 以上を透明にする
- 基準位置: 人物中心 `x=96`、足元 baseline `y=344`
- Idle: `assets/production/player-idle-sheet-10.png`、10 frames
- Walk: `assets/production/player-walk-sheet-24.png`、24 frames
- Axe attack body: `assets/production/player-attack-combo-sheet-24.png`、3 steps x 8 frames
- Shoot body: `assets/production/player-shoot-sheet-8.png`、8 frames
- Shot VFX: `assets/production/player-shot-sheet-6.png`、6 frames x `160x72`
- Axe source: `assets/source/player-axe-source-key.png` から `tools/generatePlayerAxeSheets.py` で透明化、縮小、回転合成する
- Axe accessory: `assets/production/player-axe-idle-sheet-10.png`、`assets/production/player-axe-walk-sheet-24.png`、`assets/production/player-axe-attack-combo-sheet-24.png`、`assets/production/player-axe-shoot-sheet-8.png`
- Enemy: `assets/production/enemy-idle-sheet-8.png`、`assets/production/enemy-walk-sheet-12.png`、`assets/production/enemy-attack-sheet-8.png`、`192x384`
- Boss: `assets/production/boss-idle-sheet-8.png`、`256x384`
- Stage relics: `assets/production/sigil-relic.png`、`assets/production/gate-sealed.png`、`assets/production/gate-open.png`、`assets/production/training-reliquary.png`
- Godot 表示: `PlayerSprite` と `AxeSprite` の 2 つの `AnimatedSprite2D` を同期し、`idle` / `walk` / `attack1` / `attack2` / `attack3` / `shoot` を切り替える
- 攻撃表示: 斧本体は `AxeSprite` の画像ベースアクセサリだけで描画する。攻撃時は専用 8 フレームシートで構え、溜め、急加速、接触、振り抜きを表現し、`AttackArc` のような別描画オブジェクトは使わない。
- 斧攻撃設計: `docs/axe-attack-redesign.md`
- 銃撃表示: 弾は `AnimatedSprite2D` の `fly` アニメーションで描画し、銃口閃光、煙、火花、残光を 6 フレームで表現する。見える銃撃に `ColorRect` や矩形バーは使わない。
- 銃撃設計: `docs/gunshot-redesign.md`

## 開発ロードマップ

1. 1 ステージ生成: シード付き生成器で足場、シジル、ゴールを配置する
2. 探索リスク: 高台、分岐、落下復帰、任意回収の報酬を増やす
3. 戦闘基礎: 斧攻撃、敵、被弾、ノックバックを追加する
4. ローグライク性: 部屋パーツ、報酬候補、敵配置、シード選択を増やす
5. 進行ループ: ステージクリア後の獲得、強化、次ステージ導線を作る

## テスト

全テスト:

```bash
npm run test
```

Release asset check:

```bash
npm run release:check
```

`assets/manifest.yaml` の active entry が `assets/placeholder/` または `kind: placeholder` を指している場合は失敗します。実行中に placeholder が混ざる場合は画面右上に `PLACEHOLDER ASSET` と表示します。

Godot headless E2E のみ:

```bash
npm run test:e2e
```

Headless AI プレイテスト:

```bash
npm run playtest:ai
```

最初の showcase room スクリーンショット:

```bash
npm run screenshot:showcase
```

保存先は `artifacts/showcase/showcase-room.png` です。

実ウィンドウ E2E:

```bash
npm run test:window
```

E2E は Godot でメインシーンをロードし、プレイヤー移動、歩行アニメ表示、カメラ追従、生成ステージ確認、近接攻撃、銃撃、FOCUS 消費/回復、敵接触ダメージ、全シジル収集、ゲート開放、勝利状態まで確認します。

## LLM Headless 検証

LLM や自動エージェントが画面を開かずに現在のゲーム状態を検証するためのモードです。

```bash
npm run verify:llm
```

内部では Godot を headless 起動し、`scripts/llm_verify.gd` でメインシーンをロードします。検証結果は stdout に次の形式で 1 行出力されます。

```text
LLM_VERIFY_JSON {"mode":"llm_headless_verify","status":"pass",...}
```

JSON にはプロジェクト名、ビューポート、画面右上に出す game revision と display seed、生成ステージの seed、足場数、シジル数、敵数、バランス指標、カメラ追従、プレイヤー移動量、HP、被弾リスポーン、攻撃表示、startup/active/recovery のフレーム契約、hitstop、敵フラッシュ、敵ノックバック、hit spark、camera impulse、銃撃 VFX のアニメーション契約、FOCUS 消費/回復、敵/訓練用ターゲット破壊、ゲート開放、勝利状態、失敗理由の配列が含まれます。失敗時も `failures` に理由を入れて出力するため、LLM が次の修正対象を読み取りやすくなります。

## Headless AI プレイテスト

人間の反応速度を制約として持つ 5 段階の AI プロファイルで、現在の 1 ステージを headless 評価します。

```bash
npm run playtest:ai
```

出力は `AI_PLAYTEST_JSON` で始まる 1 行 JSON です。`novice`、`casual`、`adept`、`expert`、`master` の各プロファイルについて、反応速度、入力間隔、判断ミス率、クリア可否、予測クリア試行回数、移動/分岐/近接/射撃/Boss/Goal の `route_log` を出します。

既定では、実行マシンの `availableParallelism()`、空きメモリ、プロフィール数から worker 数を自動選定し、プロフィールごとに Godot headless を並列起動します。出力 JSON の `parallel` に選定された worker 数、CPU/メモリ情報、各プロフィールの実行時間が入ります。必要なら次のように上書きできます。

```bash
AI_PLAYTEST_WORKERS=2 npm run playtest:ai
```

現在の基準では、`adept` が 2 回前後でクリア、`expert` と `master` が 1 回でクリア、`novice` と `casual` は未クリアになることを期待値にしています。これは手動プレイの代替ではなく、ステージ調整時に「難易度がどの腕前層に寄ったか」を継続比較するための計器です。

## ディレクトリ

- `project.godot` - Godot プロジェクト設定
- `scenes/` - Godot シーン
- `scripts/` - GDScript
- `assets/manifest.yaml` - Godot が読むアセット manifest
- `assets/style-bible.md` - 外部制作アセットを受け入れるための画風・規格
- `assets/production/` - Godot が実際に読む production アセット
- `assets/placeholder/` - 仮素材置き場。release/check では active 使用を禁止
- `.agents/skills/weapon-vfx-quality-gate/` - 武器/VFX を画像、hitbox、hitstop、ノックバック込みで検証する Skill
- `images/` - 参照画像やプロトタイプ素材。Godot からは `.gdignore` で除外
- `src/`, `index.html` - 旧 HTML/Canvas 版
- `test/` - Node と Godot E2E テスト
- `.agents/skills/` - このプロジェクトで得た制作手順の Skill

## 注意

Godot が初回起動時に `.godot/` や `*.import` を生成します。ゲームで使う画像は `assets/production/` に置き、`assets/manifest.yaml` で差し替えてください。`images/` は参考素材置き場です。
