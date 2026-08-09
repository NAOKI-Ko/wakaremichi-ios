import Foundation

// MARK: - 軸

enum Axis: String, CaseIterable {
    case intuition   // 直感性
    case exploration // 探索性
    case caution     // 慎重性
    case flexibility // 柔軟性

    var label: String {
        switch self {
        case .intuition:   return "直感性"
        case .exploration: return "探索性"
        case .caution:     return "慎重性"
        case .flexibility: return "柔軟性"
        }
    }
}

struct PlayStyleAxes {
    var intuition: Double
    var exploration: Double
    var caution: Double
    var flexibility: Double

    static let neutral = PlayStyleAxes(intuition: 0.5, exploration: 0.5,
                                       caution: 0.5, flexibility: 0.5)

    func value(_ axis: Axis) -> Double {
        switch axis {
        case .intuition:   return intuition
        case .exploration: return exploration
        case .caution:     return caution
        case .flexibility: return flexibility
        }
    }

    /// 高い順に並べた軸。同点は 直感性→探索性→慎重性→柔軟性 の順で優先する。
    var ranked: [Axis] {
        let order: [Axis] = [.intuition, .exploration, .caution, .flexibility]
        return order.enumerated()
            .sorted { lhs, rhs in
                let a = value(lhs.element), b = value(rhs.element)
                if a == b { return lhs.offset < rhs.offset }
                return a > b
            }
            .map { $0.element }
    }

    /// 既存4軸を強い順に並べた、短い性格コード。
    var personalityCode: String {
        ranked.map(\.initial).joined()
    }
}

extension Axis {
    fileprivate var initial: String {
        switch self {
        case .intuition:   return "I"
        case .exploration: return "E"
        case .caution:     return "C"
        case .flexibility: return "F"
        }
    }
}

// MARK: - 軸の算出

enum Diagnosis {

    static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(v, lo), hi)
    }

    /// **しきい値はすべて仮の数字**。実プレイのログが集まったら分布を見て調整すること。
    static func axes(from log: RunLog) -> PlayStyleAxes {

        // 直感性: 分かれ道での平均決定時間が短いほど高い
        let avgLatency: Double
        if log.decisionLatencies.isEmpty {
            avgLatency = (Tuning.decisionFastSeconds + Tuning.decisionSlowSeconds) / 2
        } else {
            avgLatency = log.decisionLatencies.reduce(0, +) / Double(log.decisionLatencies.count)
        }
        let span = Tuning.decisionSlowSeconds - Tuning.decisionFastSeconds
        let intuition = 1.0 - clamp((avgLatency - Tuning.decisionFastSeconds) / span, 0, 1)

        // 探索性: 見えた範囲の割合
        let exploration = log.openCellCount > 0
            ? clamp(Double(log.exploredCellCount) / Double(log.openCellCount), 0, 1)
            : 0

        // 慎重性: 「既に見た場所」を選んだ割合(戻って確かめる傾向)
        let choices = log.backtrackCount + log.forwardCount
        let caution = choices > 0
            ? clamp(Double(log.backtrackCount) / Double(choices), 0, 1)
            : 0

        // 柔軟性: 行き止まりを踏んでも、めげずに色々な道を試せているか
        //
        // ※この式はまだ仮説段階。「行き止まりが多い=色々試している」とも
        //   「道を覚えるのが下手」とも取れる、解釈の分かれる指標なので、
        //   実データで慎重性との相関が高すぎないか確認して見直すこと。
        let flexibility = clamp(Double(log.deadEndCount) / Tuning.flexibilityDeadEndFull, 0, 1)

        return PlayStyleAxes(intuition: intuition,
                             exploration: exploration,
                             caution: caution,
                             flexibility: flexibility)
    }
}

// MARK: - 12パターンの人格化

struct AxisPair: Hashable {
    let first: Axis
    let second: Axis
}

struct Archetype {
    let base: String
    let nuance: String
    let flavor: String

    var fullName: String { "\(base)・\(nuance)" }
}

extension Diagnosis {

    static let archetypeTable: [AxisPair: Archetype] = [
        AxisPair(first: .intuition, second: .exploration):
            Archetype(base: "風の道行き", nuance: "広く巡る",
                      flavor: "迷う前に、もう次の角を曲がっている"),
        AxisPair(first: .intuition, second: .caution):
            Archetype(base: "風の道行き", nuance: "確かめ足",
                      flavor: "決めるのは早いが、心のどこかでもう一度確かめている"),
        AxisPair(first: .intuition, second: .flexibility):
            Archetype(base: "風の道行き", nuance: "気まぐれ",
                      flavor: "同じ場所に、二度同じようには通らない"),

        AxisPair(first: .exploration, second: .intuition):
            Archetype(base: "灯りを抱く人", nuance: "身軽",
                      flavor: "迷わず、隅々まで足を伸ばしていく"),
        AxisPair(first: .exploration, second: .caution):
            Archetype(base: "灯りを抱く人", nuance: "測量士気質",
                      flavor: "一歩ずつ確かめながら、地図を塗りつぶしていく"),
        AxisPair(first: .exploration, second: .flexibility):
            Archetype(base: "灯りを抱く人", nuance: "道集め",
                      flavor: "一本の正解より、たくさんの道を知りたい"),

        AxisPair(first: .caution, second: .intuition):
            Archetype(base: "石を積む旅人", nuance: "機敏",
                      flavor: "決断は速いが、心のどこかで振り返っている"),
        AxisPair(first: .caution, second: .exploration):
            Archetype(base: "石を積む旅人", nuance: "測量家",
                      flavor: "確かめながら、少しずつ世界を広げていく"),
        AxisPair(first: .caution, second: .flexibility):
            Archetype(base: "石を積む旅人", nuance: "粘り強さ",
                      flavor: "何度躓いても、違うやり方でまた進む"),

        AxisPair(first: .flexibility, second: .intuition):
            Archetype(base: "渡り鳥", nuance: "気まぐれ",
                      flavor: "同じ道を、二度同じようには通らない"),
        AxisPair(first: .flexibility, second: .exploration):
            Archetype(base: "渡り鳥", nuance: "広い翼",
                      flavor: "あちこちに興味が向く、自由な足取り"),
        AxisPair(first: .flexibility, second: .caution):
            Archetype(base: "渡り鳥", nuance: "迷いながらも",
                      flavor: "揺れながらも、少しずつ確かなものを探している"),
    ]

    static func archetype(for axes: PlayStyleAxes) -> Archetype {
        let ranked = axes.ranked
        let key = AxisPair(first: ranked[0], second: ranked[1])
        return archetypeTable[key]
            ?? Archetype(base: "旅の途中", nuance: "",
                         flavor: "今日はまだ、形が見えてこない")
    }

    /// 直近14日で最も頻繁に1位だった軸と、その日に多かった2位の軸から
    /// 「繰り返し現れる歩き方」を返す。履歴不足なら表示しない。
    static func recurringArchetype(recentAxes: [PlayStyleAxes]) -> Archetype? {
        guard recentAxes.count >= 14 else { return nil }
        let recent = recentAxes.suffix(14)
        let order = Axis.allCases

        var dominantCounts: [Axis: Int] = [:]
        for axes in recent {
            dominantCounts[axes.ranked[0], default: 0] += 1
        }
        guard let dominant = order.enumerated().sorted(by: { lhs, rhs in
            let lhsCount = dominantCounts[lhs.element, default: 0]
            let rhsCount = dominantCounts[rhs.element, default: 0]
            return lhsCount == rhsCount ? lhs.offset < rhs.offset : lhsCount > rhsCount
        }).first?.element else { return nil }

        var secondCounts: [Axis: Int] = [:]
        for axes in recent where axes.ranked[0] == dominant {
            secondCounts[axes.ranked[1], default: 0] += 1
        }
        guard let second = order.enumerated()
            .filter({ $0.element != dominant })
            .sorted(by: { lhs, rhs in
                let lhsCount = secondCounts[lhs.element, default: 0]
                let rhsCount = secondCounts[rhs.element, default: 0]
                return lhsCount == rhsCount ? lhs.offset < rhs.offset : lhsCount > rhsCount
            })
            .first?.element else { return nil }

        return archetypeTable[AxisPair(first: dominant, second: second)]
    }
}

// MARK: - 今日のひとこと(自己申告と実際のズレ)

enum FogFeedback: String, CaseIterable, Identifiable {
    case deep    = "思ったより、霧が深かった"
    case usual   = "いつも通りの霧だった"
    case cleared = "思ったより、霧はすぐ晴れた"

    var id: String { rawValue }
}

enum MoodBefore: String, CaseIterable, Identifiable {
    case lonely  = "灯りが恋しい気分"
    case restless = "そわそわしている"
    case calm    = "おだやかな気分"
    case hurried = "急いでいる気分"

    var id: String { rawValue }
}

enum ActualDifficulty {
    case easy, normal, hard
}

// MARK: - 今日際立っていた特徴（上位3つ）

/// 結果画面へ載せる、その日に際立った行動上の特徴。
/// 全ログを列挙せず、強い特徴だけに絞って見せる。
struct BehaviorSignal {
    let magnitude: Double
    let phrase: String
}

extension Diagnosis {

    static func topSignals(log: RunLog, maxCount: Int = 3) -> [BehaviorSignal] {
        guard maxCount > 0 else { return [] }

        var signals: [(order: Int, signal: BehaviorSignal)] = []

        func append(magnitude: Double, phrase: String) {
            signals.append((signals.count,
                            BehaviorSignal(magnitude: magnitude,
                                           phrase: phrase)))
        }

        if !log.decisionLatencies.isEmpty {
            let average = log.decisionLatencies.reduce(0, +)
                / Double(log.decisionLatencies.count)
            if average < Tuning.decisionFastSeconds + 0.4 {
                append(magnitude: min(1, (Tuning.decisionFastSeconds + 1.5 - average) / 2),
                       phrase: "最初の分かれ道から、迷わず決めていました")
            } else if average > Tuning.decisionSlowSeconds - 1.2 {
                append(magnitude: min(1, (average - (Tuning.decisionSlowSeconds - 2.5)) / 2.5),
                       phrase: "一つ一つの分かれ道で、長く灯りを止めていました")
            }
        }

        let totalChoices = log.backtrackCount + log.forwardCount
        if totalChoices >= 3 {
            let forwardRatio = Double(log.forwardCount) / Double(totalChoices)
            if forwardRatio > 0.7 {
                append(magnitude: forwardRatio,
                       phrase: "見えていない方へ、よく足を向けていました")
            } else if forwardRatio < 0.3 {
                append(magnitude: 1 - forwardRatio,
                       phrase: "知っている道を、丁寧にたどっていました")
            }
        }

        if log.deadEndCount >= 5 {
            append(magnitude: min(1, Double(log.deadEndCount) / 12),
                   phrase: "道の終わりを、何度も確かめていました")
        }

        if log.chestOpened {
            append(magnitude: 0.45,
                   phrase: "目的地より先に、小さな気配へ心を向けていました")
        }

        if !log.reachedGoal,
           log.replayCount == 0,
           log.restartCount == 0,
           log.staminaMax > 0,
           Double(log.staminaRemaining) / Double(log.staminaMax) > 0.3 {
            append(magnitude: 0.55,
                   phrase: "奥ではなく、今日はここまでという場所を、自分で選んでいました")
        }

        if log.staminaRemaining <= 0 {
            append(magnitude: 0.6,
                   phrase: "灯りが尽きるまで、歩みを止めませんでした")
        }

        if log.reachedGoal {
            append(magnitude: 0.4,
                   phrase: "いくつもの道の先に、一つの終わりを見つけました")
        }

        return signals
            .sorted { lhs, rhs in
                lhs.signal.magnitude == rhs.signal.magnitude
                    ? lhs.order < rhs.order
                    : lhs.signal.magnitude > rhs.signal.magnitude
            }
            .prefix(maxCount)
            .map { $0.signal }
    }
}

extension Diagnosis {

    static func actualDifficulty(log: RunLog, axes: PlayStyleAxes) -> ActualDifficulty {
        let deadEndFactor = min(Double(log.deadEndCount) / 6.0, 1.0)
        let hardness = axes.caution * 0.6 + deadEndFactor * 0.4
        if hardness > 0.6 { return .hard }
        if hardness < 0.3 { return .easy }
        return .normal
    }

    static func comment(feedback: FogFeedback?,
                        log: RunLog,
                        axes: PlayStyleAxes) -> String {

        let actual = actualDifficulty(log: log, axes: axes)
        let base: String

        if let feedback {
            switch (feedback, actual) {
            case (.deep, .hard):
                base = "今日はたしかに、道がよく分からない一日でした。じっくり確かめながら進めていたようです。"
            case (.deep, _):
                base = "「深かった」と思っていたようですが、足取りは意外とまっすぐでした。今日はちょっと、自分に厳しかったのかもしれません。"
            case (.usual, _):
                base = "今日は、いつも通りの歩き方だったようです。それも立派な「今日らしさ」です。"
            case (.cleared, .easy):
                base = "思った通り、すいすい進めた一日でした。"
            case (.cleared, _):
                base = "「すぐ晴れた」と思っていたようですが、実は何度か立ち止まって確かめていました。気づかないうちに、慎重になっていたのかもしれません。"
            }
        } else {
            // 未回答のときは行動データだけから一言添える
            switch axes.ranked[0] {
            case .intuition:
                base = "今日の足取りは、迷いが少なかったようです。"
            case .exploration:
                base = "今日は、ずいぶん広く歩きまわっていたようです。"
            case .caution:
                base = "今日は、何度も来た道を確かめながら進んでいたようです。"
            case .flexibility:
                base = "今日は、いろいろな道を試していたようです。"
            }
        }

        guard let note = replayNote(replayCount: log.replayCount,
                                    restartCount: log.restartCount) else { return base }
        return base + "\n\n" + note
    }

    /// 両方使った日は、探索状態を手放す「はじめから」の言葉を優先する。
    private static func replayNote(replayCount: Int, restartCount: Int) -> String? {
        if restartCount >= 2 {
            return "今日は、何度も最初からやり直していました。今日という日を、何度も選び直していたのかもしれません。"
        }
        if restartCount == 1 {
            return "今日は、一度歩いた道を手放して、また最初から歩き直していました。"
        }
        switch replayCount {
        case 0:
            return nil
        case 1:
            return "今日は、もう一度この道を歩いていました。一度では、まだ足りなかったのかもしれません。"
        default:
            return "今日は、何度もこの道を歩いていました。何かを探し直していたのかもしれません。"
        }
    }
}

// MARK: - 今日の道しるべ

extension Diagnosis {

    static let commonOmens: [String] = [
        "灯り草 — 小さな光が、道の端にひっそり咲いている日",
        "北風 — 迷いを吹き払ってくれる、そんな一日",
        "静かな橋 — 立ち止まって、渡るかどうか考える日",
        "苔むした石 — ゆっくりでも、確かに進んでいる証",
        "遠い鈴の音 — どこかで誰かが、同じ道を探している",
        "満ちる月 — いつもよりよく、道が見える夜",
        "落ち葉の道しるべ — 誰かが通った跡が、そっと導いてくれる",
        "霧の切れ間 — 一瞬だけ、遠くまで見渡せた",
        "水たまりの空 — 足元に、思いがけない景色が映る日",
        "木漏れ日 — 隙間から差し込む、小さな確かさ",
        "蜘蛛の糸 — 見えないところで、道がつながっている",
        "遠雷 — 少し先で、何かが変わろうとしている",
        "朝露 — まだ誰も踏んでいない、静かな一歩",
        "風に舞う種 — 今日の選択が、どこかで芽吹くかもしれない",
        "古い切り株 — 立ち止まった場所にも、意味がある",
        "小さな足跡 — 先に誰かが、ここを歩いていた",
        "夜行性の目 — 見られている、と感じる静けさ",
        "とけかけの霜 — 昨日の迷いが、少しやわらいでいる",
        "遠くの灯台 — 目的地は、思ったより近いのかもしれない",
        "揺れる葉音 — 迷いも、悪いことばかりではない",
        "深い根 — 動かない強さも、ひとつの答え",
        "新月 — 何も見えない夜こそ、次の月が満ちていく",
        "渡し舟 — 今日は、誰かに委ねてみる日",
        "一番星 — 小さな灯りが、大きな道しるべになる",

        // ここから追加分(35種)。「小さな足跡」「朝露」は既存と題名が
        // 被ったため、意味を保ったまま別の題名に変えている。
        "水鏡のしずく — 揺れがおさまるまで、水面は何も急ぎません",
        "青い結晶 — 暗い場所ほど、小さな光は見つけやすくなります",
        "岩棚の影 — 少し身を寄せるだけで、見える景色もあります",
        "冷たい湧き水 — 手を浸すだけで十分な日もあります",
        "小さな石橋 — 渡る速さより、足を置く場所を覚えています",
        "白い鉱脈 — 壁の中にも、静かに続く道があります",
        "水滴の輪 — 一粒でも、水面はちゃんと揺れます",
        "洞窟の風穴 — 見えない風が、進む向きを教えることがあります",
        "細い石段 — 一段ずつでも、景色は変わっていきます",
        "琥珀色の雫 — 長い時間が、小さな形を残しました",
        "石灯籠 — 消えた灯りも、置かれていた場所は覚えています",
        "朝の冷気 — 深く息を吸うだけで、少し広がる道があります",
        "夜明け前 — 空が明るくなる前にも、朝は始まっています",
        "雨あがりの匂い — 見えない変化が、先に届くことがあります",
        "岩壁の模様 — 同じように見えても、近づけば少し違います",
        "細い水脈 — 大きな流れも、小さな一筋から始まります",
        "落ちた羽根 — 軽いものほど、遠くまで運ばれることがあります",
        "かすかな足跡 — 誰のものか分からなくても、道は続いています",
        "乾いた砂紋 — 風が通ったことだけは、静かに残っています",
        "星砂 — 手のひらに残るものは、思ったより少なくて十分です",
        "石の腰掛け — 少し座るだけで、道が短くなることもあります",
        "深い呼吸 — 足元より先に、心が落ち着く日があります",
        "水辺の反響 — 遠くの音も、水の近くでは少し近づきます",
        "白い小石 — 目印は、大きくなくても見つかります",
        "古い木桶 — 空になった器にも、役目は残っています",
        "岩の割れ目 — 狭い場所ほど、灯りがよく届くことがあります",
        "月白の霧 — 遠くを見るより、今見えるところを照らします",
        "水面の輪紋 — 小さな動きは、思ったより遠くまで広がります",
        "石英の欠片 — ほんの少し光るだけで、十分見つけられることがあります",
        "束の間の露 — 消えてしまうものにも、その朝だけの役目があります",
        "細い流れ — 急がなくても、水は行きたい方へ進みます",
        "静かな天井 — 見上げる時間も、旅の途中にあります",
        "灯芯 — 火ではなく、残っている芯を見る日もあります",
        "柔らかな土 — 足跡は、歩いた人だけのものではありません",
        "石の縁 — 少し外側を歩くと、違う形が見えてきます",
    ]

    static let rareOmens: [String] = [
        "見たことのない花 — 今日のあなたは、いつもと違う顔をしていました",
        "二つの月 — 今日は、いつもの自分と少し違う道を選んでいたようです",
        "逆さの虹 — たまには、こんな日があってもいい",
    ]

    /// 行動ログだけから明確に判定できる、評価を伴わない特別な文章。
    static func conditionalRareText(log: RunLog) -> String? {
        if log.reachedGoal, log.replayCount >= 1 {
            return "答えを見つけたあとも、あなたは戻りました。たどり着くことだけが、今日の目的ではなかったようです。"
        }
        if !log.reachedGoal,
           log.replayCount == 0,
           log.restartCount == 0,
           log.staminaMax > 0,
           Double(log.staminaRemaining) / Double(log.staminaMax) > 0.5 {
            return "まだ歩ける灯りを残したまま、あなたは帰る場所を決めました。進めることと、進むことは、同じではありません。"
        }
        if log.reachedGoal, log.deadEndCount >= 8 {
            return "たどり着けなかった道も、今日の軌跡には残っています。一本道では見つからなかったものを、あなたは多く持ち帰りました。"
        }
        if log.reachedGoal, log.restartCount >= 2 {
            return "何度も最初から歩き直して、それでもたどり着きました。同じ場所へ、違う道のりで帰ってきたのかもしれません。"
        }
        if log.reachedGoal, log.backtrackCount == 0, log.forwardCount >= 15 {
            return "一度も後ろを振り返らずに、たどり着きました。今日はまっすぐ前を向いていた一日でした。"
        }
        if log.chestOpened, !log.reachedGoal {
            return "小さな発見はありました。それだけで、今日は十分だったのかもしれません。"
        }
        if log.elapsed > 120,
           log.openCellCount > 0,
           Double(log.exploredCellCount) / Double(log.openCellCount) < 0.1 {
            return "同じあたりを、何度も歩いていたようです。遠くへ行くことだけが、今日の目的ではなかったのかもしれません。"
        }
        if log.eventOutcome == nil, log.reachedGoal, log.steps < 50 {
            return "今日は、誰にも何にも出会わない、静かな一本道でした。それも今日という日の形です。"
        }
        return nil
    }

    /// 直近7日の平均から大きく外れた日だけ、レア枠から引く。
    /// 履歴が7日に満たないうちは必ず通常24種から選ばれる。
    static func omen(dateSeed: UInt64,
                     axes: PlayStyleAxes,
                     recentAxes: [PlayStyleAxes],
                     log: RunLog? = nil) -> String {

        if let log, let conditional = conditionalRareText(log: log) {
            return conditional
        }

        if recentAxes.count >= 7 {
            let recent = recentAxes.suffix(7)
            let n = Double(recent.count)
            let avg = PlayStyleAxes(
                intuition: recent.reduce(0) { $0 + $1.intuition } / n,
                exploration: recent.reduce(0) { $0 + $1.exploration } / n,
                caution: recent.reduce(0) { $0 + $1.caution } / n,
                flexibility: recent.reduce(0) { $0 + $1.flexibility } / n)

            let deviations = [
                abs(axes.intuition - avg.intuition),
                abs(axes.exploration - avg.exploration),
                abs(axes.caution - avg.caution),
                abs(axes.flexibility - avg.flexibility),
            ]
            if (deviations.max() ?? 0) > Tuning.omenRareDeviation {
                var rng = SeededGenerator(seed: dateSeed ^ 0x5241_5245)
                return rareOmens.randomElement(using: &rng) ?? rareOmens[0]
            }
        }

        var rng = SeededGenerator(seed: dateSeed)
        return commonOmens.randomElement(using: &rng) ?? commonOmens[0]
    }
}

// MARK: - 旅人の選択との答え合わせ

extension Diagnosis {

    /// 選んだ旅人と、実際の傾向のズレ。履歴が3日ぶん溜まってから見せる。
    /// これがこのアプリの一番深い層の「わたしを探す」体験になる。
    static func travelerReflection(traveler: Traveler,
                                   recentAxes: [PlayStyleAxes]) -> String? {
        guard recentAxes.count >= 3, let implied = traveler.impliedAxis else { return nil }

        let n = Double(recentAxes.count)
        let avg = PlayStyleAxes(
            intuition: recentAxes.reduce(0) { $0 + $1.intuition } / n,
            exploration: recentAxes.reduce(0) { $0 + $1.exploration } / n,
            caution: recentAxes.reduce(0) { $0 + $1.caution } / n,
            flexibility: recentAxes.reduce(0) { $0 + $1.flexibility } / n)

        let dominant = avg.ranked[0]
        if dominant == implied {
            return "はじめに選んだ旅人と、これまでの歩き方は同じ方を向いているようです。"
        } else {
            return "はじめに選んだ旅人より、あなたの足取りは「\(dominant.label)」の方に寄っているようです。"
        }
    }
}

// MARK: - 直近の傾向（3〜6日の軽い比較）

extension Diagnosis {

    /// 直近3日の平均と今日を比べ、一番大きく動いた軸だけを短く返す。
    /// 7日以上の比較は鏡カードへ引き継ぐため、ここでは表示しない。
    static func recentTrend(axes: PlayStyleAxes,
                            recentAxes: [PlayStyleAxes]) -> String? {
        guard (3...6).contains(recentAxes.count) else { return nil }

        let window = recentAxes.suffix(3)
        let count = Double(window.count)
        let average = PlayStyleAxes(
            intuition: window.reduce(0) { $0 + $1.intuition } / count,
            exploration: window.reduce(0) { $0 + $1.exploration } / count,
            caution: window.reduce(0) { $0 + $1.caution } / count,
            flexibility: window.reduce(0) { $0 + $1.flexibility } / count)

        let differences: [(axis: Axis, value: Double)] = [
            (.intuition, axes.intuition - average.intuition),
            (.exploration, axes.exploration - average.exploration),
            (.caution, axes.caution - average.caution),
            (.flexibility, axes.flexibility - average.flexibility),
        ]

        guard let biggest = differences.enumerated().max(by: { lhs, rhs in
            let lhsMagnitude = abs(lhs.element.value)
            let rhsMagnitude = abs(rhs.element.value)
            return lhsMagnitude == rhsMagnitude
                ? lhs.offset > rhs.offset
                : lhsMagnitude < rhsMagnitude
        })?.element,
        abs(biggest.value) > 0.15 else {
            return nil
        }

        switch (biggest.axis, biggest.value > 0) {
        case (.intuition, true):
            return "最近は、分かれ道での決め方が、少しずつ速くなっているようです。"
        case (.intuition, false):
            return "最近は、分かれ道で立ち止まる時間が、少しずつ長くなっているようです。"
        case (.exploration, true):
            return "この数日は、見えていない道へ向かうことが増えています。"
        case (.exploration, false):
            return "この数日は、知っている道を選ぶことが増えています。"
        case (.caution, true):
            return "最近は、確かめながら進む日が続いています。"
        case (.caution, false):
            return "最近は、迷ったあとに戻るより、別の方法を試す日が続いています。"
        case (.flexibility, true):
            return "この数日は、行き止まりに出会っても、色々な道を試しているようです。"
        case (.flexibility, false):
            return "この数日は、同じような進み方をする日が続いています。"
        }
    }
}

// MARK: - 鏡（選ばなかった道）

/// 「分かれ道の洞窟」の鏡を、既存の4軸履歴だけから組み立てる。
/// 7日ぶん溜まるまでは結果画面へ出さない。
extension Diagnosis {

    static func mirrorReflection(recentAxes: [PlayStyleAxes]) -> String? {
        guard recentAxes.count >= 7 else { return nil }

        let n = Double(recentAxes.count)
        let average = PlayStyleAxes(
            intuition: recentAxes.reduce(0) { $0 + $1.intuition } / n,
            exploration: recentAxes.reduce(0) { $0 + $1.exploration } / n,
            caution: recentAxes.reduce(0) { $0 + $1.caution } / n,
            flexibility: recentAxes.reduce(0) { $0 + $1.flexibility } / n)

        // 一番低い軸を「まだ静かなままの道」として見せる。
        let quiet = average.ranked[3]

        return """
        今日、鏡が浮かび上がる。

        あなたの中で、まだ静かなままの道がある——\(quiet.label)。
        もし今日、その道を選んでいたなら、
        違う角を、違う速さで曲がっていたかもしれない。

        あなたは、間違えた道を歩いてきたのではありません。
        あなたは、あなたの道を歩いてきました。
        """
    }
}

// MARK: - 物語の断片（通算日数の節目）

/// 連続日数ではなく通算日数で解放し、休んだ日を責めない設計にする。
extension Diagnosis {

    static let storyFragments: [(day: Int, text: String)] = [
        (3, "灯りは、思っていたより静かだった。"),
        (7, "同じ角を、もう何度も曲がっている。それでも、景色はいつも少し違う。"),
        (14, "道は、誰かが用意したものではないと、そろそろ分かってきた。"),
        (21, "洞窟は、何も言わない。ただ、今日の分かれ道を用意している。"),
        (30, "正しい道は、どこにもなかった。あったのは、あなたの道だけだった。"),
    ]

    static func storyFragment(totalDayCount: Int) -> String? {
        storyFragments.first { $0.day == totalDayCount }?.text
    }
}

// MARK: - 心の分かれ道

extension Diagnosis {

    /// 意識して選んだ答えと、迷路内で最も強く出た軸を比較する。
    /// 一致・不一致のどちらにも優劣はつけない。
    static func eventReflection(outcome: EventOutcome?, axes: PlayStyleAxes) -> String? {
        guard let outcome else { return nil }
        let actualDominant = axes.ranked[0]

        if actualDominant == outcome.impliedAxis {
            return """
            「\(outcome.choiceText)」を選びました。
            実際の旅でも、\(actualDominant.label)に近い歩き方をしていたようです。

            今日は、自分でも感じていたことと、歩き方がよく重なっていました。
            """
        }
        return """
        「\(outcome.choiceText)」を選びました。
        けれど実際の旅では、\(actualDominant.label)の方に近い歩き方をしていたようです。

        頭で選んだことと、足が向かった先は、いつも同じとは限らないのかもしれません。
        """
    }
}
