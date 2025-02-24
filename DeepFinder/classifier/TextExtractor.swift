//
//  TextExtractor.swift
//  DeepFinder
//
//

import Vision
import PDFKit
import ZIPFoundation
import NaturalLanguage



final class TextExtractor {
    static let fileSizeLimit = 1 * 1024 * 1024
    private static let docxTextRegex: NSRegularExpression? = try? NSRegularExpression(pattern: "<w:t[^>]*>([\\s\\S]*?)</w:t>", options: [.dotMatchesLineSeparators])
    private static let pagesTextRegex: NSRegularExpression? = try? NSRegularExpression(pattern: "<text[^>]*>([\\s\\S]*?)</text>", options: [.dotMatchesLineSeparators])
    
    public static func extractText(from url: URL?) async -> String? {
        guard let url = url else { return nil }
        let fileExtension = url.pathExtension.lowercased()
        switch fileExtension {
        case "txt", "adoc", "java", "swift", "html", "css", "js", "xml", "plist", "json", "md", "mdx", "csv", "sql", "cc", "cpp", "h", "m", "mm":
            return await extractTextFromTextFile(url: url)
        case "pdf":
            return await extractTextFromPDF(url: url)
        case "jpg", "jpeg", "png", "tiff", "bmp", "gif":
            return await extractTextFromImage(url: url)
        case "pages":
            return extractTextFromPages(fileURL: url)
        case "docx":
            return extractTextFromDocxManually(fileURL: url)
        default:
            return nil
        }
    }
    
    private static func extractTextFromTextFile(url: URL) async -> String? {
        do {
            let fileHandle = try FileHandle(forReadingFrom: url)
            defer { fileHandle.closeFile() }
            let data = fileHandle.readData(ofLength: fileSizeLimit)
            if let text = String(data: data, encoding: .utf8) {
                return text
            } else {
                print("Failed to decode text from the first 1 MB of data.")
                return nil
            }
        } catch {
            print("Error reading text file at \(url.path): \(error)")
            return nil
        }
    }
    
    private static func extractTextFromPDF(url: URL) async -> String? {
        guard let pdfDocument = PDFDocument(url: url) else {
            print("Unable to open PDF document at \(url.path)")
            return nil
        }
        var fullText = ""
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            if let pageContent = page.string {
                fullText += pageContent + "\n"
            }
            if fullText.utf8.count >= fileSizeLimit {
                fullText = String(fullText.prefix(fileSizeLimit))
                break
            }
        }
        return fullText.isEmpty ? nil : fullText
    }
    
    private static func extractTextFromImage(url: URL) async -> String? {
        guard let nsImage = NSImage(contentsOf: url),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("Unable to load NSImage or its CGImage from \(url.path)")
            return nil
        }
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        do {
            try requestHandler.perform([request])
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return nil }
            let recognizedStrings = observations.compactMap { $0.topCandidates(1).first?.string }
            return recognizedStrings.joined(separator: " ")
        } catch {
            print("Error during OCR processing: \(error)")
            return nil
        }
    }
    
    static func extractTextFromDocxManually(fileURL: URL) -> String? {
        let fileManager = FileManager()
        let tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true, attributes: nil)
            defer { try? fileManager.removeItem(at: tempDirectory) }
            try fileManager.unzipItem(at: fileURL, to: tempDirectory)
            let documentXMLURL = tempDirectory.appendingPathComponent("word/document.xml")
            let xmlData = try Data(contentsOf: documentXMLURL)
            guard let xmlString = String(data: xmlData, encoding: .utf8),
                  let regex = docxTextRegex else { return nil }
            let nsRange = NSRange(xmlString.startIndex..<xmlString.endIndex, in: xmlString)
            let matches = regex.matches(in: xmlString, options: [], range: nsRange)
            let extractedTexts = matches.compactMap { match -> String? in
                guard let range = Range(match.range(at: 1), in: xmlString) else { return nil }
                return String(xmlString[range])
            }
            let joinedText = extractedTexts.joined(separator: "\n")
            return String(joinedText.prefix(fileSizeLimit))
        } catch {
            print("Error extracting text manually from DOCX: \(error)")
        }
        return nil
    }
    
    static func extractTextFromPages(fileURL: URL) -> String? {
        let fileManager = FileManager()
        let tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true, attributes: nil)
            defer {
                try? fileManager.removeItem(at: tempDirectory)
                print("Temporary directory removed: \(tempDirectory.path)")
            }
            try fileManager.unzipItem(at: fileURL, to: tempDirectory)
            let possiblePaths = [
                tempDirectory.appendingPathComponent("index.xml"),
                tempDirectory.appendingPathComponent("index.apxl")
            ]
            var xmlData: Data?
            for path in possiblePaths {
                if fileManager.fileExists(atPath: path.path) {
                    xmlData = try Data(contentsOf: path)
                    break
                }
            }
            guard let data = xmlData,
                  let xmlString = String(data: data, encoding: .utf8),
                  let regex = pagesTextRegex else { return nil }
            let nsRange = NSRange(xmlString.startIndex..<xmlString.endIndex, in: xmlString)
            let matches = regex.matches(in: xmlString, options: [], range: nsRange)
            
            let extractedTexts: [String] = matches.compactMap { match in
                guard let range = Range(match.range(at: 1), in: xmlString) else { return nil }
                return String(xmlString[range])
            }
            let joinedText = extractedTexts.joined(separator: "\n")
            return String(joinedText.prefix(fileSizeLimit))
        } catch {
            print("Error extracting text from Pages: \(error)")
            return nil
        }
    }
    
    static func redactNames(from text: String) -> String {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var modifiedText = text
        var rangesToReplace = [Range<String.Index>]()
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: [.omitPunctuation, .omitWhitespace]) { tag, tokenRange in
            if tag == .personalName {
                rangesToReplace.append(tokenRange)
            }
            return true
        }
        for range in rangesToReplace.reversed() {
            modifiedText.replaceSubrange(range, with: "[John Doe]")
        }
        return modifiedText
    }
    
    static func redactFinancialInfoAndNumbers(from text: String) -> String {
        var modifiedText = text
        let patterns = [
            "\\b[A-Z]{2}\\d{2}[A-Z0-9]{11,30}\\b": "[0000000000]",
            "\\b\\d+[.,]?\\d*\\b": "[0000]"
        ]
        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                modifiedText = regex.stringByReplacingMatches(in: modifiedText, options: [], range: NSRange(location: 0, length: modifiedText.utf16.count), withTemplate: replacement)
            }
        }
        return modifiedText
    }
    
    static func removeAllSensitiveData(from text: String) -> String {
        guard AppDelegate.settingsModel.settings.removeSensitiveData else {
            return text
        }
        return redactFinancialInfoAndNumbers(from: redactNames(from: text))
    }
}
