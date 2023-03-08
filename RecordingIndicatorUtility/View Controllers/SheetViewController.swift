//
//  SheetViewController.swift
//  Recording Indicator Utility
//

import Cocoa

enum GuidanceType {
    case asLowering
    case asRaising
    case intelLowering
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
                return "To customize the recording indicator, you need to disable System Integrity Protection."
            case .asRaising:
                return "You can start up in macOS Recovery and raise the security policy to Full Security."
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
                return "riu-as-lowering"
            case .intelLowering:
                return "riu-intel-lowering"
            case .asRaising:
                return "sip-as-raising"
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
        super.viewWillAppear()
        
        updateTextAndQRCode()
        self.view.window?.preventsApplicationTerminationWhenModal = false
        self.view.window?.styleMask.remove(.resizable)
    }
    
    override func cancelOperation(_ sender: Any?) {
        self.dismiss(nil)
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
