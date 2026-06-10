# Roguelike Plan

## Run Loop

Ecliptica のローグライク性は、固定ステージをただ遊ぶのではなく、短い城内区画を突破するたびに報酬を得て、次の seed と variant に進む構造にする。

## 現状

- `StageGenerator` は seed を持つ
- 1 ステージの城内構造、敵、Boss、シジル、ゲートは生成される
- Game Over 後の retry は同じステージへ戻る
- clear 後に deterministic な報酬が付与され、最大 HP や curse が run に反映される
- `N` または `Enter` で次ステージへ進み、stage index、seed、variant が変わる
- 2 ステージ目以降は elite enemy / curse / reward count が StageGenerator に渡る
- `npm run playtest:ai` で novice から master までの 5 段階プロファイルに対し、adept が 2 回前後で突破する想定を確認する
- `docs/stage-layout-design.md` に沿った `sanctuary_rogue_wing` 型ステージ生成を行い、入口聖域、回廊、礼拝堂枝道、地下下降、ショートカット、Boss 前室、Boss nave を持つ部屋グラフで run 判断を作る
- E2E / headless AI で `room_count`、`branch_room_count`、`shortcut_count`、`floating_platform_count == 0`、`critical_path_reachable` を確認する

## 実装する最小スライス

完了済み。

- run stage index を持つ
- stage clear で報酬候補を作る
- 最初の実装では deterministic に 1 つ報酬を選ぶ
- 報酬 `blood_vial` は最大 HP を 1 増やす
- clear 後に `N` または `Enter` で次ステージへ進む
- 次ステージは seed と stage variant を変える
- headless 検証で報酬、能力変化、次ステージ進行を確認する

## 次に足す候補

- 2-3 択の手動報酬選択 UI
- 呪い付き高性能報酬
- 部屋 archetype / connector / spawn slot の seed ごとの差し替え
- ステージ間ショップ、回復、リスク選択
- death 時の完全新 run と meta progression
