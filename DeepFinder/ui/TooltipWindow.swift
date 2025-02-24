//
//  TooltipWindow.swift
//  DeepFinder
//
//

import SwiftUI
import AppKit


struct TooltipView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.callout)
            .padding(8)
            .background(Color.white.opacity(0.9))
            .foregroundColor(.black)
            .cornerRadius(8)
    }
}



class TooltipWindow: NSPanel {
    init(contentRect: NSRect, tooltipText: String) {
        super.init(contentRect: contentRect,
                   styleMask: [.nonactivatingPanel, .borderless],
                   backing: .buffered,
                   defer: false)
        self.isFloatingPanel = true
        self.hidesOnDeactivate = true
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.ignoresMouseEvents = true
        let hostingView = NSHostingView(rootView: TooltipView(text: tooltipText))
        hostingView.frame = self.contentView?.bounds ?? contentRect
        hostingView.autoresizingMask = [.width, .height]
        self.contentView?.addSubview(hostingView)
    }
}
