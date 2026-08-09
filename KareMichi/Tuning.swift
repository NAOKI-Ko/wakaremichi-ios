import CoreGraphics
import Foundation

/// 手触りに関わる数値は全部ここに集めてある。調整はこのファイルだけ触れば済む。
enum Tuning {

    // MARK: - 迷路

    /// 迷路の一辺(必ず奇数にすること。偶数だとゴール地点が壁の位置に来て成立しない)
    static let mazeSize = 51

    /// 行き止まりをループに変える確率。上げるとループが増えて迷いにくくなる。
    static let braidProbability = 0.18

    // MARK: - 移動

    /// .untilJunction … 一本道は滑走し、分かれ道と行き止まりで止まる(推奨)
    /// .step           … 1スワイプ = 1マス
    static let moveStyle: MoveStyle = .untilJunction

    static let stepDuration: TimeInterval = 0.13
    static let maxStepsPerSwipe = 60
    static let swipeMinDistance: CGFloat = 18

    // MARK: - 視界(Fog of War)

    /// 現在地からこの歩数以内の通路が明るく見える(壁越しには見えない)
    static let sightSteps = 2

    /// 直線の通路を見通せる距離(マス)。「視界がふわっと広がる」の正体。
    static let corridorSight = 7

    static let fogFadeDuration: TimeInterval = 0.30
    static let alphaExploredFloor: CGFloat = 0.42
    static let alphaExploredWall: CGFloat = 0.28
    static let alphaVisible: CGFloat = 1.0

    // MARK: - カメラ

    /// 画面に一度に映るタイル数。小さいほどズームインし、視界が狭く感じる。
    static let viewportTiles = 13

    // MARK: - ハプティクス

    static let hapticsEnabled = true
    static let discoveryThreshold = 4

    // MARK: - ギミック

    static let warpFadeDuration: TimeInterval = 0.18
    static let chestRevealDuration: TimeInterval = 0.5

    // MARK: - 診断のしきい値
    //
    // ここから下はすべて**仮の数字**。実プレイのログが無い状態での推測値なので、
    // 数日ぶんのデータが溜まったら必ず分布を見て調整し直すこと。

    /// 分かれ道での平均決定時間。これより速ければ「直感的」に振れる(秒)
    static let decisionFastSeconds = 1.5
    /// これより遅ければ「熟考」に振れる(秒)
    static let decisionSlowSeconds = 6.0

    /// 柔軟性の算出で「これだけ行き止まりを踏めば満点」とみなす回数
    static let flexibilityDeadEndFull = 8.0

    /// 道しるべのレア判定: 直近7日平均との差がこれを超えたらレア枠
    static let omenRareDeviation = 0.3

    // MARK: - 音

    static let audioEnabled = true

    /// 足音を律儀に毎マス鳴らすと、長い滑走で「連打」がうるさくなるため、
    /// このマス数に1回だけ鳴らす(2 = 1マスおき)。実際に聞いて調整すること。
    static let footstepStride = 2

    // MARK: - 体力
    //
    // 「尽きたら失敗」ではなく「尽きたら早抜けと同じ扱いで自然に終わる」設計。
    // ゴールまでの実際の歩数はシミュレーションで700〜5000マスと運によって
    // 大きく振れることが分かっている(迷路が違えば桁が変わる)。この値は
    // 「運が良ければゴール+寄り道ができ、悪ければ体力切れで終わる」という
    // 日ごとの違いを生む狙いで置いた**仮の数字**。実プレイで頻繁に体力切れに
    // なりすぎる/全く切れない、という声が出たら調整すること。
    static let staminaMax = 1000

    // MARK: - 再探索・やり直し（広告）
    // 「続きを歩く」と「はじめからやり直す」が共有する、1日ぶんの仮上限。
    // 無制限にして「1日1回」の感覚を壊さないため、企画判断で調整できるようにする。
    static let maxReplaysPerDay = 2
}

enum MoveStyle {
    case step
    case untilJunction
}
