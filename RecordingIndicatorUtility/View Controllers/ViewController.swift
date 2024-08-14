//
//  ViewController.swift
//  Recording Indicator Utility
//

import Cocoa

let tempSystemMountPath = "/tmp/system_mount"

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
    @IBOutlet weak var learnMoreButton: NSButton!
    @IBOutlet weak var raiseSecurityButton: NSButton!
    var sheetViewController: SheetViewController?
    var waitingForRestart: String? {
        set {
            UserDefaults.standard.setValue(newValue, forKey: "WaitingForRestart")
        }
        get {
            UserDefaults.standard.value(forKey: "WaitingForRestart") as? String
        }
    }
    
    var shouldShowRestartOnMainScreen: Bool {
        return waitingForRestart != nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if (waitingForRestart != SystemInformation.shared.lastSystemBootTime) {
            waitingForRestart = nil
        }
        reloadSwitchState()
        reloadUpdateButton()
        setUpShadow()
        updatePreviewDate()
        updateUI()
        sheetViewController = SheetViewController.instantiate()
    }
    
    func reloadSwitchState(_ animated: Bool = true) {
        let toggleIsOn = SystemInformation.shared.isSystemstatusdLoaded
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
            indicatorDescription.stringValue = "The recording indicator light is shown when microphone is in use. This is ideal for day-to-day use."
        } else {
            indicatorDescription.stringValue = "The recording indicator light is hidden at all times. This is ideal for live events and screencasts."
        }
        indicatorSwitch.isEnabled = true
        raiseSecurityButton.title = shouldShowRestartOnMainScreen ? "Restart Now" : "Raise Security Settings"
        if (shouldShowRestartOnMainScreen) {
            indicatorDescription.stringValue = indicatorOn ? "After restarting your Mac, the recording indicator light will show you when an app has access to your microphone.": "After restarting your Mac, the recording indicator light will be hidden, making it ideal for live events and screencasts."
        }
        
        let canRaiseSecurity = indicatorOn && !SystemInformation.shared.isSIPEnabled && SystemInformation.shared.isSystemSealed
        learnMoreButton.isHidden = canRaiseSecurity || shouldShowRestartOnMainScreen
        raiseSecurityButton.isHidden = !learnMoreButton.isHidden
    }
    
    func checkForVersionCompatibility() {
        let processInfo = ProcessInfo()
        let osFullVersion = ProcessInfo.processInfo.operatingSystemVersion
        let osNotRecognized = processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0))
        if !osNotRecognized {
            return;
        }
        AppDelegate.showOptionSheet(title: "Update to the latest version of Recording Indicator Utility.",
                                    text: "This version of Recording Indicator Utility is only designed and tested for macOS Ventura and macOS Monterey, and does not support macOS \(osFullVersion.majorVersion).",
                                    firstButtonText: "Check for Updates",
                                    secondButtonText: "Continue Anyway",
                                    thirdButtonText: "Quit") { (response, isChecked) in
            if (response == .alertFirstButtonReturn) {
                AppDelegate.current.checkForUpdates()
            } else if (response == .alertSecondButtonReturn) {
            } else {
                NSApplication.shared.terminate(self)
            }
        }
    }
    
    func updateIndicatorInjection() {
        let isSystemstatusdLoaded = SystemInformation.shared.isSystemstatusdLoaded
        let wantsIndicatorOn = indicatorSwitch.state == .on
        if (isSystemstatusdLoaded == wantsIndicatorOn) {
            return
        }
        if (wantsIndicatorOn) {
            print("User wants indicator on")
        } else {
            print("User wants indicator off")
        }
        setSystemstatusdLoaded(wantsIndicatorOn)
    }
    
    func setSystemstatusdLoaded(_ loaded: Bool = true) {
        setActionButtonAvailability(available: false)
        DispatchQueue.global(qos: .userInteractive).async {
            STPrivilegedTask.setSystemStatusdLoaded(loaded)
            DispatchQueue.main.async {
                self.setActionButtonAvailability(available: true)
                self.reloadSwitchState(true)
                let success = SystemInformation.shared.isSystemstatusdLoaded == loaded
                print("\(loaded ? "Load" : "Unload") result is \(success)")
                if (!success) {
                    return
                }
                self.waitingForRestart = SystemInformation.shared.lastSystemBootTime
                self.updateUI()
                let title = loaded ? "Turning on the recording indicator light requires a restart to take effect." : "Turning off the recording indicator light requires a restart to take effect."
                AppDelegate.showOptionSheet(title: title, text: "Do you want to restart now?", firstButtonText: "Restart Now", secondButtonText: "Not Now", thirdButtonText: "") { response, isChecked in
                    if (response == .alertFirstButtonReturn) {
                        self.performReboot()
                    }
                }
            }
        }
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
        STPrivilegedTask.restart()
    }
    
    func applyRaisedSecuritySettings(_ isAlreadySealed: Bool = false) {
        if (SystemInformation.runUnameToPreAuthenticate() != errAuthorizationSuccess) {
            print("Unable to raise security because authentication failed")
            return
        }
        DispatchQueue.global(qos: .userInteractive).async {
            _ = SystemInformation.runTask(toolPath: "/usr/bin/csrutil", arguments: ["clear"])
            self.performReboot()
        }
    }
    
    @IBAction func updateAvailableClicked(_ sender: Any) {
        AppDelegate.current.promptForUpdateAvailable()
    }
    
    @IBAction func indicatorSwitchToggled(_ sender: Any) {
        if (SystemInformation.shared.isSIPEnabled) {
            checkAndShowAppropriateInstructions()
            return
        }
        updateIndicatorInjection()
    }
    
    func checkAndShowAppropriateInstructions() {
        if (SystemInformation.shared.isSIPEnabled) {
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
        if (shouldShowRestartOnMainScreen) {
            performReboot()
            return
        }
        
        // "Raise Security Settings"
        if (!SystemInformation.shared.isSystemSealed) {
            return
        }
        
        if (SystemInformation.shared.isAppleSilicon) {
            if let sheetVC = sheetViewController {
                sheetVC.guidanceType = .asRaising
                self.presentAsSheet(sheetVC)
            }
            return
        }
        
        AppDelegate.showOptionSheet(title: "Would you like to raise security settings?", text: "This will re-enable System Integrity Protection. Your Mac will automatically restart afterwards.", firstButtonText: "Continue and Restart", secondButtonText: "Cancel", thirdButtonText: "") { response, isChecked in
            if (response == .alertFirstButtonReturn) {
                self.applyRaisedSecuritySettings()
            }
        }
    }
    
    @IBAction func learnMoreButtonClicked(_ sender: Any) {
        AppDelegate.current.safelyOpenURL("https://github.com/cormiertyshawn895/RecordingIndicatorUtility")
    }
}

