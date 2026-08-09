import AVFoundation
import SpriteKit
import SwiftData
import SwiftUI
import UIKit
import XCTest
@testable import KareMichi

final class MazeGameTests: XCTestCase {

    func testAllTwelveAudioFilesAreBundledAndDecodable() throws {
        let names = [
            "ambient_wind_loop20s", "bgm_musicbox_v4", "sfx_bump",
            "sfx_card_flip", "sfx_chest", "sfx_discovery",
            "sfx_footstep_a", "sfx_footstep_b", "sfx_footstep_c",
            "sfx_goal", "sfx_ui_tap", "sfx_warp",
        ]

        for name in names {
            let url = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "wav"), name)
            let file = try AVAudioFile(forReading: url)
            XCTAssertGreaterThan(file.length, 0, name)
            XCTAssertGreaterThan(file.processingFormat.sampleRate, 0, name)
        }
    }

    func testThirtyDailyMazesHaveSingleWidthCorridorsAndReachableGoals() {
        for day in 1...30 {
            let maze = Maze.generate(seed: 20_260_700 + UInt64(day))
            XCTAssertEqual(maze.width, 51, "day=\(day)")
            XCTAssertEqual(maze.height, 51, "day=\(day)")
            XCTAssertNil(maze.firstWideCorridor(), "day=\(day)")
            XCTAssertTrue(maze.isGoalReachable(), "day=\(day)")
        }
    }

    func testSameSeedIsExactlyReproducibleAndDifferentDateChangesMaze() {
        let first = mazeSnapshot(Maze.generate(seed: 20_260_729))
        let second = mazeSnapshot(Maze.generate(seed: 20_260_729))
        let nextDay = mazeSnapshot(Maze.generate(seed: 20_260_730))

        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, nextDay)
    }

    func testDailySeedUsesLocalCalendarDay() throws {
        let instant = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-28T16:30:00Z"))
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))

        XCTAssertEqual(DailySeed.seed(for: instant, calendar: tokyo), 20_260_729)
        XCTAssertEqual(DailySeed.seed(for: instant, calendar: losAngeles), 20_260_728)
    }

    func testKeepsakeRequiresGoalAndIsDeterministicForTheSameDay() {
        let seed: UInt64 = 20_260_809

        XCTAssertNil(Keepsake.earned(seed: seed, reachedGoal: false))
        let first = Keepsake.earned(seed: seed, reachedGoal: true)
        let sameDayAgain = Keepsake.earned(seed: seed, reachedGoal: true)

        XCTAssertNotNil(first)
        XCTAssertEqual(first, sameDayAgain)
    }

    func testKeepsakeCanBeDeterministicallyDrawnForDifferentDays() {
        let seeds = (1...16).map { 20_260_800 + UInt64($0) }
        let firstPass = seeds.compactMap {
            Keepsake.earned(seed: $0, reachedGoal: true)
        }
        let secondPass = seeds.compactMap {
            Keepsake.earned(seed: $0, reachedGoal: true)
        }

        XCTAssertEqual(firstPass, secondPass)
        XCTAssertEqual(firstPass.count, seeds.count)
        XCTAssertGreaterThan(Set(firstPass).count, 1)
    }

    func testKeepsakeRestoresFromDailyRunWithoutAStoredField() {
        var log = RunLog()
        log.reachedGoal = true
        let firstRun = DailyRun(date: Date(timeIntervalSince1970: 1_775_000_000),
                                seed: 20_260_809,
                                log: log,
                                axes: .neutral,
                                traveler: .wanderer,
                                moodBefore: nil,
                                fogFeedback: nil)
        let restoredEquivalent = DailyRun(date: firstRun.date,
                                          seed: firstRun.seed,
                                          log: log,
                                          axes: .neutral,
                                          traveler: .wanderer,
                                          moodBefore: nil,
                                          fogFeedback: nil)

        XCTAssertNotNil(firstRun.keepsake)
        XCTAssertEqual(firstRun.keepsake, restoredEquivalent.keepsake)
    }

    func testKeepsakeCollectionDistinguishesAcquiredAndIgnoresSameDayDuplicates() {
        var clearedLog = RunLog()
        clearedLog.reachedGoal = true
        let date = Date(timeIntervalSince1970: 1_775_000_000)
        let firstRun = DailyRun(date: date,
                                seed: 20_260_809,
                                log: clearedLog,
                                axes: .neutral,
                                traveler: .wanderer,
                                moodBefore: nil,
                                fogFeedback: nil)
        let duplicate = DailyRun(date: date,
                                 seed: 20_260_809,
                                 log: clearedLog,
                                 axes: .neutral,
                                 traveler: .wanderer,
                                 moodBefore: nil,
                                 fogFeedback: nil)
        let earlyExit = DailyRun(date: date.addingTimeInterval(86_400),
                                 seed: 20_260_810,
                                 log: RunLog(),
                                 axes: .neutral,
                                 traveler: .wanderer,
                                 moodBefore: nil,
                                 fogFeedback: nil)

        let acquired = Keepsake.acquired(from: [firstRun, duplicate, earlyExit])
        XCTAssertEqual(acquired.count, 1)
        XCTAssertEqual(acquired.first, firstRun.keepsake)
        XCTAssertEqual(Keepsake.v1Catalog.count, 8)
        XCTAssertEqual(Keepsake.v1Catalog.filter(acquired.contains).count, 1)
        XCTAssertEqual(Keepsake.v1Catalog.filter { !acquired.contains($0) }.count, 7)
    }

    func testPlayStreakCountsFirstCompletionAndIgnoresSameDayDuplicates() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let firstDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026,
                                                                        month: 8,
                                                                        day: 1)))
        let sameDay = try XCTUnwrap(calendar.date(byAdding: .hour,
                                                  value: 12,
                                                  to: firstDay))

        let first = PlayStreakCalculator.summary(completedDates: [firstDay],
                                                 asOf: firstDay,
                                                 calendar: calendar)
        XCTAssertEqual(first.currentStreak, 1)
        XCTAssertEqual(first.longestStreak, 1)
        XCTAssertEqual(first.totalPlayDays, 1)
        XCTAssertEqual(first.lastCompletedDate, DailySeed.startOfDay(for: firstDay,
                                                                      calendar: calendar))

        let duplicate = PlayStreakCalculator.summary(completedDates: [firstDay, sameDay],
                                                     asOf: sameDay,
                                                     calendar: calendar)
        XCTAssertEqual(duplicate.currentStreak, 1)
        XCTAssertEqual(duplicate.longestStreak, 1)
        XCTAssertEqual(duplicate.totalPlayDays, 1)
    }

    func testPlayStreakCountsOnlyReachedGoalRunsAndIncludesPendingClear() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let firstDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026,
                                                                        month: 8,
                                                                        day: 1)))
        let secondDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: firstDay))

        var clearedLog = RunLog()
        clearedLog.reachedGoal = true
        let clearedRun = DailyRun(date: firstDay,
                                  seed: 20_260_801,
                                  log: clearedLog,
                                  axes: .neutral,
                                  traveler: .wanderer,
                                  moodBefore: nil,
                                  fogFeedback: nil)
        let earlyRun = DailyRun(date: secondDay,
                                seed: 20_260_802,
                                log: RunLog(),
                                axes: .neutral,
                                traveler: .wanderer,
                                moodBefore: nil,
                                fogFeedback: nil)

        let beforeClear = PlayStreakCalculator.summary(runs: [clearedRun, earlyRun],
                                                       asOf: secondDay,
                                                       calendar: calendar)
        XCTAssertEqual(beforeClear.currentStreak, 1)
        XCTAssertEqual(beforeClear.totalPlayDays, 1)

        let afterClear = PlayStreakCalculator.summary(
            runs: [clearedRun, earlyRun],
            includingCompletionAt: secondDay,
            asOf: secondDay,
            calendar: calendar
        )
        XCTAssertEqual(afterClear.currentStreak, 2)
        XCTAssertEqual(afterClear.totalPlayDays, 2)
    }

    func testPlayStreakAdvancesAcrossDaysAndResetsAfterGap() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let firstDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026,
                                                                        month: 8,
                                                                        day: 1)))
        let secondDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: firstDay))
        let thirdDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: firstDay))
        let fifthDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 4, to: firstDay))

        let twoDays = PlayStreakCalculator.summary(completedDates: [firstDay, secondDay],
                                                   asOf: secondDay,
                                                   calendar: calendar)
        XCTAssertEqual(twoDays.currentStreak, 2)

        let threeDays = PlayStreakCalculator.summary(
            completedDates: [firstDay, secondDay, thirdDay],
            asOf: thirdDay,
            calendar: calendar
        )
        XCTAssertEqual(threeDays.currentStreak, 3)

        let afterGap = PlayStreakCalculator.summary(
            completedDates: [firstDay, secondDay, thirdDay, fifthDay, fifthDay],
            asOf: fifthDay,
            calendar: calendar
        )
        XCTAssertEqual(afterGap.currentStreak, 1)
        XCTAssertEqual(afterGap.longestStreak, 3)
        XCTAssertEqual(afterGap.totalPlayDays, 4)
    }

    func testPlayStreakUsesCalendarDaysAcrossDaylightSavingBoundary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let firstDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026,
                                                                        month: 3,
                                                                        day: 7)))
        let secondDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: firstDay))
        let thirdDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: firstDay))

        let summary = PlayStreakCalculator.summary(
            completedDates: [firstDay, secondDay, thirdDay],
            asOf: thirdDay,
            calendar: calendar
        )

        XCTAssertEqual(summary.currentStreak, 3)
        XCTAssertEqual(summary.longestStreak, 3)
        XCTAssertEqual(summary.totalPlayDays, 3)
    }

    func testSeededGeneratorRepeatsSequence() {
        var first = SeededGenerator(seed: 42)
        var second = SeededGenerator(seed: 42)
        XCTAssertEqual((0..<64).map { _ in first.next() },
                       (0..<64).map { _ in second.next() })
    }

    func testRunCoordinatorReportsNoIntegrityWarningForToday() {
        let coordinator = RunCoordinator(date: Date(timeIntervalSince1970: 1_775_000_000))
        XCTAssertNil(coordinator.integrityWarning)
    }

    func testGeneratedSceneCreatesOnlyExploredNodesInitially() {
        let maze = Maze.generate(seed: 20_260_729)
        let scene = MazeScene(game: MazeGame(maze: maze), traveler: .wanderer)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 520, height: 520))
        view.presentScene(scene)

        XCTAssertLessThan(scene.children.count, 500)
        XCTAssertLessThan(scene.children.count, maze.width * maze.height)
    }

    func testEveryTravelerAssetLoadsAndAxisMappingStaysInternal() {
        for traveler in Traveler.allCases {
            XCTAssertNotNil(UIImage(named: traveler.imageName), traveler.imageName)
            XCTAssertFalse(traveler.displayName.contains("性"))
        }
        XCTAssertNil(Traveler.wanderer.impliedAxis)
        XCTAssertEqual(Traveler.fox.impliedAxis, .exploration)
        XCTAssertEqual(Traveler.owl.impliedAxis, .intuition)
        XCTAssertEqual(Traveler.tortoise.impliedAxis, .caution)
        XCTAssertEqual(Traveler.bird.impliedAxis, .flexibility)
    }

    func testHUDDecorationAssetsLoad() {
        for name in ["DividerOrnament", "MinimapFrame", "StaminaFrame"] {
            XCTAssertNotNil(UIImage(named: name), name)
        }
    }

    @MainActor
    func testChestWarpAndGoalRoutesKeepTheirSpriteKitEffects() throws {
        let maze = Maze.generate(seed: 20_260_729)
        let cells = allCells(in: maze)
        let chest = try XCTUnwrap(cells.first { maze.gimmick(at: $0) == .chest })
        let portals = cells.filter { maze.gimmick(at: $0) == .warp }
        XCTAssertEqual(portals.count, 2)

        // 宝箱: 隣の通路から踏み込み、開封状態と光のバーストを確認する。
        let chestApproach = try XCTUnwrap(openNeighbor(of: chest, in: maze))
        let chestGame = MazeGame(maze: maze)
        advance(chestGame, along: try XCTUnwrap(shortestPath(in: maze,
                                                            from: maze.start,
                                                            to: chestApproach)))
        let chestScene = MazeScene(game: chestGame, traveler: .wanderer)
        let chestView = SKView(frame: CGRect(x: 0, y: 0, width: 520, height: 520))
        chestView.presentScene(chestScene)
        chestScene.receive(direction: direction(from: chestApproach, to: chest))
        XCTAssertTrue(chestGame.openedChests.contains(chest))
        XCTAssertTrue(chestScene.children.contains { $0.zPosition == 4 && $0.hasActions() })

        // ワープ: 入口の回転が生きており、計画に対の出口へのジャンプが入る。
        let portal = portals[0]
        let portalExit = try XCTUnwrap(maze.warpDestination(from: portal))
        XCTAssertEqual(maze.warpDestination(from: portalExit), portal)
        let warpApproach = try XCTUnwrap(openNeighbor(of: portal, in: maze))
        let warpGame = MazeGame(maze: maze)
        advance(warpGame, along: try XCTUnwrap(shortestPath(in: maze,
                                                           from: maze.start,
                                                           to: warpApproach)))
        let warpScene = MazeScene(game: warpGame, traveler: .fox)
        let warpView = SKView(frame: CGRect(x: 0, y: 0, width: 520, height: 520))
        warpView.presentScene(warpScene)
        XCTAssertTrue(warpScene.children.contains {
            ($0 as? SKSpriteNode)?.action(forKey: "spin") != nil
        })
        let warpRoute = warpGame.plan(direction: direction(from: warpApproach, to: portal))
        XCTAssertTrue(warpRoute.contains { $0.arrivedByWarp && $0.coord == portalExit })

        // ゴール: 旗のパルス、一時停止、そこからの結果確定経路を確認する。
        let goalApproach = try XCTUnwrap(openNeighbor(of: maze.goal, in: maze))
        let goalGame = MazeGame(maze: maze)
        advance(goalGame, along: try XCTUnwrap(shortestPath(in: maze,
                                                           from: maze.start,
                                                           to: goalApproach)))
        let goalScene = MazeScene(game: goalGame, traveler: .owl)
        let goalView = SKView(frame: CGRect(x: 0, y: 0, width: 520, height: 520))
        goalView.presentScene(goalScene)
        XCTAssertTrue(goalScene.children.contains {
            ($0 as? SKSpriteNode)?.action(forKey: "pulse") != nil
        })

        let paused = expectation(description: "goal opens continue prompt")
        let finished = expectation(description: "goal commits through onFinish")
        goalScene.onPausePoint = { log in
            XCTAssertTrue(log.reachedGoal)
            paused.fulfill()
            goalScene.commitFinish()
        }
        goalScene.onFinish = { log in
            XCTAssertTrue(log.reachedGoal)
            finished.fulfill()
        }
        goalScene.receive(direction: direction(from: goalApproach, to: maze.goal))
        wait(for: [paused, finished], timeout: 2)
    }

    func testBehaviorLogAndEarlyResultRemainCoherent() throws {
        let maze = Maze.generate(seed: 20_260_729)
        let game = MazeGame(maze: maze)
        let start = Date(timeIntervalSince1970: 1_000)
        game.noteStopped(at: start)

        let direction = try XCTUnwrap(Direction.allCases.first { !game.plan(direction: $0).isEmpty })
        let route = game.plan(direction: direction)
        game.noteSwipe(direction: direction, at: start.addingTimeInterval(2))
        for step in route { game.advance(to: step.coord) }
        game.noteStopped(at: start.addingTimeInterval(3))

        let log = game.makeLog(endedAt: start.addingTimeInterval(5))
        XCTAssertEqual(log.path.count, log.steps + 1)
        XCTAssertEqual(log.decisionLatencies, [2])
        XCTAssertGreaterThan(log.exploredCellCount, 0)
        XCTAssertEqual(log.openCellCount, maze.openCellCount)
        XCTAssertFalse(log.reachedGoal)
    }

    func testStaminaCountsPhysicalStepsButNotWarpExit() throws {
        let maze = Maze.generate(seed: 20_260_729)
        let portals = allCells(in: maze).filter { maze.gimmick(at: $0) == .warp }
        let portal = try XCTUnwrap(portals.first)
        let approach = try XCTUnwrap(openNeighbor(of: portal, in: maze))
        let game = MazeGame(maze: maze)
        advanceWithoutStamina(game, along: try XCTUnwrap(shortestPath(in: maze,
                                                                      from: maze.start,
                                                                      to: approach)))

        let route = game.plan(direction: direction(from: approach, to: portal))
        XCTAssertTrue(route.contains(where: \.arrivedByWarp))
        let before = game.stamina
        for step in route {
            game.advance(to: step.coord, arrivedByWarp: step.arrivedByWarp)
        }

        XCTAssertEqual(game.stamina,
                       before - route.filter { !$0.arrivedByWarp }.count)
    }

    @MainActor
    func testExhaustionStopsAtTheExactCellAndUsesEarlyResult() throws {
        let maze = Maze.generate(seed: 20_260_729)
        let game = MazeGame(maze: maze)
        for _ in 0..<(Tuning.staminaMax - 1) {
            game.advance(to: game.player)
        }
        XCTAssertEqual(game.stamina, 1)

        let move = try XCTUnwrap(Direction.allCases.compactMap { direction -> (Direction, [RouteStep])? in
            let route = game.plan(direction: direction)
            return route.isEmpty ? nil : (direction, route)
        }.first)
        let expectedStop = move.1[0].coord

        let scene = MazeScene(game: game, traveler: .wanderer)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 520, height: 520))
        view.presentScene(scene)
        let paused = expectation(description: "stamina exhaustion pauses")
        let finished = expectation(description: "stamina exhaustion commits")
        scene.onPausePoint = { log in
            XCTAssertFalse(log.reachedGoal)
            paused.fulfill()
            scene.commitFinish()
        }
        scene.onFinish = { log in
            XCTAssertFalse(log.reachedGoal)
            finished.fulfill()
        }
        scene.receive(direction: move.0)
        wait(for: [paused, finished], timeout: 2)

        XCTAssertEqual(game.stamina, 0)
        XCTAssertEqual(game.player, expectedStop)
        XCTAssertEqual(game.steps, Tuning.staminaMax)
    }

    @MainActor
    func testGoalWinsWhenGoalAndStaminaReachZeroTogether() throws {
        let maze = Maze.generate(seed: 20_260_729)
        let approach = try XCTUnwrap(openNeighbor(of: maze.goal, in: maze))
        let game = MazeGame(maze: maze)
        advanceWithoutStamina(game, along: try XCTUnwrap(shortestPath(in: maze,
                                                                      from: maze.start,
                                                                      to: approach)))
        for _ in 0..<(Tuning.staminaMax - 1) {
            game.advance(to: game.player)
        }
        XCTAssertEqual(game.stamina, 1)

        let scene = MazeScene(game: game, traveler: .owl)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 520, height: 520))
        view.presentScene(scene)
        let paused = expectation(description: "goal wins over exhaustion")
        let finished = expectation(description: "goal result commits")
        scene.onPausePoint = { log in
            XCTAssertTrue(log.reachedGoal)
            paused.fulfill()
            scene.commitFinish()
        }
        scene.onFinish = { log in
            XCTAssertTrue(log.reachedGoal)
            finished.fulfill()
        }
        scene.receive(direction: direction(from: approach, to: maze.goal))
        wait(for: [paused, finished], timeout: 3)

        XCTAssertEqual(game.stamina, 0)
        XCTAssertEqual(game.player, maze.goal)
    }

    @MainActor
    func testGoalReplayRestoresGlowAndKeepsGoalHistory() throws {
        let maze = Maze.generate(seed: 20_260_729)
        let approach = try XCTUnwrap(openNeighbor(of: maze.goal, in: maze))
        let game = MazeGame(maze: maze)
        advanceWithoutStamina(game, along: try XCTUnwrap(shortestPath(in: maze,
                                                                      from: maze.start,
                                                                      to: approach)))

        let scene = MazeScene(game: game, traveler: .owl)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 520, height: 520))
        view.presentScene(scene)
        let paused = expectation(description: "goal pause before replay")
        scene.onPausePoint = { log in
            XCTAssertTrue(log.reachedGoal)
            paused.fulfill()
        }

        scene.receive(direction: direction(from: approach, to: maze.goal))
        wait(for: [paused], timeout: 3)

        XCTAssertTrue(scene.resumeAfterAd())
        XCTAssertEqual(game.replayCount, 1)
        XCTAssertEqual(game.stamina, Tuning.staminaMax)

        let mirror = Mirror(reflecting: scene)
        let glow = try XCTUnwrap(mirror.children.first { $0.label == "glowNode" }?.value
            as? SKSpriteNode)
        let player = try XCTUnwrap(mirror.children.first { $0.label == "playerNode" }?.value
            as? SKSpriteNode)
        XCTAssertFalse(glow.hasActions())
        XCTAssertEqual(glow.alpha, 1, accuracy: 0.001)
        XCTAssertEqual(glow.xScale, 1, accuracy: 0.001)
        XCTAssertEqual(glow.yScale, 1, accuracy: 0.001)
        XCTAssertEqual(glow.position.x, player.position.x, accuracy: 0.001)
        XCTAssertEqual(glow.position.y, player.position.y, accuracy: 0.001)

        // ゴールから離れても、その日に一度到達した事実は結果へ残る。
        game.advance(to: approach, arrivedByWarp: true)
        XCTAssertFalse(game.isCleared)
        XCTAssertTrue(game.everReachedGoal)
        XCTAssertTrue(game.makeLog().reachedGoal)
    }

    func testReplayLimitCannotBeExceeded() {
        let game = MazeGame(maze: Maze.generate(seed: 20_260_729))
        XCTAssertEqual(Tuning.maxReplaysPerDay, 2)
        XCTAssertTrue(game.refillStaminaForReplay())
        XCTAssertTrue(game.refillStaminaForReplay())
        XCTAssertFalse(game.refillStaminaForReplay())
        XCTAssertFalse(game.canReplay)
        XCTAssertEqual(game.replayCount, Tuning.maxReplaysPerDay)
    }

    func testRestartResetsRunStateAndSharesTheAdLimit() throws {
        let maze = Maze.generate(seed: 20_260_729)
        let chest = try XCTUnwrap(allCells(in: maze).first { maze.gimmick(at: $0) == .chest })
        let game = MazeGame(maze: maze)

        advanceWithoutStamina(game, along: try XCTUnwrap(shortestPath(in: maze,
                                                                      from: maze.start,
                                                                      to: chest)))
        advanceWithoutStamina(game, along: try XCTUnwrap(shortestPath(in: maze,
                                                                      from: chest,
                                                                      to: maze.goal)))
        game.noteStopped(at: Date(timeIntervalSince1970: 100))
        game.noteSwipe(direction: .left, at: Date(timeIntervalSince1970: 102))

        XCTAssertTrue(game.openedChests.contains(chest))
        XCTAssertTrue(game.everReachedGoal)
        XCTAssertGreaterThan(game.path.count, 1)
        XCTAssertTrue(game.resetForRestart())

        XCTAssertEqual(game.player, maze.start)
        XCTAssertEqual(game.path, [maze.start])
        XCTAssertEqual(game.walked, [maze.start])
        XCTAssertEqual(game.steps, 0)
        XCTAssertEqual(game.stamina, Tuning.staminaMax)
        XCTAssertTrue(game.openedChests.isEmpty)
        XCTAssertFalse(game.everReachedGoal)
        XCTAssertTrue(game.decisionLatencies.isEmpty)
        XCTAssertEqual(game.restartCount, 1)

        // 「続きから」と合わせて2枠を使い切ったら、どちらも使えない。
        XCTAssertTrue(game.refillStaminaForReplay())
        XCTAssertFalse(game.resetForRestart())
        XCTAssertFalse(game.refillStaminaForReplay())
        XCTAssertFalse(game.canUseAdAction)
        XCTAssertEqual(game.makeLog().restartCount, 1)
        XCTAssertEqual(game.makeLog().replayCount, 1)
    }

    @MainActor
    func testSceneRestartClosesChestRefogsTilesAndReturnsCameraToStart() throws {
        let maze = Maze.generate(seed: 20_260_729)
        let chest = try XCTUnwrap(allCells(in: maze).first { maze.gimmick(at: $0) == .chest })
        let approach = try XCTUnwrap(openNeighbor(of: chest, in: maze))
        let game = MazeGame(maze: maze)
        advanceWithoutStamina(game, along: try XCTUnwrap(shortestPath(in: maze,
                                                                      from: maze.start,
                                                                      to: approach)))

        let scene = MazeScene(game: game, traveler: .owl)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 520, height: 520))
        view.presentScene(scene)
        scene.receive(direction: direction(from: approach, to: chest))

        let exploredBeforeRestart = game.explored
        var mirror = Mirror(reflecting: scene)
        let chestsBefore = try XCTUnwrap(mirror.children.first { $0.label == "chestNodes" }?.value
            as? [Coord: SKSpriteNode])
        let chestNodeBefore = try XCTUnwrap(chestsBefore[chest])
        XCTAssertEqual(chestNodeBefore.texture?.description,
                       SKTexture(imageNamed: "ChestOpen").description)

        scene.finishNow()
        XCTAssertTrue(scene.restartAfterAd())
        XCTAssertEqual(game.player, maze.start)

        mirror = Mirror(reflecting: scene)
        let chestsAfter = try XCTUnwrap(mirror.children.first { $0.label == "chestNodes" }?.value
            as? [Coord: SKSpriteNode])
        let chestNodeAfter = try XCTUnwrap(chestsAfter[chest])
        XCTAssertEqual(chestNodeAfter.texture?.description,
                       SKTexture(imageNamed: "ChestClosed").description)
        XCTAssertEqual(chestNodeAfter.xScale, 1, accuracy: 0.001)
        XCTAssertEqual(chestNodeAfter.yScale, 1, accuracy: 0.001)

        let tiles = try XCTUnwrap(mirror.children.first { $0.label == "tileNodes" }?.value
            as? [Coord: SKNode])
        let oldFoggedCoord = try XCTUnwrap(exploredBeforeRestart.subtracting(game.explored)
            .first { tiles[$0] != nil })
        XCTAssertEqual(tiles[oldFoggedCoord]?.alpha ?? -1, 0, accuracy: 0.001)

        let player = try XCTUnwrap(mirror.children.first { $0.label == "playerNode" }?.value
            as? SKSpriteNode)
        let glow = try XCTUnwrap(mirror.children.first { $0.label == "glowNode" }?.value
            as? SKSpriteNode)
        let camera = try XCTUnwrap(mirror.children.first { $0.label == "cameraNode" }?.value
            as? SKCameraNode)
        let tile: CGFloat = 40
        let startPoint = CGPoint(x: (CGFloat(maze.start.x) + 0.5) * tile,
                                 y: (CGFloat(maze.height - 1 - maze.start.y) + 0.5) * tile)
        let half = scene.size.width / 2
        let world = CGFloat(maze.width) * tile
        let expectedCamera = CGPoint(x: min(max(startPoint.x, half), max(world - half, half)),
                                     y: min(max(startPoint.y, half), max(world - half, half)))

        XCTAssertEqual(player.position.x, startPoint.x, accuracy: 0.001)
        XCTAssertEqual(player.position.y, startPoint.y, accuracy: 0.001)
        XCTAssertEqual(glow.position.x, startPoint.x, accuracy: 0.001)
        XCTAssertEqual(glow.position.y, startPoint.y, accuracy: 0.001)
        XCTAssertEqual(camera.position.x, expectedCamera.x, accuracy: 0.001)
        XCTAssertEqual(camera.position.y, expectedCamera.y, accuracy: 0.001)
    }

    func testPersonalityCodeUsesRankedAxes() {
        XCTAssertEqual(PlayStyleAxes.neutral.personalityCode, "IECF")
        let axes = PlayStyleAxes(intuition: 0.1,
                                 exploration: 0.7,
                                 caution: 0.4,
                                 flexibility: 0.9)
        XCTAssertEqual(axes.personalityCode, "FECI")
    }

    @MainActor
    func testMockRewardedAdCompletesSuccessfully() {
        let completed = expectation(description: "mock rewarded ad")
        MockAdProvider(delay: 0).showRewardedAd { success in
            XCTAssertTrue(success)
            completed.fulfill()
        }
        wait(for: [completed], timeout: 2)
    }

    @MainActor
    func testAdProvidersFailSafelyWithoutReward() {
        let mockFailure = expectation(description: "mock failure")
        MockAdProvider(result: false, delay: 0).showRewardedAd { success in
            XCTAssertFalse(success)
            mockFailure.fulfill()
        }

        let unavailable = expectation(description: "unavailable")
        UnavailableAdProvider().showRewardedAd { success in
            XCTAssertFalse(success)
            unavailable.fulfill()
        }
        wait(for: [mockFailure, unavailable], timeout: 2)
    }

    func testRewardedAdSessionPreventsDoubleRewardAndDoubleCompletion() {
        var rewarded = RewardedAdSession()
        XCTAssertTrue(rewarded.recordReward())
        XCTAssertFalse(rewarded.recordReward())
        XCTAssertEqual(rewarded.finish(), true)
        XCTAssertNil(rewarded.finish())

        var dismissedWithoutReward = RewardedAdSession()
        XCTAssertEqual(dismissedWithoutReward.finish(), false)
        XCTAssertFalse(dismissedWithoutReward.recordReward())
    }

    func testResultGateRewardSuccessShowsResultExactlyOnce() {
        var gate = RewardedGateState(kind: .result)
        XCTAssertTrue(gate.beginRequest())
        XCTAssertEqual(gate.resolve(.rewarded), .showResult)
        XCTAssertTrue(gate.didTransition)
        XCTAssertFalse(gate.isRequestInFlight)
        XCTAssertEqual(gate.resolve(.rewarded), .none)
        XCTAssertFalse(gate.beginRequest())
    }

    func testResultGateFailsOpenForEveryUnavailableReason() {
        let failures: [RewardedAdFailure] = [
            .notLoaded, .loadFailed, .consentBlocked,
            .presentationFailed, .sdkError, .busy,
        ]

        for failure in failures {
            var gate = RewardedGateState(kind: .result)
            XCTAssertTrue(gate.beginRequest(), "failure=\(failure)")
            XCTAssertEqual(gate.resolve(.unavailable(failure)),
                           .showResult,
                           "failure=\(failure)")
            XCTAssertFalse(gate.isRequestInFlight, "failure=\(failure)")
            XCTAssertTrue(gate.didTransition, "failure=\(failure)")
        }
    }

    func testResultGateCancellationReturnsToGateAndOffersFallback() {
        var gate = RewardedGateState(kind: .result)
        XCTAssertTrue(gate.beginRequest())
        XCTAssertEqual(gate.resolve(.cancelled), .stay)
        XCTAssertFalse(gate.isRequestInFlight)
        XCTAssertFalse(gate.didTransition)
        XCTAssertTrue(gate.allowsResultFallback)
        XCTAssertEqual(gate.useResultFallback(), .showResult)
        XCTAssertEqual(gate.useResultFallback(), .none)
    }

    func testReplayGateRequiresRewardAndGrantsExactlyOnce() {
        for outcome in [RewardedAdOutcome.cancelled,
                        .unavailable(.notLoaded),
                        .unavailable(.loadFailed),
                        .unavailable(.consentBlocked),
                        .unavailable(.presentationFailed),
                        .unavailable(.sdkError)] {
            var rejected = RewardedGateState(kind: .replay)
            XCTAssertTrue(rejected.beginRequest())
            XCTAssertEqual(rejected.resolve(outcome), .stay)
            XCTAssertFalse(rejected.didTransition)
            XCTAssertFalse(rejected.isRequestInFlight)
        }

        var granted = RewardedGateState(kind: .replay)
        XCTAssertTrue(granted.beginRequest())
        XCTAssertEqual(granted.resolve(.rewarded), .startReplay)
        XCTAssertEqual(granted.resolve(.rewarded), .none)
        XCTAssertFalse(granted.beginRequest())
    }

    @MainActor
    func testMockRewardedProviderCanDriveAllGateOutcomesWithoutNetwork() {
        let outcomes: [RewardedAdOutcome] = [
            .rewarded,
            .cancelled,
            .unavailable(.loadFailed),
        ]
        let completions = outcomes.map { outcome in
            let completed = expectation(description: "mock \(outcome)")
            MockAdProvider(outcome: outcome).showRewardedAdOutcome { received in
                XCTAssertEqual(received, outcome)
                completed.fulfill()
            }
            return completed
        }
        wait(for: completions, timeout: 2)
    }

    @MainActor
    func testGoogleReadyOnlyReturnsNotLoadedImmediatelyWithoutWaitingForConsentOrLoad() {
        let consent = HoldingAdConsentProvider()
        let provider = GoogleMobileAdsProvider(
            rewardedAdUnitID: "ca-app-pub-3940256099942544/1712485313",
            consentProvider: consent
        )
        var received: RewardedAdOutcome?

        provider.showRewardedAdIfReady { received = $0 }

        XCTAssertEqual(received, .unavailable(.notLoaded))
        XCTAssertEqual(consent.requestCount, 1)
        XCTAssertFalse(provider.isRewardedAdReady)
    }

    @MainActor
    func testResultGateReadyOnlyNotLoadedClearsFlightAndFailsOpen() {
        let provider = MockAdProvider(outcome: .rewarded,
                                      isRewardedAdReady: false)
        var gate = RewardedGateState(kind: .result)
        XCTAssertTrue(gate.beginRequest())

        provider.showRewardedAdIfReady { outcome in
            XCTAssertEqual(gate.resolve(outcome), .showResult)
        }

        XCTAssertFalse(gate.isRequestInFlight)
        XCTAssertTrue(gate.didTransition)
    }

    @MainActor
    func testResultGateReadyOnlyConsentStatesNeverRemainInFlight() {
        let gatheringConsent = HoldingAdConsentProvider()
        let gatheringProvider = GoogleMobileAdsProvider(
            rewardedAdUnitID: "ca-app-pub-3940256099942544/1712485313",
            consentProvider: gatheringConsent
        )
        gatheringProvider.start()

        var gatheringGate = RewardedGateState(kind: .result)
        XCTAssertTrue(gatheringGate.beginRequest())
        gatheringProvider.showRewardedAdIfReady { outcome in
            XCTAssertEqual(gatheringGate.resolve(outcome), .showResult)
        }
        XCTAssertFalse(gatheringGate.isRequestInFlight)

        let deniedProvider = GoogleMobileAdsProvider(
            rewardedAdUnitID: "ca-app-pub-3940256099942544/1712485313",
            consentProvider: StubAdConsentProvider(canRequestAds: false)
        )
        deniedProvider.start()

        var deniedGate = RewardedGateState(kind: .result)
        XCTAssertTrue(deniedGate.beginRequest())
        deniedProvider.showRewardedAdIfReady { outcome in
            XCTAssertEqual(outcome, .unavailable(.consentBlocked))
            XCTAssertEqual(deniedGate.resolve(outcome), .showResult)
        }
        XCTAssertFalse(deniedGate.isRequestInFlight)
    }

    @MainActor
    func testReplayReadyOnlyNotLoadedDoesNotStartReplay() {
        let provider = MockAdProvider(outcome: .rewarded,
                                      isRewardedAdReady: false)
        var gate = RewardedGateState(kind: .replay)
        XCTAssertTrue(gate.beginRequest())

        provider.showRewardedAdIfReady { outcome in
            XCTAssertEqual(gate.resolve(outcome), .stay)
        }

        XCTAssertFalse(gate.isRequestInFlight)
        XCTAssertFalse(gate.didTransition)
    }

    @MainActor
    func testReadyOnlyRewardStillTransitionsResultAndReplay() {
        let provider = MockAdProvider(outcome: .rewarded,
                                      isRewardedAdReady: true)
        var resultGate = RewardedGateState(kind: .result)
        var replayGate = RewardedGateState(kind: .replay)
        XCTAssertTrue(resultGate.beginRequest())
        XCTAssertTrue(replayGate.beginRequest())

        let resultCompleted = expectation(description: "ready result reward")
        provider.showRewardedAdIfReady { outcome in
            XCTAssertEqual(resultGate.resolve(outcome), .showResult)
            resultCompleted.fulfill()
        }
        let replayCompleted = expectation(description: "ready replay reward")
        provider.showRewardedAdIfReady { outcome in
            XCTAssertEqual(replayGate.resolve(outcome), .startReplay)
            replayCompleted.fulfill()
        }

        wait(for: [resultCompleted, replayCompleted], timeout: 1)
        XCTAssertTrue(resultGate.didTransition)
        XCTAssertTrue(replayGate.didTransition)
    }

    func testAdConsentGateStartsOnceAndRequiresPermission() {
        var allowed = AdConsentGate()
        XCTAssertEqual(allowed.state, .notStarted)
        XCTAssertTrue(allowed.begin())
        XCTAssertFalse(allowed.begin())
        XCTAssertEqual(allowed.state, .gathering)
        XCTAssertEqual(allowed.finish(canRequestAds: true), true)
        XCTAssertEqual(allowed.state, .allowed)
        XCTAssertNil(allowed.finish(canRequestAds: false))

        var denied = AdConsentGate()
        XCTAssertTrue(denied.begin())
        XCTAssertEqual(denied.finish(canRequestAds: false), false)
        XCTAssertEqual(denied.state, .denied)
    }

    @MainActor
    func testGoogleProviderFailsSafelyWhenConsentDoesNotPermitAds() {
        let consent = StubAdConsentProvider(canRequestAds: false)
        let provider = GoogleMobileAdsProvider(
            rewardedAdUnitID: "ca-app-pub-3940256099942544/1712485313",
            consentProvider: consent
        )

        provider.start()
        provider.start()
        XCTAssertEqual(consent.requestCount, 1)

        let completed = expectation(description: "consent denied")
        provider.showRewardedAd { success in
            XCTAssertFalse(success)
            completed.fulfill()
        }
        wait(for: [completed], timeout: 1)
    }

    @MainActor
    func testGoogleProviderReportsConsentBlockedWithoutNetworkAdRequest() {
        let consent = StubAdConsentProvider(canRequestAds: false)
        let provider = GoogleMobileAdsProvider(
            rewardedAdUnitID: "ca-app-pub-3940256099942544/1712485313",
            consentProvider: consent
        )

        let completed = expectation(description: "consent blocked outcome")
        provider.showRewardedAdOutcome { outcome in
            XCTAssertEqual(outcome, .unavailable(.consentBlocked))
            completed.fulfill()
        }
        wait(for: [completed], timeout: 1)
        XCTAssertEqual(consent.requestCount, 1)
    }

    @MainActor
    func testUnitTestsStayOnMockAndDebugUsesOfficialTestAdUnitID() {
        XCTAssertTrue(Ads.provider is MockAdProvider)
        XCTAssertTrue(Ads.makeDefaultProvider(isRunningUnitTests: true) is MockAdProvider)
        XCTAssertTrue(Ads.makeDefaultProvider(isRunningUnitTests: false)
            is GoogleMobileAdsProvider)
        XCTAssertEqual(AdConfiguration.rewardedAdUnitID(),
                       "ca-app-pub-3940256099942544/1712485313")
    }

    @MainActor
    func testHUDSnapshotContainsOnlyExploredCellsAndUsesLightweightNodes() throws {
        let maze = Maze.generate(seed: 20_260_729)
        let game = MazeGame(maze: maze)
        let scene = MazeScene(game: game, traveler: .tortoise)
        var snapshot: HUDSnapshot?
        scene.onHUDUpdate = { snapshot = $0 }
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 520, height: 520))
        view.presentScene(scene)

        let hud = try XCTUnwrap(snapshot)
        XCTAssertEqual(hud.explored, game.explored)
        XCTAssertEqual(hud.walked, game.walked)
        XCTAssertTrue(hud.walked.isSubset(of: hud.explored))
        XCTAssertLessThan(hud.explored.count, maze.openCellCount)
        XCTAssertEqual(hud.stamina, Tuning.staminaMax)
        XCTAssertEqual(hud.traveler, .tortoise)

        let mirror = Mirror(reflecting: scene)
        let floorTints = try XCTUnwrap(mirror.children.first { $0.label == "floorTints" }?.value
            as? [Coord: SKSpriteNode])
        let playerNode = try XCTUnwrap(mirror.children.first { $0.label == "playerNode" }?.value
            as? SKSpriteNode)
        XCTAssertFalse(floorTints.isEmpty)
        XCTAssertLessThanOrEqual(scene.children.filter { $0.zPosition == 0.5 }.count, 24)
        XCTAssertEqual(playerNode.size.width, 40 * 0.92, accuracy: 0.001)
        XCTAssertEqual(playerNode.size.height, 40 * 0.92, accuracy: 0.001)
    }

    func testAxesAlwaysStayWithinUnitRange() {
        var log = RunLog()
        log.decisionLatencies = [-100, 100]
        log.deadEndCount = 1_000
        log.backtrackCount = 1_000
        log.forwardCount = 0
        log.exploredCellCount = 10_000
        log.openCellCount = 10

        let axes = Diagnosis.axes(from: log)
        for axis in KareMichi.Axis.allCases {
            XCTAssertGreaterThanOrEqual(axes.value(axis), 0)
            XCTAssertLessThanOrEqual(axes.value(axis), 1)
        }
    }

    func testAllTwelveArchetypesAndTieBreakAreSafe() {
        var names: Set<String> = []
        for primary in KareMichi.Axis.allCases {
            for secondary in KareMichi.Axis.allCases where secondary != primary {
                var axes = PlayStyleAxes(intuition: 0, exploration: 0,
                                         caution: 0, flexibility: 0)
                set(1, axis: primary, axes: &axes)
                set(0.8, axis: secondary, axes: &axes)
                names.insert(Diagnosis.archetype(for: axes).fullName)
            }
        }

        XCTAssertEqual(names.count, 12)
        XCTAssertEqual(PlayStyleAxes.neutral.ranked,
                       [.intuition, .exploration, .caution, .flexibility])
        XCTAssertEqual(Diagnosis.archetype(for: .neutral).fullName,
                       "風の道行き・広く巡る")
    }

    func testOmenBeforeSevenRunsIsCommonAndDeterministic() {
        let history = Array(repeating: PlayStyleAxes.neutral, count: 6)
        let first = Diagnosis.omen(dateSeed: 20_260_729,
                                   axes: .neutral,
                                   recentAxes: history)
        let second = Diagnosis.omen(dateSeed: 20_260_729,
                                    axes: .neutral,
                                    recentAxes: history)
        XCTAssertTrue(Diagnosis.commonOmens.contains(first))
        XCTAssertEqual(first, second)
    }

    func testTravelerReflectionNeedsThreeDays() {
        let twoDays = Array(repeating: PlayStyleAxes.neutral, count: 2)
        let threeDays = Array(repeating: PlayStyleAxes.neutral, count: 3)
        XCTAssertNil(Diagnosis.travelerReflection(traveler: .fox,
                                                  recentAxes: twoDays))
        XCTAssertNotNil(Diagnosis.travelerReflection(traveler: .fox,
                                                     recentAxes: threeDays))
        XCTAssertNil(Diagnosis.travelerReflection(traveler: .wanderer,
                                                  recentAxes: threeDays))
    }

    func testStoryFragmentsAppearOnlyOnMilestoneDays() {
        let expectedDays = [3, 7, 14, 21, 30]
        XCTAssertEqual(Diagnosis.storyFragments.map(\.day), expectedDays)
        for day in expectedDays {
            XCTAssertNotNil(Diagnosis.storyFragment(totalDayCount: day), "day=\(day)")
        }
        for day in [0, 1, 2, 4, 6, 8, 13, 15, 29, 31] {
            XCTAssertNil(Diagnosis.storyFragment(totalDayCount: day), "day=\(day)")
        }
    }

    func testMirrorUnlocksAtSevenDaysAndUsesQuietestAxis() {
        let axes = PlayStyleAxes(intuition: 0.9,
                                 exploration: 0.8,
                                 caution: 0.7,
                                 flexibility: 0.1)
        XCTAssertNil(Diagnosis.mirrorReflection(recentAxes: Array(repeating: axes, count: 6)))
        let reflection = Diagnosis.mirrorReflection(recentAxes: Array(repeating: axes, count: 7))
        XCTAssertNotNil(reflection)
        XCTAssertTrue(reflection?.contains("柔軟性") == true)
    }

    func testRecentTrendCoversThreeThroughSixDaysThenYieldsToMirror() {
        let today = PlayStyleAxes(intuition: 0.9,
                                  exploration: 0.5,
                                  caution: 0.5,
                                  flexibility: 0.5)
        let previous = PlayStyleAxes.neutral

        XCTAssertNil(Diagnosis.recentTrend(axes: today,
                                           recentAxes: Array(repeating: previous, count: 2)))
        for dayCount in 3...6 {
            XCTAssertNotNil(Diagnosis.recentTrend(
                axes: today,
                recentAxes: Array(repeating: previous, count: dayCount)),
                "historyCount=\(dayCount)")
        }
        XCTAssertNil(Diagnosis.recentTrend(axes: today,
                                           recentAxes: Array(repeating: previous, count: 7)))
        XCTAssertNotNil(Diagnosis.mirrorReflection(
            recentAxes: Array(repeating: previous, count: 7)))
    }

    func testTopSignalsSupportsZeroThroughThreeVisibleRows() {
        var zero = RunLog()
        zero.staminaRemaining = 50
        zero.staminaMax = 100
        zero.replayCount = 1
        XCTAssertEqual(Diagnosis.topSignals(log: zero).count, 0)

        var one = zero
        one.reachedGoal = true
        XCTAssertEqual(Diagnosis.topSignals(log: one).count, 1)

        var two = one
        two.chestOpened = true
        XCTAssertEqual(Diagnosis.topSignals(log: two).count, 2)

        var three = two
        three.deadEndCount = 8
        three.forwardCount = 4
        XCTAssertEqual(Diagnosis.topSignals(log: three).count, 3)
        XCTAssertEqual(Diagnosis.topSignals(log: three, maxCount: 2).count, 2)
        XCTAssertTrue(Diagnosis.topSignals(log: three, maxCount: 0).isEmpty)
    }

    @MainActor
    func testSevenSwiftDataRunsProvideMirrorHistory() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyRun.self, configurations: configuration)
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let today = DailySeed.startOfDay(for: Date(), calendar: calendar)
        let axes = PlayStyleAxes(intuition: 0.85,
                                 exploration: 0.75,
                                 caution: 0.65,
                                 flexibility: 0.05)

        for offset in 0..<7 {
            var log = RunLog()
            log.path = [Coord(x: 1, y: 1)]
            log.openCellCount = 1
            let date = try XCTUnwrap(calendar.date(byAdding: .day,
                                                   value: -offset,
                                                   to: today))
            context.insert(DailyRun(date: date,
                                    seed: 20_260_730 - offset,
                                    log: log,
                                    axes: axes,
                                    traveler: .wanderer,
                                    moodBefore: nil,
                                    fogFeedback: nil))
        }
        try context.save()

        let runs = try context.fetch(FetchDescriptor<DailyRun>())
        XCTAssertEqual(runs.count, 7)
        let reflection = Diagnosis.mirrorReflection(recentAxes: runs.map(\.axes))
        XCTAssertTrue(reflection?.contains("柔軟性") == true)
        XCTAssertEqual(Diagnosis.storyFragment(totalDayCount: runs.count),
                       Diagnosis.storyFragments.first { $0.day == 7 }?.text)
    }

    @MainActor
    func testDailyRunSwiftDataRoundTripPreservesArraysAndOptionals() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyRun.self, configurations: configuration)
        let context = container.mainContext
        var log = RunLog()
        log.path = [Coord(x: 1, y: 1), Coord(x: 2, y: 1)]
        log.steps = 1
        log.elapsed = 3.5
        log.exploredCellCount = 4
        log.openCellCount = 10
        log.decisionLatencies = [0.8, 1.6]
        log.deadEndCount = 2
        log.backtrackCount = 3
        log.forwardCount = 4
        log.replayCount = 2
        log.restartCount = 1

        let run = DailyRun(date: Date(timeIntervalSince1970: 1_775_000_000),
                           seed: 20_260_729,
                           log: log,
                           axes: .neutral,
                           traveler: .owl,
                           moodBefore: nil,
                           fogFeedback: .usual)
        context.insert(run)
        try context.save()

        let restored = try XCTUnwrap(context.fetch(FetchDescriptor<DailyRun>()).first)
        XCTAssertEqual(restored.path, log.path)
        XCTAssertNil(restored.moodBefore)
        XCTAssertEqual(restored.feedback, .usual)
        XCTAssertEqual(restored.traveler, .owl)
        XCTAssertEqual(restored.restoredLog.decisionLatencies, log.decisionLatencies)
        XCTAssertEqual(restored.restoredLog.deadEndCount, log.deadEndCount)
        XCTAssertEqual(restored.restoredLog.backtrackCount, log.backtrackCount)
        XCTAssertEqual(restored.restoredLog.forwardCount, log.forwardCount)
        XCTAssertEqual(restored.restoredLog.replayCount, 2)
        XCTAssertEqual(restored.restoredLog.restartCount, 1)
        XCTAssertTrue(Diagnosis.comment(feedback: nil,
                                        log: restored.restoredLog,
                                        axes: .neutral).contains("最初から歩き直して"))
    }

    func testRandomEventPlacementIsDeterministicAndDoesNotOverlapGimmicks() throws {
        for day in 1...30 {
            let seed = 20_260_700 + UInt64(day)
            let first = Maze.generate(seed: seed)
            let second = Maze.generate(seed: seed)
            XCTAssertEqual(first.eventCoord, second.eventCoord, "day=\(day)")

            let event = try XCTUnwrap(first.eventCoord, "day=\(day)")
            XCTAssertTrue(first.isOpen(event), "day=\(day)")
            XCTAssertNotEqual(event, first.start)
            XCTAssertNotEqual(event, first.goal)
            XCTAssertNil(first.gimmick(at: event), "day=\(day)")
        }
    }

    func testEventStopsRouteAndCanOnlyBeResolvedOnce() throws {
        let maze = Maze.generate(seed: 20_260_730)
        let eventCoord = try XCTUnwrap(maze.eventCoord)
        let approach = try XCTUnwrap(openNeighbor(of: eventCoord, in: maze))
        let game = MazeGame(maze: maze)
        advanceWithoutStamina(game, along: try XCTUnwrap(shortestPath(in: maze,
                                                                      from: maze.start,
                                                                      to: approach)))

        let route = game.plan(direction: direction(from: approach, to: eventCoord))
        XCTAssertEqual(route.last?.coord, eventCoord)

        let event = RandomEvents.todaysEvent(dateSeed: 20_260_730, recentThemes: [])
        XCTAssertFalse(game.resolveEvent(event, choiceIndex: -1))
        XCTAssertTrue(game.resolveEvent(event, choiceIndex: 1))
        XCTAssertFalse(game.resolveEvent(event, choiceIndex: 0))
        XCTAssertEqual(game.eventOutcome?.eventID, event.id)
        XCTAssertEqual(game.eventOutcome?.choiceText, event.choices[1].text)
        XCTAssertEqual(game.makeLog(endedAt: Date()).eventOutcome?.theme, event.theme)
    }

    func testDailyEventSelectionIsDeterministicAndAvoidsRecentThemes() {
        let recent: [EventTheme] = [.past, .others, .decision]
        let first = RandomEvents.todaysEvent(dateSeed: 20_260_730, recentThemes: recent)
        let second = RandomEvents.todaysEvent(dateSeed: 20_260_730, recentThemes: recent)
        XCTAssertEqual(first.id, second.id)
        XCTAssertFalse(Set(recent).contains(first.theme))
        XCTAssertEqual(first.choices.count, 3)
    }

    func testExpandedOmenAndEventLibrariesAreUniqueAndReachableBySeed() {
        XCTAssertEqual(Diagnosis.commonOmens.count, 59)
        XCTAssertEqual(RandomEvents.library.count, 12)

        let omenTitles = Diagnosis.commonOmens.map {
            $0.components(separatedBy: " — ").first ?? $0
        }
        XCTAssertEqual(Set(omenTitles).count, 59)
        XCTAssertEqual(Set(RandomEvents.library.map(\.id)).count, 12)
        XCTAssertTrue(RandomEvents.library.allSatisfy { $0.choices.count == 3 })

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let firstDay = calendar.date(from: DateComponents(year: 2026,
                                                          month: 7,
                                                          day: 30))!
        let dailySeeds = (0..<4_000).map { dayOffset in
            let date = calendar.date(byAdding: .day,
                                     value: dayOffset,
                                     to: firstDay)!
            return DailySeed.seed(for: date, calendar: calendar)
        }
        let sampledOmens = Set(dailySeeds.map { dateSeed in
            Diagnosis.omen(dateSeed: dateSeed,
                           axes: .neutral,
                           recentAxes: [])
        })
        let sampledEvents = Set(dailySeeds.prefix(1_000).map { dateSeed in
            RandomEvents.todaysEvent(dateSeed: dateSeed,
                                     recentThemes: []).id
        })

        XCTAssertEqual(sampledOmens.count, 59)
        XCTAssertEqual(sampledEvents.count, 12)
        XCTAssertTrue(sampledOmens.contains { $0.hasPrefix("水鏡のしずく —") })
        XCTAssertTrue(sampledEvents.contains("untied_bundle"))
    }

    @MainActor
    func testNewDailyRunFieldsRoundTripThroughSwiftData() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyRun.self, configurations: configuration)
        let context = container.mainContext
        let event = RandomEvents.library[0]
        var log = RunLog()
        log.path = [Coord(x: 1, y: 1)]
        log.staminaRemaining = 321
        log.staminaMax = 1_000
        log.eventOutcome = EventOutcome(eventID: event.id,
                                        theme: event.theme,
                                        choiceText: event.choices[2].text,
                                        impliedAxis: event.choices[2].impliedAxis)
        context.insert(DailyRun(date: Date(),
                                seed: 20_260_730,
                                log: log,
                                axes: .neutral,
                                traveler: .wanderer,
                                moodBefore: nil,
                                fogFeedback: nil))
        try context.save()

        let restored = try XCTUnwrap(context.fetch(FetchDescriptor<DailyRun>()).first)
        XCTAssertEqual(restored.staminaRemaining, 321)
        XCTAssertEqual(restored.staminaMax, 1_000)
        XCTAssertEqual(restored.eventTheme, event.theme)
        XCTAssertEqual(restored.restoredLog.eventOutcome?.choiceText, event.choices[2].text)
        XCTAssertEqual(restored.restoredLog.eventOutcome?.impliedAxis,
                       event.choices[2].impliedAxis)
    }

    @MainActor
    func testReplaySessionUsesSameDateSeedMazeAndFreshGameplayState() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026,
                                                                    month: 8,
                                                                    day: 10)))
        let coordinator = RunCoordinator(date: date)
        let officialSeed = coordinator.seed
        let officialMaze = mazeSnapshot(coordinator.maze)
        coordinator.startPlaying(traveler: .wanderer)

        let officialScene = try XCTUnwrap(coordinator.scene)
        let neighbor = try XCTUnwrap(openNeighbor(of: officialScene.game.player,
                                                  in: officialScene.game.maze))
        officialScene.game.advance(to: neighbor)
        XCTAssertGreaterThan(officialScene.game.steps, 0)

        coordinator.startReplay(seed: officialSeed,
                                date: date,
                                traveler: .wanderer)

        let replayScene = try XCTUnwrap(coordinator.scene)
        let pristine = MazeGame(maze: replayScene.game.maze)
        XCTAssertEqual(coordinator.sessionMode, .replay)
        XCTAssertEqual(coordinator.sessionDate, date)
        XCTAssertEqual(coordinator.seed, officialSeed)
        XCTAssertEqual(mazeSnapshot(coordinator.maze), officialMaze)
        XCTAssertEqual(replayScene.game.player, replayScene.game.maze.start)
        XCTAssertEqual(replayScene.game.path, [replayScene.game.maze.start])
        XCTAssertEqual(replayScene.game.steps, 0)
        XCTAssertEqual(replayScene.game.stamina, Tuning.staminaMax)
        XCTAssertEqual(replayScene.game.explored, pristine.explored)
        XCTAssertEqual(replayScene.game.walked, pristine.walked)
        XCTAssertTrue(replayScene.game.openedChests.isEmpty)
        XCTAssertNil(replayScene.game.eventOutcome)
        XCTAssertFalse(replayScene.game.everReachedGoal)
        XCTAssertEqual(replayScene.todaysEvent?.id, officialScene.todaysEvent?.id)
    }

    @MainActor
    func testReplayGoalDoesNotInsertOfficialDailyRun() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyRun.self, configurations: configuration)
        let context = container.mainContext
        var replayLog = RunLog()
        replayLog.reachedGoal = true
        replayLog.steps = 222

        let saved = DailyRunPersistence.saveIfOfficial(
            mode: .replay,
            context: context,
            existingRuns: [],
            date: Date(timeIntervalSince1970: 1_775_000_000),
            seed: 20_260_810,
            log: replayLog,
            axes: .neutral,
            traveler: .wanderer,
            moodBefore: nil,
            fogFeedback: nil
        )

        XCTAssertFalse(saved)
        XCTAssertTrue(try context.fetch(FetchDescriptor<DailyRun>()).isEmpty)
    }

    @MainActor
    func testReplayDoesNotOverwriteOfficialHistoryOrDerivedProgress() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DailyRun.self, configurations: configuration)
        let context = container.mainContext
        let date = Date(timeIntervalSince1970: 1_775_000_000)
        var officialLog = RunLog()
        officialLog.reachedGoal = true
        officialLog.steps = 41
        officialLog.exploredCellCount = 60
        officialLog.openCellCount = 100
        let officialAxes = PlayStyleAxes(intuition: 0.8,
                                         exploration: 0.6,
                                         caution: 0.3,
                                         flexibility: 0.4)
        let official = DailyRun(date: date,
                                seed: 20_260_810,
                                log: officialLog,
                                axes: officialAxes,
                                traveler: .owl,
                                moodBefore: .calm,
                                fogFeedback: nil)
        context.insert(official)
        try context.save()

        let beforeRuns = try context.fetch(FetchDescriptor<DailyRun>())
        let beforeStreak = PlayStreakCalculator.summary(runs: beforeRuns, asOf: date)
        let beforeKeepsakes = Keepsake.acquired(from: beforeRuns)

        var replayLog = RunLog()
        replayLog.reachedGoal = true
        replayLog.steps = 999
        replayLog.chestOpened = true
        let replayAxes = PlayStyleAxes(intuition: 0.1,
                                       exploration: 0.2,
                                       caution: 0.9,
                                       flexibility: 0.95)
        XCTAssertFalse(DailyRunPersistence.saveIfOfficial(
            mode: .replay,
            context: context,
            existingRuns: beforeRuns,
            date: date,
            seed: 99,
            log: replayLog,
            axes: replayAxes,
            traveler: .fox,
            moodBefore: nil,
            fogFeedback: .deep
        ))

        let afterRuns = try context.fetch(FetchDescriptor<DailyRun>())
        let restored = try XCTUnwrap(afterRuns.first)
        XCTAssertEqual(afterRuns.count, 1)
        XCTAssertEqual(restored.seed, 20_260_810)
        XCTAssertEqual(restored.steps, 41)
        XCTAssertTrue(restored.reachedGoal)
        XCTAssertEqual(restored.axes.intuition, officialAxes.intuition)
        XCTAssertEqual(restored.axes.exploration, officialAxes.exploration)
        XCTAssertEqual(restored.axes.caution, officialAxes.caution)
        XCTAssertEqual(restored.axes.flexibility, officialAxes.flexibility)
        XCTAssertEqual(restored.traveler, .owl)
        XCTAssertEqual(PlayStreakCalculator.summary(runs: afterRuns, asOf: date), beforeStreak)
        XCTAssertEqual(Keepsake.acquired(from: afterRuns), beforeKeepsakes)
        XCTAssertEqual(afterRuns.count, beforeRuns.count)
    }

    @MainActor
    func testResultGateAndReplayActionRenderOnSmallPhone() throws {
        let size = CGSize(width: 320, height: 568)
        let gate = ResultGateView(isPurchased: false,
                                  adProvider: MockAdProvider(outcome: .cancelled),
                                  onShowResult: {})
            .frame(width: size.width, height: size.height)
        try renderVisual(gate,
                         size: size,
                         name: "Result Gate — small iPhone",
                         path: "/tmp/KareMichi-result-gate-visual.png")

        var log = RunLog()
        log.path = [Coord(x: 1, y: 1), Coord(x: 2, y: 1), Coord(x: 2, y: 2)]
        log.steps = 42
        log.elapsed = 38
        log.reachedGoal = true
        log.exploredCellCount = 70
        log.openCellCount = 100
        log.chestOpened = true

        let result = ResultView(log: log,
                                axes: .neutral,
                                feedback: .usual,
                                traveler: .wanderer,
                                seed: 20_260_810,
                                recentAxes: [],
                                totalDayCount: 1,
                                currentStreak: 1,
                                resultDate: Date(timeIntervalSince1970: 1_775_000_000),
                                alreadyPlayed: false,
                                isReplay: false,
                                isPurchased: false,
                                adProvider: MockAdProvider(outcome: .rewarded),
                                onReplay: {},
                                onClose: nil)
            .frame(width: size.width, height: size.height)
        try renderVisual(result,
                         size: size,
                         name: "Result Replay CTA — small iPhone",
                         path: "/tmp/KareMichi-result-replay-visual.png")
    }

    func testCollectionAndStoreBranchesDoNotNeedAConfiguredProduct() {
        XCTAssertEqual(StoreManager.remainingAdActions(isPurchased: false,
                                                       replayCount: 1,
                                                       restartCount: 1),
                       max(0, Tuning.maxReplaysPerDay - 2))
        XCTAssertEqual(StoreManager.remainingAdActions(isPurchased: true,
                                                       replayCount: 999,
                                                       restartCount: 999),
                       Int.max)
        XCTAssertEqual(StoreManager.collectionRunLimit(isPurchased: false), 7)
        XCTAssertNil(StoreManager.collectionRunLimit(isPurchased: true))
        XCTAssertEqual(StoreManager.removeAdsProductID, "com.karemichi.removeads")
    }

    func testDiagnosisEventAndRecurringBranches() {
        let axes = PlayStyleAxes(intuition: 0.9,
                                 exploration: 0.4,
                                 caution: 0.3,
                                 flexibility: 0.2)
        let outcome = EventOutcome(eventID: "test",
                                   theme: .decision,
                                   choiceText: "灯りを選ぶ",
                                   impliedAxis: .intuition)
        XCTAssertTrue(Diagnosis.eventReflection(outcome: outcome, axes: axes)?
            .contains("よく重なって") == true)
        XCTAssertNil(Diagnosis.recurringArchetype(recentAxes: Array(repeating: axes,
                                                                    count: 13)))
        XCTAssertNotNil(Diagnosis.recurringArchetype(recentAxes: Array(repeating: axes,
                                                                       count: 14)))

        var early = RunLog()
        early.staminaMax = 1_000
        early.staminaRemaining = 700
        XCTAssertNotNil(Diagnosis.conditionalRareText(log: early))
    }

    @MainActor
    func testShareImageRendersAtRetinaResolution() throws {
        var log = RunLog()
        log.reachedGoal = true
        log.steps = 84
        log.exploredCellCount = 72
        log.openCellCount = 100
        log.chestOpened = true
        let archetype = Diagnosis.archetype(for: .neutral)
        let keepsake = Keepsake.earned(seed: 20_260_809, reachedGoal: true)
        let content = ShareCardContent(log: log,
                                       archetype: archetype,
                                       traveler: .wanderer,
                                       date: Date(timeIntervalSince1970: 1_775_000_000),
                                       currentStreak: 7,
                                       keepsake: keepsake)
        let image = try XCTUnwrap(ShareImageRenderer.render(content: content))
        XCTAssertEqual(image.size.width * image.scale, 1_920, accuracy: 1)
        XCTAssertEqual(image.size.height * image.scale, 2_400, accuracy: 1)
        XCTAssertEqual(content.currentStreak, 7)
        XCTAssertEqual(content.keepsakeName, keepsake?.name)
        XCTAssertEqual(content.explorationPercent, 72)
        XCTAssertEqual(content.chestCount, 1)
    }

    func testShareContentIsStableAndEarlyExitOmitsGoalOnlyValues() {
        var cleared = RunLog()
        cleared.reachedGoal = true
        cleared.steps = 51
        cleared.exploredCellCount = 35
        cleared.openCellCount = 50
        let archetype = Diagnosis.archetype(for: .neutral)
        let date = Date(timeIntervalSince1970: 1_775_000_000)
        let keepsake = Keepsake.earned(seed: 20_260_809, reachedGoal: true)

        let first = ShareCardContent(log: cleared,
                                     archetype: archetype,
                                     traveler: .owl,
                                     date: date,
                                     currentStreak: 3,
                                     keepsake: keepsake)
        let restoredEquivalent = ShareCardContent(log: cleared,
                                                  archetype: archetype,
                                                  traveler: .owl,
                                                  date: date,
                                                  currentStreak: 3,
                                                  keepsake: keepsake)
        XCTAssertEqual(first, restoredEquivalent)

        var earlyExit = cleared
        earlyExit.reachedGoal = false
        let early = ShareCardContent(log: earlyExit,
                                     archetype: archetype,
                                     traveler: .owl,
                                     date: date,
                                     currentStreak: 3,
                                     keepsake: keepsake)
        XCTAssertEqual(early.currentStreak, 0)
        XCTAssertNil(early.keepsakeName)
        XCTAssertFalse(early.reachedGoal)
    }

    private func mazeSnapshot(_ maze: Maze) -> String {
        var text = ""
        for y in 0..<maze.height {
            for x in 0..<maze.width {
                let coord = Coord(x: x, y: y)
                if maze.isWall(coord) {
                    text.append("#")
                } else if coord == maze.start {
                    text.append("S")
                } else if coord == maze.goal {
                    text.append("G")
                } else {
                    switch maze.gimmick(at: coord) {
                    case .chest: text.append("C")
                    case .warp: text.append("W")
                    case .none: text.append(".")
                    }
                }
            }
            text.append("\n")
        }
        return text
    }

    private func allCells(in maze: Maze) -> [Coord] {
        (0..<maze.height).flatMap { y in
            (0..<maze.width).map { x in Coord(x: x, y: y) }
        }
    }

    private func openNeighbor(of cell: Coord, in maze: Maze) -> Coord? {
        Direction.allCases.map { cell.moved($0) }.first(where: maze.isOpen)
    }

    private func direction(from: Coord, to: Coord) -> Direction {
        Direction.allCases.first { from.moved($0) == to }!
    }

    private func advance(_ game: MazeGame, along path: [Coord]) {
        for cell in path.dropFirst() { game.advance(to: cell) }
    }

    private func advanceWithoutStamina(_ game: MazeGame, along path: [Coord]) {
        for cell in path.dropFirst() { game.advance(to: cell, arrivedByWarp: true) }
    }

    private func shortestPath(in maze: Maze, from start: Coord, to target: Coord) -> [Coord]? {
        var parent: [Coord: Coord] = [:]
        var seen: Set<Coord> = [start]
        var queue: [Coord] = [start]
        var head = 0

        while head < queue.count {
            let cell = queue[head]
            head += 1
            if cell == target { break }
            for direction in Direction.allCases {
                let next = cell.moved(direction)
                guard maze.isOpen(next), seen.insert(next).inserted else { continue }
                parent[next] = cell
                queue.append(next)
            }
        }
        guard seen.contains(target) else { return nil }

        var path = [target]
        while let previous = parent[path.last!], path.last != start {
            path.append(previous)
        }
        return path.reversed()
    }

    private func set(_ value: Double,
                     axis: KareMichi.Axis,
                     axes: inout PlayStyleAxes) {
        switch axis {
        case .intuition: axes.intuition = value
        case .exploration: axes.exploration = value
        case .caution: axes.caution = value
        case .flexibility: axes.flexibility = value
        }
    }

    @MainActor
    private func renderVisual<V: View>(_ view: V,
                                       size: CGSize,
                                       name: String,
                                       path: String) throws {
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        let controller = UIHostingController(rootView: view.environment(\.colorScheme, .dark))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.frame = window.bounds
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            XCTAssertTrue(controller.view.drawHierarchy(in: controller.view.bounds,
                                                        afterScreenUpdates: true))
        }
        XCTAssertEqual(image.size.width, size.width)
        XCTAssertEqual(image.size.height, size.height)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        try XCTUnwrap(image.pngData()).write(to: URL(fileURLWithPath: path),
                                             options: .atomic)
        window.isHidden = true
    }

    @MainActor
    private final class StubAdConsentProvider: AdConsentProviding {
        let canRequestAds: Bool
        private(set) var requestCount = 0

        init(canRequestAds: Bool) {
            self.canRequestAds = canRequestAds
        }

        func requestConsent(completion: @escaping (Bool) -> Void) {
            requestCount += 1
            completion(canRequestAds)
        }
    }

    @MainActor
    private final class HoldingAdConsentProvider: AdConsentProviding {
        private(set) var requestCount = 0

        func requestConsent(completion: @escaping (Bool) -> Void) {
            requestCount += 1
            // Consent gatheringを再現し、意図的にcompletionを保留する。
        }
    }
}
