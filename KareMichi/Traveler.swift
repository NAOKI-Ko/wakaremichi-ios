import Foundation

/// 最初に選ぶ「連れて行く旅人」。
///
/// **重要**: 選択画面では、どの旅人がどの軸に対応するかを絶対に見せない。
/// ラベルを見せると「自分がどう見られたいか」で選ぶことになり、素の直感で
/// 選ばなくなる。見た目と佇まいだけで選ばせ、対応は内緒にしておく。
/// 数日プレイしたあとで「選んだ旅人」と「実際の傾向」を照らし合わせるのが、
/// このアプリの一番深い層の「わたしを探す」体験になる。
enum Traveler: String, CaseIterable, Identifiable {

    case wanderer   // フードの旅人 … どの軸にも寄らない
    case fox        // きつね     … 探索性
    case owl        // ふくろう   … 直感性
    case tortoise   // 甲羅を負う … 慎重性
    case bird       // 渡り鳥     … 柔軟性

    var id: String { rawValue }

    var imageName: String {
        switch self {
        case .wanderer: return "TravelerWanderer"
        case .fox:      return "TravelerFox"
        case .owl:      return "TravelerOwl"
        case .tortoise: return "TravelerTortoise"
        case .bird:     return "TravelerBird"
        }
    }

    /// 選択画面に出す名前。性格を匂わせない、見た目だけの呼び名にすること。
    var displayName: String {
        switch self {
        case .wanderer: return "ともしびの旅人"
        case .fox:      return "あかつきの旅人"
        case .owl:      return "しののめの旅人"
        case .tortoise: return "こけむす旅人"
        case .bird:     return "たそがれの旅人"
        }
    }

    /// 内部でだけ使う対応軸。UIには出さない。
    var impliedAxis: Axis? {
        switch self {
        case .wanderer: return nil
        case .fox:      return .exploration
        case .owl:      return .intuition
        case .tortoise: return .caution
        case .bird:     return .flexibility
        }
    }
}
