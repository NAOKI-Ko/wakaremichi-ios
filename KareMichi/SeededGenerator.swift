import Foundation

/// 日付から同じ迷路を再現するための、決定的な乱数生成器(SplitMix64)。
/// Swift標準のRNGはシード指定ができないため自前で持つ。
struct SeededGenerator: RandomNumberGenerator {

    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

enum DailySeed {

    /// 端末のローカル日付から seed を作る。UTCではなく端末のタイムゾーンで
    /// 「今日」が決まるので、日付が変わった瞬間に迷路も変わる。
    static func seed(for date: Date, calendar: Calendar = .current) -> UInt64 {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let y = UInt64(c.year ?? 2026)
        let m = UInt64(c.month ?? 1)
        let d = UInt64(c.day ?? 1)
        return y &* 10000 &+ m &* 100 &+ d
    }

    /// その日の0時。SwiftDataでの同日判定に使う。
    static func startOfDay(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }
}
