//
//  FileClassifier.swift
//  DeepFinder
//


import Foundation

class FileClassifier {
    private var handleClassifiedFile: (_ category: String, _ categoryTag: String, _ subtype: String?, _ subtypeTag: String?) -> Void
    private var openAiClient: OpenAiClient?
    private var ollamaClient: OllamaClient?
    private var useSubtypes: Bool
    private let categoriesData: [DocumentCategory]
    
    init(useSubtypes: Bool, handleClassifiedFile: @escaping (_ category: String, _ categoryTag: String, _ subtype: String?, _ subtypeTag: String?) -> Void) {
        self.useSubtypes = useSubtypes
        self.handleClassifiedFile = handleClassifiedFile
        categoriesData = AppDelegate.categoriesData
        if !AppDelegate.settingsModel.settings.openAiKey.isEmpty {
            self.openAiClient = OpenAiClient(isStreamMode: false) { messageId, response in
                if let response = response {
                    self.handleClassificationResponse(response)
                } else {
                }
            }
        } else if !AppDelegate.settingsModel.settings.ollamaUrl.isEmpty {
            ollamaClient = OllamaClient()
        }
    }
    
    func classifyFileContent(fileContent: String) {
        let prompt = buildClassificationPrompt(fileContent: fileContent)
        if let openAiClient = openAiClient {
            openAiClient.send(prompt, "File Classification")
        } else if let ollamaClient = ollamaClient {
            ollamaClient.sendRequest(prompt: prompt) { result in
                switch result {
                case .success(let response):
                    self.handleClassificationResponse(response.result)
                case .failure(let error):
                    print("Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func buildClassificationPrompt(fileContent: String) -> String {
        let listing = categoriesData.enumerated().map { (index, category) -> String in
            var catStr = "\(index + 1). \(category.name) (\(category.tag))"
            if useSubtypes {
                let subtypes = category.subtypes.enumerated().map { (subIndex, subtype) in
                    "   \(subIndex + 1). \(subtype.name) (\(subtype.tag))"
                }.joined(separator: "\n")
                catStr += "\n" + subtypes
            }
            return catStr
        }.joined(separator: "\n\n")
        let instructions = """
        Based on the following content, respond with EITHER:
        - a single number (the category index), or
        - two numbers (category index and subtype index),
        depending on whether you can identify a specific subtype or not.
        
        Content (truncated to 4096 chars if too long):
        \(fileContent.prefix(4096))
        
        IMPORTANT: Output only the number(s) separated by space. No other explanation.
        """
        return "\(listing)\n\n\(instructions)"
    }
    
    private func handleClassificationResponse(_ response: String) {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = trimmed.split(separator: " ").map(String.init)
        var chosenCategoryName = "UNKNOWN"
        var chosenCategoryTag = "UNKNOWN"
        var chosenSubtypeName: String? = nil
        var chosenSubtypeTag: String? = nil
        if components.count == 1, let cIdx = Int(components[0]), cIdx > 0, cIdx <= categoriesData.count {
            let category = categoriesData[cIdx - 1]
            chosenCategoryName = category.name
            chosenCategoryTag = category.tag
        } else if components.count == 2,
                  let cIdx = Int(components[0]), cIdx > 0, cIdx <= categoriesData.count,
                  let sIdx = Int(components[1]) {
            let category = categoriesData[cIdx - 1]
            chosenCategoryName = category.name
            chosenCategoryTag = category.tag
            if sIdx > 0, sIdx <= category.subtypes.count {
                let subtype = category.subtypes[sIdx - 1]
                chosenSubtypeName = subtype.name
                chosenSubtypeTag = subtype.tag
            }
        } else {
            print("Unexpected classification response: \(trimmed)")
        }
        handleClassifiedFile(chosenCategoryName, chosenCategoryTag, chosenSubtypeName, chosenSubtypeTag)
    }
}
