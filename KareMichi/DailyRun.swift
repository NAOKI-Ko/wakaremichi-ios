import Foundation
import SwiftData

struct PlayStreakSummary: Equatable {
    let currentStreak: Int
    let longestStreak: Int
    let totalPlayDays: Int
    let lastCompletedDate: Date?

    static let empty = PlayStreakSummary(currentStreak: 0,
                                         longestStreak: 0,
                                         totalPlayDays: 0,
                                         lastCompletedDate: nil)
}

/// `DailyRun.reachedGoal` の日付だけから連続プレイ日数を復元する。
/// 日付の加減算は端末のカレンダーへ任せ、24時間差では判定しない。
enum PlayStreakCalculator {

    static func summary(completedDates: [Date],
                        asOf date: Date = Date(),
                        calendar: Calendar = .current) -> PlayStreakSummary {
        let days = Array(Set(completedDates.map {
            DailySeed.startOfDay(for: $0, calendar: calendar)
        })).sorted()

        guard let lastCompletedDate = days.last else { return .empty }

        var running = 1
        var longest = 1

        for (previous, current) in zip(days, days.dropFirst()) {
            if let expectedNextDay = calendar.date(byAdding: .day,
                                                   value: 1,
                                                   to: previous),
               calendar.isDate(current, inSameDayAs: expectedNextDay) {
                running += 1
            } else {
                running = 1
            }
            longest = max(longest, running)
        }

        let today = DailySeed.startOfDay(for: date, calendar: calendar)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
        let isStillCurrent = calendar.isDate(lastCompletedDate, inSameDayAs: today)
            || yesterday.map { calendar.isDate(lastCompletedDate, inSameDayAs: $0) } == true

        return PlayStreakSummary(currentStreak: isStillCurrent ? running : 0,
                                 longestStreak: longest,
                                 totalPlayDays: days.count,
                                 lastCompletedDate: lastCompletedDate)
    }
}

/// その日の結果を1日1件で保存する記録。
@Model
final class DailyRun {

    /// その日の0時に正規化した日付(同日判定に使う)
    var date: Date
    /// 迷路のseed。同じseedなら同じ迷路が再現できる
    var seed: Int

    var steps: Int
    var elapsedSeconds: Double
    var reachedGoal: Bool
    var exploredCellCount: Int
    var openCellCount: Int
    var chestOpened: Bool
    /// 広告視聴で探索を再開した回数。既存ストアの移行用に初期値を持つ。
    var replayCount: Int = 0
    /// 広告視聴で最初からやり直した回数。既存ストアの移行用に初期値を持つ。
    var restartCount: Int = 0
    /// 追加前のストアも軽量移行できるよう、すべて既定値を持たせる。
    var staminaRemaining: Int = 0
    var staminaMax: Int = Tuning.staminaMax
    var eventThemeRaw: String?
    var eventChoiceText: String?
    var eventImpliedAxisRaw: String?

    /// 再起動後も診断コメントを同じ根拠から再構成できるよう、
    /// 軸の算出に使った行動ログも保存する。既存ストアの軽量移行用に初期値を持つ。
    var decisionLatencies: [Double] = []
    var deadEndCount: Int = 0
    var backtrackCount: Int = 0
    var forwardCount: Int = 0

    /// 軌跡(結果画面の線画の再描画用)
    var pathXs: [Int]
    var pathYs: [Int]

    /// 前後の任意入力(スキップなら nil)
    var moodBefore: String?
    var fogFeedback: String?

    /// 選んでいた旅人
    var travelerRaw: String

    /// 算出済みの4軸(後から集計するとき再計算しなくて済むよう保存しておく)
    var axisIntuition: Double
    var axisExploration: Double
    var axisCaution: Double
    var axisFlexibility: Double

    init(date: Date,
         seed: Int,
         log: RunLog,
         axes: PlayStyleAxes,
         traveler: Traveler,
         moodBefore: MoodBefore?,
         fogFeedback: FogFeedback?) {
        self.date = date
        self.seed = seed
        self.steps = log.steps
        self.elapsedSeconds = log.elapsed
        self.reachedGoal = log.reachedGoal
        self.exploredCellCount = log.exploredCellCount
        self.openCellCount = log.openCellCount
        self.chestOpened = log.chestOpened
        self.replayCount = log.replayCount
        self.restartCount = log.restartCount
        self.staminaRemaining = log.staminaRemaining
        self.staminaMax = log.staminaMax
        self.eventThemeRaw = log.eventOutcome?.theme.rawValue
        self.eventChoiceText = log.eventOutcome?.choiceText
        self.eventImpliedAxisRaw = log.eventOutcome?.impliedAxis.rawValue
        self.decisionLatencies = log.decisionLatencies
        self.deadEndCount = log.deadEndCount
        self.backtrackCount = log.backtrackCount
        self.forwardCount = log.forwardCount
        self.pathXs = log.path.map { $0.x }
        self.pathYs = log.path.map { $0.y }
        self.moodBefore = moodBefore?.rawValue
        self.fogFeedback = fogFeedback?.rawValue
        self.travelerRaw = traveler.rawValue
        self.axisIntuition = axes.intuition
        self.axisExploration = axes.exploration
        self.axisCaution = axes.caution
        self.axisFlexibility = axes.flexibility
    }

    // MARK: - 復元

    var axes: PlayStyleAxes {
        PlayStyleAxes(intuition: axisIntuition,
                      exploration: axisExploration,
                      caution: axisCaution,
                      flexibility: axisFlexibility)
    }

    var path: [Coord] {
        zip(pathXs, pathYs).map { Coord(x: $0, y: $1) }
    }

    var traveler: Traveler {
        Traveler(rawValue: travelerRaw) ?? .wanderer
    }

    var feedback: FogFeedback? {
        fogFeedback.flatMap { FogFeedback(rawValue: $0) }
    }

    var eventTheme: EventTheme? {
        eventThemeRaw.flatMap { EventTheme(rawValue: $0) }
    }

    /// 結果画面に渡すための、保存済みデータからの復元
    var restoredLog: RunLog {
        var log = RunLog()
        log.path = path
        log.steps = steps
        log.elapsed = elapsedSeconds
        log.reachedGoal = reachedGoal
        log.exploredCellCount = exploredCellCount
        log.openCellCount = openCellCount
        log.chestOpened = chestOpened
        log.replayCount = replayCount
        log.restartCount = restartCount
        log.staminaRemaining = staminaRemaining
        log.staminaMax = staminaMax
        if let theme = eventTheme,
           let choiceText = eventChoiceText,
           let axisRaw = eventImpliedAxisRaw,
           let axis = Axis(rawValue: axisRaw) {
            log.eventOutcome = EventOutcome(eventID: "",
                                            theme: theme,
                                            choiceText: choiceText,
                                            impliedAxis: axis)
        }
        log.decisionLatencies = decisionLatencies
        log.deadEndCount = deadEndCount
        log.backtrackCount = backtrackCount
        log.forwardCount = forwardCount
        return log
    }
}

extension PlayStreakCalculator {

    /// 早抜けの記録はプレイ日に含めず、保存直前のクリアだけ任意で加える。
    static func summary(runs: [DailyRun],
                        includingCompletionAt completionDate: Date? = nil,
                        asOf date: Date = Date(),
                        calendar: Calendar = .current) -> PlayStreakSummary {
        var completedDates = runs
            .filter(\.reachedGoal)
            .map(\.date)
        if let completionDate {
            completedDates.append(completionDate)
        }
        return summary(completedDates: completedDates,
                       asOf: date,
                       calendar: calendar)
    }
}
