//
//  TagsBar.swift
//  DeepFinder
//
//

import SwiftUI

struct TagsBar: View {
    var viewModel: FileListViewModel
    @Binding var tags: [String: Bool]
    @State private var tooltipWindow: TooltipWindow?
    let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 8)
    
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(tags.keys.sorted(), id: \.self) { tag in
                        HStack {
                            CheckBoxView(isChecked: Binding(
                                get: { tags[tag] ?? false },
                                set: { newValue in
                                    tags[tag] = newValue
                                    _ = viewModel.setTag(tag, newValue)
                                }
                            ), onToggle: { _ in true })
                            Text(tag)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: 100, alignment: .leading)
                        }
                        .onHover { isHovering in
                            if isHovering {
                                showTooltip(tag)
                            } else {
                                hideTooltip()
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    private func showTooltip(_ tag: String) {
        guard let text = AppDelegate.categoriesData.compactMap({ $0.getTitleForTag(tag) }).first(where: { !$0.isEmpty }) else { return }
        let mouseLocation = NSEvent.mouseLocation
        let tooltipSize = NSSize(width: 600, height: 40)
        let tooltipOrigin = NSPoint(x: mouseLocation.x - 300, y: mouseLocation.y + 10)
        let tooltipFrame = NSRect(origin: tooltipOrigin, size: tooltipSize)
        if let window = tooltipWindow {
            window.setFrame(tooltipFrame, display: true)
        } else {
            tooltipWindow = TooltipWindow(contentRect: tooltipFrame, tooltipText: text)
        }
        tooltipWindow?.orderFront(nil)
    }
    
    private func hideTooltip() {
        tooltipWindow?.orderOut(nil)
        tooltipWindow = nil
    }
}
