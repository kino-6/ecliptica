# Roguelike Plan

## Run Loop

Ecliptica のローグライク性は、固定ステージをただ遊ぶのではなく、短い城内区画を突破するたびに報酬を得て、次の seed と variant に進む構造にする。

## 現状

- `StageGenerator` は seed を持つ
- 1 ステージの城内構造、敵、Boss、シジル、ゲートは生成される
- Game Over 後の retry は同じステージへ戻る

まだ足りなかったものは、run の進行、報酬、次ステージへの導線、報酬が実際に能力へ反映される仕組み。

## 実装する最小スライス

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
- 部屋パーツの seed ごとの差し替え
- ステージ間ショップ、回復、リスク選択
- death 時の完全新 run と meta progression
