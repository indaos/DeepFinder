//
//  CategoryManagerView.swift
//  DeepFinder
//
//

import SwiftUI
import Combine



struct DocumentSubtype: Identifiable, Codable {
    var id = UUID()
    var name: String
    var tag: String
}

struct DocumentCategory: Identifiable, Codable {
    var id = UUID()
    var name: String
    var tag: String
    var subtypes: [DocumentSubtype]
    
    func getTitleForTag(_ tag: String) -> String {
        if self.tag == tag { return name }
        return subtypes.first(where: { $0.tag == tag })?.name ?? ""
    }
}

let initialCategoriesData: [DocumentCategory] = [
    DocumentCategory(
        name: "Financial & Legal Documents",
        tag: "FIN",
        subtypes: [
            DocumentSubtype(name: "Bank Statements", tag: "BANK"),
            DocumentSubtype(name: "Invoices & Receipts", tag: "INV"),
            DocumentSubtype(name: "Tax Documents", tag: "TAX"),
            DocumentSubtype(name: "Contracts & Agreements", tag: "CON"),
            DocumentSubtype(name: "Insurance Documents", tag: "INS")
        ]
    ),
    DocumentCategory(
        name: "Medical & Health Documents",
        tag: "MED",
        subtypes: [
            DocumentSubtype(name: "Prescriptions", tag: "RX"),
            DocumentSubtype(name: "Medical Records", tag: "MEDREC"),
            DocumentSubtype(name: "Doctor’s Notes", tag: "DOCNOTES"),
            DocumentSubtype(name: "Health Insurance Papers", tag: "HIP")
        ]
    ),
    DocumentCategory(
        name: "Personal & Identity Documents",
        tag: "ID",
        subtypes: [
            DocumentSubtype(name: "Passports & IDs", tag: "ID"),
            DocumentSubtype(name: "Birth & Marriage Certificates", tag: "BMC"),
            DocumentSubtype(name: "Resumes & CVs", tag: "RESUME"),
            DocumentSubtype(name: "Education Documents", tag: "EDU")
        ]
    ),
    DocumentCategory(
        name: "Work & Productivity Files",
        tag: "WORK",
        subtypes: [
            DocumentSubtype(name: "Emails & Correspondence", tag: "EMAIL"),
            DocumentSubtype(name: "Reports & Research Papers", tag: "REPORT"),
            DocumentSubtype(name: "Presentations & Slides", tag: "PRESENT"),
            DocumentSubtype(name: "Meeting Notes & Minutes", tag: "MEET")
        ]
    ),
    DocumentCategory(
        name: "Media & Creative Files",
        tag: "MEDIA",
        subtypes: [
            DocumentSubtype(name: "Photographs & Images", tag: "IMG"),
            DocumentSubtype(name: "Videos & Recordings", tag: "VIDEO"),
            DocumentSubtype(name: "Design & CAD Files", tag: "CAD"),
            DocumentSubtype(name: "Music & Audio Files", tag: "AUDIO")
        ]
    ),
    DocumentCategory(
        name: "Legal & Compliance Documents",
        tag: "LEGAL",
        subtypes: [
            DocumentSubtype(name: "Privacy Policies & Terms of Service", tag: "POLICY"),
            DocumentSubtype(name: "Regulatory Filings", tag: "REG"),
            DocumentSubtype(name: "Court Documents", tag: "COURT")
        ]
    ),
    DocumentCategory(
        name: "Technical & Development Files",
        tag: "TECH",
        subtypes: [
            DocumentSubtype(name: "Source Code Files", tag: "CODE"),
            DocumentSubtype(name: "Configuration & Log Files", tag: "CONFIG"),
            DocumentSubtype(name: "Software Documentation", tag: "DOC")
        ]
    )
]

struct CategoryManagerView: View {
    @Binding var categoriesData: [DocumentCategory]
    @Binding var monitoringDirectory: String
    @State private var isExpandedMonitoring: Bool = true
    @State private var isExpandedCategories: Bool = false
    @ObservedObject var processedState = FileTag.state

    var body: some View {
        VStack(alignment: .leading) {
            DisclosureGroup("Monitoring", isExpanded: Binding(
                get: { isExpandedMonitoring },
                set: { newValue in
                    withAnimation {
                        isExpandedMonitoring = newValue
                        if newValue { isExpandedCategories = false }
                    }
                }
            )) {
                VStack {
                    Text("The starting directory where files in it and its subdirectories will be automatically classified upon addition or modification")
                        .font(.footnote)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                HStack {
                        Label("Monitoring directory:", systemImage: "folder")
                            .font(.headline)
                        TextField("Enter file directory", text: $monitoringDirectory)
                            .frame(width: 200)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                .padding()
                Button {
                    if !processedState.processing {
                        FileTag.tagFiles(monitoringDirectory)
                    }
                } label: {
                    HStack {
                        Label(processedState.processing ? "Stop tagging files" : "Start tagging files",
                              systemImage: processedState.processing ? "stop.fill" : "play.fill")
                            .font(.headline)
                        if processedState.processing {
                            HStack {
                                ProgressView()
                                Text("/ \(processedState.numFileProcessed)")
                            }
                        } else {
                            Text("/ Completed")
                        }
                    }
                }
                .padding(.horizontal)
            }
            DisclosureGroup("Categories", isExpanded: Binding(
                get: { isExpandedCategories },
                set: { newValue in
                    withAnimation {
                        isExpandedCategories = newValue
                        if newValue { isExpandedMonitoring = false }
                    }
                }
            )) {
                Button {
                    addCategory()
                } label: {
                    Label("Add category", systemImage: "plus")
                }
                .padding(.bottom, 5)
                List {
                    ForEach($categoriesData) { $category in
                        HStack {
                            CategoryRowView(category: $category)
                            Divider()
                            Button(role: .destructive) {
                                if let index = categoriesData.firstIndex(where: { $0.id == category.id }) {
                                    categoriesData.remove(at: index)
                                }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                }
                .frame(width: 450, height: 350)
                .navigationTitle("Categories")
                .toolbar { ToolbarItem(placement: .automatic) { EmptyView() } }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(EdgeInsets(top: 10, leading: 20, bottom: 0, trailing: 20))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 1))
    }
    
    private func addCategory() {
        categoriesData.append(DocumentCategory(name: "", tag: "", subtypes: []))
    }
}

struct CategoryRowView: View {
    @Binding var category: DocumentCategory
    
    var body: some View {
        Section {
            VStack(alignment: .leading) {
                TextField("Category Name", text: $category.name)
                TextField("Category Tag", text: $category.tag)
                    .foregroundColor(.secondary)
                Divider()
                ForEach($category.subtypes) { $subtype in
                    HStack {
                        VStack(alignment: .leading) {
                            TextField("Subtype Name", text: $subtype.name)
                            TextField("Subtype Tag", text: $subtype.tag)
                                .foregroundColor(.secondary)
                        }
                        Button {
                            if let index = category.subtypes.firstIndex(where: { $0.id == subtype.id }) {
                                category.subtypes.remove(at: index)
                            }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    .padding(.leading, 16)
                }
                Button("Add Subtype") {
                    category.subtypes.append(DocumentSubtype(name: "", tag: ""))
                }
                .padding(.top, 4)
            }
        }
    }
}
