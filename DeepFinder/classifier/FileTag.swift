//
//  FileTag.swift
//  DeepFinder
//
//

import Foundation
import Cocoa

class ProcessedState: ObservableObject {
    @Published var stop = false
    @Published var processing = false
    @Published var numFileProcessed = 0
}

class FileTag {
    public static var state: ProcessedState = ProcessedState()

    public static func tagFiles(_ startPath: String) {
        guard !state.processing else { return }
        Task {
            await MainActor.run {
                state.numFileProcessed = 0
                state.processing = true
            }
            iterateFiles(in: startPath) { file in
                guard !state.stop else { return }
                let semaphore = DispatchSemaphore(value: 0)
                Task {
                    if let text = await TextExtractor.extractText(from: URL(fileURLWithPath: file)) {
                        storeTag(content: text, in: file)
                    }
                    semaphore.signal()
                }
                _ = semaphore.wait(timeout: .now() + 120)
            }
            await MainActor.run { state.processing = false }
        }
    }

    static func storeTag(content: String, in path: String) {
        let text = TextExtractor.removeAllSensitiveData(from: content)
        FileClassifier(useSubtypes: true) { category, tag, subtype, subtypeTag in
            if tag != "UNKNOWN" {
                var finalTag = tag
                if let subtypeTag = subtypeTag {
                    finalTag += "_" + subtypeTag
                }
                if FileTag.addTag(finalTag, to: path) {
                    DispatchQueue.main.async { state.numFileProcessed += 1 }
                }
            }
        }.classifyFileContent(fileContent: text)
    }

    public static func addTag(_ tag: String, to path: String) -> Bool {
        let xattrName = "com.apple.metadata:_kMDItemUserTags"
        var existingTags = [String]()
        let size = getxattr(path, xattrName, nil, 0, 0, 0)
        if size > 0 {
            var buffer = [UInt8](repeating: 0, count: size)
            let readSize = getxattr(path, xattrName, &buffer, size, 0, 0)
            if readSize >= 0 {
                if let tagsArray = try? PropertyListSerialization.propertyList(from: Data(buffer), options: [], format: nil) as? [String] {
                    existingTags = tagsArray
                }
            }
        } else if size == -1 && errno != ENOATTR {
            _ = String(cString: strerror(errno))
        }
        if existingTags.contains(tag) {
            print("Added tag \"\(tag)\" to \(path)")
            return true
        }
        existingTags.append(tag)
        if let newData = try? PropertyListSerialization.data(fromPropertyList: existingTags, format: .binary, options: 0) {
            let result = setxattr(path, xattrName, (newData as NSData).bytes, newData.count, 0, 0)
            if result == 0 {
                print("Added tag \"\(tag)\" to \(path)")
                return true
            }
        }
        return false
    }

    static func storeEmbedding(_ base64String: String, in path: String, attributeName: String = "com.mobico.prototype.DeepFinder.embedding") {
        let data = Data(base64String.utf8)
        data.withUnsafeBytes { buffer in
            guard let rawBuffer = buffer.baseAddress else { return }
            _ = setxattr(path, attributeName, rawBuffer, buffer.count, 0, 0)
        }
    }

    static func readEmbedding(from path: String, attributeName: String = "com.mobico.prototype.DeepFinder.embedding") -> String? {
        let length = getxattr(path, attributeName, nil, 0, 0, 0)
        guard length > 0 else { return nil }
        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes { buffer in
            getxattr(path, attributeName, buffer.baseAddress, buffer.count, 0, 0)
        }
        guard result >= 0 else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func iterateFiles(in directory: String, processingHandler: (String) -> Void) {
        let fileManager = FileManager.default
        let rootURL = URL(fileURLWithPath: directory)
        guard let enumerator = fileManager.enumerator(at: rootURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return }
        for case let fileURL as URL in enumerator {
            if !fileURL.lastPathComponent.hasPrefix(".") {
                processingHandler(fileURL.path)
            }
        }
    }

    static func fetchAllUserTags(completion: @escaping ([String]) -> Void) {
        var result: [String] = []
        for cat in AppDelegate.categoriesData {
            result.append(cat.tag)
            for subCat in cat.subtypes {
                result.append(subCat.tag)
            }
        }
        completion(result)
    }

}
