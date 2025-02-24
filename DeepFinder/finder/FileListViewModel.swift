//
//  FileListViewModel.swift
//  DeepFinder
//
//

import SwiftUI
import Foundation

class FileListViewModel: ObservableObject {
    @Published var fileList: [FileItem] = []
    
    var searcher = SpotlightParallelSearcher()
    private var hasMoreData = true
    private var lastDeliveredIndex = 0
    private var startShutdown = false
    private var isLoading = false
    private var genKeyWords = false
    
    func startSearch(query: String, _ genKeyWords: Bool = false, onCompletion: @escaping () -> Void, progress: @escaping (Double) -> Void) {
        hasMoreData = true
        lastDeliveredIndex = 0
        startShutdown = false
        isLoading = true
        self.genKeyWords = genKeyWords
        
        removeAll()
        
        searcher.search(
            queryString: query,
            genKeyWords: true,
            batchSize: 50,
            onBatchReady: { [weak self] batch, replace, percentage in
                guard let self = self, !self.startShutdown else { return }
                progress(percentage)
                DispatchQueue.main.async {
                    if replace {
                        self.fileList = batch
                    } else {
                        self.fileList.append(contentsOf: batch)
                    }
                    if batch.isEmpty {
                        self.hasMoreData = false
                    }
                }
            },
            onCompletion: {
                print("******* complete MAIN")
                self.isLoading = false
                onCompletion()
            }
        )
    }
    
    func setExtension(_ ext: String, _ value: Bool) -> Bool {
        if !value {
            if genKeyWords, searcher.priorityExtension.count == 1 { return false }
            searcher.priorityExtension.removeAll { $0 == ext }
        } else {
            searcher.priorityExtension.append(ext)
        }
        if !isLoading {
            reload()
        }
        return true
    }
    
    func setTag(_ tag: String, _ value: Bool) -> Bool {
        if !value {
            searcher.priorityTags.removeAll { $0 == tag }
        } else {
            searcher.priorityTags.append(tag)
        }
        return true
    }
    
    func reload(_ sortedColumn: Int = 0, _ ascending: Bool = false) {
        let result = searcher.getBatch(startIndex: 0, windowSize: 40, sortedColumn, ascending)
        fileList = result.0
        lastDeliveredIndex = result.1
    }
    
    func isExtension(_ ext: String) -> Bool {
        searcher.priorityExtension.contains(ext)
    }
    
    func isTag(_ tag: String) -> Bool {
        searcher.priorityTags.contains(tag)
    }
    
    func getFileList() -> [FileItem] {
        fileList
    }
    
    func getFileListCount() -> Int {
        fileList.count
    }
    
    func isLastFile(file: FileItem) -> Bool {
        fileList.last == file
    }
    
    func removeAll() {
        fileList.removeAll(keepingCapacity: false)
        searcher.removeAll()
    }
    
    func loadNextBatch() {
        guard hasMoreData else { return }
        if !isLoading {
            let result = searcher.getBatch(startIndex: lastDeliveredIndex)
            if result.1 == lastDeliveredIndex {
                hasMoreData = false
            } else {
                fileList.append(contentsOf: result.0)
                lastDeliveredIndex = result.1
            }
        } else {
            let newIndex = searcher.deliverBatches(index: lastDeliveredIndex, false)
            if newIndex == lastDeliveredIndex {
                hasMoreData = false
            } else {
                lastDeliveredIndex = newIndex
            }
        }
    }
    
    func cancelSearch() {
        startShutdown = true
        searcher.cancel()
        lastDeliveredIndex = 0
    }
}
