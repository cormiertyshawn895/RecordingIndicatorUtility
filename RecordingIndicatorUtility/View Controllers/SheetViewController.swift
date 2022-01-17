//
//  SheetViewController.swift
//  Recording Indicator Utility
//

import Cocoa

enum GuidanceType {
    case asLowering
    case asRaising
    case asRaisingAlreadySealed
    case intelLowering
    case intelRaising
    case intelRaisingAlreadySealed
}

let instructionsURLPrefix = "https://cormiertyshawn895.github.io/instruction/?arch="

class SheetViewController: NSViewController {
    @IBOutlet weak var titleLabel: NSTextField!
    @IBOutlet weak var captionLabel: NSTextField!
    @IBOutlet weak var qrCodeImageView: NSImageView!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var viewInstructionsButton: NSButton!
    @IBOutlet weak var closeButton: NSButton!
    var guidanceType: GuidanceType = .asLowering
    var titleText: String {
        get {
            switch (self.guidanceType) {
            case .asLowering, .intelLowering:
                return "To turn off the recording indicator, you need to disable System Integrity Protection and allow non-sealed system snapshots."
            case .asRaising:
                return "The last sealed system volume snapshot has been successfully restored. You can now enable Full Security."
            case .asRaisingAlreadySealed:
                return "You can now start up in macOS Recovery, open Startup Security Utility, then raise the security policy to Full Security."
            case .intelRaising:
                return "The last sealed system volume snapshot has been successfully restored. You can now raise security settings."
            case .intelRaisingAlreadySealed:
                return "You can now start up in macOS Recovery, enable System Integrity Protection, and only allow sealed system snapshots."
            }
        }
    }
    
    var instructionsURL: URL {
        return URL(string: "\(instructionsURLPrefix)\(instructionsArch)")!
    }
    
    var instructionsArch: String {
        get {
            switch (self.guidanceType) {
            case .asLowering:
                return "as-lowering"
            case .asRaising, .asRaisingAlreadySealed:
                return "as-raising"
            case .intelLowering:
                return "intel-lowering"
            case .intelRaising, .intelRaisingAlreadySealed:
                return "intel-raising"
            }
        }
    }
    
    static func instantiate() -> SheetViewController {
        return NSStoryboard.main?.instantiateController(withIdentifier: "SheetViewController") as! SheetViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear() {
        updateTextAndQRCode()
        self.view.window?.preventsApplicationTerminationWhenModal = false
        self.view.window?.styleMask.remove(.resizable)
    }
    
    @IBAction func closeButtonClicked(_ sender: Any) {
        self.dismiss(nil)
    }
    
    @IBAction func viewInstructionsClicked(_ sender: Any) {
        NSWorkspace.shared.open(self.instructionsURL)
    }
    
    func updateTextAndQRCode() {
        titleLabel.stringValue = self.titleText
        qrCodeImageView.isHidden = false
        progressIndicator.isHidden = false
        progressIndicator.startAnimation(nil)
        DispatchQueue.global(qos: .userInteractive).async {
            let image = QRCodeGenerator.generate(string: self.instructionsURL.absoluteString, size: CGSize(width: 140, height: 140))
            image?.isTemplate = true
            DispatchQueue.main.async {
                self.qrCodeImageView.image = image
                self.progressIndicator.stopAnimation(nil)
                self.progressIndicator.isHidden = true
            }
        }
    }
}
