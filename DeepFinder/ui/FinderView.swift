//
//  FinderView.swift
//  DeepFinder
//
//

import SwiftUI


struct FinderView: View {
    @Binding var refreshTrigger: Bool
    @State private var savedSearchQuery = ""
    @State private var searchQuery = ""
    @StateObject private var viewModel = FileListViewModel()
    @State private var isLoading = false
    @State private var genKeyWords = false
    @State private var progress = 0.0
    @State private var generatedExtensions: [String] = []
    @State private var allTags: [String: Bool] = [:]
    @State private var isExtensionsExpanded = false
    @State private var isTagsExpanded = false
    @State private var selectedMode = 0
    @State private var settingsModel = AppDelegate.settingsModel
    @State private var assistant: ChatAssitant?
    @State private var isClarificationMode = false
    @State private var assistQuery = ""
    @State private var sortedColumn = 0
    @State private var sortedAsc1 = false
    @State private var sortedAsc0 = false
    @State private var noResults = false
    @State private var waitClarification = ""

    private var hasResults: Bool { viewModel.getFileListCount() > 0 }

    var body: some View {
        VStack {
            searchBar
            ZStack {
                if isLoading && !hasResults {
                    VStack {
                        ProgressView().transition(.opacity)
                        if !waitClarification.isEmpty {
                            Text(waitClarification)
                        }
                    }
                } else {
                    resultsView.transition(.opacity)
                }
            }
        }
        .padding(.top, 10)
    }

    private var searchBar: some View {
        HStack(alignment: .top) {
            ZStack(alignment: .top) {
                headerLabel
                searchFieldAndExtensions
            }
        }
    }

    private var headerLabel: some View {
        HStack {
            Picker("", selection: $selectedMode) {
                Text("Keyword Search").tag(0)
                Text("Natural Language Search").tag(1)
                Text("Assisted Natural Language Search").tag(2)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 100, alignment: .leading)
            .onChange(of: selectedMode) { newValue in
                if newValue != 2 {
                    isLoading = false
                    isClarificationMode = false
                }
            }
            Spacer()
        }
        .offset(x: 20, y: -18)
        .disabled(settingsModel.settings.openAiKey.isEmpty && settingsModel.settings.ollamaUrl.isEmpty)
    }

    private var searchFieldAndExtensions: some View {
        VStack {
            if isClarificationMode {
                Text(assistQuery)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .font(.system(size: 14))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.yellow, lineWidth: 1))
                    .frame(maxHeight: 80)
            }
            HStack {
                ZStack {
                    Menu {
                        ForEach(AppDelegate.settingsModel.settings.searchHistory, id: \.self) { item in
                            Button(action: {
                                searchQuery = item
                            }) {
                                Text(item)
                            }
                        }
                    } label: {

                    }.menuStyle(BorderlessButtonMenuStyle())
                    
                    FinderTextField(isClarificationMode ? "Assistant asks..." : "Enter query...", text: $searchQuery, onCommit: {
                        if isClarificationMode {
                            assistant?.addAClarification(searchQuery)
                            waitClarification = "Wait for assistant..."
                        } else {
                            AppDelegate.settingsModel.settings.addSearchQuery(searchQuery)
                            AppDelegate.saveConfigsToUserDefaults()
                            performSearch()
                        }
                    })
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 20))
                    .padding(.leading, 10)
                    .frame(height: 40)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                    .padding(.horizontal, 15)
                }
                if isLoading && hasResults { stopButton }
                
            }
            if hasResults {
                DisclosureGroup("Extensions by highest file count", isExpanded: $isExtensionsExpanded) {
                    ExtensionsBar(viewModel: viewModel, extensions: $generatedExtensions)
                        .frame(height: 80)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 0.2))
                        .padding(.horizontal, 15)
                }
            } else {
                DisclosureGroup("All Tags", isExpanded: $isTagsExpanded) {
                    TagsBar(viewModel: viewModel, tags: $allTags)
                        .frame(height: 80)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 0.2))
                        .padding(.horizontal, 15)
                }
            }
        }
        .padding(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))
        .onAppear {
            FileTag.fetchAllUserTags { tags in
                allTags = tags.reduce(into: [String: Bool]()) { $0[$1] = false }
            }
        }
    }

    private var stopButton: some View {
        Button(action: cancelSearch) {
            Image(systemName: "stop.fill")
                .foregroundColor(.red.opacity(0.8))
                .frame(width: 40, height: 40)
                .overlay(Circle().stroke(Color.gray, lineWidth: 2))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var resultsView: some View {
        ZStack(alignment: .topTrailing) {
            if hasResults && !isLoading {
                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.removeAll()
                        allTags = allTags.mapValues { _ in false }
                        isClarificationMode = false
                        searchQuery = ""
                        sortedColumn = 0
                        sortedAsc1 = false
                        sortedAsc0 = false
                    }) {
                        Text("Clear").font(.footnote)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 40, height: 10)
                    .padding(0.5)
                    .overlay(Capsule().stroke(Color.gray, lineWidth: 2))
                    .offset(x: -20, y: -20)
                }
            }
            VStack {
                FileListView(viewModel: viewModel, sortedColumn: $sortedColumn, sortedAsc1: $sortedAsc1, sortedAsc0: $sortedAsc0)
                if isLoading && progress < 1.0 {
                    HStack {
                        ProgressView(value: progress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue.opacity(0.8)))
                        ProgressView()
                    }
                } else if !hasResults, noResults  {
                    Text("No results found")
                }
            }
        }
    }

    private func performSearch() {
        guard !searchQuery.isEmpty, searchQuery.count > 3 else { return }
        isLoading = true
        progress = 0.0
        generatedExtensions = []
        sortedColumn = 0
        sortedAsc1 = false
        sortedAsc0 = false
        if selectedMode == 2 {
            savedSearchQuery = searchQuery
            assistant = ChatAssitant(query: searchQuery) { result, isFinal in
                DispatchQueue.main.async {                          
                    waitClarification = ""
                    if isFinal {
                        isClarificationMode = false
                        let finalQuery = savedSearchQuery
                        searchQuery = finalQuery
                        Prompter.generateKeywords(for: finalQuery) { keywords, extensions in
                            generatedExtensions = extensions
                            viewModel.searcher.priorityExtension = extensions
                            startSearch(with: keywords, extensions: extensions)
                        }
                    } else {
                        isClarificationMode = true
                        searchQuery = ""
                        assistQuery = assistant?.lastAssistantMessage ?? ""
                    }
                }
            }
            assistant?.conversationLoop()
        } else if selectedMode == 1 {
            Prompter.generateKeywords(for: searchQuery) { keywords, extensions in
                generatedExtensions = extensions
                viewModel.searcher.priorityExtension = extensions
                startSearch(with: keywords, extensions: extensions)
            }
        } else {
            startSearch(with: searchQuery, extensions: [])
        }
    }

    private func startSearch(with query: String, extensions: [String]) {
        noResults = false
        waitClarification = ""
        viewModel.startSearch(query: query,
                               selectedMode == 1,
                               onCompletion: {
                                   viewModel.fileList.isEmpty ? noResults = true : ()
                                   isLoading = false
                                   generatedExtensions = viewModel.searcher.getSortedExtension()
                                   viewModel.searcher.priorityExtension = []
                                   viewModel.searcher.allExtension = [:]
                               },
                               progress: { progress = $0 })
    }

    private func cancelSearch() {
        isLoading = false
        viewModel.searcher.priorityExtension = []
        viewModel.searcher.allExtension = [:]
        viewModel.cancelSearch()
    }
}
