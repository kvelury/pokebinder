import Foundation
import PokeBinderGrid

func continuousGridLayoutTests() -> [TestCase] {
    let cardCount = 151
    let columns = ContinuousGridLayout.columns
    let rows = ContinuousGridLayout.rows(cardCount: cardCount)

    return [
        TestCase(name: "continuousGridIsFourteenByEleven") {
            try expectEqual(columns, 14)
            try expectEqual(rows, 11)
            try expectEqual(columns * (rows - 1), 140)
            try expectEqual(cardCount - columns * (rows - 1), 11)
        },
        TestCase(name: "continuousGridDexPositionsFollowRowMajorOrder") {
            try expectEqual(ContinuousGridLayout.dex(row: 0, column: 0, cardCount: cardCount), 1)
            try expectEqual(ContinuousGridLayout.dex(row: 0, column: 13, cardCount: cardCount), 14)
            try expectEqual(ContinuousGridLayout.dex(row: 1, column: 0, cardCount: cardCount), 15)
            try expectEqual(ContinuousGridLayout.dex(row: 10, column: 10, cardCount: cardCount), 151)
            try expectEqual(ContinuousGridLayout.dex(row: 10, column: 11, cardCount: cardCount), nil)
        },
        TestCase(name: "continuousGridAnchorMapsViewportCentreToNearestCard") {
            let cardWidth = 80.0
            let cardHeight = 112.0
            let gap = 7.2

            try expectEqual(
                ContinuousGridLayout.anchorDex(
                    offsetX: 0,
                    offsetY: 0,
                    viewportWidth: 80,
                    viewportHeight: 112,
                    cardCount: cardCount,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    gap: gap
                ),
                1
            )

            let strideX = cardWidth + gap
            let strideY = cardHeight + gap
            try expectEqual(
                ContinuousGridLayout.anchorDex(
                    offsetX: strideX * 13,
                    offsetY: strideY * 10,
                    viewportWidth: 80,
                    viewportHeight: 112,
                    cardCount: cardCount,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    gap: gap
                ),
                151
            )
        },
        TestCase(name: "continuousGridEmptyLastRowCellsClampToMew") {
            try expectEqual(
                ContinuousGridLayout.anchorDex(
                    offsetX: 2000,
                    offsetY: 5000,
                    viewportWidth: 100,
                    viewportHeight: 100,
                    cardCount: cardCount,
                    cardWidth: 80,
                    cardHeight: 112,
                    gap: 7.2
                ),
                151
            )
        }
    ]
}
