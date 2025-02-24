//
//  PromptTemplates.swift
//  DeepFinder
//
//



class PromptTemplates {
    static let chatSystemMessage = """
    You are a helpful assistant. If the user's request is ambiguous, ask up to two brief clarifying questions,
    each in one short sentence. Once you have enough information, call the function 'finalize_request'
    with the relevant details.
    """
    
    static func chatUserMessage(query: String) -> String {
        return """
        You are an expert in text analysis. Please generate 50 context-aware, one-word keywords 
        (excluding any hyphenated words) for the following search query. These keywords should be 
        highly relevant and frequently associated with the query while avoiding words commonly found 
        across unrelated topics. Provide them separated by spaces, with no commas. Query: \(query)
        """
    }
    
    static let maxClarificationsPrompt = """
    You have reached the maximum number of allowed clarifications.
    Please finalize your response now by calling 'finalize_request' with your best information.
    """
    
    static let ollamaPromptAddition = "Provide only the result as words separated by spaces, without any introductions or conclusions."
    
    static func priorityExtensionsPrompt(query: String) -> String {
        return  """
                Provide only the most relevant file extensions (omitting the dot), separated by spaces, that are 
                commonly associated with this query’s content. Query: \(query)
                """
    }
    
    static func localKeywordsPrompt(query: String) -> String {
        return "Extract only the relevant index words from the query, using exactly the words provided. List them separated by spaces: \(query)"
    }
    
    static func globalKeywordsPrompt(query: String) -> String {
        return """
                You are an expert in text analysis. Please generate 50 context-aware, one-word keywords
                (excluding any hyphenated words) for the following search query. These keywords should be
                highly relevant and frequently associated with the query while avoiding words commonly 
                found across unrelated topics. Provide them separated by spaces, with no commas. Query: \(query)
                """
    }
    
    
    static func answerLineRange(query: String) -> String {
        return "Return only the start and end line numbers that match the query in this file, formatted as: start_line,end_line. Each line in the file begins with its line number. Return only these numbers, without any additional text or explanation. Query: \(query)"
    }
    
    static func answerTextBlock(query: String, fileContent: String) -> String {
        return """
        Based on this query, extract and return the exact text block from this file that matches the query. 
        Ensure that:
        - The extracted text **is identical** to how it appears in the file.
        - **Do not modify** indentation, whitespace, tabs (`\t`), or newlines.
        - **Do not alter** character encoding or replace special characters.
        - The output must match the **exact formatting** of the original file.
        Query:
        \(query)
        File:
        \(fileContent)
        """
    }

}
