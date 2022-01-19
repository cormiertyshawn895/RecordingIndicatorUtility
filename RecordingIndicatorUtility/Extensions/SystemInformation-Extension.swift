//
//  SystemInformation-Extension.swift
//  Recording Indicator Utility
//

import Foundation

extension SystemInformation {
    func syncMainQueue(closure: (() -> ())) {
        if !Thread.isMainThread {
            DispatchQueue.main.sync {
                closure()
            }
        } else {
            closure()
        }
    }
}
