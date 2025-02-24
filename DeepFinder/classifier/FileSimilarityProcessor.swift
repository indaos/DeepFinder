//
//  FileSimilarityProcessor.swift
//  DeepFinder
//
//
 
import Foundation
import NaturalLanguage
import Vision
import PDFKit

class FileSimilarityProcessor {
    static var sentenceEmbedding: NLEmbedding? = NLEmbedding.wordEmbedding(for: .english)
    static var germanWordEmbedding: NLEmbedding? = NLEmbedding.wordEmbedding(for: .german)
    static var russianWordEmbedding: NLEmbedding? = NLEmbedding.wordEmbedding(for: .russian)
    static var italienWordEmbedding: NLEmbedding? = NLEmbedding.wordEmbedding(for: .italian)
    static var spanishWordEmbedding: NLEmbedding? = NLEmbedding.wordEmbedding(for: .spanish)
    static var frenchWordEmbedding: NLEmbedding? = NLEmbedding.wordEmbedding(for: .french)
    static var bulgarianWordEmbedding: NLEmbedding? = NLEmbedding.wordEmbedding(for: .bulgarian)
    static var polishWordEmbedding: NLEmbedding? = NLEmbedding.wordEmbedding(for: .polish)

    static func createEmbedding(from text: String) -> [Double]? {
        guard let language = detectedLanguage(for: text) else {
            return nil
        }

        let words = text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.filter { $0.isLetter } }
            .filter { !$0.isEmpty }
        
        guard !words.isEmpty else {
            return nil
        }
        
        let embedding: NLEmbedding?
        switch language {
        case .english:
            embedding = sentenceEmbedding
        case .german:
            embedding = germanWordEmbedding
        case .russian:
            embedding = russianWordEmbedding
        case .italian:
            embedding = italienWordEmbedding
        case .spanish:
            embedding = spanishWordEmbedding
        case .french:
            embedding = frenchWordEmbedding
        case .bulgarian:
            embedding = bulgarianWordEmbedding
        case .polish:
            embedding = polishWordEmbedding
        default:
            return nil
        }
        
        guard let model = embedding else {
            return nil
        }
        
        let vectors = words.compactMap { model.vector(for: $0) }
        guard !vectors.isEmpty else { return nil }
        
        return average(vectors: vectors)
    }

    private static func average(vectors: [[Double]]) -> [Double] {
        let count = Double(vectors.count)
        var sum = [Double](repeating: 0, count: vectors[0].count)
        for vector in vectors {
            sum = zip(sum, vector).map(+)
        }
        return sum.map { $0 / count }
    }

    static func detectedLanguage(for text: String) -> NLLanguage? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage
    }

    static func isEnglish(text: String) -> Bool {
        return detectedLanguage(for: text) == .english
    }

    static func isGerman(text: String) -> Bool {
        return detectedLanguage(for: text) == .german
    }
    
    static func normalizeVector(_ vector: [Double]) -> [Double]? {
        let magnitude = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        guard magnitude > 0 else { return nil }
        return vector.map { $0 / magnitude }
    }
    
    static func cosineSimilarity(_ vectorA: [Double], _ vectorB: [Double]) -> Double? {
        guard vectorA.count == vectorB.count else {
            return nil
        }
        guard let normalizedA = normalizeVector(vectorA),
              let normalizedB = normalizeVector(vectorB) else {
            return nil
        }
        let dotProduct = zip(normalizedA, normalizedB).reduce(0) { $0 + $1.0 * $1.1 }
        return abs(dotProduct)
    }
    
    static func cosineSimilarity3(_ vectorA: [Double], _ vectorB: [Double]) -> Double? {
        guard vectorA.count == vectorB.count else {
            return nil
        }
        let distance = sqrt(zip(vectorA, vectorB).reduce(0) { $0 + pow($1.0 - $1.1, 2) })
        return 1 / (1 + distance)
    }
        
    static func cosineSimilarity2(_ vectorA: [Double], _ vectorB: [Double]) -> Double? {
        guard vectorA.count == vectorB.count else {
            return nil
        }
        let dotProduct = zip(vectorA, vectorB).reduce(0) { $0 + $1.0 * $1.1 }
        let magnitudeA = sqrt(vectorA.reduce(0) { $0 + $1 * $1 })
        let magnitudeB = sqrt(vectorB.reduce(0) { $0 + $1 * $1 })
        guard magnitudeA > 0, magnitudeB > 0 else {
            return nil
        }
        return abs(dotProduct / (magnitudeA * magnitudeB))
    }
    
    static func embeddingToBase64(_ vector: [Double]) -> String {
        let data = vector.withUnsafeBufferPointer { Data(buffer: $0) }
        return data.base64EncodedString()
    }
    
    static func base64ToEmbedding(_ base64String: String) -> [Double]? {
        guard let data = Data(base64Encoded: base64String) else { return nil }
        return data.withUnsafeBytes {
            Array(UnsafeBufferPointer<Double>(start: $0.bindMemory(to: Double.self).baseAddress, count: data.count / MemoryLayout<Double>.size))
        }
    }
}
