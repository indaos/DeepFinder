//
//  SpotlightParallelSearcher.swift
//  DeepFinder
//
//

import Foundation
import Cocoa
import NaturalLanguage
import Accelerate

final class SpotlightParallelSearcher: NSObject, NSMetadataQueryDelegate {
    private var queries: [NSMetadataQuery] = []
    private var resultsCount: [URL: Int] = [:]
    private let resultsQueue = DispatchQueue(label: "com.spotlightsearcher.resultsQueue")
    private let dispatchGroup = DispatchGroup()
    private let threadLock = DispatchQueue(label: "com.spotlightsearcher.lock")
    private var shouldTerminate = false
    private var batchSize: Int = 40
    private var onBatchReady: (([FileItem], Bool, Double) -> Void)?
    private var onCompletion: (() -> Void)?
    public var finishedThread: Int = 0
    public var queryString = ""
    public var keywordsArray: [String] = []
    public var priorityExtension: [String] = []
    public var priorityTags: [String] = []
    public var allExtension: [String: Int] = [:]
    private var keyWordManager: KeyWordFrequencyManager?
    private var currentIndex = 0
    private var canceled: Bool = false
    private var queryVector: [Double]?
    private var sortedColumn = 0
    private var ascending = false

    func search(queryString: String,
                genKeyWords: Bool,
                batchSize: Int = 50,
                onBatchReady: @escaping ([FileItem], Bool, Double) -> Void,
                onCompletion: (() -> Void)? = nil) {
        keyWordManager = KeyWordFrequencyManager()
        self.batchSize = batchSize
        self.onBatchReady = onBatchReady
        self.onCompletion = onCompletion
        self.resultsCount = [:]
        self.shouldTerminate = false
        self.canceled = false
        self.finishedThread = 0
        self.queryString = queryString
        keywordsArray = queryString.components(separatedBy: " ")
        keyWordManager?.removeAll()
        
        print("*** keys: \(keywordsArray)")
        print("*** exts: \(priorityExtension)")
        print("*** exts: \(priorityTags)")
        print("******* start MAIN \(keywordsArray.count)")

        for keyword in keywordsArray {
            dispatchGroup.enter()
            let query = NSMetadataQuery()
            query.delegate = self
            var subpredicates = [NSPredicate]()
            let keywordPredicate = NSPredicate(format: "kMDItemTextContent CONTAINS[c] %@", keyword)
            subpredicates.append(keywordPredicate)
            if !priorityExtension.isEmpty {
                let fileExtensionsPredicate: NSPredicate
                if priorityExtension.count == 1, let ext = priorityExtension.first {
                    fileExtensionsPredicate = NSPredicate(format: "kMDItemFSName ENDSWITH[c] %@", ext)
                } else {
                    let extensionPredicates = priorityExtension.map { NSPredicate(format: "kMDItemFSName ENDSWITH[c] %@", $0) }
                    fileExtensionsPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: extensionPredicates)
                }
                subpredicates.append(fileExtensionsPredicate)
            }
            if !priorityTags.isEmpty {
                if priorityTags.count == 1, let singleTag = priorityTags.first {
                    let tagsPredicate = NSPredicate(format: "ANY kMDItemUserTags CONTAINS[c] %@", singleTag)
                    subpredicates.append(tagsPredicate)
                } else {
                    let tagPredicates = priorityTags.map { NSPredicate(format: "ANY kMDItemUserTags CONTAINS[c] %@", $0) }
                    let tagsPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: tagPredicates)
                    subpredicates.append(tagsPredicate)
                }
            }
            if subpredicates.isEmpty {
                query.predicate = NSPredicate(value: true)
            } else if subpredicates.count == 1 {
                query.predicate = subpredicates[0]
            } else {
                query.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
            }
            query.searchScopes = [NSMetadataQueryLocalComputerScope]
            NotificationCenter.default.addObserver(self, selector: #selector(queryDidFinishGathering(_:)), name: .NSMetadataQueryDidFinishGathering, object: query)
            self.queries.append(query)
            DispatchQueue.main.async { query.start() }
        }
        self.dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            print("******* complete MAIN 0")

            self.onCompletion?()
        }
    }
    
    @objc private func queryDidFinishGathering(_ notification: Notification) {
        guard let query = notification.object as? NSMetadataQuery else { return }
        query.disableUpdates()
        query.stop()
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: query)
        let items = query.results.compactMap { $0 as? NSMetadataItem }
        resultsQueue.async {
            let updateFrequency = 1000
            let maxItems = Int(AppDelegate.settingsModel.settings.numResultFiles)
            for (index, item) in items.prefix(maxItems).enumerated() {
                if self.canceled { break }
                if let path = item.value(forAttribute: kMDItemPath as String) as? String {
                    let fileDate = item.value(forAttribute: kMDItemContentModificationDate as String) as? Date ?? Date()
                    self.updateAllExtension(path: path)
                    let similarity = 0.0 // It is not being used at the moment
                    self.keyWordManager?.incrementKeyWordFrequency(path, date: fileDate, similarity: similarity)
                }
                if index % updateFrequency == 0 {
                    DispatchQueue.main.async { self.processUIUpdates() }
                }
            }
            self.safelyIncrementFinishedThreads()
            self.processUIUpdates()
            self.dispatchGroup.leave()
            print("******* complete leave ")

        }
    }
    
    private func updateAllExtension(path: String) {
        let ext = URL(fileURLWithPath: path).pathExtension
        let oldFreq = self.allExtension[ext, default: 0]
        self.allExtension[ext] = oldFreq + 1
    }
    
    func getSortedExtension() -> [String] {
        return allExtension.sorted { $0.value > $1.value }.map { $0.key }
    }
    
    private func safelyIncrementFinishedThreads() {
        threadLock.sync { finishedThread += 1 }
    }
    
    private func processUIUpdates() {
        guard let sortedResult = keyWordManager?.getSortedList(startIndex: currentIndex, maxKeyWord: keywordsArray.count, extensions: priorityExtension, sortColumn: sortedColumn, ascending: ascending, batchSize),
              !sortedResult.isEmpty else { return }
        DispatchQueue.main.async {
            let percentage = self.keywordsArray.isEmpty ? 0.0 : Double(self.finishedThread) / Double(self.keywordsArray.count)
            self.onBatchReady?(sortedResult, true, percentage)
        }
    }
    
    func getBatch(startIndex index: Int, windowSize: Int = 20, _ sortedColumn: Int = 0, _ ascending: Bool = false) -> ([FileItem], Int) {
        self.sortedColumn = sortedColumn
        self.ascending = ascending
        guard let sortedResult = keyWordManager?.getSortedList(startIndex: index, maxKeyWord: keywordsArray.count, extensions: priorityExtension, sortColumn: sortedColumn, ascending: ascending, windowSize),
              !sortedResult.isEmpty else {
            return ([], 0)
        }
        let newIndex = index + sortedResult.count
        return (sortedResult, newIndex)
    }
    
    func deliverBatches(index: Int, _ replace: Bool = false) -> Int {
        guard let sortedResult = keyWordManager?.getSortedList(startIndex: index, maxKeyWord: keywordsArray.count, extensions: priorityExtension, sortColumn: sortedColumn, ascending: ascending, batchSize),
              !sortedResult.isEmpty else { return index }
        let total = sortedResult.count
        for chunkStart in stride(from: 0, to: total, by: batchSize) {
            let chunk = Array(sortedResult[chunkStart..<min(chunkStart + batchSize, total)])
            DispatchQueue.main.async {
                let percentage = self.keywordsArray.isEmpty ? 0.0 : Double(self.finishedThread) / Double(self.keywordsArray.count)
                self.onBatchReady?(chunk, replace, percentage)
            }
        }
        return index + total
    }
    
    func cancel() {
        cancelAllQueries()
        finishedThread = 0
        onCompletion?()
    }
    
    func removeAll() {
        resultsCount = [:]
        keywordsArray = []
        keyWordManager?.removeAll()
    }
    
    private func cancelAllQueries() {
        canceled = true
        for query in queries {
            query.disableUpdates()
            query.stop()
            NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: query)
        }
        queries.removeAll()
    }
}
