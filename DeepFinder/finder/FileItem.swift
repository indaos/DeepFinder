//
//  FileItem.swift
//  DeepFinder
//
//

import Foundation


struct FileItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let freq: Int
    let similarity: Int?
    let updated: String
}
