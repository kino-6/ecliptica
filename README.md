# Ecliptica

Ecliptica は、ローグライク要素を持つ悪魔城ドラキュラ風の 2D 探索アクションゲームです。暗い森と聖堂跡を進み、区画ごとに変化する足場、報酬、危険、封印を読みながら出口を目指します。

現在の主対象は Godot 4.6 版です。旧 HTML/Canvas 版もプロトタイプとして残しています。

## 現在の状態

- Godot 4.6 で起動する 2D 横スクロール探索アクション
- シード付き `StageGenerator` による 1 ステージ生成
- 1920x1080 の既定ビューポート、起動時は全画面
- 10 フレーム Idle、24 フレーム Walk の主人公スプライト
- 18 フレームの 3 段斧攻撃本体アニメーション、8 フレームの斧スイング、前方攻撃判定、訓練用ターゲット破壊
- 8 フレームの射撃本体アニメーション、時間回復する FOCUS を消費する銃撃、前方弾、遠距離の敵破壊
- 専用スプライトの通常敵と、複数ヒットで倒す Boss
- 読みやすい寄りカメラ、HP/FOCUS バー、シジルピップ、敵接触ダメージ、被弾時リスポーン
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

```bash
godot --path .
```

別シーンを指定して検証したい場合:

```bash
godot --path . --scene res://scenes/main.tscn
```

ゲーム内部の論理ビューポートは既定で 1920x1080 です。起動時は全画面になり、カメラはプレイ中のキャラクターと足場を読みやすい倍率に寄せています。HUD の HP と FOCUS はバー、シジルはピップで表示します。

## 操作

- 移動: `A/D` または `←/→`
- ジャンプ: `W`、`↑`、または `Space`
- 攻撃: `J`、`K`、または `X`
- 射撃: `L`、`C`、または `V`

赤いシジルをすべて集めるとゲートが開きます。ステージ上の敵と訓練用ターゲットは斧攻撃や銃撃で壊せます。Boss は複数回攻撃すると倒せます。銃撃は FOCUS を 1 消費し、FOCUS は時間経過で最大 3 まで回復します。敵に触れると HP が減り、開始位置へ戻されます。

## 生成ステージ

`scripts/stage_generator.gd` が `DEFAULT_STAGE_SEED := 1337` から 1 ステージ分の足場、6 個のシジル、3 体の通常敵、1 体の Boss、ゴール位置を生成します。`scenes/main.tscn` には固定配置の足場や収集物を置かず、`Platforms`、`Collectibles`、`Enemies` の空コンテナへ実行時に生成します。

今後はこの生成器に、分岐部屋、報酬部屋、敵配置、危険地形、シード選択を足してローグライク性を広げていきます。

## キャラクターアセット規格

- フレームサイズ: `192x384`
- ガター: 各フレーム上下左右 `12px` 以上を透明にする
- 基準位置: 人物中心 `x=96`、足元 baseline `y=344`
- Idle: `assets/player-idle-sheet-10.png`、10 frames
- Walk: `assets/player-walk-sheet-24.png`、24 frames
- Axe attack body: `assets/player-attack-combo-sheet-18.png`、3 steps x 6 frames
- Shoot body: `assets/player-shoot-sheet-8.png`、8 frames
- Axe swing: `assets/axe-swing-sheet-8.png`、8 frames、`128x128`
- Godot 表示: `PlayerSprite` の単一 `AnimatedSprite2D` で `idle` / `walk` / `attack1` / `attack2` / `attack3` / `shoot` を切り替える
- 攻撃表示: `AttackArc` の別 `AnimatedSprite2D` で斧スイングを重ねる

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

Godot headless E2E のみ:

```bash
npm run test:e2e
```

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

JSON にはプロジェクト名、ビューポート、生成ステージの seed、足場数、シジル数、敵数、カメラ追従、プレイヤー移動量、HP、被弾リスポーン、攻撃表示、攻撃判定、銃撃、FOCUS 消費/回復、敵/訓練用ターゲット破壊、ゲート開放、勝利状態、失敗理由の配列が含まれます。失敗時も `failures` に理由を入れて出力するため、LLM が次の修正対象を読み取りやすくなります。

## ディレクトリ

- `project.godot` - Godot プロジェクト設定
- `scenes/` - Godot シーン
- `scripts/` - GDScript
- `assets/` - Godot が実際に使うゲームアセット
- `images/` - 参照画像やプロトタイプ素材。Godot からは `.gdignore` で除外
- `src/`, `index.html` - 旧 HTML/Canvas 版
- `test/` - Node と Godot E2E テスト
- `.agents/skills/` - このプロジェクトで得た制作手順の Skill

## 注意

Godot が初回起動時に `.godot/` や `*.import` を生成します。ゲームで使う画像は `assets/` に置いてください。`images/` は参考素材置き場です。
