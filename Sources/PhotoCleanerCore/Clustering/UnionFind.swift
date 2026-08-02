import Foundation

/// Classic disjoint-set-union structure used to build duplicate clusters from pairwise
/// "these two are similar" decisions without an O(n^2) grouping pass.
public struct UnionFind {
    private var parent: [Int]
    private var rank: [Int]

    public init(count: Int) {
        parent = Array(0..<count)
        rank = Array(repeating: 0, count: count)
    }

    public mutating func find(_ x: Int) -> Int {
        if parent[x] != x {
            parent[x] = find(parent[x])
        }
        return parent[x]
    }

    public mutating func union(_ a: Int, _ b: Int) {
        let rootA = find(a)
        let rootB = find(b)
        guard rootA != rootB else { return }
        if rank[rootA] < rank[rootB] {
            parent[rootA] = rootB
        } else if rank[rootA] > rank[rootB] {
            parent[rootB] = rootA
        } else {
            parent[rootB] = rootA
            rank[rootA] += 1
        }
    }

    /// Returns groups of original indices, keyed by root, in insertion order (excludes singletons).
    public mutating func groups(excludingSingletons: Bool = true) -> [[Int]] {
        var buckets: [Int: [Int]] = [:]
        for i in 0..<parent.count {
            let root = find(i)
            buckets[root, default: []].append(i)
        }
        let all = buckets.values.map { $0 }
        return excludingSingletons ? all.filter { $0.count > 1 } : all
    }
}
