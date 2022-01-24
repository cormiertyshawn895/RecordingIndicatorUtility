//
//  RangeReplaceableCollection-Extension.swift
//  Recording Indicator Utility
//

import Foundation

extension RangeReplaceableCollection where Self: MutableCollection, Index == Int {
    
    mutating func remove(at indexes : IndexSet) {
        guard var i = indexes.first, i < count else { return }
        var j = index(after: i)
        var k = indexes.integerGreaterThan(i) ?? endIndex
        while j != endIndex {
            if k != j { swapAt(i, j); formIndex(after: &i) }
            else { k = indexes.integerGreaterThan(k) ?? endIndex }
            formIndex(after: &j)
        }
        removeSubrange(i...)
    }
}

