//
//  ViewController.swift
//  Recording Indicator Utility
//

import Cocoa

let tempSystemMountPath = "/tmp/system_mount"

enum WaitingForRestartReason: Int {
    case installByTogglingOff, update, exceptionsSheet
}

class ViewController: NSViewController {
    @IBOutlet weak var dateTimeLabel: NSTextField!
    @IBOutlet weak var statusItemImageView: NSImageView!
    @IBOutlet weak var previewImageView: NSImageView!
    @IBOutlet weak var boxView: NSBox!
    @IBOutlet weak var imageGradientView: NSBox!
    @IBOutlet weak var updateButton: NSButton!
    @IBOutlet weak var recordingIndicatorLabel: NSTextField!
    @IBOutlet weak var indicatorSwitch: NSSwitch!
    @IBOutlet weak var progressSpinner: NSProgressIndicator!
    @IBOutlet weak var indicatorDescription: NSTextField!
    @IBOutlet weak var manageExceptionsButton: NSButton!
    @IBOutlet weak var learnMoreButton: NSButton!
    @IBOutlet weak var raiseSecurityButton: NSButton!
    var sheetViewController: SheetViewController?
    var exceptionViewController: ExceptionViewController?
    var waitingForRestart: (timeStamp: String?, reason: WaitingForRestartReason?) {
        set {
            UserDefaults.standard.setValue(newValue.timeStamp, forKey: "WaitingForRestart")
            UserDefaults.standard.setValue((newValue.timeStamp != nil) ? (newValue.reason?.rawValue) : nil, forKey: "WaitingForRestartReason")
        }
        get {
            let timeStamp = UserDefaults.standard.value(forKey: "WaitingForRestart") as? String
            var reason: WaitingForRestartReason?
            if let rawReason = UserDefaults.standard.value(forKey: "WaitingForRestartReason") as? Int, let resolvedReason = WaitingForRestartReason(rawValue: rawReason) {
                reason = resolvedReason
            }
            return (timeStamp, reason)
        }
    }
    
    var shouldShowRestartOnMainScreen: Bool {
        switch waitingForRestart.reason {
        case .installByTogglingOff:
            return true
        case .update:
            return true
        case .exceptionsSheet:
            return false
        case .none:
            return false
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if (waitingForRestart.timeStamp != SystemInformation.shared.lastSystemBootTime) {
            waitingForRestart = (nil, nil)
        }
        checkForTranslation()
        reloadSwitchState()
        reloadUpdateButton()
        setUpShadow()
        updatePreviewDate()
        updateUI()
        checkForVersionCompatibility()
        sheetViewController = SheetViewController.instantiate()
        exceptionViewController = ExceptionViewController.instantiate()
        checkForInjectionUpdate()
    }
    
    func checkForInjectionUpdate() {
        if (!SystemInformation.shared.isModificationInstalled) {
            return
        }
        if (!SystemInformation.shared.isInjectionUpToDate) {
            promptForInjectionUpdate()
        }
    }
    
    func promptForInjectionUpdate() {
        AppDelegate.showOptionSheet(title: "Recording Indicator Utility has been updated.", text: "To finish updating Recording Indicator Utility, please enter your admin password.", firstButtonText: "Enter Password…", secondButtonText: "Quit", thirdButtonText: "") { response in
            if (response == .alertFirstButtonReturn) {
                if (SystemInformation.runUnameToPreAuthenticate() != errAuthorizationSuccess) {
                    self.promptForInjectionUpdate()
                    return
                }
                self.beginAsyncInstallInjection(update: true)
            } else {
                NSApplication.shared.terminate(self)
            }
        }
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
        var toggleIsOn = SystemInformation.shared.computedRecordingIndicatorOn
        switch waitingForRestart.reason {
        case .installByTogglingOff:
            toggleIsOn = false
        case .update:
            break
        case .exceptionsSheet:
            break
        case .none:
            break
        }
        let state: NSControl.StateValue = toggleIsOn ? .on : .off
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
        previewImageView.image = NSImage(named: indicatorOn ? "preview-on" : "preview-off")
        if (indicatorOn) {
            indicatorDescription.stringValue = "The recording indicator light shows you when an app has access to your microphone."
        } else {
            indicatorDescription.stringValue = "The recording indicator light is hidden at all times, making it ideal for live events and screencasts."
        }
        indicatorSwitch.isEnabled = true
        manageExceptionsButton.isHidden = !indicatorOn
        raiseSecurityButton.title = shouldShowRestartOnMainScreen ? "Restart Now" : "Raise Security Settings"
        switch waitingForRestart.reason {
        case .installByTogglingOff:
            indicatorDescription.stringValue = "After restarting your Mac, the recording indicator light will be hidden, making it ideal for live events and screencasts."
        case .update:
            indicatorDescription.stringValue = "Recording Indicator Utility has been updated. After restarting your Mac, you can customize the recording indicator light."
            indicatorSwitch.isEnabled = false
            manageExceptionsButton.isHidden = true
            break
        case .exceptionsSheet:
            break
        case .none:
            break
        }
        
        let canRaiseSecurity = indicatorOn && SystemInformation.shared.canRaiseSecurity
        learnMoreButton.isHidden = canRaiseSecurity || shouldShowRestartOnMainScreen
        raiseSecurityButton.isHidden = !learnMoreButton.isHidden
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
                                    secondButtonText: "Continue Anyway",
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
        let alreadyInstalled = SystemInformation.shared.isModificationInstalled
        let wantsIndicatorFilePath = "\(injectionFolderPath)/\(injectionWantsIndicatorFileName)"
        let wantsIndicatorOn = indicatorSwitch.state == .on
        if (wantsIndicatorOn) {
            print("User wants indicator on")
            switch waitingForRestart.reason {
            case .installByTogglingOff:
                waitingForRestart = (nil, nil)
            case .update:
                break
            case .exceptionsSheet:
                break
            case .none:
                waitingForRestart = (nil, nil)
            }
            _ = Process.runNonAdminTask(toolPath: "/usr/bin/touch", arguments: [wantsIndicatorFilePath])
            _ = Process.runNonAdminTask(toolPath: "/bin/chmod", arguments: ["777", wantsIndicatorFilePath])
            if (alreadyInstalled) {
                AppDelegate.current.startZeroSecondRecording()
            }
            updateUI()
        } else {
            print("User wants indicator off")
            if (alreadyInstalled) {
                _ = Process.runNonAdminTask(toolPath: "/bin/rm", arguments: [wantsIndicatorFilePath])
                AppDelegate.current.startZeroSecondRecording()
                updateUI()
            } else {
                if (SystemInformation.runUnameToPreAuthenticate() != errAuthorizationSuccess) {
                    self.reloadSwitchState()
                    return
                }
                beginAsyncInstallInjection()
            }
        }
    }
    
    func beginAsyncInstallInjection(_ install: Bool = true, update: Bool = false, forExceptionsSheet: Bool = false) {
        if (!install) {
            waitingForRestart = (nil, nil)
        }
        setActionButtonAvailability(available: false)
        DispatchQueue.global(qos: .userInteractive).async {
            let result = self.sync_installInjection(install, update: update, forExceptionsSheet: forExceptionsSheet)
            print("\(install ? "Install" : "Uninstall") result is \(result)")
            let bootTime = SystemInformation.shared.lastSystemBootTime
            if (forExceptionsSheet) {
                self.waitingForRestart = (bootTime, .exceptionsSheet)
            } else if (update) {
                self.waitingForRestart = (bootTime, .update)
            } else if (install) {
                self.waitingForRestart = (bootTime, .installByTogglingOff)
            } else {
                self.waitingForRestart = (nil, nil)
            }
            DispatchQueue.main.async {
                self.setActionButtonAvailability(available: true)
                self.updateUI()
                if (install) {
                    var title = update ? "Updating Recording Indicator Utility requires a restart to take effect." : "Turning off the recording indicator light requires a restart to take effect."
                    if (forExceptionsSheet) {
                        title = "You need to restart your Mac before customizing the recording indicator."
                    }
                    AppDelegate.showOptionSheet(title: title, text: "Do you want to restart now?", firstButtonText: "Restart Now", secondButtonText: "Not Now", thirdButtonText: "") { response in
                        if (response == .alertFirstButtonReturn) {
                            self.performReboot()
                        }
                    }
                }
            }
        }
    }
    
    func sync_installInjection(_ install: Bool = true, update: Bool = false, forExceptionsSheet: Bool = false) -> Bool {
        let frameworkPath = Bundle.main.privateFrameworksPath!.fileSystemString
        let resourcePath = Bundle.main.resourcePath!.fileSystemString
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
            _ = SystemInformation.runTask(toolPath: "/bin/cp", arguments: ["\(resourcePath)/CompatibilityRevision", "\(injectionFolderPath)/\(compatibilityRevisionFileName)"])
            _ = SystemInformation.runTask(toolPath: "/usr/bin/xattr", arguments: ["-d", "com.apple.quarantine", injectionDylibPath])
            let wantsIndicatorFilePath = "\(injectionFolderPath)/\(injectionWantsIndicatorFileName)"
            if (!update && !forExceptionsSheet) {
                _ = SystemInformation.runTask(toolPath: "/bin/rm", arguments: [wantsIndicatorFilePath])
            }
            if (forExceptionsSheet) {
                _ = SystemInformation.runTask(toolPath: "/usr/bin/touch", arguments: [wantsIndicatorFilePath])
            }
            _ = SystemInformation.runTask(toolPath: "/usr/bin/touch", arguments: ["\(injectionFolderPath)/\(injectionExceptionsPlistName)"])
            _ = SystemInformation.runTask(toolPath: "/usr/bin/touch", arguments: ["\(injectionFolderPath)/\(candidateSourcesPlistName)"])
            _ = SystemInformation.runTask(toolPath: "/bin/chmod", arguments: ["777", injectionFolderPath])
            _ = SystemInformation.runTask(toolPath: "/bin/chmod", arguments: ["-R", "777", injectionFolderPath])
            
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
        manageExceptionsButton.isEnabled = available
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
        if (!SystemInformation.shared.securityAllowsToggling) {
            checkAndShowAppropriateInstructions()
            return
        }
        updateIndicatorInjection()
    }
    
    func checkAndShowAppropriateInstructions() {
        if (SystemInformation.shared.isFileVaultEnabled) {
            let decryptionProgress = SystemInformation.shared.fileVaultDecryptionProgress
            let title = (decryptionProgress != nil) ? "To customize the recording indicator, FileVault needs to finish decrypting." : "To customize the recording indicator, you need to turn off FileVault first."
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
    
    @IBAction func manageExceptionsClicked(_ sender: Any) {
        if (!SystemInformation.shared.securityAllowsToggling) {
            checkAndShowAppropriateInstructions()
            return
        }
        
        let alreadyInstalled = SystemInformation.shared.isModificationInstalled
        if (!alreadyInstalled) {
            if (self.waitingForRestart.reason == .exceptionsSheet) {
                AppDelegate.showOptionSheet(title: "Restart Required", text: "After restarting your Mac, open Recording Indicator Utility again to customize the recording indicator light on a per-app basis.", firstButtonText: "Restart Now", secondButtonText: "Cancel", thirdButtonText: "") { response in
                    if (response == .alertFirstButtonReturn) {
                        self.performReboot()
                    }
                }
                return
            }
            
            if (SystemInformation.runUnameToPreAuthenticate() == errAuthorizationSuccess) {
                beginAsyncInstallInjection(forExceptionsSheet: true)
            }
            return
        }

        guard let exceptionVC = self.exceptionViewController else {
            return
        }
        
        self.presentAsSheet(exceptionVC)
    }
    
    @IBAction func raiseSecurityButtonClicked(_ sender: Any) {
        // "Restart Now"
        if (shouldShowRestartOnMainScreen) {
            performReboot()
            return
        }
        
        // "Raise Security Settings"
        let systemAlreadySealed = Process.runNonAdminTask(toolPath: "/usr/sbin/diskutil", arguments: ["apfs", "listSnapshots", "/"]).contains("1 found")
        if (systemAlreadySealed) {
            self.applyRaisedSecuritySettings(true)
            return
        }
        AppDelegate.showOptionSheet(title: "Raise Security Settings", text: "After raising security settings, the recording indicator will no longer be hidden in apps or system-wide.\n\nTo continue, Recording Indicator Utility will apply the last sealed system snapshot. This only affects the macOS system volume and does not affect your apps or data.\n\nIf your Mac misbehaves after continuing, choose Apple menu > Restart or force restart. Once your Mac starts up, reopen Recording Indicator Utility to repeat this process.", firstButtonText: "Continue", secondButtonText: "Cancel", thirdButtonText: "") { response in
            if (response == .alertFirstButtonReturn) {
                self.applyRaisedSecuritySettings()
            }
        }
    }
    
    @IBAction func learnMoreButtonClicked(_ sender: Any) {
        AppDelegate.current.safelyOpenURL("https://github.com/cormiertyshawn895/RecordingIndicatorUtility")
    }
}

