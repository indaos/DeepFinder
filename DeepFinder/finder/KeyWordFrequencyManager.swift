//
//  KeyWordFrequencyManager.swift
//  DeepFinder
//
//

import Foundation
import Collections
import SortedCollections


final class KeyWordFrequencyManager {
    private var fileToFreq: [String: Int] = [:]
    private var freqToFiles: [Int: Set<String>] = [:]
    private var sortedFrequencies = SortedSet<Int>()
    private var fileToSim: [String: Int] = [:]
    private var fileToDate: [String: Date] = [:]
    private let lock = NSLock()
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter
    }()
    
    func incrementKeyWordFrequency(_ filename: String, date: Date, similarity: Double = 0.0) {
        lock.lock()
        defer { lock.unlock() }
        
        fileToDate[filename] = date
        let oldFreq = fileToFreq[filename, default: 0]
        let newFreq = oldFreq + 1
        fileToFreq[filename] = newFreq
        
        if oldFreq > 0, var oldSet = freqToFiles[oldFreq] {
            oldSet.remove(filename)
            if oldSet.isEmpty {
                freqToFiles[oldFreq] = nil
                sortedFrequencies.remove(oldFreq)
            } else {
                freqToFiles[oldFreq] = oldSet
            }
        }
        
        var newSet = freqToFiles[newFreq] ?? Set<String>()
        newSet.insert(filename)
        freqToFiles[newFreq] = newSet
        sortedFrequencies.insert(newFreq)
        
        if similarity > 0 {
            fileToSim[filename] = Int(similarity * 100)
        }
    }
    
    func getSortedList(startIndex: Int,
                       maxKeyWord: Int,
                       extensions: [String],
                       sortColumn: Int,
                       ascending: Bool = false,
                       _ maxCount: Int = -1) -> [FileItem] {
        lock.lock()
        defer { lock.unlock() }
        
        let sortedFiles: [String]
        if sortColumn == 1 {
            sortedFiles = fileToDate.keys.sorted { f1, f2 in
                let d1 = fileToDate[f1] ?? Date.distantPast
                let d2 = fileToDate[f2] ?? Date.distantPast
                if d1 == d2 {
                    return ascending ? (fileToFreq[f1, default: 0] < fileToFreq[f2, default: 0]) : (fileToFreq[f1, default: 0] > fileToFreq[f2, default: 0])
                }
                return ascending ? (d1 < d2) : (d1 > d2)
            }
        } else {
            let sortedFrequenciesArray: [Int] = ascending ? Array(sortedFrequencies) : sortedFrequencies.reversed()
            sortedFiles = sortedFrequenciesArray.flatMap { freq in
                let files = freqToFiles[freq] ?? []
                return files.sorted {
                    let d1 = fileToDate[$0] ?? Date.distantPast
                    let d2 = fileToDate[$1] ?? Date.distantPast
                    return ascending ? (d1 < d2) : (d1 > d2)
                }
            }
        }
        
        let filteredFiles = sortedFiles.filter {
            extensions.isEmpty || extensions.contains(URL(fileURLWithPath: $0).pathExtension)
        }
        
        let formatter = KeyWordFrequencyManager.dateFormatter
        let mappedItems: [FileItem] = filteredFiles.map { filename in
            let freq = fileToFreq[filename] ?? 0
            let sim = fileToSim[filename] ?? 0
            let updated = fileToDate[filename] ?? Date.distantPast
            let percentage = maxKeyWord != 0 ? Int(Double(freq) / Double(maxKeyWord) * 100) : 0
            return FileItem(name: filename,
                            freq: percentage,
                            similarity: sim,
                            updated: formatter.string(from: updated))
        }
        
        let slicedItems = mappedItems.dropFirst(startIndex)
        return maxCount > 0 ? Array(slicedItems.prefix(maxCount)) : Array(slicedItems)
    }
    
    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        fileToFreq.removeAll(keepingCapacity: false)
        freqToFiles.removeAll(keepingCapacity: false)
        fileToDate.removeAll(keepingCapacity: false)
        fileToSim.removeAll(keepingCapacity: false)
        sortedFrequencies = SortedSet<Int>()
    }
}
