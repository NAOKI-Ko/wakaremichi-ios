# App Store Screenshot Plan

## Direction Lock

- Project: Wakaremichi / まいにちの分かれ道
- Primary direction: B — 世界観 × 習慣化訴求
- Supporting direction: C — 結果・自己投影訴求
- Story: 静かな世界観で惹き、1日1回の探索を見せ、結果・記録・小さな発見・共有へつなぐ。
- Target: iPhone 6.9-inch screenshot slot, portrait 1290 × 2796 px PNG, opaque.

## Final Set

| # | Role | Main copy | Supporting copy | Source screen | Final file |
|---|---|---|---|---|---|
| 1 | 世界観フック | 1日1回、霧の迷路へ | 小さな灯りをたよりに、今日の道を歩く | Fog of War中の探索画面 + HUD | `final/01-daily-fog-maze.png` |
| 2 | 探索体験 | 進んだ道が、今日の結果になる | 歩いた軌跡を、静かに振り返る | 結果画面「今日の探検結果」 | `final/02-path-becomes-result.png` |
| 3 | 結果・自己投影 | 迷い方が、あなたをそっと映す | 上手さではなく、選んだ道の傾向から | 結果画面「今日のあなたの傾向」 | `final/03-reflection-in-choices.png` |
| 4 | 習慣化・継続 | 毎日の一歩が、旅の記録になる | 歩いた日々が、少しずつ積み重なる | 旅の記録（履歴と持ち帰ったもの） | `final/04-daily-journey-record.png` |
| 5 | コレクション | 小さな発見を、少しずつ集める | 迷路から持ち帰る、八つの小さなもの | 旅の記録「持ち帰ったもの」 | `final/05-small-discoveries.png` |
| 6 | 共有 | 今日の結果を、やさしく共有 | 迷路の答えは見せず、旅の余韻だけを | アプリの共有専用カード | `final/06-gentle-sharing.png` |

## Raw-to-Final Traceability

- `raw/01-gameplay-center.png` → final 1
- `raw/03-result-trail.png` → final 2
- `raw/04-result-tendency.png` → final 3
- `raw/05-collection.png` → final 4 and 5（5は同画面の持ち帰ったもの領域を拡大）
- `raw/06-share-card.png` → final 6
- `raw/02-gameplay-goal.png`, `raw/07-traveler-picker.png`, `raw/08-result-omen.png` are retained alternatives.

## Why This Sequence

1. 霧・灯り・旅人で、説明より先に世界観を伝える。
2. 探索が単なる迷路ではなく、軌跡として結果へつながることを示す。
3. 診断を断定的に売らず、「そっと映す」という距離感で独自性を示す。
4. 1日単位の記録で習慣化価値を伝える。
5. 小さな収集動機を見せる。
6. 最後にネタバレのない共有で、体験がアプリ外へ続くことを示す。

## Truthfulness Guardrails

- すべて実装済みの実UIまたはアプリ内の共有専用Viewを使用。
- 迷路の完全構造・正解ルートは共有画像に含めない。
- 広告、課金、設定、Privacy機能は主役にしない。
- 実装されていない報酬・レアリティ・物語効果は追加しない。
- 加工は背景、余白、見出し、枠、実画面の比率維持配置に限定。

## Future Improvement

- 実機の正式提出OSで同日の「クリア済み探索」「7日以上の履歴」を再撮影し、rawをリリースビルド由来へ統一する。
- 6.9-inchの別accepted sizeや追加ローカライズが必要になった場合は、同一レイアウト比率で書き出す。
- Product Page Optimizationを行う場合は、1枚目だけ「旅人中心」と「迷路中心」でA/B比較する。
