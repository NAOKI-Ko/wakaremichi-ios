import SwiftUI
import SpriteKit
import SwiftData

// MARK: - 進行状態

@Observable
final class RunCoordinator {

    enum Phase: Equatable {
        case moodInput
        case playing
        case continuePrompt
        case fogFeedback
        case resultGate
        case result
    }

    var phase: Phase = .moodInput
    var scene: MazeScene?
    var mood: MoodBefore?
    var feedback: FogFeedback?
    var log: RunLog?
    var axes: PlayStyleAxes = .neutral
    var hud: HUDSnapshot?
    /// ゴール・体力切れ・早抜けで一旦止まった時点の記録。
    var pausedLog: RunLog?
    /// ランダムイベントの選択待ち。表示中は迷路入力を止める。
    var pendingEvent: EventDefinition?
    /// 生成された迷路の自己チェックに失敗したときだけ入る
    var integrityWarning: String?

    private(set) var sessionMode: RunSessionMode = .official
    private(set) var sessionDate: Date
    private(set) var seed: UInt64
    private(set) var maze: Maze

    var isReplaySession: Bool { sessionMode == .replay }

    init(date: Date = Date()) {
        let s = DailySeed.seed(for: date)
        sessionDate = date
        seed = s
        maze = Maze.generate(seed: s)

        validateMaze()
    }

    private func validateMaze() {
        integrityWarning = nil
        // 通路が2マス幅になっていないか、ゴールに行けるかを起動時に確認する。
        // 以前の実装で「道が3マス幅に見える」不具合があったため、
        // 同じ壊れ方をしたらすぐ気づけるようにしてある。
        if let wide = maze.firstWideCorridor() {
            integrityWarning = "迷路の生成に異常があります(\(wide.x), \(wide.y) 付近で通路が2マス幅以上)"
        } else if !maze.isGoalReachable() {
            integrityWarning = "迷路の生成に異常があります(ゴールに到達できません)"
        }
    }

    /// 保存済みの公式Dailyと同じ日付・seedから、新しい一時セッションを作る。
    /// MazeGame自体を新規生成するため、位置・体力・霧・宝箱・ログは初期状態になる。
    func startReplay(seed: UInt64,
                     date: Date,
                     traveler: Traveler,
                     recentEventThemes: [EventTheme] = []) {
        sessionMode = .replay
        sessionDate = date
        self.seed = seed
        maze = Maze.generate(seed: seed)
        validateMaze()

        mood = nil
        feedback = nil
        log = nil
        axes = .neutral
        hud = nil
        pausedLog = nil
        pendingEvent = nil
        startPlaying(traveler: traveler, recentEventThemes: recentEventThemes)
    }

    /// Result Gateの複数callbackが競合しても、遷移は一度だけにする。
    func showResultFromGate() {
        guard phase == .resultGate else { return }
        phase = .result
    }

    func startPlaying(traveler: Traveler, recentEventThemes: [EventTheme] = []) {
        let game = MazeGame(maze: maze)
        let event = RandomEvents.todaysEvent(dateSeed: seed, recentThemes: recentEventThemes)
        let newScene = MazeScene(game: game, traveler: traveler, event: event)
        newScene.onPausePoint = { [weak self] log in
            guard let self else { return }
            self.pausedLog = log
            self.phase = .continuePrompt
        }
        newScene.onFinish = { [weak self] log in
            guard let self else { return }
            self.log = log
            self.axes = Diagnosis.axes(from: log)
            self.phase = .fogFeedback
        }
        newScene.onHUDUpdate = { [weak self] snapshot in
            self?.hud = snapshot
        }
        newScene.onEventTrigger = { [weak self] event in
            self?.pendingEvent = event
        }
        scene = newScene
        phase = .playing
    }
}

// MARK: - ルート

struct RootView: View {

    @AppStorage("selectedTraveler") private var travelerRaw: String = ""
    @AppStorage("hasSeenPrologue") private var hasSeenPrologue = false
    @Environment(\.modelContext) private var context
    @Query private var allRuns: [DailyRun]

    @State private var coordinator = RunCoordinator()
    @State private var store = StoreManager.shared

    private var traveler: Traveler? {
        travelerRaw.isEmpty ? nil : Traveler(rawValue: travelerRaw)
    }

    private var todaysRun: DailyRun? {
        let today = DailySeed.startOfDay(for: Date())
        return allRuns.first { DailySeed.startOfDay(for: $0.date) == today }
    }

    /// 直近の履歴(古い順、今日ぶんは除く)。
    /// 道しるべのレア判定は「今日が普段とどれだけ違うか」を見るので、
    /// 比較対象に今日を混ぜてしまうと差が薄まる。必ず除外する。
    private var recentAxes: [PlayStyleAxes] {
        let today = DailySeed.startOfDay(for: Date())
        return allRuns
            .filter { DailySeed.startOfDay(for: $0.date) < today }
            .sorted { $0.date < $1.date }
            .map(\.axes)
    }

    /// 今日を除く直近テーマ。過去7日と同じテーマを避けるために使う。
    private var recentEventThemes: [EventTheme] {
        let today = DailySeed.startOfDay(for: Date())
        return allRuns
            .filter { DailySeed.startOfDay(for: $0.date) < today }
            .sorted { $0.date < $1.date }
            .compactMap(\.eventTheme)
    }

    /// 保存直後、@Queryへ今日の記録が届く前でも節目の日数を1日少なく見せない。
    private var totalDayCount: Int {
        guard !coordinator.isReplaySession,
              case .result = coordinator.phase,
              coordinator.log != nil else {
            return allRuns.count
        }
        return todaysRun == nil ? allRuns.count + 1 : allRuns.count
    }

    /// 既存のクリア済み日だけで算出する。保存直後に `@Query` がまだ更新されて
    /// いない間は、いま完了したクリア日を一時的に加える。
    private var streakSummary: PlayStreakSummary {
        let now = Date()
        let pendingCompletionDate: Date?
        if !coordinator.isReplaySession,
           case .result = coordinator.phase,
           coordinator.log?.reachedGoal == true {
            pendingCompletionDate = now
        } else {
            pendingCompletionDate = nil
        }

        return PlayStreakCalculator.summary(runs: allRuns,
                                            includingCompletionAt: pendingCompletionDate,
                                            asOf: now)
    }

    var body: some View {
        ZStack {
            Palette.backgroundSUI.ignoresSafeArea()

            if let traveler {
                if coordinator.isReplaySession {
                    // 保存済みの今日のDailyRunより、一時Replayセッションを優先する。
                    playFlow(traveler: traveler)
                } else if coordinator.phase == .resultGate {
                    // 正式結果の保存後も、保存済み結果へショートカットせずGateを保つ。
                    playFlow(traveler: traveler)
                // 保存直後も、いま完了したプレイの結果として見せる。
                // 保存による @Query の更新を先に判定すると、その場でいきなり
                // 「今日は、もう歩きました」に置き換わってしまうため。
                } else if case .result = coordinator.phase, coordinator.log != nil {
                    playFlow(traveler: traveler)
                } else if let run = todaysRun {
                    // 今日はもう歩き終わっている
                    ResultView(log: run.restoredLog,
                               axes: run.axes,
                               feedback: run.feedback,
                               traveler: run.traveler,
                               seed: UInt64(max(run.seed, 0)),
                               recentAxes: recentAxes,
                               totalDayCount: totalDayCount,
                               currentStreak: streakSummary.currentStreak,
                               resultDate: run.date,
                               alreadyPlayed: true,
                               isReplay: false,
                               isPurchased: store.isPurchased,
                               adProvider: Ads.provider,
                               onReplay: {
                                   coordinator.startReplay(
                                       seed: UInt64(max(run.seed, 0)),
                                       date: run.date,
                                       traveler: run.traveler,
                                       recentEventThemes: recentEventThemes
                                   )
                               },
                               onClose: nil)
                } else {
                    playFlow(traveler: traveler)
                }
            } else if !hasSeenPrologue {
                PrologueView {
                    hasSeenPrologue = true
                }
            } else {
                TravelerPickerView { picked in
                    travelerRaw = picked.rawValue
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func playFlow(traveler: Traveler) -> some View {
        switch coordinator.phase {

        case .moodInput:
            MoodInputView { picked in
                coordinator.mood = picked
                coordinator.startPlaying(traveler: traveler,
                                         recentEventThemes: recentEventThemes)
            }

        case .playing:
            if let scene = coordinator.scene {
                MazePlayView(scene: scene,
                             warning: coordinator.integrityWarning,
                             hud: coordinator.hud,
                             isInputBlocked: coordinator.pendingEvent != nil)
                    .overlay {
                        if let event = coordinator.pendingEvent {
                            EventChoiceView(event: event) { index in
                                guard scene.resolveEventChoice(index: index) else { return }
                                coordinator.pendingEvent = nil
                            }
                            .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.3),
                               value: coordinator.pendingEvent != nil)
            }

        case .continuePrompt:
            if let scene = coordinator.scene, let pausedLog = coordinator.pausedLog {
                ContinuePromptView(
                    log: pausedLog,
                    remainingAdActions: StoreManager.remainingAdActions(
                        isPurchased: store.isPurchased,
                        replayCount: pausedLog.replayCount,
                        restartCount: pausedLog.restartCount
                    ),
                    isPurchased: store.isPurchased,
                    onWatchAdToContinue: {
                        if store.isPurchased {
                            guard scene.resumeAfterAd(ignoringLimit: true) else { return }
                            coordinator.pausedLog = nil
                            coordinator.phase = .playing
                            return
                        }
                        Ads.provider.showRewardedAd { success in
                            // 実広告SDKは任意のキューで完了を返し得るため、
                            // SwiftUIとSpriteKitの状態変更は必ずメインへ戻す。
                            DispatchQueue.main.async {
                                guard success, scene.resumeAfterAd() else { return }
                                coordinator.pausedLog = nil
                                coordinator.phase = .playing
                            }
                        }
                    },
                    onWatchAdToRestart: {
                        if store.isPurchased {
                            guard scene.restartAfterAd(ignoringLimit: true) else { return }
                            coordinator.pausedLog = nil
                            coordinator.phase = .playing
                            return
                        }
                        Ads.provider.showRewardedAd { success in
                            DispatchQueue.main.async {
                                guard success, scene.restartAfterAd() else { return }
                                coordinator.pausedLog = nil
                                coordinator.phase = .playing
                            }
                        }
                    },
                    onFinishHere: {
                        scene.commitFinish()
                    }
                )
            }

        case .fogFeedback:
            FogFeedbackView { picked in
                coordinator.feedback = picked
                save(traveler: traveler)
                if coordinator.log?.reachedGoal == true,
                   !coordinator.isReplaySession {
                    // 正式DailyRunはここですでに保存済み。広告成否は完了記録に影響しない。
                    coordinator.phase = .resultGate
                } else {
                    coordinator.phase = .result
                }
            }

        case .resultGate:
            ResultGateView(isPurchased: store.isPurchased,
                           adProvider: Ads.provider) {
                coordinator.showResultFromGate()
            }

        case .result:
            if let log = coordinator.log {
                ResultView(log: log,
                           axes: coordinator.axes,
                           feedback: coordinator.feedback,
                           traveler: traveler,
                           seed: coordinator.seed,
                           recentAxes: recentAxes,
                           totalDayCount: totalDayCount,
                           currentStreak: coordinator.isReplaySession
                               ? 0 : streakSummary.currentStreak,
                           resultDate: coordinator.sessionDate,
                           alreadyPlayed: false,
                           isReplay: coordinator.isReplaySession,
                           isPurchased: store.isPurchased,
                           adProvider: Ads.provider,
                           onReplay: {
                               coordinator.startReplay(
                                   seed: coordinator.seed,
                                   date: coordinator.sessionDate,
                                   traveler: traveler,
                                   recentEventThemes: recentEventThemes
                               )
                           },
                           onClose: nil)
            }
        }
    }

    private func save(traveler: Traveler) {
        guard let log = coordinator.log else { return }
        DailyRunPersistence.saveIfOfficial(mode: coordinator.sessionMode,
                                           context: context,
                                           existingRuns: allRuns,
                                           date: coordinator.sessionDate,
                                           seed: coordinator.seed,
                                           log: log,
                                           axes: coordinator.axes,
                                           traveler: traveler,
                                           moodBefore: coordinator.mood,
                                           fogFeedback: coordinator.feedback)
    }
}

// MARK: - プロローグ（初回のみ）

struct PrologueView: View {

    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image("PrologueIllustration")
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 220)
                .padding(.horizontal, 40)

            Text("""
            灯りをともす。

            ここは、夢と現実の境目にある、
            小さな洞窟。

            歩くたびに、道は静かに組み替わる。
            あなたの心に合わせて。

            正しい道はありません。
            ただ、今日のあなたが選ぶ道があるだけです。
            """)
            .font(.system(size: 15))
            .lineSpacing(10)
            .foregroundStyle(.white.opacity(0.82))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 36)

            Spacer()

            Button {
                // UIタップは音だけ。節目のハプティクスとは役割を分ける。
                GameAudio.shared.play(.uiTap)
                onContinue()
            } label: {
                Text("灯りを受け取る")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.backgroundSUI)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Palette.lampSUI, in: Capsule())
            }
            .accessibilityIdentifier("prologueContinueButton")
            .padding(.horizontal, 42)
            .padding(.bottom, 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.backgroundSUI.ignoresSafeArea())
    }
}

// MARK: - ランダムイベント

struct EventChoiceView: View {

    let event: EventDefinition
    let onChoose: (Int) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()

            VStack(spacing: 24) {
                Text(event.title)
                    .font(.system(size: 16, weight: .medium))
                    .kerning(1.5)
                    .foregroundStyle(Palette.lampSUI.opacity(0.9))

                Image(event.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 96)

                Text(event.prompt)
                    .font(.system(size: 14))
                    .lineSpacing(7)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                VStack(spacing: 10) {
                    ForEach(Array(event.choices.enumerated()), id: \.offset) { index, choice in
                        Button {
                            onChoose(index)
                        } label: {
                            Text(choice.text)
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.88))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Palette.surfaceSUI,
                                            in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("eventChoice_\(index)")
                    }
                }
                .padding(.horizontal, 30)
            }
            .padding(.vertical, 32)
            .background(Palette.backgroundSUI.opacity(0.92),
                        in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 24)
        }
        .accessibilityIdentifier("eventChoiceOverlay")
    }
}

// MARK: - 正式結果を見る前のRewarded Gate

struct ResultGateView: View {

    let isPurchased: Bool
    let adProvider: any AdProvider
    let onShowResult: () -> Void

    @State private var gate = RewardedGateState(kind: .result)

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            Image(systemName: "lightbulb.circle.fill")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(Palette.lampSUI.opacity(0.82))

            VStack(spacing: 10) {
                Text("今日の歩みを見る")
                    .font(.system(size: 19, weight: .medium))
                    .kerning(1.5)
                    .foregroundStyle(Palette.lampSUI.opacity(0.9))

                Text("歩いた道は、もう記録されています")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    requestResult()
                } label: {
                    HStack(spacing: 8) {
                        if gate.isRequestInFlight {
                            ProgressView().tint(Palette.backgroundSUI)
                        }
                        Text(gate.isRequestInFlight
                             ? "広告を読み込み中..."
                             : (isPurchased ? "結果を見る" : "広告を見て結果を見る"))
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.backgroundSUI)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Palette.lampSUI, in: Capsule())
                }
                .disabled(gate.isRequestInFlight || gate.didTransition)
                .accessibilityIdentifier("resultGateRewardButton")

                if gate.allowsResultFallback {
                    Button {
                        guard gate.useResultFallback() == .showResult else { return }
                        GameAudio.shared.play(.uiTap)
                        onShowResult()
                    } label: {
                        Text("結果を見る")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.65))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Palette.surfaceSUI, in: Capsule())
                    }
                    .accessibilityIdentifier("resultGateFallbackButton")
                }
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.backgroundSUI.ignoresSafeArea())
        .accessibilityIdentifier("resultGateView")
    }

    private func requestResult() {
        guard gate.beginRequest() else { return }
        GameAudio.shared.play(.uiTap)

        if isPurchased {
            resolve(.rewarded)
            return
        }

        adProvider.showRewardedAdIfReady { outcome in
            DispatchQueue.main.async {
                resolve(outcome)
            }
        }
    }

    private func resolve(_ outcome: RewardedAdOutcome) {
        switch gate.resolve(outcome) {
        case .showResult:
            onShowResult()
        case .none, .stay, .startReplay:
            break
        }
    }
}

// MARK: - 一時停止（続きを歩く／今日の結果を見る）

struct ContinuePromptView: View {

    let log: RunLog
    let remainingAdActions: Int
    let isPurchased: Bool
    let onWatchAdToContinue: () -> Void
    let onWatchAdToRestart: () -> Void
    let onFinishHere: () -> Void

    @State private var loadingAction: AdAction?

    private enum AdAction {
        case continueWalk
        case restart
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            Text(log.reachedGoal ? "灯りは、ここまで届きました" : "今日は、ここでひと休み")
                .font(.system(size: 19, weight: .medium))
                .kerning(1.5)
                .foregroundStyle(Palette.lampSUI.opacity(0.9))

            Text(log.reachedGoal
                 ? "このまま見るか、まだ見ぬ道を続けて歩くか"
                 : "今日はここまで見るか、もう少し歩いてみるか")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: 12) {
                if remainingAdActions > 0 {
                    adButton(
                        title: isPurchased ? "続きを歩く" : "続きを歩く（広告を見る）",
                        action: .continueWalk,
                        emphasized: true,
                        accessibilityIdentifier: "continueAfterAdButton",
                        onWatch: onWatchAdToContinue
                    )

                    adButton(
                        title: isPurchased ? "はじめからやり直す" : "はじめからやり直す（広告を見る）",
                        action: .restart,
                        emphasized: false,
                        accessibilityIdentifier: "restartAfterAdButton",
                        onWatch: onWatchAdToRestart
                    )

                    if !isPurchased {
                        Text("今日はあと\(remainingAdActions)回まで")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.35))
                            .accessibilityIdentifier("remainingReplaysText")
                    }
                }

                Button {
                    GameAudio.shared.play(.uiTap)
                    onFinishHere()
                } label: {
                    Text("今日はここまで見る")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(loadingAction == nil ? 0.6 : 0.25))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Palette.surfaceSUI, in: Capsule())
                }
                // 広告完了と結果確定が競合しないよう、読込中は片方だけに絞る。
                .disabled(loadingAction != nil)
                .accessibilityIdentifier("finishAtPauseButton")
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.backgroundSUI.ignoresSafeArea())
    }

    @ViewBuilder
    private func adButton(title: String,
                          action: AdAction,
                          emphasized: Bool,
                          accessibilityIdentifier: String,
                          onWatch: @escaping () -> Void) -> some View {
        Button {
            guard loadingAction == nil else { return }
            loadingAction = action
            // UIタップは音だけ。節目のハプティクスとは役割を分ける。
            GameAudio.shared.play(.uiTap)
            onWatch()

            // 広告失敗・途中終了時にも選び直せるようにする。
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                loadingAction = nil
            }
        } label: {
            HStack(spacing: 8) {
                if loadingAction == action {
                    ProgressView().tint(emphasized ? Palette.backgroundSUI : .white)
                }
                Text(loadingAction == action ? "広告を読み込み中..." : title)
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(emphasized ? Palette.backgroundSUI : .white.opacity(0.85))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                emphasized ? AnyShapeStyle(Palette.lampSUI) : AnyShapeStyle(Palette.surfaceSUI),
                in: Capsule()
            )
        }
        .disabled(loadingAction != nil)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

// MARK: - 旅人を選ぶ

struct TravelerPickerView: View {

    let onPick: (Traveler) -> Void
    @State private var selection: Traveler?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 26) {
            VStack(spacing: 10) {
                Text("さいしょの、ひとり")
                    .font(.system(size: 19, weight: .medium))
                    .kerning(2)
                    .foregroundStyle(Palette.lampSUI.opacity(0.9))
                Text("これから一緒に歩く旅人を選んでください")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.top, 40)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(Traveler.allCases) { traveler in
                        Button {
                            GameAudio.shared.play(.uiTap)
                            selection = traveler
                        } label: {
                            VStack(spacing: 10) {
                                Image(traveler.imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 96)
                                Text(traveler.displayName)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Palette.surfaceSUI.opacity(selection == traveler ? 1 : 0.5))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Palette.lampSUI.opacity(selection == traveler ? 0.8 : 0),
                                            lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("traveler_\(traveler.rawValue)")
                    }
                }
                .padding(.horizontal, 20)
            }

            Button {
                GameAudio.shared.play(.uiTap)
                if let selection { onPick(selection) }
            } label: {
                Text("この旅人と歩く")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.backgroundSUI)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Palette.lampSUI.opacity(selection == nil ? 0.3 : 1), in: Capsule())
            }
            .disabled(selection == nil)
            .accessibilityIdentifier("travelerConfirmButton")
            .padding(.horizontal, 42)
            .padding(.bottom, 30)
        }
    }
}

// MARK: - 探索前の気分

struct MoodInputView: View {

    let onPick: (MoodBefore?) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("今日はどんな気分?")
                .font(.system(size: 18, weight: .medium))
                .kerning(1.5)
                .foregroundStyle(Palette.lampSUI.opacity(0.9))

            VStack(spacing: 12) {
                ForEach(MoodBefore.allCases) { mood in
                    Button {
                        GameAudio.shared.play(.uiTap)
                        onPick(mood)
                    } label: {
                        Text(mood.rawValue)
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Palette.surfaceSUI, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 36)

            Spacer()

            Button {
                GameAudio.shared.play(.uiTap)
                onPick(nil)
            } label: {
                Text("こたえずに はじめる")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .accessibilityIdentifier("moodSkipButton")
            .padding(.bottom, 40)
        }
    }
}

// MARK: - 探索後の霧

struct FogFeedbackView: View {

    let onPick: (FogFeedback?) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("今日の霧は、どうでしたか?")
                .font(.system(size: 18, weight: .medium))
                .kerning(1.5)
                .foregroundStyle(Palette.lampSUI.opacity(0.9))

            VStack(spacing: 12) {
                ForEach(FogFeedback.allCases) { item in
                    Button {
                        GameAudio.shared.play(.uiTap)
                        onPick(item)
                    } label: {
                        Text(item.rawValue)
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Palette.surfaceSUI, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 36)

            Spacer()

            Button {
                GameAudio.shared.play(.uiTap)
                onPick(nil)
            } label: {
                Text("こたえずに すすむ")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .accessibilityIdentifier("fogSkipButton")
            .padding(.bottom, 40)
        }
    }
}

// MARK: - 探索画面

struct MazePlayView: View {

    let scene: MazeScene
    let warning: String?
    let hud: HUDSnapshot?
    /// イベント選択中はSpriteKitのタッチとスワイプ処理を二重に止める。
    var isInputBlocked = false

    var body: some View {
        VStack(spacing: 0) {
            // --- 常設の上部バー ---
            // 早抜けボタンをSpriteViewの外へ出し、迷路の表示領域を覆わない。
            HStack {
                Text("まいにちの分かれ道")
                    .font(.system(size: 15, weight: .medium))
                    .kerning(1.5)
                    .foregroundStyle(Palette.lampSUI.opacity(0.85))

                Spacer()

                Button {
                    GameAudio.shared.play(.uiTap)
                    scene.finishNow()
                } label: {
                    Text("ここまでにする")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Palette.surfaceSUI, in: Capsule())
                }
                .accessibilityIdentifier("finishEarlyButton")
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)
            .padding(.bottom, 4)

            Rectangle()
                .fill(Palette.lampSUI.opacity(0.12))
                .frame(height: 1)
                .padding(.horizontal, 14)

            if let warning {
                Text(warning)
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.85))
                    .padding(8)
                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // SKSceneは表示領域へ追従するため、SwiftUI側では正方形制約を重ねず、
            // 上部バーとHUDの間をすべて迷路へ渡す。
            SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .allowsHitTesting(!isInputBlocked)
                .gesture(
                    DragGesture(minimumDistance: Tuning.swipeMinDistance)
                        .onEnded { value in
                            guard !isInputBlocked else { return }
                            let t = value.translation
                            let direction: Direction
                            if abs(t.width) > abs(t.height) {
                                direction = t.width > 0 ? .right : .left
                            } else {
                                direction = t.height > 0 ? .down : .up
                            }
                            scene.receive(direction: direction)
                        }
                )
                // SpriteView自身をVStackのflexible childにすることで、112pt HUDを
                // 差し引いた残余高へ収める。GeometryReaderは計測だけを担う。
                .background {
                    GeometryReader { viewport in
                        Color.clear
                            .onAppear {
                                scene.updateViewportSize(viewport.size)
                            }
                            .onChange(of: viewport.size) { _, newSize in
                                scene.updateViewportSize(newSize)
                            }
                    }
                }

            // --- 下部HUD: 旅人・体力・ミニマップ ---
            Rectangle()
                .fill(Palette.lampSUI.opacity(0.12))
                .frame(height: 1)
                .background(Palette.surfaceSUI)

            ExplorationHUD(hud: hud)
                .frame(maxWidth: .infinity)
                .frame(height: 112)
                .background(Palette.surfaceSUI)
                // hudTextureのaspectFillが割当領域外へ描画されるとSpriteView下端を
                // 覆うため、HUDは112ptの境界で明示的に切る。
                .clipped()
                .accessibilityIdentifier("explorationHUD")
        }
    }
}

// MARK: - 下部HUD

struct ExplorationHUD: View {

    let hud: HUDSnapshot?

    var body: some View {
        HStack(spacing: 10) {
            if let hud {
                ZStack {
                    RadialGradient(colors: [Palette.lampSUI.opacity(0.20), .clear],
                                   center: .center, startRadius: 4, endRadius: 46)
                        .frame(width: 82, height: 82)
                    Image(hud.traveler.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 74, height: 74)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(hud.traveler.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .kerning(1)
                        .foregroundStyle(Palette.lampSUI.opacity(0.85))
                    StaminaGauge(remaining: hud.stamina, maximum: hud.staminaMax)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                MinimapView(hud: hud, size: 90)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(hudTexture)
        .accessibilityElement(children: .contain)
    }

    /// 床の質感を薄く敷いて、単色の背景よりも密度を出す。
    /// 新しい素材は増やさず、既存のMazeFloor画像を再利用している。
    private var hudTexture: some View {
        ZStack {
            Palette.surfaceSUI
            Image("MazeFloor")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .opacity(0.10)
                .clipped()
            Palette.surfaceSUI.opacity(0.55)
        }
    }
}

struct StaminaGauge: View {

    let remaining: Int
    let maximum: Int

    private var ratio: CGFloat {
        guard maximum > 0 else { return 0 }
        return CGFloat(remaining) / CGFloat(maximum)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("のこり \(remaining)歩")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.68))

            ProgressView(value: Double(Swift.max(0, Swift.min(remaining, maximum))),
                         total: Double(Swift.max(maximum, 1)))
                .progressViewStyle(.linear)
                .tint(ratio < 0.2 ? Color.red.opacity(0.72) : Palette.lampSUI.opacity(0.78))
                .frame(maxWidth: 120)
                .scaleEffect(y: 0.65)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("体力")
        .accessibilityValue("のこり \(remaining) 歩")
        .accessibilityIdentifier("staminaText")
    }
}

// MARK: - ミニマップ

/// 探索済み(explored)のマスだけを描く。未踏の領域は描かないので、
/// ここから迷路全体が透けて見えてしまう「霧抜け」は起きない。
struct MinimapView: View {

    let hud: HUDSnapshot
    var size: CGFloat = 90

    var body: some View {
        minimapCanvas
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("ミニマップ")
        .accessibilityIdentifier("minimap")
    }

    private var minimapCanvas: some View {
        Canvas { context, size in
            let cell = size.width / CGFloat(hud.mazeSize)

            for coord in hud.explored {
                let isWalked = hud.walked.contains(coord)
                let rect = CGRect(x: CGFloat(coord.x) * cell,
                                  y: CGFloat(coord.y) * cell,
                                  width: max(cell, 1), height: max(cell, 1))
                let color: Color = isWalked
                    ? Palette.lampSUI.opacity(0.9)
                    : Color.white.opacity(0.18)
                context.fill(Path(rect), with: .color(color))
            }

            // ゴール(見えている範囲にあるときだけ)
            if hud.explored.contains(hud.goal) {
                let gx = CGFloat(hud.goal.x) * cell
                let gy = CGFloat(hud.goal.y) * cell
                context.fill(Path(ellipseIn: CGRect(x: gx-1, y: gy-1, width: cell+2, height: cell+2)),
                            with: .color(Palette.goalSUI))
            }

            // 現在地
            let px = CGFloat(hud.player.x) * cell
            let py = CGFloat(hud.player.y) * cell
            context.fill(Path(ellipseIn: CGRect(x: px-1.5, y: py-1.5, width: cell+3, height: cell+3)),
                        with: .color(.white))
        }
        .background(Palette.backgroundSUI.opacity(0.6))
    }
}
