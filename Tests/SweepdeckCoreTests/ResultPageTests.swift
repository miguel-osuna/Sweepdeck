import Testing
@testable import SweepdeckCore

struct ResultPageTests {
    @Test func largeResultsStayBoundedAndPagesPreserveEveryRow() {
        let rows = Array(0..<25_000)
        let pageSize = 100
        let pageCount = ResultPage(pageIndex: 0, pageSize: pageSize, itemCount: rows.count).pageCount
        var displayedRows: [Int] = []

        for pageIndex in 0..<pageCount {
            let page = ResultPage(pageIndex: pageIndex, pageSize: pageSize, itemCount: rows.count)
            #expect(page.range.count <= pageSize)
            displayedRows.append(contentsOf: rows[page.range])
        }

        #expect(pageCount == 250)
        #expect(displayedRows == rows)
    }

    @Test func emptyAndPartialLastPagesHaveSafeRanges() {
        let empty = ResultPage(pageIndex: 0, pageSize: 100, itemCount: 0)
        #expect(empty.pageCount == 0)
        #expect(empty.range.isEmpty)
        #expect(!empty.hasPrevious)
        #expect(!empty.hasNext)

        let last = ResultPage(pageIndex: 4, pageSize: 100, itemCount: 405)
        #expect(last.range == 400..<405)
        #expect(last.hasPrevious)
        #expect(!last.hasNext)
    }

    @Test func invalidPageIndexesAreClampedToAvailableResults() {
        let negative = ResultPage(pageIndex: -1, pageSize: 100, itemCount: 205)
        #expect(negative.pageIndex == 0)
        #expect(negative.range == 0..<100)

        let pastEnd = ResultPage(pageIndex: 99, pageSize: 100, itemCount: 205)
        #expect(pastEnd.pageIndex == 2)
        #expect(pastEnd.range == 200..<205)
    }

    @Test func invalidDimensionsAndVeryLargeRangesStaySafe() {
        let empty = ResultPage(pageIndex: .max, pageSize: 0, itemCount: -1)
        #expect(empty.pageSize == 1)
        #expect(empty.itemCount == 0)
        #expect(empty.range == 0..<0)

        let finalPage = ResultPage(pageIndex: .max, pageSize: 100, itemCount: .max)
        #expect(finalPage.hasPrevious)
        #expect(!finalPage.hasNext)
        #expect(finalPage.range.upperBound == Int.max)
        #expect(finalPage.range.count <= finalPage.pageSize)
    }
}
