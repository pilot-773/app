//
//  DSMScriptLineView.swift
//  Promptly
//
//  Created by Sasha Bagrov on 05/10/2025.
//

import SwiftUI

struct DSMScriptLineView: View {
    let line: ScriptLine
    let isCurrent: Bool
    let onLineTap: () -> Void
    let calledCues: Set<UUID>
    
    private let isStageDirection: Bool
    
    init(line: ScriptLine, isCurrent: Bool, onLineTap: @escaping () -> Void, calledCues: Set<UUID>) {
        self.line = line
        self.isCurrent = isCurrent
        self.onLineTap = onLineTap
        self.calledCues = calledCues
        self.isStageDirection = line.flags.contains(.stageDirection)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onLineTap) {
                HStack(alignment: .top, spacing: 12) {
                    Text(verbatim: "\(line.lineNumber)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isCurrent ? .black : .secondary)
                        .frame(width: 30, alignment: .trailing)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        scriptLineWithCues
                        scriptContentWithCueArrows
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isCurrent ? Color.yellow : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isCurrent ? Color.orange : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var scriptLineWithCues: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !line.cues.isEmpty {
                HStack(spacing: 4) {
                    ForEach(line.cues) { cue in
                        CueTagView(cue: cue, isCalled: calledCues.contains(cue.id))
                    }
                    Spacer()
                }
            }
        }
    }
    
    private var scriptContentWithCueArrows: some View {
        let cuesByIndex = Dictionary(grouping: line.cues) { $0.position.elementIndex }
        let words = line.content.split(separator: " ", omittingEmptySubsequences: false)
        
        return Text(buildLineWithCues(words: words, cuesByIndex: cuesByIndex))
            .font(.body)
            .italic(isStageDirection)
            .foregroundColor(isCurrent ? .black : .primary)
    }

    private func buildLineWithCues(words: [Substring], cuesByIndex: [Int: [Cue]]) -> AttributedString {
        var result = AttributedString()
        
        for (i, word) in words.enumerated() {
            if let cues = cuesByIndex[i] {
                for cue in cues {
                    var label = AttributedString("⬇︎ \(cue.label) ")

                    label.foregroundColor = calledCues.contains(cue.id) ? .secondary : Color(hex: cue.type.color)
                    label.inlinePresentationIntent = .emphasized

                    if calledCues.contains(cue.id) {
                        label.strikethroughStyle = Text.LineStyle.single
                    }
                    result += label
                }
            }
            
            var wordAttr = AttributedString(word + " ")
            
            if isStageDirection {
                wordAttr.inlinePresentationIntent = .emphasized
            }
            result += wordAttr
        }
        
        return result
    }
}
