//
//  DirectoryMonitor.swift
//  DeepFinder
//
//

import Foundation


class DirectoryMonitor {

    private var stream: FSEventStreamRef?
    private let pathsToWatch: [String]
    private var filePaths: [String] = []
    private let filePathsQueue = DispatchQueue(label: "directory.monitor.filepaths")
    private var stopProcessing = false

    init(pathsToWatch: [String]) {
        self.pathsToWatch = pathsToWatch
        startProcessingQueue()
    }

    func start() {
        let pathsToWatchCFArray = pathsToWatch as CFArray
        let callback: FSEventStreamCallback = { (streamRef, clientCallBackInfo, numEvents, eventPathsPointer, eventFlags, eventIds) in
            let cfArray = Unmanaged<CFArray>.fromOpaque(eventPathsPointer).takeUnretainedValue()
            guard let paths = cfArray as? [String] else { return }
            let monitor = Unmanaged<DirectoryMonitor>.fromOpaque(clientCallBackInfo!).takeUnretainedValue()
            for i in 0..<numEvents {
                let changedPath = paths[i]
                let flags = eventFlags[i]
                let eventID = eventIds[i]
                monitor.handle(eventID: eventID, path: changedPath, flags: flags)
            }
        }
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToWatchCFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer)
        )
        if let stream = stream {
            FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            let started = FSEventStreamStart(stream)
            if !started {}
        }
    }

    func stop() {
        guard let stream = stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        stopProcessingQueue()
    }

    private func handle(eventID: FSEventStreamEventId, path: String, flags: FSEventStreamEventFlags) {
        if (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated)) != 0 {
            enqueueFile(path: path)
        }
        if (flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified)) != 0 {
            enqueueFile(path: path)
        }
    }
}

extension DirectoryMonitor {

    private func enqueueFile(path: String) {
        filePathsQueue.sync {
            if !filePaths.contains(path) {
                filePaths.append(path)
            }
        }
    }

    private func startProcessingQueue() {
        stopProcessing = false
        DispatchQueue.global().async {
            while !self.stopProcessing {
                var filePath: String?
                self.filePathsQueue.sync {
                    filePath = self.filePaths.first
                }
                guard let path = filePath else {
                    Thread.sleep(forTimeInterval: 10)
                    continue
                }
                let success = self.handleFile(path: path)
                self.filePathsQueue.sync {
                    if success {
                        self.filePaths.removeFirst()
                    } else {
                        self.filePaths.append(self.filePaths.removeFirst())
                    }
                }
                Thread.sleep(forTimeInterval: 10)
            }
        }
    }

    private func stopProcessingQueue() {
        stopProcessing = true
    }

    private func handleFile(path: String) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            let url = URL(fileURLWithPath: path)
            if let content = await TextExtractor.extractText(from: url) {
                let text = TextExtractor.removeAllSensitiveData(from: content)
                FileClassifier(useSubtypes: true) { category, tag, subtype, subtypeTag in
                    if tag != "UNKNOWN" {
                        var finalTag = tag
                        if let subtypeTag = subtypeTag {
                            finalTag += ("_" + subtypeTag)
                        }
                        FileTag.addTag(finalTag, to: path)
                    }
                    semaphore.signal()
                }.classifyFileContent(fileContent: text)
            } else {
                semaphore.signal()
            }
        }
        return semaphore.wait(timeout: .now() + 120) != .timedOut
    }
}
