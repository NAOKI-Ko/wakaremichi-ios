import Foundation

/// 迷路の中で1日1回だけ出会う、意識して選ぶ選択肢。
/// 「自分で選んだ答え」と「無意識の迷路内行動」を比較するための仕組み。
///
/// **設計原則(必ず守ること)**:
/// - 選択肢に得失(ゲーム上の有利不利)をつけない。差がつくのは解釈の
///   文章だけで、その先の展開やアイテムには一切差をつけない
/// - どの選択肢も「悪くない」ように書く。優劣が読めてしまう問い
///   (助ける/助けない、のような)は避ける
enum EventTheme: String, CaseIterable {
    case unknown   // 未知
    case past      // 過去
    case others    // 他者
    case decision  // 決断
    case loss      // 喪失
    case purpose   // 目的
}

struct EventChoice {
    let text: String
    /// 内部でだけ使う、この選択が示唆する軸。プレイヤーには見せない。
    let impliedAxis: Axis
}

struct EventDefinition {
    let id: String
    let theme: EventTheme
    let title: String
    let prompt: String
    let choices: [EventChoice]   // 必ず3つ

    /// アセット名は "EventItem" + id をキャメルケース化したもの。
    /// 新しいイベントを足すたびに対応表を更新しなくて済むよう、idから導出する。
    var imageName: String {
        "EventItem" + id.split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined()
    }
}

enum RandomEvents {

    static let library: [EventDefinition] = [
        EventDefinition(
            id: "burnt_letter",
            theme: .past,
            title: "消えかけた手紙",
            prompt: "岩の隙間に、半分だけ燃えた手紙が挟まっている。宛名は読めない。",
            choices: [
                EventChoice(text: "残った部分を読む", impliedAxis: .exploration),
                EventChoice(text: "元の場所へ戻す", impliedAxis: .caution),
                EventChoice(text: "持ち帰る", impliedAxis: .flexibility),
            ]
        ),
        EventDefinition(
            id: "another_footstep",
            theme: .others,
            title: "もう一人の足音",
            prompt: "自分のものではない足音が、少し遅れてついてくる。",
            choices: [
                EventChoice(text: "立ち止まって待つ", impliedAxis: .caution),
                EventChoice(text: "振り返らず進む", impliedAxis: .intuition),
                EventChoice(text: "違う道へ入る", impliedAxis: .flexibility),
            ]
        ),
        EventDefinition(
            id: "two_lights",
            theme: .decision,
            title: "二つの灯り",
            prompt: "片方は明るいが、もうすぐ消えそうだ。もう片方は弱いが、長く燃えそうに見える。",
            choices: [
                EventChoice(text: "明るい灯りを選ぶ", impliedAxis: .intuition),
                EventChoice(text: "長く燃える灯りを選ぶ", impliedAxis: .caution),
                EventChoice(text: "今の灯りを使い続ける", impliedAxis: .flexibility),
            ]
        ),
        EventDefinition(
            id: "old_map",
            theme: .past,
            title: "古い地図",
            prompt: "壁に貼られた地図は、今の洞窟と形が違う。",
            choices: [
                EventChoice(text: "地図を信じて進む", impliedAxis: .intuition),
                EventChoice(text: "参考にだけする", impliedAxis: .caution),
                EventChoice(text: "見なかったことにする", impliedAxis: .exploration),
            ]
        ),
        EventDefinition(
            id: "forgotten_footprint",
            theme: .loss,
            title: "忘れられた足跡",
            prompt: "誰かの足跡が、途中で消えている。",
            choices: [
                EventChoice(text: "たどってみる", impliedAxis: .exploration),
                EventChoice(text: "そのままにしておく", impliedAxis: .caution),
                EventChoice(text: "自分の足跡で上書きする", impliedAxis: .flexibility),
            ]
        ),
        EventDefinition(
            id: "distant_signal",
            theme: .purpose,
            title: "遠くの合図",
            prompt: "遠くで、小さな光が二度、点滅した。",
            choices: [
                EventChoice(text: "急いで向かう", impliedAxis: .intuition),
                EventChoice(text: "遠回りしてでも向かう", impliedAxis: .exploration),
                EventChoice(text: "見なかったことにして進む", impliedAxis: .flexibility),
            ]
        ),

        // --- ここから追加分(6個) ---

        EventDefinition(
            id: "untied_bundle",
            theme: .loss,
            title: "ほどけた包み",
            prompt: "足元に、小さな布包みが落ちている。結び目だけがほどけ、中には何かが入っていた形跡だけが残っている。",
            choices: [
                EventChoice(text: "布をたたんで、岩の上へ置く", impliedAxis: .caution),
                EventChoice(text: "包みを持って歩き、持ち主がいたら返せるようにする", impliedAxis: .exploration),
                EventChoice(text: "結び目だけを結び直し、その場へ戻す", impliedAxis: .flexibility),
            ]
        ),
        EventDefinition(
            id: "chipped_bowl",
            theme: .loss,
            title: "欠けた器",
            prompt: "洞窟の壁際に、小さな器がある。縁が少し欠けているが、水を受けるにはまだ十分そうだ。",
            choices: [
                EventChoice(text: "器をそのまま残す", impliedAxis: .caution),
                EventChoice(text: "欠けた欠片だけ持ち帰る", impliedAxis: .exploration),
                EventChoice(text: "水を一杯だけ注いでから立ち去る", impliedAxis: .flexibility),
            ]
        ),
        EventDefinition(
            id: "diverging_water_sound",
            theme: .purpose,
            title: "分かれる水音",
            prompt: "前から、水の流れる音が聞こえる。地図にはないが、少し脇へ入れば近づけそうだ。",
            choices: [
                EventChoice(text: "水音をたどってみる", impliedAxis: .exploration),
                EventChoice(text: "今の道をそのまま進む", impliedAxis: .caution),
                EventChoice(text: "少しだけ寄り道してから戻る", impliedAxis: .flexibility),
            ]
        ),
        EventDefinition(
            id: "roundabout_stairs",
            theme: .purpose,
            title: "遠回りの階段",
            prompt: "目の前には緩やかな石段がある。少し離れた場所には、階段を避ける細い通路も見えている。",
            choices: [
                EventChoice(text: "石段を上って先を目指す", impliedAxis: .caution),
                EventChoice(text: "細い通路を歩いてみる", impliedAxis: .exploration),
                EventChoice(text: "どちらにも入らず、別の分かれ道を探す", impliedAxis: .flexibility),
            ]
        ),
        EventDefinition(
            id: "still_puddle",
            theme: .decision,
            title: "静かな水たまり",
            prompt: "小さな水たまりに灯りが映っている。水面は揺れていない。",
            choices: [
                EventChoice(text: "水面をのぞき込む", impliedAxis: .exploration),
                EventChoice(text: "灯りを少し近づけてみる", impliedAxis: .intuition),
                EventChoice(text: "そのまま通り過ぎる", impliedAxis: .caution),
            ]
        ),
        EventDefinition(
            id: "carved_line",
            theme: .past,
            title: "石に刻まれた線",
            prompt: "壁に、細い一本の線が刻まれている。誰かが道を覚えるためにつけたものなのかもしれない。",
            choices: [
                EventChoice(text: "指でなぞってから進む", impliedAxis: .exploration),
                EventChoice(text: "少し離れて眺める", impliedAxis: .caution),
                EventChoice(text: "見つけたことだけ覚えて歩き出す", impliedAxis: .flexibility),
            ]
        ),
    ]

    /// 日付seedから今日のイベントを1つ選ぶ。直近7日と同じテーマは避ける。
    static func todaysEvent(dateSeed: UInt64, recentThemes: [EventTheme]) -> EventDefinition {
        let avoidThemes = Set(recentThemes.suffix(7))
        let candidates = library.filter { !avoidThemes.contains($0.theme) }
        let pool = candidates.isEmpty ? library : candidates

        var rng = SeededGenerator(seed: dateSeed ^ 0x4556_454E)   // 通常抽選とは別のずらし
        return pool[Int(rng.next() % UInt64(pool.count))]
    }
}

/// プレイヤーが実際に選んだ結果。RunLogに記録し、診断で使う。
struct EventOutcome {
    let eventID: String
    let theme: EventTheme
    let choiceText: String
    let impliedAxis: Axis
}
