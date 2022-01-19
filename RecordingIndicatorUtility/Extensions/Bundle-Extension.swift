//
//  Bundle-Extension.swift
//  Recording Indicator Utility
//

import Foundation

let kCFBundleVersion = "CFBundleVersion"
let kCFBundleShortVersionString = "CFBundleShortVersionString"

extension Bundle {
    var cfBundleVersionInt: Int? {
        get {
            if let bundleVersion = self.infoDictionary?[kCFBundleVersion] as? String, let intVersion = Int(bundleVersion) {
                return intVersion
            }
            return nil
        }
    }
    
    var cfBundleVersionString: String? {
        get {
            return self.infoDictionary?[kCFBundleShortVersionString] as? String
        }
    }
}
