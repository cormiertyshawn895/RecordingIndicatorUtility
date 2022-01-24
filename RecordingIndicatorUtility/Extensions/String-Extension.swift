//
//  String-Extension.swift
//  Recording Indicator Utility
//

import Foundation

extension String {
    var lastPathComponent: String {
        return (self as NSString).lastPathComponent
    }
    
    var lastPathComponentWithoutExtension: String {
        return (lastPathComponent as NSString).deletingPathExtension
    }

    var rootBundlePath: String {
        return self.rootPathUntilExtension("app") ?? self.rootPathUntilExtension("prefPane") ?? self
    }
    
    var fileSystemString: String {
        let cStr = (self as NSString).fileSystemRepresentation
        let swiftString = String(cString: cStr)
        return swiftString
    }
    
    func rootPathUntilExtension(_ extensionString: String) -> String? {
        let separatedByExtension = self.components(separatedBy: ".\(extensionString)/")
        if (separatedByExtension.count > 1) {
            if let first = separatedByExtension.first {
                return first.appending(".\(extensionString)")
            }
        }
        return nil
    }
    
    func groups(for regexPattern: String) -> [[String]] {
        do {
            let text = self
            let regex = try NSRegularExpression(pattern: regexPattern)
            let matches = regex.matches(in: text,
                                        range: NSRange(text.startIndex..., in: text))
            return matches.map { match in
                return (0..<match.numberOfRanges).map {
                    let rangeBounds = match.range(at: $0)
                    guard let range = Range(rangeBounds, in: text) else {
                        return ""
                    }
                    return String(text[range])
                }
            }
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
}
