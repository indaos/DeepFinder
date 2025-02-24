//
//  ExtensionsBar.swift
//  DeepFinder
//
//

import SwiftUI

struct ExtensionsBar: View {
    var viewModel: FileListViewModel
    @Binding  var extensions: [String]
    
    let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 8)
    
    var body: some View {
        ZStack(alignment: .top) {
            VStack {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(extensions, id: \.self) { item in
                            HStack {
                                CheckBoxView(isChecked: .constant(viewModel.isExtension(item))) { value in
                                    return viewModel.setExtension(item,value)
                                }
                                Text(item )
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: 70, alignment: .leading)
                            }
                        }
                    }
                    .padding()
                }
            }
            .zIndex(0)
        }
    }
}


