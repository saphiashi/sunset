import XCTest
@testable import SunsetLog

final class RankingTests: XCTestCase {
    func testEmptyLadderNeedsNoQuestions() {
        let comparison = RankComparison(ladderCount: 0)
        XCTAssertTrue(comparison.isComplete)
        XCTAssertNil(comparison.probe)
        XCTAssertEqual(comparison.insertionIndex, 0)
    }

    func testBestEverLandsOnTop() {
        var comparison = RankComparison(ladderCount: 7)
        var asked = 0
        while !comparison.isComplete {
            comparison.answer(newIsBetter: true)
            asked += 1
        }
        XCTAssertEqual(comparison.insertionIndex, 0)
        XCTAssertLessThanOrEqual(asked, 3)
    }

    func testWorstEverLandsAtBottom() {
        var comparison = RankComparison(ladderCount: 7)
        while !comparison.isComplete {
            comparison.answer(newIsBetter: false)
        }
        XCTAssertEqual(comparison.insertionIndex, 7)
    }

    func testFindsMiddleSlotAgainstHiddenTruth() {
        // Ladder holds "true" qualities best-first; the new sky is 0.55.
        let ladder: [Double] = [0.95, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1]
        var comparison = RankComparison(ladderCount: ladder.count)
        while let probe = comparison.probe {
            comparison.answer(newIsBetter: 0.55 > ladder[probe])
        }
        XCTAssertEqual(comparison.insertionIndex, 5)
    }

    func testSettleStopsAtProbe() {
        var comparison = RankComparison(ladderCount: 10)
        let probe = comparison.probe
        comparison.settle()
        XCTAssertTrue(comparison.isComplete)
        XCTAssertEqual(comparison.insertionIndex, probe)
    }

    func testRemainingIsLogarithmic() {
        XCTAssertEqual(RankComparison(ladderCount: 1).remaining, 1)
        XCTAssertEqual(RankComparison(ladderCount: 3).remaining, 2)
        XCTAssertEqual(RankComparison(ladderCount: 100).remaining, 7)
    }

    func testScoresStayInsideTierAndDescend() {
        for tier in RankTier.allCases {
            let scores = RankScore.scores(count: 9, tier: tier)
            XCTAssertEqual(scores, scores.sorted(by: >))
            XCTAssertTrue(scores.allSatisfy { tier.scoreRange.contains($0) })
        }
        XCTAssertEqual(RankScore.scores(count: 1, tier: .unforgettable), [8.5])
    }
}
