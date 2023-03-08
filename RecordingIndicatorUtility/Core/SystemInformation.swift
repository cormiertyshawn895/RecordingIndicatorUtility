//
//  SystemInformation.swift
//  Recording Indicator Utility
//

import Foundation

let tempDir = "/tmp"
let disabledTextOldOS = "\"com.apple.systemstatusd\" => true"
let disabledText = "\"com.apple.systemstatusd\" => disabled"

class SystemInformation {
    static let shared = SystemInformation()
    
    private init() {
        let sipStatus = Process.runNonAdminTask(toolPath: "/usr/bin/csrutil", arguments: ["status"])
        isSIPEnabled = !sipStatus.lowercased().contains("disabled")
        isSystemSealed = Process.runNonAdminTask(toolPath: "/usr/sbin/diskutil", arguments: ["apfs", "listSnapshots", "/"]).contains("1 found")

        let lastRebootAll = Process.runNonAdminTask(toolPath: "/usr/bin/last", arguments: ["reboot"])
        let lastRebootByLine = lastRebootAll.split(whereSeparator: \.isNewline)
        if let last = lastRebootByLine.first {
            lastSystemBootTime = String(last)
        }
        
        if let path = Bundle.main.path(forResource: "SupportPath", ofType: "plist"),
            let loaded = NSDictionary(contentsOfFile: path) as? Dictionary<String, Any> {
            self.configurationDictionary = loaded
        }
        
        if (isOutdatedModificationInstalled) {
            _ = Process.runNonAdminTask(toolPath: "/bin/mkdir", arguments: ["-p", "/Users/Shared/.recordingIndicator"])
            _ = Process.runNonAdminTask(toolPath: "/usr/bin/touch", arguments: ["/Users/Shared/.recordingIndicator/wants_indicator"])
            _ = Process.runNonAdminTask(toolPath: "/bin/rm", arguments: ["/Users/Shared/.recordingIndicator/wants_cc_only"])
            _ = Process.runNonAdminTask(toolPath: "/bin/rm", arguments: ["/Users/Shared/.recordingIndicator/exceptions.plist"])
        }
        
        self.checkForConfigurationUpdates()
    }
    
    var isAppleSilicon: Bool {
        return machineArchitectureName.contains("arm") || isTranslated
    }
    
    private(set) public var isSIPEnabled: Bool = true
    private(set) public var isSystemSealed: Bool = true
    private(set) public var lastSystemBootTime: String?
    
    private var isOutdatedModificationInstalled: Bool {
        Process.runNonAdminTask(toolPath: "/bin/cat", arguments: ["/System/Library/LaunchDaemons/com.apple.WindowServer.plist"]).contains("indicator_injection.dylib") || Process.runNonAdminTask(toolPath: "/bin/cat", arguments: ["/System/Library/LaunchAgents/com.apple.controlcenter.plist"]).contains("indicator_injection.dylib")
    }
    
    var isSystemstatusdLoaded: Bool {
        let result = Process.runNonAdminTask(toolPath: "/bin/launchctl", arguments: ["print-disabled", "system"])
        let disabled = result.contains(disabledText) || result.contains(disabledTextOldOS)
        return !disabled
    }
    
    var isTranslated: Bool {
        return processIsTranslated == EMULATED_EXECUTION
    }
    
    static func runUnameToPreAuthenticate() -> OSStatus {
        return SystemInformation.runTask(toolPath: "/usr/bin/uname", arguments: ["-a"], path: tempDir, wait: true)
    }
    
    static func runTask(toolPath: String, arguments: [String], path: String = tempDir, wait: Bool = true) -> OSStatus {
        let priviledgedTask = STPrivilegedTask()
        priviledgedTask.launchPath = toolPath
        priviledgedTask.arguments = arguments
        priviledgedTask.currentDirectoryPath = path
        let err: OSStatus = priviledgedTask.launch()
        if (err != errAuthorizationSuccess) {
            if (err == errAuthorizationCanceled) {
                print("User cancelled")
            } else {
                print("Something went wrong with authorization \(err)")
                // For error codes, see http://www.opensource.apple.com/source/libsecurity_authorization/libsecurity_authorization-36329/lib/Authorization.h
            }
            print("Critical error: Failed to authenticate")
            return err
        }
        if wait == true {
            priviledgedTask.waitUntilExit()
        }
        let readHandle = priviledgedTask.outputFileHandle
        if let outputData = readHandle?.readDataToEndOfFile(), let outputString = String(data: outputData, encoding: .utf8) {
            print("Output string is \(outputString), terminationStatus is \(priviledgedTask.terminationStatus)")
        }
        return err
    }
    
    let NATIVE_EXECUTION = Int32(0)
    let EMULATED_EXECUTION = Int32(1)
    let UNKNOWN_EXECUTION = -Int32(1)
    
    private var processIsTranslated: Int32 {
        let key = "sysctl.proc_translated"
        var ret = Int32(0)
        var size: Int = 0
        sysctlbyname(key, nil, &size, nil, 0)
        let result = sysctlbyname(key, &ret, &size, nil, 0)
        if result == -1 {
            if errno == ENOENT {
                return 0
            }
            return -1
        }
        return ret
    }
    
    private var machineArchitectureName: String {
        var sysinfo = utsname()
        let result = uname(&sysinfo)
        guard result == EXIT_SUCCESS else { return "unknown" }
        let data = Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN))
        guard let identifier = String(bytes: data, encoding: .ascii) else { return "unknown" }
        return identifier.trimmingCharacters(in: .controlCharacters)
    }
    
    // MARK: - Update Configuration
    func checkForConfigurationUpdates() {
        guard let support = self.supportPath, let configurationPath = URL(string: support) else { return }
        self.downloadAndParsePlist(plistPath: configurationPath) { (newDictionary) in
            self.configurationDictionary = newDictionary
        }
    }
    
    func downloadAndParsePlist(plistPath: URL, completed: @escaping ((Dictionary<String, Any>) -> ())) {
        let task = URLSession.shared.dataTask(with: plistPath) { (data, response, error) in
            if error != nil {
                print("Error loading \(plistPath). \(String(describing: error))")
            }
            do {
                let data = try Data(contentsOf:plistPath)
                if let newDictionary = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? Dictionary<String, Any> {
                    print("Downloaded dictionary \(String(describing: self.configurationDictionary))")
                    completed(newDictionary)
                }
            } catch {
                print("Error loading fetched support data. \(error)")
            }
        }
        
        task.resume()
    }
    
    func refreshUpdateBadge() {
        self.syncMainQueue {
            if self.hasNewerVersion {
                print("update available")
                AppDelegate.rootVC?.reloadUpdateButton()
            }
        }
    }
    
    var hasNewerVersion: Bool {
        get {
            if let versionNumber = Bundle.main.cfBundleVersionInt, let remoteVersion = self.latestBuildNumber {
                print("\(versionNumber), \(remoteVersion)")
                if (versionNumber < remoteVersion) {
                    return true
                }
            }
        return false
        }
    }
    
    private var configurationDictionary: Dictionary<String, Any>? {
        didSet {
            self.refreshUpdateBadge()
        }
    }
    
    var newVersionVisibleTitle: String? {
        return configurationDictionary?["NewVersionVisibleTitle"] as? String
    }

    var newVersionChangelog: String? {
        return configurationDictionary?["NewVersionChangelog"] as? String
    }
    
    var latestZIP: String? {
        return configurationDictionary?["LatestZIP"] as? String
    }
    
    var latestBuildNumber: Int? {
        return configurationDictionary?["LatestBuildNumber"] as? Int
    }
    
    var supportPath: String? {
        return configurationDictionary?["SupportPathURL"] as? String
    }
    
    var releasePage: String? {
        return configurationDictionary?["ReleasePage"] as? String
    }
    
}
