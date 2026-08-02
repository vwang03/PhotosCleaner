import XCTest
@testable import PhotoCleanerCore

final class UnionFindTests: XCTestCase {
    func testSingletonsExcludedByDefault() {
        var uf = UnionFind(count: 5)
        uf.union(0, 1)
        let groups = uf.groups()
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(Set(groups[0]), Set([0, 1]))
    }

    func testTransitiveUnionMergesChain() {
        var uf = UnionFind(count: 5)
        uf.union(0, 1)
        uf.union(1, 2)
        uf.union(3, 4)
        let groups = uf.groups().map { Set($0) }
        XCTAssertEqual(groups.count, 2)
        XCTAssertTrue(groups.contains(Set([0, 1, 2])))
        XCTAssertTrue(groups.contains(Set([3, 4])))
    }

    func testIncludingSingletonsReturnsAllElements() {
        var uf = UnionFind(count: 3)
        uf.union(0, 1)
        let groups = uf.groups(excludingSingletons: false)
        let flattened = groups.flatMap { $0 }
        XCTAssertEqual(Set(flattened), Set([0, 1, 2]))
    }

    func testNoUnionsProducesNoGroupsByDefault() {
        var uf = UnionFind(count: 4)
        XCTAssertTrue(uf.groups().isEmpty)
    }
}
