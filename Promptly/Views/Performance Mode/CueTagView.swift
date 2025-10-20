//
//  CueTagView.swift
//  Promptly
//
//  Created by Sasha Bagrov on 05/10/2025.
//

import SwiftUI

struct CueTagView: View {
    let cue: Cue
    let isCalled: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: cue.type.color))
                .frame(width: 8, height: 8)
            
            Text(cue.label)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .foregroundColor(isCalled ? .secondary : .primary)
                .strikethrough(isCalled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(hex: cue.type.color).opacity(isCalled ? 0.1 : 0.2))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isCalled ? Color.gray : Color(hex: cue.type.color), lineWidth: 2)
        )
    }
}
