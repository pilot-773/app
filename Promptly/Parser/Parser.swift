//
//  PDFScriptParser.swift
//  Promptly
//
//  Smart PDF parsing using newlines + context intelligence for script structure
//

import Foundation
import PDFKit
import SwiftData

class PDFScriptParser: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var currentPage = 0
    @Published var totalPages = 0
    @Published var errorMessage: String?
    
    private let modelContext: ModelContext
    
    // Stage direction keywords for detection
    private let stageDirectionKeywords = [
        // Movement and positioning
        "enter", "enters", "exit", "exits", "cross", "crosses", "move", "moves",
        "he walks", "she walks", "he turns", "she turns", "he looks", "she looks",
        "he sits", "she sits", "he stands", "she stands", "he runs", "she runs",
        
        // Stage positions (abbreviations and full forms)
        "dsr", "dsl", "dcr", "dcl", "dc", "usr", "usl", "ucr", "ucl", "uc",
        "stage left", "stage right", "upstage", "downstage", "centre", "center",
        "down stage", "up stage", "down left", "down right", "up left", "up right",
        
        // Technical/lighting/sound
        "lights", "light", "sound", "music", "fade", "blackout", "dim", "bright",
        "curtain", "scene change", "interval", "props", "costume", "set",
        "fx", "sfx", "lx", "follow spot", "spot", "cue",
        
        // Actions and gestures
        "gesture", "gestures", "point", "points", "nod", "nods", "shake", "shakes",
        "laugh", "laughs", "cry", "cries", "shout", "shouts", "whisper", "whispers",
        "pause", "beat", "silence", "aside", "to audience", "fourth wall",
        
        // Common stage directions
        "meanwhile", "later", "earlier", "suddenly", "slowly", "quickly", "quietly",
        "loudly", "angrily", "sadly", "happily", "nervously", "confidently"
    ]
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Main parsing function
    func parseScript(from pdfDocument: PDFDocument, scriptName: String) async throws -> Script {
        await MainActor.run {
            isProcessing = true
            progress = 0.0
            errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }
        
        let pageCount = pdfDocument.pageCount
        print("PDF loaded with \(pageCount) pages")
        
        await MainActor.run {
            totalPages = pageCount
        }
        
        guard pageCount > 0 else {
            throw PDFParsingError.invalidPDF
        }
        
        let script = Script(
            id: UUID(),
            name: scriptName,
            dateAdded: Date()
        )
        
        var allText = ""
        
        // Extract text from all pages using PDFKit
        for pageIndex in 0..<pageCount {
            print("Processing page \(pageIndex + 1) of \(pageCount)")
            
            await MainActor.run {
                currentPage = pageIndex + 1
                progress = Double(pageIndex) / Double(pageCount)
            }
            
            guard let page = pdfDocument.page(at: pageIndex) else {
                print("Failed to get page at index \(pageIndex)")
                continue
            }
            
            if let pageText = page.string {
                allText += pageText + "\n"
            }
        }
        
        print("Extracted \(allText.count) characters of text")
        
        // Process text with intelligent parsing
        let scriptLines = processTextIntelligently(allText)
        
        print("Created \(scriptLines.count) intelligent script lines")
        
        // Convert to ScriptLine objects
        for (index, lineText) in scriptLines.enumerated() {
            let scriptLine = ScriptLine(
                id: UUID(),
                lineNumber: index + 1,
                content: lineText
            )
            script.lines.append(scriptLine)
        }
        
        await MainActor.run {
            progress = 1.0
        }
        
        return script
    }
    
    // MARK: - Intelligent text processing
    private func processTextIntelligently(_ text: String) -> [String] {
        // Split by newlines first (PDFKit approach)
        let rawLines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        print("Raw lines from PDF: \(rawLines.count)")
        
        var processedLines: [String] = []
        var i = 0
        
        while i < rawLines.count {
            let currentLine = rawLines[i]
            let lineType = detectLineType(currentLine)
            
            // Look ahead for context
            let nextLine = i + 1 < rawLines.count ? rawLines[i + 1] : nil
            let previousLine = processedLines.last
            
            var finalLine = currentLine
            
            // Apply intelligent merging rules
            if shouldMergeWithNext(
                current: currentLine,
                next: nextLine,
                currentType: lineType,
                previousLine: previousLine
            ) {
                // Merge with next line
                if let next = nextLine {
                    finalLine = currentLine + " " + next
                    i += 1 // Skip the next line since we merged it
                }
            }
            
            processedLines.append(finalLine)
            i += 1
        }
        
        print("After intelligent processing: \(processedLines.count) lines")
        return processedLines
    }
    
    // MARK: - Line type detection
    enum LineType {
        case characterName
        case stageDirection
        case dialogue
        case sceneHeader
        case actHeader
        case unknown
    }
    
    private func detectLineType(_ line: String) -> LineType {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Act detection
        if isActHeader(trimmed) {
            return .actHeader
        }
        
        // Scene detection
        if isSceneHeader(trimmed) {
            return .sceneHeader
        }
        
        // Character name detection
        if isCharacterName(trimmed) {
            return .characterName
        }
        
        // Stage direction detection
        if isStageDirection(trimmed) {
            return .stageDirection
        }
        
        // Default to dialogue
        return .dialogue
    }
    
    private func isCharacterName(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Must be reasonably short
        guard trimmed.count > 1 && trimmed.count < 30 else { return false }
        
        // Check if it's all uppercase (allowing for periods, colons, spaces)
        let uppercasePattern = #"^[A-Z\s\.\:]+$"#
        let isAllCaps = trimmed.range(of: uppercasePattern, options: .regularExpression) != nil
        
        // Additional checks for character names
        let endsWithPunctuation = trimmed.hasSuffix(".") || trimmed.hasSuffix(":")
        let hasNoLowercase = !trimmed.contains { $0.isLowercase }
        
        return isAllCaps && (endsWithPunctuation || hasNoLowercase)
    }
    
    private func isStageDirection(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Parentheses or brackets
        if (trimmed.hasPrefix("(") && trimmed.hasSuffix(")")) ||
           (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
            return true
        }
        
        // Italic markers (common in some PDFs)
        if trimmed.hasPrefix("*") && trimmed.hasSuffix("*") {
            return true
        }
        
        // Check for stage direction keywords
        let lowercased = trimmed.lowercased()
        return stageDirectionKeywords.contains { keyword in
            lowercased.hasPrefix(keyword) || lowercased.contains(" " + keyword)
        }
    }
    
    private func isSceneHeader(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let patterns = [
            #"(?i)^SCENE\s+([IVX1-9]+|ONE|TWO|THREE|FOUR|FIVE)"#,
            #"(?i)^Scene\s+([IVX1-9]+|One|Two|Three|Four|Five)"#
        ]
        
        return patterns.contains { pattern in
            trimmed.range(of: pattern, options: .regularExpression) != nil
        }
    }
    
    private func isActHeader(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let patterns = [
            #"(?i)^ACT\s+([IVX1-9]+|ONE|TWO|THREE)"#,
            #"(?i)^Act\s+([IVX1-9]+|One|Two|Three)"#
        ]
        
        return patterns.contains { pattern in
            trimmed.range(of: pattern, options: .regularExpression) != nil
        }
    }
    
    // MARK: - Intelligent merging logic
    private func shouldMergeWithNext(
        current: String,
        next: String?,
        currentType: LineType,
        previousLine: String?
    ) -> Bool {
        guard let nextLine = next else { return false }
        
        let nextType = detectLineType(nextLine)
        
        // Never merge these types
        if currentType == .characterName || currentType == .sceneHeader || currentType == .actHeader {
            return false
        }
        
        if nextType == .characterName || nextType == .sceneHeader || nextType == .actHeader {
            return false
        }
        
        // Don't merge stage directions with other content
        if currentType == .stageDirection || nextType == .stageDirection {
            return false
        }
        
        // Merge dialogue that seems to be split incorrectly
        if currentType == .dialogue && nextType == .dialogue {
            // If current line ends mid-sentence and next doesn't start with capital
            let currentTrimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            let nextTrimmed = nextLine.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Don't merge if current line ends with sentence punctuation
            if currentTrimmed.hasSuffix(".") || currentTrimmed.hasSuffix("!") || currentTrimmed.hasSuffix("?") {
                return false
            }
            
            // Merge if next line doesn't start with capital (likely continuation)
            if let firstChar = nextTrimmed.first, !firstChar.isUppercase {
                return true
            }
            
            // Merge very short lines that are likely splits
            if currentTrimmed.count < 20 && ((nextTrimmed.first?.isUppercase) == nil) == true {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Script structure detection
    func analyzeScriptStructure(_ script: Script) {
        var sections: [ScriptSection] = []
        
        for line in script.lines {
            let content = line.content.trimmingCharacters(in: .whitespacesAndNewlines)
            let lineType = detectLineType(content)
            
            switch lineType {
            case .actHeader:
                let section = ScriptSection(
                    id: UUID(),
                    title: content,
                    type: .act,
                    startLineNumber: line.lineNumber
                )
                sections.append(section)
                
            case .sceneHeader:
                let section = ScriptSection(
                    id: UUID(),
                    title: content,
                    type: .scene,
                    startLineNumber: line.lineNumber
                )
                sections.append(section)
                
            default:
                break
            }
        }
        
        script.sections.append(contentsOf: sections)
        print("Detected \(sections.count) script sections")
    }
}

// MARK: - Supporting Types
enum PDFParsingError: Error, LocalizedError {
    case invalidPDF
    case pageRenderingFailed
    case processingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidPDF:
            return "The PDF file is invalid or corrupted"
        case .pageRenderingFailed:
            return "Failed to render PDF page"
        case .processingFailed:
            return "Failed to process the script text"
        }
    }
}
