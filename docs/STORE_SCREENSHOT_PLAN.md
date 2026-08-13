# App Store Screenshot Plan v2

## Direction Lock

- Project: Wakaremichi / まいにちの分かれ道
- Primary direction: B — 世界観 × 習慣化訴求
- Supporting direction: C — 結果・自己投影訴求
- Story: 静かな世界観で惹き、1日1回の探索を見せ、結果・記録・小さな発見・共有へつなぐ。
- Target: iPhone 6.9-inch screenshot slot, portrait 1290 × 2796 px PNG, opaque.
- State Snapshot base: `e6dc821452fc965d647f7223e9229a103d6d51e4`
- Keepsake artwork implementation: `5cb43efd4011b3fd517d93c5c5157bd87a8106cb` (APPROVED)

## Final Set

| # | Role | Main copy | Supporting copy | Source screen | Final file |
|---|---|---|---|---|---|
| 1 | 世界観フック | 1日1回、霧の迷路へ | 小さな灯りをたよりに、今日の道を歩く | Fog of War中の探索画面 + HUD | `final/01-daily-fog-maze.png` |
| 2 | 探索体験 | 進んだ道が、今日の結果になる | 歩いた軌跡を、静かに振り返る | 82歩・探索率38%の結果画面 | `final/02-path-becomes-result.png` |
| 3 | 結果・自己投影 | 迷い方が、あなたをそっと映す | 上手さではなく、選んだ道の傾向から | 4軸が判別できる傾向カード | `final/03-reflection-in-choices.png` |
| 4 | 習慣化・継続 | 毎日の一歩が、旅の記録になる | 歩いた日々が、少しずつ積み重なる | 8日分の旅の履歴 | `final/04-daily-journey-record.png` |
| 5 | コレクション | 小さな発見を、少しずつ集める | 迷路から持ち帰る、八つの小さなもの | 5/8取得済みのKeepsake shelf | `final/05-small-discoveries.png` |
| 6 | 共有 | 今日の結果を、やさしく共有 | 迷路の答えは見せず、旅の余韻だけを | 最新の共有専用カード | `final/06-gentle-sharing.png` |

## Raw-to-Final Traceability

- `raw/v2-01-gameplay.png` → final 1
- `raw/v2-02-result-trail.png` → final 2
- `raw/v2-03-tendency.png` → final 3
- `raw/v2-04-journey-history.png` → final 4
- `raw/v2-05-keepsake-shelf.png` → final 5
- `raw/v2-06-share-card.png` → final 6
- `contact-sheet-v2.png` → 6枚を順番に並べたVisual QA evidence
- v1 rawは比較・履歴用に保持し、v2の新evidenceとしては使用していない。

## v1 Review Findings and v2 Response

- 01: 大きな暗部を外し、迷路・旅人・灯りを拡大。実HUDを別の実UIクロップで保持した。
- 02: 18歩の短いfixtureを、82歩・探索率38%・複数回曲がる軌跡へ変更した。
- 03: 一本線に近いfixtureを、4方向へ面積が見える軸値へ変更した。
- 04: 同じ暗いサムネイルではなく、異なる8つの軌跡を大きく表示した。
- 05: 文字中心の旧Collectionから、実装済みKeepsake artworkと5/8 counterを主役にした。
- 06: 完成度の高かった構成を維持し、最新の結果値・Keepsakeへ再renderした。

## Why This Sequence

1. 霧・灯り・旅人で、説明より先に世界観を伝える。
2. 探索が単なる迷路ではなく、軌跡として結果へつながることを示す。
3. 診断を断定的に売らず、「そっと映す」という距離感で独自性を示す。
4. 8日分の実履歴で習慣化価値を伝える。
5. 実画像と未取得silhouetteで、小さな収集動機を見せる。
6. 最後にネタバレのない共有で、体験がアプリ外へ続くことを示す。

## Truthfulness Guardrails

- すべて実装済みの実UI、アプリ内ShareCard、deterministic fixtureのみを使用。
- 迷路の完全構造・正解ルートは共有画像に含めない。
- 広告、課金、設定、Privacy機能は主役にしない。
- 実装されていない報酬・レアリティ・物語・SNS機能は追加しない。
- 加工は背景、余白、見出し、枠、比率維持のscale/crop、控えめな光に限定。
- 05のKeepsakeはUI外へ並べず、実装済みCollection shelfをそのまま使用。

## Human Visual Gate

- App Store Screenshot v2: IMPLEMENTED / HUMAN VISUAL REVIEW PENDING
- 6枚のcopy、順序、実UIの可読性をHuman Gateで確認してから提出へ進む。
- 現時点ではFinal submission-readyとは扱わない。

## Future Improvement

- 実機の正式提出OSで同じ6状態を再撮影し、Simulator fixtureとの差を比較する。
- App Store Connectの実際の縮小プレビューでheadlineと04/05の細部可読性を確認する。
- Product Page Optimizationを行う場合は、1枚目だけ「旅人中心」と「迷路中心」でA/B比較する。
