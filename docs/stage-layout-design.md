# Stage Layout Design

## Goal

Ecliptica のステージは、横スクロールの足場列ではなく、暗い城内を断面で探索する 2D Soulsvania/Roguelike に寄せる。

参考にするのは Salt and Sanctuary 的な、縦横に接続された城、聖域、隠し通路、ショートカット、能力/鍵による進行制御である。ただし本作は固定巨大ワールドではなく、1 run ごとに短い城内 wing を生成するローグライクとして扱う。

この設計の最重要判断は、ステージ生成を `platform list` から `room graph + architectural room modules` に変えること。プレイヤーに見えるものは「浮いた床」ではなく、床、壁、天井、扉、階段、崩れた回廊を持つ城内区画にする。

## Reference Notes

調査日: 2026-06-09

- Steam 公式ページは Salt and Sanctuary を、忘れられた都市、血に染まった地下牢、冒涜された記念碑を探索する暗い 2D action RPG として打ち出している。Ecliptica でも背景画像だけでなく、部屋そのものの形をこの文脈に合わせる。
- Game Informer の review は、Salt and Sanctuary を Dark Souls 的な進行/チェックポイントと、Castlevania 的な 2D combat/platforming/level design の中間に置いている。つまり「足場アクション」ではなく、「チェックポイントから危険な探索へ出て、ショートカットや聖域へ戻る」導線が重要。
- 複数レビューで sanctuary / shrine が fast travel、shop、blacksmith などの拠点として触れられている。Ecliptica では run が短いため、fast travel そのものより、retry 時の復帰地点、報酬選択、危険枝道から戻る安全地帯として使う。
- Spelunky generator の解説では、16 部屋のグリッドに solution path を先に通し、部屋タイプごとの出口保証で到達可能性を守っている。Ecliptica でも「全部ランダム」ではなく、まず必達経路、次に枝道、最後に装飾と敵を置く。
- PCG 研究では dungeon map、locked-door mission、enemy placement を同時に扱う例があり、部屋生成だけでなく鍵/扉/敵配置を設計者の制約に合わせて評価する必要がある。
- Two-step constructive approach のように、まず大枠の map/mission を作り、その後に詳細を配置する分離は、本作の `room graph -> room shell -> encounter` に向いている。
- 2D platformer の AI assisted level design 研究は、レベル全体の成功確率や難易度を評価する必要を述べている。Ecliptica では jump 成否だけでなく、部屋グラフ、ショートカット、戦闘遭遇、回復窓を headless 指標化する。

## Original Problem

変更前の `ROOM_LIBRARY` は名前こそ外門、階段、回廊、鐘塔だが、実体は `StaticBody2D` の横長床を複数置いていた。プレイヤー視点では「城内の部屋」ではなく、空中に浮いた石床の列に見えていた。

プレイヤー体験としての問題は、次の 3 つ。

- 城内を進んでいる感覚が弱い。
- 縦移動や分岐はあるが、部屋同士の接続やショートカットの意味が見えない。
- ローグライク要素が seed / reward に寄っており、ステージ構造そのもののリスク選択が薄い。

変更前のコード上の症状:

- `ROOM_LIBRARY[*].platform` が部屋の本体になっている。
- `_create_platform()` が `StaticBody2D` の矩形 collision とタイル sprite を直接生成している。
- `layout_style == "castle_keep"` の検証はあるが、部屋の壁、天井、扉、ショートカット接続、浮き床の有無を見ていない。
- `platform_count` が成功指標になっており、増えるほど現状の見た目が悪化しやすい。

## Design Pillars

### 1. Room First, Platform Second

床を単体の足場として生成しない。まず部屋を生成し、その中に床、壁、天井、背景窓、段差、梯子/階段、ドアを置く。

ステージの最小単位:

- `RoomShell`: 背景、左右壁、天井/床、奥行き装飾
- `Traversal`: 主床、段差、階段、梯子、落下穴、片方向ドロップ
- `Connectors`: 左右扉、上下扉、ショートカット扉、封印門
- `Encounter`: 敵、罠、回復、報酬、シジル

足場は部屋の内部構造であり、ゲーム画面に「謎の浮き床」として見えないようにする。

### 2. Salt-Like Cross Section

2D ではカメラが部屋の断面を見る。よって、階層構造は次のように表現する。

- 左右移動: 回廊、門、橋、礼拝堂 nave
- 上下移動: 階段室、梯子、崩れた床、塔の内側
- ショートカット: 内側から開く扉、落下で戻れる縦穴、封印解除後の横道
- 能力/鍵 gate: シジル門、重い格子、儀式扉、壊せる壁

単体の浮き床は原則禁止。例外は、壁や柱に接続された balcony、崩れた橋、足場である理由が視覚的に伝わる scaffold のみ。

### 3. Small Interconnected Wing

1 ステージは巨大な一本道ではなく、7-10 部屋程度の城内 wing として生成する。

基本形:

- Entrance Sanctuary
- Critical path 4-5 rooms
- Optional branch 2 rooms
- Locked/ritual gate
- Boss antechamber
- Exit gate

各 wing は一度きりの走破で完結するが、内部に小さなループを持つ。Salt and Sanctuary の巨大ワールドを、そのまま固定マップにするのではなく、短い run 単位に圧縮する。

### 4. Shortcuts as Risk Relief

ショートカットは単なる横道ではなく、失敗後の再挑戦や回収ルートを短くする報酬にする。

例:

- 上層 chapel でレバーを開くと、入口近くから boss 前室へ戻れる。
- 地下 crypt を抜けると、封印門の裏側に通じる。
- 危険な optional room には回復/報酬があるが、開通後は安全な戻り導線になる。

ローグライクでは毎回 map が変わるため、ショートカットは「地理の記憶」ではなく「今 run の地形を支配した感覚」として機能させる。

### 5. Rogue Decisions Inside the Layout

報酬選択だけでなく、ステージ構造にも run 判断を入れる。

部屋ごとに以下のタグを持たせる。

- `critical`: クリア必須
- `branch_reward`: 危険だが報酬/回復/シジルがある
- `shortcut`: 開通すると戻りが短くなる
- `locked`: key / sigil / switch が必要
- `curse`: 入ると curse が増えるが高価値報酬
- `sanctuary`: checkpoint / shop / reward choice

これにより「安全に boss へ行くか」「枝道で強化してから行くか」「curse を背負って報酬を取るか」がステージ単位の意思決定になる。

### 6. Generated, But Authored

完全ランダムな地形は採用しない。部屋は手触りと見た目を保証した authored module とし、run ごとに graph、接続、報酬、敵 budget、lock/key を差し替える。

生成するもの:

- 部屋の順序
- 枝道の有無
- shortcut の向き
- locked gate の鍵/シジル配置
- 敵 budget と elite 変化
- 報酬/呪い/回復配置

生成しないもの:

- 画面内の足場を完全ランダム配置すること
- 到達性が怪しいジャンプ幅
- 背景と無関係な collision
- 理由のない浮き床

## Proposed Stage Graph

```text
Entrance Sanctuary
  |
  v
Gatehouse Hall ---- optional: Ossuary Cache
  |                         |
  v                         v
Lower Cloister <---- shortcut lever
  |
  +--> Upper Chapel -- branch_reward / sigil
  |
  v
Crypt Descent -- locked switch -- shortcut back to Gatehouse
  |
  v
Boss Antechamber -- sanctuary-lite / recovery
  |
  v
Sealed Nave Boss
  |
  v
Exit Gate / Reward Choice
```

この graph は毎回固定ではなく、seed で以下を差し替える。

- `Upper Chapel` と `Ossuary Cache` の位置を入れ替える
- `Crypt Descent` を `Library Stack` または `Flooded Cistern` に置換する
- `shortcut lever` の位置を critical path または optional branch に置く
- `locked switch` を sigil requirement / mini encounter / curse room に変える

## Room Archetypes

### Entrance Sanctuary

- retry / reward / quiet start の部屋
- 戦闘を置かない
- 片側に sanctuary altar、反対側に gatehouse door
- 初回 run では回復と操作再確認の場所

### Gatehouse Hall

- 横長だが、壁と天井を持つ屋内ホール
- 足場ではなく床として見せる
- 初回敵 1 体、ジャンプ不要
- 入口 sanctuary から近い
- 左右どちらかに door frame を置く
- 背景はアーチ、鉄柵、低い霧

### Lower Cloister

- 低い天井、柱、奥のアーチ
- 小さな段差と遮蔽物
- 銃撃の射線を試す room
- 初期 run の安全な練習空間
- 床の下端は画面下部と接続し、浮いて見せない

### Upper Chapel

- 縦移動 room
- 枝道報酬またはシジル
- 落下で Lower Cloister に戻れる
- 失敗しても即死ではなく時間ロス
- balcony は壁と柱に接続する
- 高所に stained window / torn banner を置き、縦移動の意味を出す

### Crypt Descent

- 下方向へ進む room
- 片方向ドロップと小型敵
- 奥で switch / key を得る
- 開通後に shortcut 化
- 下層に細い通路、上層に戻り扉
- 落下復帰できる段差を置く

### Boss Antechamber

- 戦闘前の読み替え空間
- 回復、静かな床、扉演出
- boss の silhouette を遠景/扉越しに見せる

### Sealed Nave Boss

- 広いが、ただの平面ではなく柱、祭壇、壊れた階段を持つ
- boss 用に退避幅を確保する
- boss door が閉じる演出を入れられる構造にする

### Optional Ossuary Cache

- reward / curse / heal の判断部屋
- 強敵 1 体または罠 1 つ
- 入らなくてもクリア可能
- shortcut の鍵を置く候補

## Generator Model

現在の `ROOM_LIBRARY` を flat platform list から graph + room archetype に変える。

```gdscript
const STAGE_LAYOUT_STYLE := "sanctuary_rogue_wing"

const ROOM_GRAPH_RULES := {
  "min_rooms": 7,
  "max_rooms": 10,
  "critical_path_min": 5,
  "branch_min": 2,
  "shortcut_min": 1,
  "sanctuary_min": 1,
  "locked_gate_min": 1,
}

const ROOM_ARCHETYPES := {
  "gatehouse_hall": {
    "size": Vector2i(720, 420),
    "connectors": ["left", "right"],
    "floor_plan": "solid_floor",
    "encounter_budget": 1,
  },
  "upper_chapel": {
    "size": Vector2i(560, 560),
    "connectors": ["left", "down", "right_locked"],
    "floor_plan": "balcony_stack",
    "encounter_budget": 2,
  },
}

const ROOM_TEMPLATE := {
  "id": "lower_cloister",
  "archetype": "cloister",
  "grid": Vector2i(1, 0),
  "size": Vector2i(720, 420),
  "connectors": {
    "left": "door",
    "right": "door",
    "up": "stair",
  },
  "encounter_budget": 1,
  "reward_slot": "",
  "risk": 1,
}
```

生成手順:

1. seed から stage graph を作る。
2. critical path を保証する。
3. branch と shortcut を差し込む。
4. 各 room に archetype を割り当てる。
5. room shell を配置する。
6. connector が合うように room 座標を解く。
7. platform collision は room 内部の床/階段/壁から生成する。
8. sigil/enemy/reward を encounter budget で配置する。
9. headless AI で到達可能性、落下復帰、branch risk を検証する。

実装上は `Platforms` container の役割を変える。今は「見える足場」だが、今後は `Architecture` または `Rooms` に改名し、各 room shell の子に collision を持たせる。互換のため最初は `Platforms` 名を残してもよいが、summary では `platform_count` より `room_count` を主指標にする。

## Visual Direction

足場タイルを横に並べるのではなく、部屋単位で以下を描く。

- 背景壁: 暗い石、アーチ、鉄柵、破れた旗
- 床: 部屋の下端に接地した石床
- 天井/梁: 画面上部に奥行きの境界
- 接続扉: 左右/上下の遷移を明示
- 前景: 鉄柵、柱、崩れた石で room の端を隠す

当面は 2D sprite の部屋パーツでよい。最初から tilemap 完成を狙わず、`RoomShell` 用の大きめ背景画像と collision 用の見えない床を分ける。

画面構成の基準:

- Player は画面高の 16-22% 程度に見えるサイズを維持する。
- 1 画面に room の用途が分かること。床、壁、接続先が読めること。
- Boss arena 以外では、横に広すぎる空白を作らない。
- 石床 tile は床面だけに使い、空中矩形に貼らない。
- 背景画像の上に gameplay collision を置く場合も、見た目の床/壁と一致させる。

## Roguelike Metrics

E2E / AI playtest に追加したい指標:

- `room_count`
- `critical_room_count`
- `branch_room_count`
- `shortcut_count`
- `locked_connector_count`
- `sanctuary_count`
- `risk_room_count`
- `reward_room_count`
- `route_length_to_boss`
- `route_length_after_shortcut`
- `adept_clear_attempt_estimate`
- `floating_platform_count`
- `unsupported_balcony_count`
- `critical_path_reachable`
- `branch_reward_reachable`
- `boss_route_requires_optional_branch`

この指標がないと、見た目を変えても「ローグライクの判断」が増えたか分からない。

## First Implementation Slice

実装は一気に全部変えない。まず 1 stage を「部屋として読める」状態にする。

1. `docs/stage-layout-design.md` を基準設計にする。
2. `StageGenerator` に `ROOM_ARCHETYPES` と `ROOM_GRAPH_RULES` を追加する。
3. 既存の `ROOM_LIBRARY` を 7 部屋の graph に置き換える。
4. `RoomShell` node を作り、背景/壁/床/扉 visual を一体化する。
5. collision は床と壁を持つが、空中足場として見えないようにする。
6. `layout_style` を `sanctuary_rogue_wing` に変更する。
7. summary に `room_count`、`branch_room_count`、`shortcut_count`、`sanctuary_count`、`floating_platform_count` を追加する。
8. E2E で `room_count >= 7`、`shortcut_count >= 1`、`branch_room_count >= 2`、`floating_platform_count == 0` を検査する。
9. AI playtest で adept が 2 回前後で clear できるか確認する。

最初に作る 7 部屋:

1. `entrance_sanctuary`
2. `gatehouse_hall`
3. `lower_cloister`
4. `upper_chapel`
5. `crypt_descent`
6. `boss_antechamber`
7. `sealed_nave_boss`

任意 branch:

- `ossuary_cache`
- `library_stack`

次の実装で「最低限見た目が破綻しない」ため、`RoomShell` は大きめの背景 panel と接地した床を必須にする。既存の `platform-stone-tile.png` は床面 texture として残せるが、矩形 tile の羅列として使わない。

## Implementation Tasks

### Task 1: Data Contract

- `ROOM_LIBRARY` を `ROOM_ARCHETYPES` と `STAGE_GRAPH` に分ける。
- `platform` key を廃止し、`size`、`grid`、`connectors`、`floor_segments`、`wall_segments` を使う。
- summary の主指標を `platform_count` から `room_count` に移す。

### Task 2: Room Shell Rendering

- `_create_platform()` を `_create_room_shell()` に置き換える。
- `RoomBackground`、`BackWall`、`FloorVisual`、`DoorFrame`、`Collision` を room child として作る。
- 目に見える床と collision の y 座標を一致させる。

### Task 3: Connectors

- left/right door を hallway 接続として配置する。
- up/down stair を明示的な room 内構造として置く。
- shortcut door は閉状態/開状態を持たせる。

### Task 4: Rogue Placement

- critical path に必須敵を置く。
- optional branch に報酬か curse を置く。
- boss 前に sanctuary-lite または回復窓を置く。
- key/sigil は locked gate より手前の reachable room に置く。

### Task 5: Validation

- `llm_verify.gd` に `floating_platform_count == 0` を追加する。
- E2E で start -> boss antechamber -> boss gate が到達可能か確認する。
- AI playtest で branch を取る/取らない route の clear 率を比較する。

## What Not To Do

- 横長 platform を増やして「城っぽい名前」を付けるだけ。
- 背景画像の上に浮き床を置く。
- 全部の部屋を毎回ランダムにして、到達不能や不公平な jump を作る。
- ローグライクを報酬抽選だけに閉じ込める。
- Salt and Sanctuary の固定 map をコピーする。

## Sources

- Salt and Sanctuary Steam page: https://store.steampowered.com/app/283640/Salt_and_Sanctuary/
- Game Informer, "Salt and Sanctuary Review - Finding The Soul Of 2D Action": https://gameinformer.com/games/salt_and_sanctuary/b/playstation4/archive/2016/03/30/finding-the-soul-of-2d-action.aspx
- GameSpot, "Salt and Sanctuary Review": https://www.gamespot.com/reviews/salt-and-sanctuary-review/1900-6416407/
- Tinysubversions, "Spelunky Generator Lessons": https://tinysubversions.com/spelunkyGen/
- ScienceDirect, "Procedural generation of dungeons' maps and locked-door missions through an evolutionary algorithm validated with players": https://www.sciencedirect.com/science/article/pii/S0957417421004504
- PNNL, "Algorithms for Procedural Dungeon Generation": https://www.pnnl.gov/publications/algorithms-procedural-dungeon-generation
- arXiv, "Two-step Constructive Approaches for Dungeon Generation": https://arxiv.org/abs/1906.04660
- arXiv, "An Integrated Framework for AI Assisted Level Design in 2D Platformers": https://arxiv.org/abs/1804.09153
