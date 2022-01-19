//
//  ViewController.swift
//  Recording Indicator Utility
//

import Cocoa
import AVFAudio

let tempSystemMountPath = "/tmp/system_mount"

class ViewController: NSViewController {
    @IBOutlet weak var dateTimeLabel: NSTextField!
    @IBOutlet weak var statusItemImageView: NSImageView!
    @IBOutlet weak var previewImageView: NSImageView!
    @IBOutlet weak var boxView: NSBox!
    @IBOutlet weak var imageGradientView: NSBox!
    @IBOutlet weak var updateButton: NSButton!
    @IBOutlet weak var indicatorSwitch: NSSwitch!
    @IBOutlet weak var progressSpinner: NSProgressIndicator!
    @IBOutlet weak var indicatorDescription: NSTextField!
    @IBOutlet weak var learnMoreButton: NSButton!
    @IBOutlet weak var raiseSecurityButton: NSButton!
    var sheetViewController: SheetViewController?
    var waitingForRestart: String? {
        set {
            UserDefaults.standard.setValue(newValue, forKey: "WaitingForRestart")
        }
        get {
            return UserDefaults.standard.value(forKey: "WaitingForRestart") as? String
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if (waitingForRestart != SystemInformation.shared.lastSystemBootTime) {
            waitingForRestart = nil
        }
        checkForTranslation()
        reloadSwitchState()
        reloadUpdateButton()
        setUpShadow()
        updatePreviewDate()
        updateUI()
        checkForVersionCompatibility()
        sheetViewController = SheetViewController.instantiate()
    }
    
    func checkForTranslation() {
        if SystemInformation.shared.isTranslated {
            print("This process is translated.")
            AppDelegate.showOptionSheet(title: "You need to open Recording Indicator Utility without Rosetta.", text: "In Finder, right click on Recording Indicator Utility, choose Get Info, and uncheck “Open using Rosetta”. Then double click to open Recording Indicator Utility again.", firstButtonText: "OK", secondButtonText: "", thirdButtonText: "") { response in
                NSApplication.shared.terminate(self)
            }
        }
    }
    
    func reloadSwitchState(_ animated: Bool = true) {
        let state: NSControl.StateValue = (SystemInformation.shared.computedRecordingIndicatorOn && waitingForRestart == nil) ? .on : .off
        if (animated) {
            indicatorSwitch.animator().state = state
        } else {
            indicatorSwitch.state = state
        }
    }
    
    func reloadUpdateButton() {
        let hasNewerVersion = SystemInformation.shared.hasNewerVersion
        updateButton.isHidden = !hasNewerVersion
        statusItemImageView.isHidden = hasNewerVersion
        dateTimeLabel.isHidden = hasNewerVersion
    }
    
    func setUpShadow() {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.14)
        shadow.shadowOffset = NSSize(width: 0, height: 2)
        shadow.shadowBlurRadius = 13
        boxView.shadow = shadow
    }
    
    func updatePreviewDate() {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM d  h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let date = Calendar.current.date(bySettingHour: 9, minute: 41, second: 0, of: Date()) else {
            return
        }
        dateTimeLabel.stringValue = formatter.string(from: date)
    }
    
    func updateUI() {
        let indicatorOn = indicatorSwitch.state == .on
        if (indicatorOn) {
            indicatorDescription.stringValue = "When microphone is in use, an orange recording indicator light appears on all connected displays."
        } else {
            indicatorDescription.stringValue = (waitingForRestart != nil) ? "After restarting your Mac, no recording indicator light will be shown when microphone is in use." : "No recording indicator light is shown when microphone is in use, making it ideal for live events and screencasts."
        }
        previewImageView.image = NSImage(named: indicatorOn ? "preview-on" : "preview-off")
        let showRaiseSecurityButton = indicatorOn && SystemInformation.shared.canRaiseSecurity
        learnMoreButton.isHidden = showRaiseSecurityButton || (waitingForRestart != nil)
        raiseSecurityButton.isHidden = !learnMoreButton.isHidden
        raiseSecurityButton.title = (waitingForRestart != nil) ? "Restart Now" : "Raise Security Settings"
    }
    
    func checkForVersionCompatibility() {
        let processInfo = ProcessInfo()
        let osFullVersion = ProcessInfo.processInfo.operatingSystemVersion
        let osNotRecognized = processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 13, minorVersion: 0, patchVersion: 0))
        if !osNotRecognized {
            return;
        }
        AppDelegate.showOptionSheet(title: "Update to the latest version of Recording Indicator Utility.",
                                    text: "This version of Recording Indicator Utility is only designed and tested for macOS Monterey, and does not support macOS \(osFullVersion.majorVersion).",
                                    firstButtonText: "Check for Updates",
                                    secondButtonText: "Continue Anyways",
                                    thirdButtonText: "Quit") { (response) in
            if (response == .alertFirstButtonReturn) {
                AppDelegate.current.checkForUpdates()
            } else if (response == .alertSecondButtonReturn) {
            } else {
                NSApplication.shared.terminate(self)
            }
        }
    }
    
    func updateIndicatorInjection() {
        if (SystemInformation.runUnameToPreAuthenticate() != errAuthorizationSuccess) {
            self.reloadSwitchState()
            return
        }
        
        let alreadyInstalled = SystemInformation.shared.isModificationInstalled
        let configFilePath = "\(injectionFolderPath)/\(injectionWantsIndicatorFileName)"
        let wantsIndicatorOn = indicatorSwitch.state == .on
        if (wantsIndicatorOn) {
            print("User wants indicator on")
            waitingForRestart = nil
            _ = SystemInformation.runTask(toolPath: "/usr/bin/touch", arguments: [configFilePath])
            if (alreadyInstalled) {
                self.startZeroSecondRecording()
            }
            updateUI()
        } else {
            print("User wants indicator off")
            _ = SystemInformation.runTask(toolPath: "/bin/rm", arguments: [configFilePath])
            if (alreadyInstalled) {
                self.startZeroSecondRecording()
                updateUI()
            } else {
                beginAsyncInstallInjection()
            }
        }
    }
    
    func startZeroSecondRecording() {
        // Begin a 0 second long recording to force WindowServer and Control Center refresh their recording state.
        // No audio is actually recorded or saved.
        let url = URL(fileURLWithPath: (NSTemporaryDirectory() as NSString).appendingPathComponent("discarded"))
        do {
            let recorder = try AVAudioRecorder(url: url, settings: [:])
            recorder.record(forDuration: 0)
        } catch {
            print("Unable to simulate a zero second recording to refresh microphone indicator, \(error)")
        }
        updateUI()
    }
    
    func beginAsyncInstallInjection(_ install: Bool = true) {
        if (!install) {
            self.waitingForRestart = nil
        }
        setActionButtonAvailability(available: false)
        DispatchQueue.global(qos: .userInteractive).async {
            let result = self.sync_installInjection(install)
            print("\(install ? "Install" : "Uninstall") result is \(result)")
            if (install) {
                self.waitingForRestart = SystemInformation.shared.lastSystemBootTime
            }
            DispatchQueue.main.async {
                self.setActionButtonAvailability(available: true)
                self.updateUI()
                if (install) {
                    AppDelegate.showOptionSheet(title: "Turning off the recording indicator light requires a restart to take effect.", text: "Do you want to restart now?", firstButtonText: "Restart Now", secondButtonText: "Not Now", thirdButtonText: "") { response in
                        if (response == .alertFirstButtonReturn) {
                            self.performReboot()
                        }
                    }
                }
            }
        }
    }
    
    func sync_installInjection(_ install: Bool = true) -> Bool {
        let frameworkPath = Bundle.main.privateFrameworksPath!.fileSystemString
        let mount = Process.runNonAdminTask(toolPath: "/sbin/mount", arguments: [])
        let alreadyMounted = mount.contains(tempSystemMountPath)
        print(mount)
        let splitByLine = mount.split(whereSeparator: \.isNewline)
        guard let first = splitByLine.first else {
            print("Unable to locate system volume from mount output")
            return false
        }
        let firstLine = String(first)
        print("First line in mount output is \(firstLine)")
        let matches = firstLine.groups(for: #"(\/dev\/)(.*)s1"#)
        guard let systemVolumeIdentifier = matches.first?.last else {
            return false
        }
        if (!alreadyMounted) {
            _ = SystemInformation.runTask(toolPath: "/bin/mkdir", arguments: ["-p", tempSystemMountPath])
            _ = SystemInformation.runTask(toolPath: "/sbin/mount", arguments: ["-o", "nobrowse", "-t", "apfs", "/dev/\(systemVolumeIdentifier)", tempSystemMountPath])
        }
        if (install) {
            let injectionDylibPath = "\(injectionFolderPath)/\(injectionDylibName)"
            
            // Install dylib
            _ = SystemInformation.runTask(toolPath: "/bin/mkdir", arguments: ["-p", injectionFolderPath])
            _ = SystemInformation.runTask(toolPath: "/bin/cp", arguments: ["\(frameworkPath)/RecordingIndicatorInjection.framework/Versions/A/RecordingIndicatorInjection", injectionDylibPath])
            _ = SystemInformation.runTask(toolPath: "/usr/bin/xattr", arguments: ["-d", "com.apple.quarantine", injectionDylibPath])
            _ = SystemInformation.runTask(toolPath: "/bin/rm", arguments: ["\(injectionFolderPath)/\(injectionWantsIndicatorFileName)"])
            
            // Allow injection
            _ = SystemInformation.runTask(toolPath: "/usr/bin/defaults", arguments: ["write", "/Library/Preferences/com.apple.security.libraryvalidation", "DisableLibraryValidation", "-bool", "true"])
            
            // Modify WindowServer and Control Center environment variable
            let dyldDict = "<dict><key>DYLD_INSERT_LIBRARIES</key><string>\(injectionDylibPath)</string></dict>"
            _ = SystemInformation.runTask(toolPath: "/usr/bin/plutil", arguments: ["-insert", "EnvironmentVariables", "-xml", dyldDict, "\(tempSystemMountPath)/System/Library/LaunchDaemons/com.apple.WindowServer.plist"])
            _ = SystemInformation.runTask(toolPath: "/usr/bin/plutil", arguments: ["-insert", "EnvironmentVariables", "-xml", dyldDict, "\(tempSystemMountPath)/System/Library/LaunchAgents/com.apple.controlcenter.plist"])
            
            // Bless snapshot
            _ = SystemInformation.runTask(toolPath: "/usr/sbin/bless", arguments: ["--mount", tempSystemMountPath, "--bootefi", "--create-snapshot"])
        } else {
            _ = SystemInformation.runTask(toolPath: "/usr/sbin/bless", arguments: ["--mount", tempSystemMountPath, "--bootefi", "--last-sealed-snapshot"])
            /* We cannot yank out indicator_injection.dylib or re-enable library validation. Doing so breaks WindowServer and Control
             Center for this boot. Once the user raises their security settings in recoveryOS, the custom library validation flag
             is automatically ignored.
             */
        }
        _ = SystemInformation.runTask(toolPath: "/usr/sbin/diskutil", arguments: ["unmount", "force", tempSystemMountPath])
        print("matches are \(matches)")
        return true
    }
    
    func setActionButtonAvailability(available: Bool) {
        AppDelegate.current.shouldPreventClosing = !available
        indicatorSwitch.isHidden = !available
        raiseSecurityButton.isEnabled = available
        progressSpinner.isHidden = available
        if (available) {
            progressSpinner.stopAnimation(nil)
        } else {
            progressSpinner.startAnimation(nil)
        }
    }
    
    func performReboot() {
        _ = SystemInformation.runTask(toolPath: "/sbin/reboot", arguments: [])
    }
    
    func applyRaisedSecuritySettings(_ isAlreadySealed: Bool = false) {
        if (SystemInformation.runUnameToPreAuthenticate() != errAuthorizationSuccess) {
            print("Unable to raise security because authentication failed")
            return
        }
        self.beginAsyncInstallInjection(false)
        if let sheetVC = self.sheetViewController {
            let isAppleSilicon = SystemInformation.shared.isAppleSilicon
            if (isAlreadySealed) {
                sheetVC.guidanceType = isAppleSilicon ? .asRaisingAlreadySealed : .intelRaisingAlreadySealed
            } else {
                sheetVC.guidanceType = isAppleSilicon ? .asRaising : .intelRaising
            }
            self.presentAsSheet(sheetVC)
        }
    }
    
    @IBAction func updateAvailableClicked(_ sender: Any) {
        AppDelegate.current.promptForUpdateAvailable()
    }
    
    @IBAction func indicatorSwitchToggled(_ sender: Any) {
        if (SystemInformation.shared.securityAllowsToggling) {
            updateIndicatorInjection()
            return
        }
        
        if (SystemInformation.shared.isFileVaultEnabled) {
            let decryptionProgress = SystemInformation.shared.fileVaultDecryptionProgress
            let title = (decryptionProgress != nil) ? "To configure the recording indicator, FileVault needs to finish decrypting." : "To configure the recording indicator, you need to turn off FileVault first."
            let text = (decryptionProgress != nil) ? "FileVault decryption is \(decryptionProgress!)% complete. You can follow along the latest progress in the FileVault pane of Security & Privacy preferences." : "Open the FileVault pane of Security & Privacy preferences. Click the lock to make changes, then click Turn Off FileVault."
            AppDelegate.showOptionSheet(title: title, text: text, firstButtonText: "Open FileVault Preferences", secondButtonText: "Cancel", thirdButtonText: "") { response in
                self.reloadSwitchState()
                if (response == .alertFirstButtonReturn) {
                    AppDelegate.current.safelyOpenURL("x-apple.systempreferences:com.apple.preference.security?FDE")
                }
            }
            return
        }
        if (SystemInformation.shared.isSIPEnabled || SystemInformation.shared.isAuthenticatedRootEnabled) {
            if let sheetVC = sheetViewController {
                sheetVC.guidanceType = SystemInformation.shared.isAppleSilicon ? .asLowering : .intelLowering
                self.presentAsSheet(sheetVC)
                reloadSwitchState()
            }
            return
        }
    }
    
    @IBAction func raiseSecurityButtonClicked(_ sender: Any) {
        // "Restart Now"
        if (waitingForRestart != nil) {
            performReboot()
            return
        }
        
        // "Raise Security Settings"
        let systemAlreadySealed = Process.runNonAdminTask(toolPath: "/usr/sbin/diskutil", arguments: ["apfs", "listSnapshots", "/"]).contains("1 found")
        if (systemAlreadySealed) {
            self.applyRaisedSecuritySettings(true)
            return
        }
        AppDelegate.showOptionSheet(title: "Apply last sealed system snapshot", text: "Before raising the security setting of your Mac, Recording Indicator Utility must apply the last sealed system snapshot. This only affects the macOS system volume and does not affect your apps or data.\n\nIf your Mac misbehaves after continuing, choose Apple menu > Restart or force restart. Once your Mac starts up, reopen Recording Indicator Utility to repeat this process.", firstButtonText: "Continue", secondButtonText: "Cancel", thirdButtonText: "") { response in
            if (response == .alertFirstButtonReturn) {
                self.applyRaisedSecuritySettings()
            }
        }
    }
    
    @IBAction func learnMoreButtonClicked(_ sender: Any) {
        AppDelegate.current.safelyOpenURL("https://github.com/cormiertyshawn895/RecordingIndicatorUtility")
    }
}

