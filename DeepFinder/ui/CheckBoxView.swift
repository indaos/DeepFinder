//
//  CheckBoxView.swift
//  DeepFinder
//
//

import SwiftUI


struct CheckBoxView: View {
    @Binding var isChecked: Bool
    var onToggle: (Bool) -> Bool

    var body: some View {
        Button(action: {
            isChecked.toggle()
            if !onToggle(!isChecked) {
                isChecked.toggle()
            }
        }) {
            Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                .font(.callout)
                .foregroundColor(isChecked ? .blue : .gray)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
