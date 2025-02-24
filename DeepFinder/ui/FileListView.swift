//
//  FilesList.swift
//  DeepFinder
//
//

import SwiftUI


struct FileListView: View {
    @ObservedObject var viewModel: FileListViewModel
    @State private var hovering: Bool = false
    @State private var tooltipWindow: TooltipWindow?
    @Binding var sortedColumn: Int
    @Binding var sortedAsc1: Bool
    @Binding var sortedAsc0: Bool
    @State private var parentWidth: CGFloat = 0

    private var fileNameWidth: CGFloat { parentWidth * 0.6 }
    private var columnWidth: CGFloat { parentWidth * 0.1 }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if viewModel.getFileListCount() > 0 {
                List {
                    Section(header: headerView) {
                        ForEach(viewModel.getFileList(), id: \.id) { file in
                            rowView(for: file)
                                .onAppear {
                                    withAnimation {
                                        if viewModel.isLastFile(file: file) {
                                            viewModel.loadNextBatch()
                                        }
                                    }
                                }
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .frame(minWidth: 600, minHeight: viewModel.getFileListCount() > 0 ? 600 : 1)
        .animation(.easeInOut, value: viewModel.getFileListCount())
        .background(GeometryReader { proxy in
            Color.clear
                .onAppear { parentWidth = proxy.size.width }
                .onChange(of: proxy.size.width) { newValue in parentWidth = newValue }
        })
    }

    private var headerView: some View {
        HStack {
            Text("File name")
                .frame(width: fileNameWidth, alignment: .center)
            Divider()
            HStack {
                Text("Date")
                if sortedColumn == 1 {
                    Image(systemName: sortedAsc1 ? "arrow.down" : "arrow.up")
                }
            }
            .frame(width: columnWidth, height: 40)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in
                        sortedColumn = 1
                        sortedAsc1.toggle()
                        viewModel.reload(sortedColumn, sortedAsc1)
                    }
            )
            Divider()
            HStack {
                Text("Keywords")
                if sortedColumn == 0 {
                    Image(systemName: sortedAsc0 ? "arrow.down" : "arrow.up")
                }
            }
            .frame(width: columnWidth, height: 40)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { _ in
                        sortedColumn = 0
                        sortedAsc0.toggle()
                        viewModel.reload(sortedColumn, sortedAsc0)
                    }
            )
            Divider()
            Text("Preview")
                .frame(width: columnWidth, alignment: .center)
            Divider()
        }
        .frame(height: 40)
        .background(Color.gray.opacity(0.2))
    }

    private func rowView(for file: FileItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(URL(fileURLWithPath: file.name).lastPathComponent)
                    .frame(width: fileNameWidth, alignment: .leading)
                Text(URL(fileURLWithPath: file.name).deletingLastPathComponent().path)
                    .frame(width: fileNameWidth, alignment: .leading)
                    .font(.caption)
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.name)])
            }
            Divider()
            Text(String(file.updated))
                .font(.caption)
                .frame(width: columnWidth, alignment: .center)
            Divider()
            Text("\(file.freq.description)%")
                .frame(width: columnWidth, alignment: .center)
            Divider()
            Button {
                if AppDelegate.previewWindow != nil {
                    hidePreview()
                } else {
                    showPreview(file.name)
                }
                hovering.toggle()
            } label: {
                Image(systemName: "eye")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .padding(8)
            }.buttonStyle(.plain)
      
            Divider()
        }
        .padding(.vertical, 8)
    }

    private func showPreview(_ fileName: String) {
        let mouseLocation = NSEvent.mouseLocation
        let previewSize = NSSize(width: 800, height: 800)
        let previewOrigin = NSPoint(x: mouseLocation.x, y: mouseLocation.y + 10)
        let previewFrame = NSRect(origin: previewOrigin, size: previewSize)
        if AppDelegate.previewWindow == nil {
            if (fileName as NSString).pathExtension.lowercased() == "pdf" {
                Prompter.generateAnswer(for: viewModel.searcher.queryString,path: fileName) { text  in
                    AppDelegate.previewWindow = PreviewWindow(contentRect: previewFrame, path: fileName,highlightStartLine: -1,highlightEndLine: -1,answerText: text)
                }
            } else {
                Prompter.generateLineRange(for: viewModel.searcher.queryString,path: fileName ) { lines  in
                    AppDelegate.previewWindow = PreviewWindow(contentRect: previewFrame, path: fileName,highlightStartLine: lines[0],highlightEndLine: lines[1],answerText: "")
                }
            }
        } else {
            AppDelegate.previewWindow?.setFrame(previewFrame, display: true)
        }
        AppDelegate.previewWindow?.orderFront(nil)
        AppDelegate.previewIsVisible = true
    }

    private func hidePreview() {
        AppDelegate.previewWindow?.orderOut(nil)
        AppDelegate.previewWindow = nil
        AppDelegate.previewIsVisible = false
    }

    private func showTooltip(_ fileName: String) {
        let mouseLocation = NSEvent.mouseLocation
        let tooltipSize = NSSize(width: 600, height: 40)
        let tooltipOrigin = NSPoint(x: mouseLocation.x, y: mouseLocation.y + 10)
        let tooltipFrame = NSRect(origin: tooltipOrigin, size: tooltipSize)
        if tooltipWindow == nil {
            tooltipWindow = TooltipWindow(contentRect: tooltipFrame, tooltipText: fileName)
        } else {
            tooltipWindow?.setFrame(tooltipFrame, display: true)
        }
        tooltipWindow?.orderFront(nil)
    }

    private func hideTooltip() {
        tooltipWindow?.orderOut(nil)
        tooltipWindow = nil
    }
}
