import Foundation

/// A bounded window into a result collection for incremental UI presentation.
public struct ResultPage: Equatable, Sendable {
    public let pageIndex: Int
    public let pageSize: Int
    public let itemCount: Int

    public init(pageIndex: Int, pageSize: Int, itemCount: Int) {
        let safePageSize = max(1, pageSize)
        let safeItemCount = max(0, itemCount)
        let pageCount = safeItemCount == 0 ? 0 : 1 + (safeItemCount - 1) / safePageSize

        self.pageIndex = pageCount == 0 ? 0 : min(max(0, pageIndex), pageCount - 1)
        self.pageSize = safePageSize
        self.itemCount = safeItemCount
    }

    public var pageCount: Int {
        itemCount == 0 ? 0 : 1 + (itemCount - 1) / pageSize
    }

    public var range: Range<Int> {
        let lowerBound = pageIndex * pageSize
        let countOnPage = min(pageSize, itemCount - lowerBound)
        return lowerBound..<(lowerBound + countOnPage)
    }

    public var hasPrevious: Bool { pageIndex > 0 }
    public var hasNext: Bool { pageIndex + 1 < pageCount }
}
