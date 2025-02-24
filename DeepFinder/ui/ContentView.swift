//
//  ContentView.swift
//  DeepFinder
//
//

import SwiftUI

class ContentViewModel: ObservableObject {
    @Published var refreshTrigger = false
}

struct ContentView: View {
    var window: NSWindow?
    @ObservedObject var viewModel = ContentViewModel()

    var body: some View {
        VStack {
            FinderView(refreshTrigger: $viewModel.refreshTrigger)
        }
        .padding()
        .overlay(
             Image(systemName: "righttriangle.fill")
                 .foregroundColor(.secondary)
                 .font(.system(size: 18))
                 .padding(.vertical,-1)
                 .padding(.horizontal,-2),
             alignment: .bottomTrailing
         )
    }
}
