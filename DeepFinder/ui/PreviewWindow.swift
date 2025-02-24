//
//  PreviewWindow.swift
//  DeepFinder
//
//

import SwiftUI
import AppKit
import AppKit
import Quartz
import HighlightSwift


struct PDFPreviewView: NSViewRepresentable {
    let path: String
    let searchText: String
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.autoresizingMask = [.width, .height]
        
        if let pdfDocument = PDFDocument(url: URL(fileURLWithPath: path)) {
            pdfView.document = pdfDocument
            searchAndHighlight(in: pdfView, word: searchText)
        }
        
        return pdfView
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        searchAndHighlight(in: pdfView, word: searchText)
    }
    
    private func searchAndHighlight(in pdfView: PDFView, word: String) {
        guard let document = pdfView.document else { return }
        let matches = document.findString(word, withOptions: .caseInsensitive)
        if let firstMatch = matches.first {
            pdfView.go(to: firstMatch)
            pdfView.setCurrentSelection(firstMatch, animate: true)
        }
    }
}

// MARK: - Text Preview Wrapper
struct TextPreviewView: NSViewRepresentable {
    let path: String
    let highlightStartLine: Int
    let highlightEndLine: Int
    let answerText: String
    let searchText: String = ""

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        
        let contentSize = scrollView.contentSize
        let textView = NSTextView(frame: NSRect(origin: .zero, size: contentSize))
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        
        
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.backgroundColor = .clear
        scrollView.documentView = textView
        textView.backgroundColor = .white

        Task {
            let highlight = Highlight()
            if let text = try? String(contentsOf: URL(fileURLWithPath: path)) {
                print("**** \(text.count)")
                var attributedText: AttributedString? = nil
                if text.count <= 1204*100 {
                     attributedText = try await highlight.attributedText(text)
                }
                DispatchQueue.main.async {
                    if let attributedText = attributedText {
                        textView.textStorage?.setAttributedString(NSAttributedString(attributedText))
                    } else {
                        textView.textStorage?.setAttributedString(NSAttributedString(string: text))
                    }
                    if highlightStartLine >= 0 && highlightEndLine > 0 {
                        selectLines(in: textView, startLine: highlightStartLine, endLine: highlightEndLine)
                    } else if answerText.count > 0 {
                        guard let attributedString = textView.textStorage else { return }
                        let fullText = attributedString.string
                        findTextBlockInFile(in: textView,fileContent: fullText,textBlock: answerText)
                    }
                }
            }
        }
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {

    }
    
    
    func findTextBlockInFile(in textView: NSTextView, fileContent: String, textBlock: String)  {
        func normalize(_ text: String) -> String {
            return text.replacingOccurrences(of: "\r", with: "")
                       .replacingOccurrences(of: "\t", with: " ")
                       .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let normalizedFileLines = fileContent.components(separatedBy: .newlines).map { normalize($0) }
        let normalizedBlock = normalize(textBlock)

        for (index, _) in normalizedFileLines.enumerated() {
            for endIndex in index..<normalizedFileLines.count {
                let section = normalizedFileLines[index...endIndex].joined(separator: " ")
                if section.contains(normalizedBlock) {
                    selectLines(in: textView,startLine: index + 1, endLine: endIndex + 1)
                    return
                }
            }
        }

    }
    
    private func searchAndHighlight(in textView: NSTextView, text: String) {
        guard let attributedString = textView.textStorage else { return }
        let fullText = attributedString.string
        let range = (fullText as NSString).range(of: text, options: .caseInsensitive)
        if range.location != NSNotFound {
            textView.scrollRangeToVisible(range)
            textView.setSelectedRange(range)
        }
    }
    
    func selectLines(in textView: NSTextView,startLine: Int, endLine: Int)
    {
        guard startLine > 0, endLine >= startLine else { return }
        let fullText = textView.string
        let lines = fullText.components(separatedBy: .newlines)
        guard startLine <= lines.count, endLine <= lines.count else { return }
        let startIndex = startLine - 1
        let endIndex   = endLine   - 1
        let startOffset = lines[0..<startIndex].reduce(0) { $0 + $1.count + 1 }
        let endOffset   = lines[0...endIndex].reduce(0) { $0 + $1.count + 1 }

        let selectionRange = NSRange(location: startOffset, length: endOffset - startOffset)
        
        textView.scrollRangeToVisible(selectionRange)
        
        textView.setSelectedRange(selectionRange)
    }

}


struct DirectoryQLPreview: NSViewRepresentable {
    var fileName: String
    typealias NSViewType = QLPreviewView


    func makeNSView(context: NSViewRepresentableContext<DirectoryQLPreview>) -> QLPreviewView {
        let preview = QLPreviewView(frame: .zero, style: .normal)
        preview?.autostarts = true
        preview?.previewItem = loadPreviewItem(with: fileName) as QLPreviewItem
        return preview ?? QLPreviewView()
    }
    
    
    func loadPreviewItem(with name: String) -> NSURL {
        let url = NSURL(fileURLWithPath: fileName)
        return url
    }

    func updateNSView(_ nsView: QLPreviewView, context: NSViewRepresentableContext<DirectoryQLPreview>) {
    }

}



class PreviewWindow: NSWindow,NSWindowDelegate {
    
    init(contentRect: NSRect, path: String, highlightStartLine: Int = -1, highlightEndLine: Int = -1, answerText: String = "") {
        let styleMask: NSWindow.StyleMask = [.titled, .closable]
        super.init(contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false)
        self.isReleasedWhenClosed = false
        self.center()
        self.level = .floating + 1
        self.delegate = self
        self.isReleasedWhenClosed = false
        
        print("****\(path)")
        print("\(highlightStartLine)")
        print("\(highlightEndLine)")

        if let fileType = fromFilePath(path) {
            let preview = TextPreviewView(path: path, highlightStartLine: highlightStartLine, highlightEndLine: highlightEndLine,answerText: answerText)
            let hostingView = NSHostingView(rootView:  preview)
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            self.contentView?.addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: self.contentView!.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: self.contentView!.trailingAnchor),
                hostingView.topAnchor.constraint(equalTo: self.contentView!.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: self.contentView!.bottomAnchor)
            ])
        } else if (path as NSString).pathExtension.lowercased() == "pdf" {
            let preview = PDFPreviewView(path: path, searchText: answerText)
            let hostingView = NSHostingView(rootView:  preview)
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            self.contentView?.addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: self.contentView!.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: self.contentView!.trailingAnchor),
                hostingView.topAnchor.constraint(equalTo: self.contentView!.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: self.contentView!.bottomAnchor)
            ])
        } else {
            let hostingView = NSHostingView(rootView: DirectoryQLPreview(fileName: path))
            self.contentView?.addSubview(hostingView)
            hostingView.frame = self.contentView?.bounds ?? contentRect
            hostingView.autoresizingMask = [.width, .height]
            self.contentView?.addSubview(hostingView)
        }
        if let closeButton = self.standardWindowButton(.closeButton) {
            closeButton.isHidden = false
        }
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }
    
    func windowWillClose(_ notification: Notification) {
        AppDelegate.previewIsVisible = false
        AppDelegate.previewWindow = nil
    }
    
    
    public func fromFilePath(_ filePath: String) -> HighlightLanguage? {
          let fileName = (filePath as NSString).lastPathComponent
          let fileExtension = (filePath as NSString).pathExtension.lowercased()

          switch fileName.lowercased() {
          case "dockerfile":
              return .dockerfile
          case "makefile":
              return .makefile
          default:
              break
          }

          switch fileExtension {
          case "applescript", "scpt":
              return .appleScript
          case "ino":
              return .arduino
          case "awk":
              return .awk
          case "sh", "bash", "zsh":
              return .bash
          case "bas":
              return .basic
          case "c", "h":
              return .c
          case "cpp", "cxx", "hpp", "hxx", "cc", "hh":
              return .cPlusPlus
          case "cs":
              return .cSharp
          case "clj":
              return .clojure
          case "css":
              return .css
          case "dart":
              return .dart
          case "pas":
              return .delphi
          case "diff", "patch":
              return .diff
          case "ex", "exs":
              return .elixir
          case "elm":
              return .elm
          case "erl":
              return .erlang
          case "feature":
              return .gherkin
          case "go":
              return .go
          case "gradle":
              return .gradle
          case "graphql":
              return .graphQL
          case "hs":
              return .haskell
          case "html", "htm":
              return .html
          case "java":
              return .java
          case "js", "mjs":
              return .javaScript
          case "json":
              return .json
          case "jl":
              return .julia
          case "kt", "kts":
              return .kotlin
          case "tex":
              return .latex
          case "less":
              return .less
          case "lisp":
              return .lisp
          case "lua":
              return .lua
          case "md", "markdown":
              return .markdown
          case "m":
              // `.m` can be Objective-C or MATLAB. Adjust to your preference:
              // return .objectiveC
              return .objectiveC
          case "nix":
              return .nix
          case "mm":
              // Could be Objective-C++
              return .objectiveC
          case "pl", "pm":
              return .perl
          case "php":
              return .php
          case "phpt", "phtml":
              return .phpTemplate
          case "txt":
              return .plaintext
          case "proto":
              return .protocolBuffers
          case "py":
              return .python
          case "r":
              return .r
          case "rb":
              return .ruby
          case "rs":
              return .rust
          case "scala":
              return .scala
          case "scss":
              return .scss
          case "sql":
              return .sql
          case "swift":
              return .swift
          case "toml":
              return .toml
          case "ts":
              return .typeScript
          case "vb":
              return .visualBasic
          case "wat":
              return .webAssembly
          case "yaml", "yml":
              return .yaml
          default:
              // No recognized extension or special filename
              return nil
          }
      }
}
