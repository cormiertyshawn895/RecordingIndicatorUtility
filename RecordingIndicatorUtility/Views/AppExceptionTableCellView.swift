//
//  AppExceptionTableCellView.swift
//  Recording Indicator Utility
//

import Cocoa

protocol AppExceptionTableCellViewDelegate: AnyObject {
    func didToggleCheckbox(_ cell: AppExceptionTableCellView)
}

class AppExceptionTableCellView: NSTableCellView {
    @IBOutlet weak var iconView: NSImageView!
    @IBOutlet weak var label: NSTextField!
    @IBOutlet weak var checkbox: NSButton!
    weak var delegate: AppExceptionTableCellViewDelegate?
    
    @IBAction func checkboxClicked(_ sender: Any) {
        delegate?.didToggleCheckbox(self)
    }
}
