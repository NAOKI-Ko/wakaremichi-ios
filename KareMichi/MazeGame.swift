import Foundation

/// スワイプ1回で通るマスの1つぶん。ワープで飛んだ先だけ `arrivedByWarp` が立つ。
struct RouteStep {
    let coord: Coord
    let arrivedByWarp: Bool
}

/// 1回の探索の記録。診断はすべてこの値から計算する。
struct RunLog {
    var path: [Coord] = []
    var steps = 0
    var elapsed: TimeInterval = 0
    var reachedGoal = false
    var exploredCellCount = 0
    var openCellCount = 0
    var chestOpened = false

    /// 分かれ道で止まってから次のスワイプまでの時間
    var decisionLatencies: [TimeInterval] = []
    /// 行き止まりに入った回数
    var deadEndCount = 0
    /// 「既に見たことのあるマス」へ向かった回数
    var backtrackCount = 0
    /// 未探索のマスへ向かった回数
    var forwardCount = 0
    /// 「もう一度探索する」(広告視聴による体力回復)を使った回数
    var replayCount = 0
    /// 「はじめからやり直す」(広告視聴)を使った回数
    var restartCount = 0
    /// 終了時点の体力。体力を残した早抜け等の診断に使う。
    var staminaRemaining = 0
    var staminaMax = Tuning.staminaMax
    /// 今日のランダムイベントで選んだ結果。
    var eventOutcome: EventOutcome?
}

/// 迷路の状態を持つだけのクラス。描画は一切しない。
final class MazeGame {

    let maze: Maze

    private(set) var player: Coord
    private(set) var visible: Set<Coord> = []
    private(set) var explored: Set<Coord> = []
    private(set) var walked: Set<Coord> = []
    private(set) var path: [Coord] = []
    private(set) var steps = 0
    private(set) var openedChests: Set<Coord> = []

    /// 体力(歩いたマス数で減る)。ワープでの瞬間移動ぶんは消費しない。
    private(set) var stamina = Tuning.staminaMax
    var isExhausted: Bool { stamina <= 0 }

    /// 一度でもゴールへ着いたら、ゴールの先へ歩いてもtrueを維持する。
    private(set) var everReachedGoal = false

    /// 広告視聴で体力を回復した回数。
    private(set) var replayCount = 0
    /// 広告視聴で最初からやり直した回数。
    private(set) var restartCount = 0
    /// 「続きから」と「はじめから」は同じ1日ぶんの広告枠を共有する。
    var canUseAdAction: Bool {
        replayCount + restartCount < Tuning.maxReplaysPerDay
    }
    /// 既存コードとの意味を保つための別名。
    var canReplay: Bool { canUseAdAction }

    /// 今日のランダムイベントで選んだ結果。未選択ならnil。
    private(set) var eventOutcome: EventOutcome?

    // 診断用のログ
    private(set) var decisionLatencies: [TimeInterval] = []
    private(set) var deadEndCount = 0
    private(set) var backtrackCount = 0
    private(set) var forwardCount = 0

    /// 直近で移動が止まった時刻。次のスワイプまでの差分が「迷った時間」になる。
    private var lastStopTime: Date?
    private var startTime: Date?

    init(maze: Maze) {
        self.maze = maze
        self.player = maze.start
        self.path = [maze.start]
        self.walked = [maze.start]
        refreshVisibility()
    }

    var isCleared: Bool { player == maze.goal }

    // MARK: - 移動の計画

    /// その方向にスワイプしたとき実際に通るマスを返す。空なら壁にぶつかった。
    /// 一本道は曲がり角も自動で曲がって進み、分かれ道・行き止まり・ゴール・
    /// 未開封の宝箱で止まる。ワープに乗ると対の出口まで飛ぶ。
    func plan(direction: Direction) -> [RouteStep] {
        guard maze.isOpen(player.moved(direction)) else { return [] }

        var route: [RouteStep] = []
        var current = player
        var heading = direction

        routeLoop: while route.count < Tuning.maxStepsPerSwipe {
            let next = current.moved(heading)
            guard maze.isOpen(next) else { break }

            route.append(RouteStep(coord: next, arrivedByWarp: false))
            current = next

            if current == maze.goal { break }
            if Tuning.moveStyle == .step { break }

            if let kind = maze.gimmick(at: current) {
                if kind == .chest, !openedChests.contains(current) {
                    break routeLoop
                }
                if kind == .warp, let dest = maze.warpDestination(from: current) {
                    route.append(RouteStep(coord: dest, arrivedByWarp: true))
                    current = dest
                    if current == maze.goal { break routeLoop }

                    // ワープ直後は「来た道」が無いので全方向で判定し直す
                    let exits = Direction.allCases.filter { maze.isOpen(current.moved($0)) }
                    if exits.count == 1 {
                        heading = exits[0]
                        continue routeLoop
                    } else {
                        break routeLoop
                    }
                }
            }

            // イベント地点では、選択肢を表示するため一度止まる。
            if current == maze.eventCoord, eventOutcome == nil {
                break routeLoop
            }

            let exits = Direction.allCases.filter {
                $0 != heading.opposite && maze.isOpen(current.moved($0))
            }
            if exits.count == 1 {
                heading = exits[0]
            } else {
                break
            }
        }
        return route
    }

    // MARK: - 入力の記録

    /// スワイプが入力された瞬間に呼ぶ。迷った時間と、進んだ方向の性質を記録する。
    func noteSwipe(direction: Direction, at time: Date = Date()) {
        if startTime == nil { startTime = time }
        if let last = lastStopTime {
            decisionLatencies.append(time.timeIntervalSince(last))
        }

        // 進む先が既に見たことのあるマスか、それとも霧の中か
        let target = player.moved(direction)
        if maze.isOpen(target) {
            if explored.contains(target) {
                backtrackCount += 1
            } else {
                forwardCount += 1
            }
        }
    }

    /// 移動が止まった瞬間に呼ぶ。
    func noteStopped(at time: Date = Date()) {
        lastStopTime = time
        let exits = Direction.allCases.filter { maze.isOpen(player.moved($0)) }
        if exits.count == 1 && player != maze.start && player != maze.goal {
            deadEndCount += 1
        }
    }

    // MARK: - 移動の実行

    @discardableResult
    func advance(to cell: Coord, arrivedByWarp: Bool = false) -> (newlyVisible: Set<Coord>, chestOpened: Bool) {
        var chestOpened = false
        if maze.gimmick(at: cell) == .chest, !openedChests.contains(cell) {
            openedChests.insert(cell)
            chestOpened = true
        }
        player = cell
        path.append(cell)
        walked.insert(cell)
        steps += 1
        if !arrivedByWarp {
            stamina = max(0, stamina - 1)
        }
        if cell == maze.goal {
            everReachedGoal = true
        }
        return (refreshVisibility(), chestOpened)
    }

    /// 位置・霧・軌跡は保ったまま体力だけを満タンへ戻す。
    /// 上限到達後に外部から誤って呼ばれても状態を変えない。
    @discardableResult
    func refillStaminaForReplay(ignoringLimit: Bool = false) -> Bool {
        guard ignoringLimit || canUseAdAction else { return false }
        stamina = Tuning.staminaMax
        replayCount += 1
        lastStopTime = nil   // 広告視聴時間を判断時間へ含めない
        return true
    }

    /// 広告視聴後、今日の探索をスタート地点の状態へ巻き戻す。
    /// 位置・霧・軌跡・宝箱・ゴール到達・診断ログはリセットする一方、
    /// その日に広告枠を使った回数は引き継ぐ。
    @discardableResult
    func resetForRestart(ignoringLimit: Bool = false) -> Bool {
        guard ignoringLimit || canUseAdAction else { return false }

        player = maze.start
        visible = []
        explored = []
        walked = [maze.start]
        path = [maze.start]
        steps = 0
        openedChests = []
        stamina = Tuning.staminaMax
        everReachedGoal = false
        decisionLatencies = []
        deadEndCount = 0
        backtrackCount = 0
        forwardCount = 0
        lastStopTime = nil
        startTime = nil
        eventOutcome = nil
        restartCount += 1
        refreshVisibility()
        return true
    }

    /// イベントの選択を一度だけ記録する。不正なindexや二重選択は無視する。
    @discardableResult
    func resolveEvent(_ event: EventDefinition, choiceIndex: Int) -> Bool {
        guard eventOutcome == nil, event.choices.indices.contains(choiceIndex) else {
            return false
        }
        let choice = event.choices[choiceIndex]
        eventOutcome = EventOutcome(eventID: event.id,
                                    theme: event.theme,
                                    choiceText: choice.text,
                                    impliedAxis: choice.impliedAxis)
        return true
    }

    @discardableResult
    private func refreshVisibility() -> Set<Coord> {
        visible = computeVisible(from: player)
        let newly = visible.subtracting(explored)
        explored.formUnion(visible)
        return newly
    }

    // MARK: - 視界

    /// 壁越しには見えない。通路を伝って sightSteps 歩ぶんと、
    /// 直線の通路については corridorSight マス先まで見通せる。
    private func computeVisible(from origin: Coord) -> Set<Coord> {
        var result: Set<Coord> = [origin]

        // 1) 通路を伝った幅優先探索(近距離の広がり)
        var frontier: [(cell: Coord, dist: Int)] = [(origin, 0)]
        var seen: Set<Coord> = [origin]
        var head = 0
        while head < frontier.count {
            let cell = frontier[head].cell
            let dist = frontier[head].dist
            head += 1
            for dir in Direction.allCases {
                let next = cell.moved(dir)
                guard maze.contains(next), !seen.contains(next) else { continue }
                seen.insert(next)
                result.insert(next)                    // 壁も「見えた」ので地図に残る
                if !maze.isWall(next), dist + 1 < Tuning.sightSteps {
                    frontier.append((next, dist + 1))
                }
            }
        }

        // 2) 直線の見通し(廊下の先が奥まで見える)
        for dir in Direction.allCases {
            var cell = origin
            for _ in 0..<Tuning.corridorSight {
                let next = cell.moved(dir)
                guard maze.contains(next) else { break }
                result.insert(next)
                if maze.isWall(next) { break }
                for side in dir.perpendicular {
                    let flank = next.moved(side)
                    if maze.contains(flank) { result.insert(flank) }
                }
                cell = next
            }
        }
        return result
    }

    // MARK: - 結果

    func makeLog(endedAt: Date = Date()) -> RunLog {
        var log = RunLog()
        log.path = path
        log.steps = steps
        log.elapsed = endedAt.timeIntervalSince(startTime ?? endedAt)
        log.reachedGoal = everReachedGoal
        log.exploredCellCount = explored.filter { !maze.isWall($0) }.count
        log.openCellCount = maze.openCellCount
        log.chestOpened = !openedChests.isEmpty
        log.decisionLatencies = decisionLatencies
        log.deadEndCount = deadEndCount
        log.backtrackCount = backtrackCount
        log.forwardCount = forwardCount
        log.replayCount = replayCount
        log.restartCount = restartCount
        log.staminaRemaining = stamina
        log.staminaMax = Tuning.staminaMax
        log.eventOutcome = eventOutcome
        return log
    }
}
