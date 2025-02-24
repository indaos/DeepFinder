//
//  Prompter.swift
//  DeepFinder
//
//

import Foundation
import OpenAI

class Prompter {
    static func generateKeywords(for queryString: String, completion: @escaping (String, [String]) -> Void) {
        let maxWordsCount = Int(AppDelegate.settingsModel.settings.numKeyWords) ?? 20
        let getPriorityExtensionsPrompt = PromptTemplates.priorityExtensionsPrompt(query: queryString)
        let extractLocalKeyWordsPrompt = PromptTemplates.localKeywordsPrompt(query: queryString)
        let extractGlobalKeyWordsPrompt = PromptTemplates.globalKeywordsPrompt(query: queryString)
        
        askToGenerateKeywords(for: getPriorityExtensionsPrompt) { priorityExtensions in
            self.askToGenerateKeywords(for: extractLocalKeyWordsPrompt) { localKeywords in
                self.askToGenerateKeywords(for: extractGlobalKeyWordsPrompt) { globalKeywords in
                    let uniqueKeywords = {
                        var seen = Set<String>()
                        return (localKeywords + globalKeywords).filter { seen.insert($0).inserted }
                    }()
                    let topWords = uniqueKeywords.prefix(maxWordsCount)
                    completion(topWords.joined(separator: " "), priorityExtensions)
                }
            }
        }
    }
    
    private static func askToGenerateKeywords(for queryString: String, separate: Bool = true, completion: @escaping ([String]) -> Void) {
        let semaphore = DispatchSemaphore(value: 0)
        var keywordsResult: String?
        if !AppDelegate.settingsModel.settings.openAiKey.isEmpty {
            OpenAiClient(isStreamMode: false) { _, result in
                keywordsResult = result
                semaphore.signal()
            }.send(queryString, "")
        } else if !AppDelegate.settingsModel.settings.ollamaUrl.isEmpty {
            OllamaClient().sendRequest(prompt: queryString) { result in
                switch result {
                case .success(let response):
                    print("Received response: \(response.result)")
                    keywordsResult = response.result
                case .failure(let error):
                    print("Error: \(error.localizedDescription)")
                }
                semaphore.signal()
            }
        } else {
            semaphore.signal()
        }
        if semaphore.wait(timeout: .now() + 60) == .timedOut {
            completion([])
        } else {
            if separate {
                let keywords = keywordsResult?.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty } ?? []
                completion(keywords)
            } else {
                completion([keywordsResult ?? ""])
            }
        }
    }
    
    static func generateLineRange(for queryString: String,path: String, completion: @escaping ([Int]) -> Void) {
        let semaphore = DispatchSemaphore(value: 0)
        var lines: [Int] = []
        func addLineNumbers(to text: String) -> String {
            let lines = text.components(separatedBy: .newlines)
            let numberedLines = lines.enumerated().map { index, line in
                "\(index + 1) \(line)"
            }
            return numberedLines.joined(separator: "\n")
        }
        Task {
            let text = await TextExtractor.extractText(from:  URL(fileURLWithPath: path)) ?? ""
            guard text.count < 1024*100  else {
                semaphore.signal()
                return
            }
            let getLineRange = PromptTemplates.answerLineRange(query: queryString) + addLineNumbers(to: text)
            askToGenerateKeywords(for: getLineRange) { lineRange in
                guard lineRange.count > 0  else {
                    semaphore.signal()
                    return
                }
                lines = lineRange[0].split(separator: ",").compactMap {
                    Int(String($0).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
                }
                semaphore.signal()
            }
        }
        if semaphore.wait(timeout: .now() + 60) == .timedOut {
            completion([-1,-1])
        } else {
            if lines.count != 2 {
                completion([-1,-1])
            } else {
                completion(lines)
            }
        }
    }
    
    static func getFileSize(at path: String) -> Int64? {
        let fileManager = FileManager.default
        do {
            let attributes = try fileManager.attributesOfItem(atPath: path)
            if let fileSize = attributes[.size] as? Int64 {
                return fileSize
            }
        } catch {
            print("Error getting file size: \(error.localizedDescription)")
        }
        return nil
    }
    
    static func generateAnswer(for queryString: String,path: String, completion: @escaping (String) -> Void) {
        let semaphore = DispatchSemaphore(value: 0)
        var answer = ""
        print("**********")
        Task {
            let text = await TextExtractor.extractText(from:  URL(fileURLWithPath: path)) ?? ""
            guard text.count < 1024*100  else {
                semaphore.signal()
                return
            }
            let getLineRange = PromptTemplates.answerTextBlock(query: queryString, fileContent: text) + text
            askToGenerateKeywords(for: getLineRange, separate: false) { answers in
                print("answer ******* \n(\(answers))")
                guard answers.count > 0  else {
                    semaphore.signal()
                    return
                }
                answer = answers[0].replacingOccurrences(of: "^```\\w+\\s*", with: "", options: .regularExpression)
                semaphore.signal()
            }
        }
        if semaphore.wait(timeout: .now() + 60) == .timedOut {
            completion("")
        } else {
            if answer.count > 0 {
                completion(answer)
            } else {
                completion("")
            }
        }
    }
    
    
}
