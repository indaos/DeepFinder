//
//  ChatAssitant.swift
//  DeepFinder
//
//

import OpenAI
import Foundation

class ChatAssitant {
    let query: String
    let handler: (String, Bool) -> Void
    let openAI = OpenAI(apiToken:  AppDelegate.settingsModel.settings.openAiKey)
    typealias PropertyType = ChatQuery.ChatCompletionToolParam.FunctionDefinition.FunctionParameters.Property
    var lastAssistantMessage = ""
    private var clarificationsCount = 0
    private let maxClarifications = 3

    let finalizeRequestFunction: [ChatQuery.ChatCompletionToolParam] = [
        ChatQuery.ChatCompletionToolParam(function: .init(
            name: "finalize_request",
            description: "Outputs the final details after clarifications for an abstract query",
            parameters: .init(
                type: .object,
                properties: [
                    "topic": PropertyType(type: .string, description: "The specific topic the user decided on after clarifications"),
                    "detailLevel": PropertyType(type: .string, description: "How in-depth or high-level the user wants to explore"),
                    "additionalNotes": PropertyType(type: .string, description: "Any extra clarifications or notes about the final request")
                ],
                required: ["topic"]
            )
        ))
    ]

    lazy var messages: [ChatQuery.ChatCompletionMessageParam] = [
        .init(role: .system, content: PromptTemplates.chatSystemMessage)!,
        .init(role: .user, content: PromptTemplates.chatUserMessage(query: query))!
    ]

    init(query: String, handler: @escaping (String, Bool) -> Void) {
        self.query = query
        self.handler = handler
    }

    func addAClarification(_ clarification: String) {
        if clarificationsCount >= maxClarifications {
            forceFinalize()
            return
        }
        clarificationsCount += 1
        messages.append(contentsOf: [
            .init(role: .assistant, content: clarification)!,
            .init(role: .user, content: clarification)!
        ])
        conversationLoop()
    }

    private func forceFinalize() {
        messages.append(.init(role: .system, content: PromptTemplates.maxClarificationsPrompt)!)
        conversationLoop()
    }

    func conversationLoop() {
        sendChat(messages: messages) { assistantMessage in
            if let toolCalls = assistantMessage.toolCalls, let functionCall = toolCalls.first?.function {
                self.handleFunctionCall(functionCall)
            } else if case .assistant(let msg) = assistantMessage {
                self.lastAssistantMessage = msg.content ?? ""
                self.handler(self.lastAssistantMessage, false)
            }
        }
    }

    private func sendChat(messages: [ChatQuery.ChatCompletionMessageParam], completion: @escaping (ChatQuery.ChatCompletionMessageParam) -> Void) {
        let chatQuery = ChatQuery(messages: messages, model: .gpt4_o, tools: finalizeRequestFunction)
        openAI.chats(query: chatQuery) { result in
            switch result {
            case .success(let response):
                if let assistantMessage = response.choices.first?.message {
                    completion(assistantMessage)
                } else {
                }
            case .failure(let error):
                print("Error: \(error.localizedDescription)")
            }
        }
    }

    private func handleFunctionCall(_ functionCall: ChatQuery.ChatCompletionMessageParam.AssistantMessageParam.ToolCallParam.FunctionCall) {
        guard let jsonData = functionCall.arguments.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { return }
        let topic = dict["topic"] as? String ?? ""
        let detailLevel = dict["detailLevel"] as? String ?? ""
        let additionalNotes = dict["additionalNotes"] as? String ?? ""
        
        print("DECISION *****")
        print("Topic: \(topic)")
        print("Detail Level: \(detailLevel)")
        print("Additional Notes: \(additionalNotes)")
        
        self.handler(topic + "," + additionalNotes, true)
    }


}
