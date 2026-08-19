public struct ContinuousGridSize: Equatable, Sendable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

/// Pure geometry for the fixed rectangular Continuous grid surface.
public enum ContinuousGridLayout {
    public static let columns = 14

    public static func rows(cardCount: Int) -> Int {
        (cardCount + columns - 1) / columns
    }

    public static func contentSize(
        cardCount: Int,
        cardWidth: Double,
        cardHeight: Double,
        gap: Double
    ) -> ContinuousGridSize {
        let rowCount = rows(cardCount: cardCount)
        let width = Double(columns) * cardWidth + Double(max(columns - 1, 0)) * gap
        let height = Double(rowCount) * cardHeight + Double(max(rowCount - 1, 0)) * gap
        return ContinuousGridSize(width: width, height: height)
    }

    public static func dex(row: Int, column: Int, cardCount: Int) -> Int? {
        let index = row * columns + column + 1
        guard (1...cardCount).contains(index) else { return nil }
        return index
    }

    /// Card nearest the viewport centre. Empty cells on the last row map to the
    /// final card.
    public static func anchorDex(
        offsetX: Double,
        offsetY: Double,
        viewportWidth: Double,
        viewportHeight: Double,
        cardCount: Int,
        cardWidth: Double,
        cardHeight: Double,
        gap: Double
    ) -> Int {
        let rowCount = rows(cardCount: cardCount)
        let strideX = max(cardWidth + gap, 1)
        let strideY = max(cardHeight + gap, 1)
        let column = Int(((offsetX + viewportWidth / 2) / strideX).rounded(.down))
        let row = Int(((offsetY + viewportHeight / 2) / strideY).rounded(.down))
        let clampedColumn = min(max(column, 0), columns - 1)
        let clampedRow = min(max(row, 0), rowCount - 1)
        return dex(row: clampedRow, column: clampedColumn, cardCount: cardCount) ?? cardCount
    }
}
