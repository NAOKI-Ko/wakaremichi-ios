import Foundation

struct Coord: Hashable {
    var x: Int
    var y: Int

    func moved(_ d: Direction) -> Coord {
        Coord(x: x + d.dx, y: y + d.dy)
    }
}

enum Direction: CaseIterable {
    case up, down, left, right

    var dx: Int {
        switch self {
        case .left:  return -1
        case .right: return 1
        case .up, .down: return 0
        }
    }

    var dy: Int {
        switch self {
        case .up:   return -1   // 配列の行番号が小さいほど上
        case .down: return 1
        case .left, .right: return 0
        }
    }

    var opposite: Direction {
        switch self {
        case .up:    return .down
        case .down:  return .up
        case .left:  return .right
        case .right: return .left
        }
    }

    var perpendicular: [Direction] {
        switch self {
        case .up, .down:    return [.left, .right]
        case .left, .right: return [.up, .down]
        }
    }
}

enum GimmickKind {
    case chest
    case warp
}

struct Maze {

    let width: Int
    let height: Int
    let start: Coord
    let goal: Coord

    private let walls: [[Bool]]
    private let gimmicks: [Coord: GimmickKind]
    private let warpPartner: [Coord: Coord]
    /// ランダムイベントの発生場所。既存ギミックの描画とは別枠で扱う。
    let eventCoord: Coord?

    let openCellCount: Int

    // MARK: - 照会

    func contains(_ c: Coord) -> Bool {
        c.x >= 0 && c.y >= 0 && c.x < width && c.y < height
    }

    func isWall(_ c: Coord) -> Bool {
        guard contains(c) else { return true }
        return walls[c.y][c.x]
    }

    func isOpen(_ c: Coord) -> Bool {
        contains(c) && !walls[c.y][c.x]
    }

    func gimmick(at c: Coord) -> GimmickKind? { gimmicks[c] }

    func warpDestination(from c: Coord) -> Coord? { warpPartner[c] }

    // MARK: - 生成

    /// 日付seedから迷路を作る。同じseedなら必ず同じ迷路になる。
    ///
    /// 再帰バックトラッカーを **明示的なスタックによる反復処理** で実装している。
    /// 51x51では再帰の深さが最大386に達することを事前に計測しており、
    /// 再帰のまま書くとスタックオーバーフローのリスクがあるため。
    static func generate(seed: UInt64,
                         size: Int = Tuning.mazeSize,
                         braid: Double = Tuning.braidProbability) -> Maze {

        precondition(size % 2 == 1, "迷路の一辺は奇数でなければならない")

        var rng = SeededGenerator(seed: seed)
        var wall = Array(repeating: Array(repeating: true, count: size), count: size)

        // --- 1. 通路を掘る(反復バックトラッカー) ---
        var stack: [Coord] = [Coord(x: 1, y: 1)]
        wall[1][1] = false

        while let current = stack.last {
            var jumps = [(2, 0), (-2, 0), (0, 2), (0, -2)]
            jumps.shuffle(using: &rng)

            var moved = false
            for (dx, dy) in jumps {
                let nx = current.x + dx
                let ny = current.y + dy
                guard nx >= 1, nx < size - 1, ny >= 1, ny < size - 1 else { continue }
                guard wall[ny][nx] else { continue }

                wall[current.y + dy / 2][current.x + dx / 2] = false   // 間の壁を壊す
                wall[ny][nx] = false
                stack.append(Coord(x: nx, y: ny))
                moved = true
                break
            }
            if !moved { stack.removeLast() }
        }

        // --- 2. braid: 行き止まりを一定確率でループに変える ---
        for y in 1..<(size - 1) {
            for x in 1..<(size - 1) {
                guard !wall[y][x] else { continue }
                let openNeighbors = Direction.allCases.filter { !wall[y + $0.dy][x + $0.dx] }.count
                guard openNeighbors == 1 else { continue }
                guard Double.random(in: 0..<1, using: &rng) < braid else { continue }

                let candidates = Direction.allCases.filter { d in
                    let nx = x + d.dx, ny = y + d.dy
                    return nx >= 1 && nx < size - 1 && ny >= 1 && ny < size - 1 && wall[ny][nx]
                }
                if let pick = candidates.randomElement(using: &rng) {
                    wall[y + pick.dy][x + pick.dx] = false
                }
            }
        }

        let start = Coord(x: 1, y: 1)
        let goal = Coord(x: size - 2, y: size - 2)

        // --- 3. ギミックの自動配置 ---
        let placement = Self.placeGimmicks(wall: wall, size: size, start: start, goal: goal, rng: &rng)

        let openCount = wall.reduce(0) { $0 + $1.filter { !$0 }.count }

        return Maze(width: size,
                    height: size,
                    start: start,
                    goal: goal,
                    walls: wall,
                    gimmicks: placement.gimmicks,
                    warpPartner: placement.partners,
                    eventCoord: placement.event,
                    openCellCount: openCount)
    }

    // MARK: - ギミック配置

    private struct Placement {
        var gimmicks: [Coord: GimmickKind]
        var partners: [Coord: Coord]
        var event: Coord?
    }

    private static func placeGimmicks(wall: [[Bool]],
                                      size: Int,
                                      start: Coord,
                                      goal: Coord,
                                      rng: inout SeededGenerator) -> Placement {

        func open(_ c: Coord) -> Bool {
            c.x >= 0 && c.y >= 0 && c.x < size && c.y < size && !wall[c.y][c.x]
        }

        // スタートからの距離
        var dist: [Coord: Int] = [start: 0]
        var queue: [Coord] = [start]
        var head = 0
        while head < queue.count {
            let c = queue[head]; head += 1
            for d in Direction.allCases {
                let n = c.moved(d)
                guard open(n), dist[n] == nil else { continue }
                dist[n] = dist[c]! + 1
                queue.append(n)
            }
        }

        // 行き止まり(隣接する通路が1つだけ)を距離順に集める
        var deadEnds: [Coord] = []
        for y in 1..<(size - 1) {
            for x in 1..<(size - 1) {
                let c = Coord(x: x, y: y)
                guard open(c), c != start, c != goal, dist[c] != nil else { continue }
                let degree = Direction.allCases.filter { open(c.moved($0)) }.count
                if degree == 1 { deadEnds.append(c) }
            }
        }
        deadEnds.sort { (dist[$0] ?? 0) < (dist[$1] ?? 0) }

        // 行き止まりが足りない日は、ギミック無しの迷路として諦める
        guard deadEnds.count >= 3 else {
            return Placement(gimmicks: [:], partners: [:], event: nil)
        }

        var gimmicks: [Coord: GimmickKind] = [:]
        var partners: [Coord: Coord] = [:]

        // 宝箱: 距離が中央値に一番近い行き止まり
        let chest = deadEnds[deadEnds.count / 2]
        gimmicks[chest] = .chest

        // ワープ: 残りのうち「かなり手前」と「かなり奥」を結ぶ。
        // 全ペアの経路距離を測るのは重いので、距離順の両端付近から選ぶ。
        var used: Set<Coord> = [chest]
        let rest = deadEnds.filter { $0 != chest }
        if rest.count >= 2 {
            let nearPool = Array(rest.prefix(max(1, rest.count / 4)))
            let farPool = Array(rest.suffix(max(1, rest.count / 4)))
            let a = nearPool.randomElement(using: &rng) ?? rest.first!
            var b = farPool.randomElement(using: &rng) ?? rest.last!
            if a == b, let alt = rest.last, alt != a { b = alt }
            if a != b {
                gimmicks[a] = .warp
                gimmicks[b] = .warp
                partners[a] = b
                partners[b] = a
                used.insert(a)
                used.insert(b)
            }
        }

        // 宝箱・ワープに使わなかった行き止まりから、1地点だけ選ぶ。
        let event = deadEnds.filter { !used.contains($0) }.randomElement(using: &rng)
        return Placement(gimmicks: gimmicks, partners: partners, event: event)
    }

    // MARK: - 自己チェック

    /// 通路が2マス以上の幅になっている箇所を探す。
    ///
    /// 正しく生成された迷路の通路は必ず1マス幅なので、2x2の開放ブロックが
    /// 見つかったら生成ロジックが壊れている。以前の実装で「道が3マス幅に
    /// 見える」不具合が実際に起きたため、その再発を検知するために置いてある。
    /// 見つかれば最初の座標を返し、健全なら nil を返す。
    func firstWideCorridor() -> Coord? {
        for y in 0..<(height - 1) {
            for x in 0..<(width - 1) {
                let a = Coord(x: x, y: y)
                let b = Coord(x: x + 1, y: y)
                let c = Coord(x: x, y: y + 1)
                let d = Coord(x: x + 1, y: y + 1)
                if isOpen(a) && isOpen(b) && isOpen(c) && isOpen(d) {
                    return a
                }
            }
        }
        return nil
    }

    /// ゴールに到達できるかを確認する。
    func isGoalReachable() -> Bool {
        var seen: Set<Coord> = [start]
        var queue: [Coord] = [start]
        var head = 0
        while head < queue.count {
            let c = queue[head]; head += 1
            if c == goal { return true }
            for d in Direction.allCases {
                let n = c.moved(d)
                guard isOpen(n), !seen.contains(n) else { continue }
                seen.insert(n)
                queue.append(n)
            }
        }
        return false
    }
}
