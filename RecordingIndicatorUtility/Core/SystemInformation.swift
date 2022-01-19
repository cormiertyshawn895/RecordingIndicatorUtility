//
//  SystemInformation.swift
//  Recording Indicator Utility
//

import Foundation

let tempDir = "/tmp"
let injectionFolderPath = "/Users/Shared/.recordingIndicator"
let injectionDylibName = "indicator_injection.dylib"
let injectionWantsIndicatorFileName = "wants_indicator"

let hasSeveralMacOSString = "several macOS installations"
let pickAMacOSString = "Pick a macOS installation"

class SystemInformation {
    static let shared = SystemInformation()
    
    private init() {
        let sipStatus = Process.runNonAdminTask(toolPath: "/usr/bin/csrutil", arguments: ["status"])
        isSIPEnabled = !sipStatus.lowercased().contains("disabled")
        
        let processInfo = ProcessInfo()
        isLegacyOS = !processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 12, minorVersion: 2, patchVersion: 0))
        
        _oneTimeCheckAuthenticatedRoot()
        
        let lastRebootAll = Process.runNonAdminTask(toolPath: "/usr/bin/last", arguments: ["reboot"])
        let lastRebootByLine = lastRebootAll.split(whereSeparator: \.isNewline)
        if let last = lastRebootByLine.first {
            lastSystemBootTime = String(last)
        }
        
        if let path = Bundle.main.path(forResource: "SupportPath", ofType: "plist"),
            let loaded = NSDictionary(contentsOfFile: path) as? Dictionary<String, Any> {
            self.configurationDictionary = loaded
        }
        
        self.checkForConfigurationUpdates()
    }
    
    func _oneTimeCheckAuthenticatedRoot() {
        guard let systemVolumeName = FileManager.default.componentsToDisplay(forPath: "/")?.first else {
            return
        }
        self.updateAuthenticatedRootEnabledForVolume(volumeName: systemVolumeName)
    }

    // Workaround for detecting authenticated-root on Apple Silicon. Assumes volumes order is randomized per try.
    // It's not possible to pipe through live input based on output because of stdout caching. See:
    // https://iosdivin.blog/2020/12/24/the-adventures-with-nstask-co-part-3/
    func updateAuthenticatedRootEnabledForVolume(volumeName: String, depth: Int = 0) {
        let result = Process.runNonAdminTask(toolPath: "/usr/bin/csrutil", arguments: ["authenticated-root"], attemptInteractive: "1\n")
        if result.contains(hasSeveralMacOSString) {
            print("Multiple macOS installed, recursively finding the booted one")
            let splits = result.components(separatedBy: .newlines)
            let firstVolumeRow = splits.first { candidate in
                return candidate.components(separatedBy: ": ").first?.trimmingCharacters(in: .whitespaces) == "1"
            }
            if let firstVolumeName = firstVolumeRow?.components(separatedBy: ": ").dropFirst().joined(separator: ": ") {
                if (firstVolumeName == volumeName) {
                    print("After \(depth + 1) tries, first installation in randomly ordered set match the booted installation \(firstVolumeName)")
                    let statusRow = splits.first { candidate in
                        candidate.contains("Authenticated Root status: ")
                    }
                    if let resultRow = statusRow {
                        print("Result row is \(resultRow)")
                        isAuthenticatedRootEnabled = !resultRow.contains("disabled")
                        return
                    }
                }
            }
            if (depth > 50) {
                AppDelegate.showOptionSheet(title: "Unable to determine if your Mac allows non-sealed system snapshots", text: "You have installed multiple copies of macOS, and Recording Indicator Utility is unable to locate the security status of the booted volume. If you have already allowed booting from non-sealed system snapshots, click Continue Anyways.", firstButtonText: "Continue Anyways", secondButtonText: "Cancel", thirdButtonText: "") { response in
                    if (response == .alertFirstButtonReturn) {
                        self.isAuthenticatedRootEnabled = false
                    } else {
                        self.isAuthenticatedRootEnabled = true
                    }
                }
                return
            }
            updateAuthenticatedRootEnabledForVolume(volumeName: volumeName, depth: depth + 1)
            return
        }

        isAuthenticatedRootEnabled = !result.contains("disabled")
    }
    
    var isAppleSilicon: Bool {
        return machineArchitectureName.contains("arm") || isTranslated
    }
    
    var isFileVaultEnabled: Bool {
        let status = Process.runNonAdminTask(toolPath: "/usr/bin/fdesetup", arguments: ["status"])
        return !status.lowercased().contains("off")
    }
    
    var fileVaultDecryptionProgress: String? {
        let status = Process.runNonAdminTask(toolPath: "/usr/bin/fdesetup", arguments: ["status"])
        let components = status.components(separatedBy: "completed = ")
        if components.count < 2 {
            return nil
        }
        return components.last
    }
    
    private(set) public var isLegacyOS: Bool = false
    private(set) public var isSIPEnabled: Bool = true
    private(set) public var isAuthenticatedRootEnabled: Bool = true
    private(set) public var lastSystemBootTime: String?
    
    var isModificationInstalled: Bool {
        return FileManager.default.fileExists(atPath: "\(injectionFolderPath)/\(injectionDylibName)")
        && Process.runNonAdminTask(toolPath: "/usr/bin/defaults", arguments: ["read", "/Library/Preferences/com.apple.security.libraryvalidation", "DisableLibraryValidation"]).contains("1")
        && Process.runNonAdminTask(toolPath: "/bin/cat", arguments: ["/System/Library/LaunchDaemons/com.apple.WindowServer.plist"]).contains("indicator_injection.dylib")
        && Process.runNonAdminTask(toolPath: "/bin/cat", arguments: ["/System/Library/LaunchAgents/com.apple.controlcenter.plist"]).contains("indicator_injection.dylib")
    }
    
    var isWantsIndicatorFilePresent: Bool {
        return FileManager.default.fileExists(atPath: "\(injectionFolderPath)/\(injectionWantsIndicatorFileName)")
    }
    
    var isTranslated: Bool {
        return processIsTranslated == EMULATED_EXECUTION
    }
    
    var securityAllowsToggling: Bool {
        return !isFileVaultEnabled && !isSIPEnabled && !isAuthenticatedRootEnabled
    }
    
    var canRaiseSecurity: Bool {
        return !isSIPEnabled || !isAuthenticatedRootEnabled
    }
    
    var computedRecordingIndicatorOn: Bool {
        return !securityAllowsToggling || !isModificationInstalled || isWantsIndicatorFilePresent
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
