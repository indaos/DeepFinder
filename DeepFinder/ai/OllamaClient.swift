//
//  OllamaClient.swift
//  DeepFinder
//
//

import Foundation
import OllamaKit


struct OllamaResponse: Codable {
    let result: String
}

class OllamaClient {
    private let baseURL: URL
    private let session: URLSession
    private let ollama: OllamaKit

    private static let thinkTagPattern: NSRegularExpression = {
        do {
            return try NSRegularExpression(pattern: "<think>.*?</think>", options: .dotMatchesLineSeparators)
        } catch {
            fatalError("Invalid regular expression pattern: \(error)")
        }
    }()

    init(baseURL: URL = URL(string: "http://localhost:11434")!, session: URLSession = .shared) {
        self.baseURL = URL(string: AppDelegate.settingsModel.settings.ollamaUrl) ?? baseURL
        self.session = session
        self.ollama = OllamaKit(baseURL: self.baseURL)
    }

    func sendRequest(prompt: String, model: String = "deepseek-r1:14b", completion: @escaping (Result<OllamaResponse, Error>) -> Void) {
        let fullPrompt = prompt + PromptTemplates.ollamaPromptAddition
        let requestData = OKGenerateRequestData(model: model, prompt: fullPrompt)
        
        Task {
            do {
                var result = ""
                for try await response in ollama.generate(data: requestData) {
                    result.append(response.response)
                }
                
                let range = NSRange(location: 0, length: result.utf16.count)
                let cleanedResult = Self.thinkTagPattern.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: range,
                    withTemplate: ""
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                
                let ollamaResponse = OllamaResponse(result: cleanedResult)
                completion(.success(ollamaResponse))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
