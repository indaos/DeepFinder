//
//  OpenAiClient.swift
//  DeepFinder
//
//

import Foundation
import OpenAI

class OpenAiClient {
    let config: OpenAI.Configuration
    var openAI: OpenAI?
    let completion: (String, String?) -> Void
    let messageId: String
    var responseBuffer: [String] = []
    let bufferLengthLimit = 100
    var sent = false
    var isStreamMode = false
    
    init(isStreamMode: Bool, _ completion: @escaping (String, String?) -> Void) {
        config = OpenAI.Configuration(token: AppDelegate.settingsModel.settings.openAiKey, timeoutInterval: 60.0)
        openAI = OpenAI(configuration: config)
        messageId = UUID().uuidString
        self.isStreamMode = isStreamMode
        self.completion = completion
    }
    
    deinit {
        openAI = nil
    }
    
    func sendBufferedResponses() {
        guard !responseBuffer.isEmpty else { return }
        let bufferedContent = responseBuffer.joined()
        addResponse(bufferedContent)
        responseBuffer.removeAll()
    }
    
    func send(_ text: String, _ context: String) {
        guard let msg = ChatQuery.ChatCompletionMessageParam(role: .user, content: text) else { return }
        let query = !isStreamMode ?
        ChatQuery(messages: [msg], model: .gpt4_o, maxTokens: 150, temperature: AppDelegate.settingsModel.settings.temperature, topP: AppDelegate.settingsModel.settings.topp)
        : ChatQuery(messages: [msg], model: .gpt4_o)
        
        if !isStreamMode {
            openAI?.chats(query: query) { result in
                switch result {
                case .success(let result):
                    if let str = result.choices.first?.message.content?.string {
                        self.responseBuffer.append(str)
                        self.sendBufferedResponses()
                    }
                case .failure:
                    self.sendBufferedResponses()
                }
            }
        } else {
            openAI?.chatsStream(query: query) { partialResult in
                switch partialResult {
                case .success(let result):
                    guard result.choices.first?.finishReason as? String != "stop" else { return }
                    if let str = result.choices.first?.delta.content {
                        self.responseBuffer.append(str)
                        if self.responseBuffer.count >= self.bufferLengthLimit {
                            self.sendBufferedResponses()
                            self.sent = true
                        }
                    }
                case .failure:
                    self.sendBufferedResponses()
                    return
                }
            } completion: { error in
                if !self.sent {
                    self.sendBufferedResponses()
                }
            }
        }
    }
    
    func addResponse(_ text: String?) {
        guard let text = text, !text.isEmpty else { return }
        completion(messageId, text)
    }
}
