//
//  EditScriptView.swift
//  Promptly
//
//  Created by Sasha Bagrov on 04/06/2025.
//

import SwiftUI
import SwiftData

class RefreshTrigger: ObservableObject {
    func refresh() {
        objectWillChange.send()
    }
}

struct EditScriptView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let script: Script
    @State private var isEditing = false
    @State private var selectedLines: Set<UUID> = []
    @State private var showingDeleteAlert = false
    @State private var showingCueWarning = false
    @State private var linesToDelete: [ScriptLine] = []
    @State private var editingLineId: UUID?
    @State private var editingText = ""
    @State private var newLineText = ""
    @State private var insertAfterLineNumber: Int?
    @State private var showingAddLine = false
    @State private var showingCombineConfirm = false
    @State private var showingAddSection = false
    @State private var showingSections = false
    @State private var isSelectingLineForSection = false
    @State private var pendingSectionType: SectionType = .scene
    @State private var pendingSectionTitle = ""
    @State private var pendingSectionNotes = ""
    @State private var showingLineConfirmation = false
    @State private var selectedLineForSection: ScriptLine?
    @StateObject private var refreshTrigger = RefreshTrigger()
    
    var sortedLines: [ScriptLine] {
        script.lines.sorted { $0.lineNumber < $1.lineNumber }
    }
    
    var sortedSections: [ScriptSection] {
        script.sections.sorted { $0.startLineNumber < $1.startLineNumber }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isSelectingLineForSection {
                selectionOverlay
            }
            
            mainContentView
        }
        .alert("Combine Lines", isPresented: .constant(false)) {
            Button("Cancel", role: .cancel) { }
            Button("Combine") { }
        } message: {
            Text("This will merge lines into one. Cues from all lines will be preserved. This action cannot be undone.")
        }
        .alert("Combine Lines", isPresented: $showingCombineConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Combine") {
                combineSelectedLines()
            }
        } message: {
            Text("This will merge \(selectedLines.count) lines into one. Cues from all lines will be preserved. This action cannot be undone.")
        }
        .alert("Delete Lines with Cues", isPresented: $showingCueWarning) {
            Button("Cancel", role: .cancel) {
                linesToDelete.removeAll()
            }
            Button("Delete Anyway", role: .destructive) {
                deleteSelectedLines()
            }
        } message: {
            Text("Some selected lines contain cues that will be permanently deleted. This action cannot be undone.")
        }
        .alert("Delete Lines", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                linesToDelete.removeAll()
            }
            Button("Delete", role: .destructive) {
                deleteSelectedLines()
            }
        } message: {
            Text("Are you sure you want to delete \(selectedLines.count) line(s)? This action cannot be undone.")
        }
        .alert("Confirm Section Start", isPresented: $showingLineConfirmation) {
            Button("Cancel", role: .cancel) {
                selectedLineForSection = nil
                isSelectingLineForSection = true
            }
            Button("Confirm") {
                createSectionWithSelectedLine()
            }
        } message: {
            if let line = selectedLineForSection {
                Text("Start '\(pendingSectionTitle)' at line \(line.lineNumber)?\n\n\"\(line.content.prefix(100))...\"")
            }
        }
        .sheet(isPresented: $showingAddLine) {
            AddLineView(
                insertAfterLineNumber: insertAfterLineNumber,
                script: script
            ) {
                renumberLines()
            }
        }
        .sheet(isPresented: $showingAddSection) {
            SectionDetailsView(
                pendingTitle: $pendingSectionTitle,
                pendingType: $pendingSectionType,
                pendingNotes: $pendingSectionNotes
            ) { title, type, notes in
                pendingSectionTitle = title
                pendingSectionType = type
                pendingSectionNotes = notes
                isSelectingLineForSection = true
            }
        }
        .sheet(isPresented: $showingSections) {
            SectionsManagerView(
                script: script,
                calledFromEditView: true
            ) { title, type, notes in
                // Handle the section creation request from SectionsManagerView
                pendingSectionTitle = title
                pendingSectionType = type
                pendingSectionNotes = notes
                isSelectingLineForSection = true
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing, content: {
                if isEditing {
                    Button {
                        cancelEditing()
                    } label: {
                        Image(systemName: "pencil.slash")
                    }
                }
                
                Menu {
                    if isEditing {
                        Button("Save", systemImage: "checkmark") {
                            saveChanges()
                        }
                    } else {
                        Button("Edit Script", systemImage: "pencil") {
                            isEditing = true
                        }
                    }
                    
                    Divider()
                    
                    Button("Sections", systemImage: "list.bullet.rectangle") {
                        showingSections = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            })
        }
        .navigationTitle(Text(script.name))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - View Components
    
    private var selectionOverlay: some View {
        VStack(spacing: 12) {
            Text("Select Start Line for Section")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Tap a line to mark where '\(pendingSectionTitle)' begins")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            Button("Cancel") {
                isSelectingLineForSection = false
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.2))
            .cornerRadius(8)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.blue.opacity(0.9))
    }
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            if isEditing {
                editControlsView
            }
            
            scriptContentView
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue, lineWidth: isSelectingLineForSection ? 4 : 0)
                .animation(.easeInOut(duration: 0.2), value: isSelectingLineForSection)
        )
    }
    
    private var editControlsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Button("Select All") {
                    selectedLines = Set(sortedLines.map { $0.id })
                }
                
                if !selectedLines.isEmpty {
                    Text("\(selectedLines.count) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                    
                    if selectedLines.count > 1 {
                        Button("Combine Lines") {
                            showingCombineConfirm = true
                        }
                        .foregroundColor(.blue)
                    }
                    
                    Button("Delete") {
                        checkForCuesBeforeDelete()
                    }
                    .foregroundColor(.red)
                }
                
                Divider()
                    .frame(height: 20)
                
                Button("Add Line") {
                    showingAddLine = true
                }
                
                Button("Add Section") {
                    showingAddSection = true
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }
    
    private var scriptContentView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(groupLinesBySection(), id: \.stableId) { group in
                        if let section = group.section {
                            SectionHeaderView(section: section)
                                .id("section-\(section.id)")
                        }
                        
                        ForEach(group.lines, id: \.id) { line in
                            scriptLineView(for: line)
                                .id("line-\(line.id)")
                        }
                    }
                }
                .padding()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ScrollToSection"))) { notification in
                if let sectionId = notification.object as? UUID {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo("section-\(sectionId)", anchor: .top)
                    }
                }
            }
        }
    }
    
    private func scriptLineView(for line: ScriptLine) -> some View {
        EditableScriptLineView(
            line: line,
            isEditing: isEditing,
            isSelected: selectedLines.contains(line.id),
            isEditingText: editingLineId == line.id,
            isSelectingForSection: isSelectingLineForSection,
            editingText: $editingText,
            onToggleSelection: { line in
                if isSelectingLineForSection {
                    selectLineForSection(line: line)
                } else {
                    toggleLineSelection(line: line)
                }
                refreshTrigger.refresh()
            },
            onStartTextEdit: { line in
                startTextEditing(line: line)
            },
            onFinishTextEdit: { newText in
                finishTextEditing(newText: newText)
                refreshTrigger.refresh()
            },
            onInsertAfter: { line in
                insertAfterLineNumber = line.lineNumber
                showingAddLine = true
            }
        )
    }
}

// MARK: - EditScriptView Extension for Alerts and Sheets
extension EditScriptView {
    private struct LineGroup {
        let section: ScriptSection?
        let lines: [ScriptLine]
        
        var stableId: String {
            if let section = section {
                return "section-\(section.id)"
            } else {
                let lineIds = lines.map { $0.id.uuidString }.joined(separator: "-")
                return "unsectioned-\(lineIds.hashValue)"
            }
        }
    }
    
    private func groupLinesBySection() -> [LineGroup] {
        let currentSortedLines = script.lines.sorted { $0.lineNumber < $1.lineNumber }
        let currentSortedSections = script.sections.sorted { $0.startLineNumber < $1.startLineNumber }
        
        var groups: [LineGroup] = []
        var lineIndex = 0
        var sectionIndex = 0
        
        while lineIndex < currentSortedLines.count {
            let currentLine = currentSortedLines[lineIndex]
            
            // Check if we're at the start of a section
            if sectionIndex < currentSortedSections.count &&
               currentLine.lineNumber >= currentSortedSections[sectionIndex].startLineNumber {
                
                let section = currentSortedSections[sectionIndex]
                var sectionLines: [ScriptLine] = []
                
                // Determine section end - either explicit end or start of next section
                let sectionEnd: Int
                if let explicitEnd = section.endLineNumber {
                    sectionEnd = explicitEnd
                } else if sectionIndex + 1 < currentSortedSections.count {
                    sectionEnd = currentSortedSections[sectionIndex + 1].startLineNumber - 1
                } else {
                    sectionEnd = Int.max // No end, goes to end of script
                }
                
                // Collect all lines for this section
                while lineIndex < currentSortedLines.count &&
                      currentSortedLines[lineIndex].lineNumber >= section.startLineNumber &&
                      currentSortedLines[lineIndex].lineNumber <= sectionEnd {
                    sectionLines.append(currentSortedLines[lineIndex])
                    lineIndex += 1
                }
                
                if !sectionLines.isEmpty {
                    groups.append(LineGroup(section: section, lines: sectionLines))
                }
                
                sectionIndex += 1
            } else {
                // Handle unsectioned lines
                var unsectionedGroup: [ScriptLine] = []
                
                // Collect consecutive unsectioned lines
                while lineIndex < currentSortedLines.count {
                    let line = currentSortedLines[lineIndex]
                    
                    // Stop if we hit the start of a section
                    if sectionIndex < currentSortedSections.count &&
                       line.lineNumber >= currentSortedSections[sectionIndex].startLineNumber {
                        break
                    }
                    
                    unsectionedGroup.append(line)
                    lineIndex += 1
                }
                
                if !unsectionedGroup.isEmpty {
                    groups.append(LineGroup(section: nil, lines: unsectionedGroup))
                }
            }
        }
        
        return groups
    }
    
    private func toggleLineSelection(line: ScriptLine) {
        if selectedLines.contains(line.id) {
            selectedLines.remove(line.id)
        } else {
            selectedLines.insert(line.id)
        }
    }
    
    private func startTextEditing(line: ScriptLine) {
        editingLineId = line.id
        editingText = line.content
    }
    
    private func combineSelectedLines() {
        let linesToCombine = selectedLines.compactMap { lineId in
            script.lines.first { $0.id == lineId }
        }.sorted { $0.lineNumber < $1.lineNumber }
        
        guard linesToCombine.count > 1 else { return }
        
        let firstLine = linesToCombine[0]
        let combinedText = linesToCombine.map { $0.content }.joined(separator: " ")
        
        var allCues: [Cue] = []
        for line in linesToCombine {
            allCues.append(contentsOf: line.cues)
        }
        
        firstLine.content = combinedText
        firstLine.parseContentIntoElements()
        firstLine.cues.append(contentsOf: allCues)
        
        for line in linesToCombine.dropFirst() {
            script.lines.removeAll { $0.id == line.id }
            modelContext.delete(line)
        }
        
        selectedLines.removeAll()
        renumberLines()
        
        try? modelContext.save()
        refreshTrigger.refresh()
    }
    
    private func getNextSectionStartLine() -> Int {
        if let lastSelected = selectedLines.compactMap({ lineId in
            script.lines.first { $0.id == lineId }
        }).max(by: { $0.lineNumber < $1.lineNumber }) {
            return lastSelected.lineNumber
        }
        return sortedLines.last?.lineNumber ?? 1
    }
    
    private func selectLineForSection(line: ScriptLine) {
        selectedLineForSection = line
        showingLineConfirmation = true
    }
    
    private func createSectionWithSelectedLine() {
        guard let line = selectedLineForSection else { return }
        
        let section = ScriptSection(
            id: UUID(),
            title: pendingSectionTitle,
            type: pendingSectionType,
            startLineNumber: line.lineNumber
        )
        section.notes = pendingSectionNotes
        
        script.sections.append(section)
        
        isSelectingLineForSection = false
        selectedLineForSection = nil
        pendingSectionTitle = ""
        pendingSectionNotes = ""
        
        try? modelContext.save()
        refreshTrigger.refresh()
    }
    
    private func finishTextEditing(newText: String) {
        guard let lineId = editingLineId,
              let line = script.lines.first(where: { $0.id == lineId }) else { return }
        
        if line.content != newText {
            if !line.cues.isEmpty {
                line.content = newText
                line.parseContentIntoElements()
            } else {
                line.content = newText
                line.parseContentIntoElements()
            }
        }
        
        editingLineId = nil
        editingText = ""
    }
    
    private func checkForCuesBeforeDelete() {
        linesToDelete = selectedLines.compactMap { lineId in
            script.lines.first { $0.id == lineId }
        }
        
        let linesWithCues = linesToDelete.filter { !$0.cues.isEmpty }
        
        if !linesWithCues.isEmpty {
            showingCueWarning = true
        } else {
            showingDeleteAlert = true
        }
    }
    
    private func deleteSelectedLines() {
        let lineIdsToDelete = Array(selectedLines)
        
        for lineId in lineIdsToDelete {
            if let line = script.lines.first(where: { $0.id == lineId }) {
                script.lines.removeAll { $0.id == lineId }
                modelContext.delete(line)
            }
        }
        
        selectedLines.removeAll()
        linesToDelete.removeAll()
        renumberLines()
        
        try? modelContext.save()
        refreshTrigger.refresh()
    }
    
    private func renumberLines() {
        let sorted = script.lines.sorted { $0.lineNumber < $1.lineNumber }
        for (index, line) in sorted.enumerated() {
            line.lineNumber = index + 1
        }
    }
    
    private func resetEditingState() {
        isEditing = false
        selectedLines.removeAll()
        editingLineId = nil
        editingText = ""
        isSelectingLineForSection = false
        selectedLineForSection = nil
        
        refreshTrigger.refresh()
    }
    
    private func cancelEditing() {
        resetEditingState()
    }
    
    private func saveChanges() {
        do {
            try modelContext.save()
            resetEditingState()
        } catch {
            print("Failed to save: \(error)")
        }
    }
}

struct EditableScriptLineView: View {
    let line: ScriptLine
    let isEditing: Bool
    let isSelected: Bool
    let isEditingText: Bool
    let isSelectingForSection: Bool
    @Binding var editingText: String
    
    let onToggleSelection: (ScriptLine) -> Void
    let onStartTextEdit: (ScriptLine) -> Void
    let onFinishTextEdit: (String) -> Void
    let onInsertAfter: (ScriptLine) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 8) {
                if isEditing {
                    Button(action: { onToggleSelection(line) }) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? .blue : .gray)
                    }
                }
                
                Text("\(line.lineNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 30, alignment: .trailing)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if isEditingText {
                    TextField("Line content", text: $editingText, onCommit: {
                        onFinishTextEdit(editingText)
                    })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                } else {
                    Button(action: {
                        if isSelectingForSection {
                            onToggleSelection(line)
                        } else if isEditing {
                            onStartTextEdit(line)
                        }
                    }) {
                        Text(line.content)
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!(isEditing || isSelectingForSection))
                }
                
                if !line.cues.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        
                        Text("\(line.cues.count) cue(s)")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            if isEditing && isSelected {
                VStack(spacing: 4) {
                    Button(action: { onInsertAfter(line) }) {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.blue)
                    }
                }
                .font(.title3)
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColorForLine)
                .opacity(backgroundOpacity)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(borderColor, lineWidth: borderWidth)
        )
    }
    
    private var backgroundColorForLine: Color {
        if line.isMarked, let colorHex = line.markColor {
            return Color(hex: colorHex)
        }
        return Color(.secondarySystemGroupedBackground)
    }
    
    private var backgroundOpacity: Double {
        if isSelected && isEditing {
            return 0.6
        } else if line.isMarked {
            return 0.3
        } else {
            return 0.1
        }
    }
    
    private var borderColor: Color {
        if isSelected && isEditing {
            return .blue
        } else if !line.cues.isEmpty {
            return .orange
        } else {
            return .clear
        }
    }
    
    private var borderWidth: CGFloat {
        (isSelected && isEditing) || !line.cues.isEmpty ? 1 : 0
    }
}

struct AddLineView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let insertAfterLineNumber: Int?
    let script: Script
    let onComplete: () -> Void
    
    @State private var newLineText = ""
    @State private var lineType: LineType = .dialogue
    
    enum LineType: String, CaseIterable {
        case dialogue = "Dialogue"
        case stageDirection = "Stage Direction"
        case character = "Character Name"
        case sceneDescription = "Scene Description"
        
        var prefix: String {
            switch self {
            case .dialogue: return ""
            case .stageDirection: return "("
            case .character: return ""
            case .sceneDescription: return "["
            }
        }
        
        var suffix: String {
            switch self {
            case .dialogue: return ""
            case .stageDirection: return ")"
            case .character: return ":"
            case .sceneDescription: return "]"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Line Content")) {
                    TextField("Enter line text", text: $newLineText, axis: .vertical)
                        .lineLimit(3)
                }
                
                Section(header: Text("Line Type")) {
                    Picker("Type", selection: $lineType) {
                        ForEach(LineType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Preview")) {
                    Text(lineType.prefix + newLineText + lineType.suffix)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if let insertAfter = insertAfterLineNumber {
                    Section {
                        Text("Inserting after line \(insertAfter)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Add Line")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addLine()
                    }
                    .disabled(newLineText.isEmpty)
                }
            }
        }
    }
    
    private func addLine() {
        let formattedText = lineType.prefix + newLineText + lineType.suffix
        let newLineNumber = (insertAfterLineNumber ?? script.lines.count) + 1
        
        for line in script.lines where line.lineNumber >= newLineNumber {
            line.lineNumber += 1
        }
        
        let newLine = ScriptLine(
            id: UUID(),
            lineNumber: newLineNumber,
            content: formattedText
        )
        
        script.lines.append(newLine)
        
        try? modelContext.save()
        onComplete()
        dismiss()
    }
}
