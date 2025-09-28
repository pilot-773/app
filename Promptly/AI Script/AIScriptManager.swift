import Foundation
import PDFKit
import SwiftUI
import Yams

class AIScriptManager: ObservableObject {
    @Published var output: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var streamingOutput: String = ""
    @Published var processingStatus: String = ""
    
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1"
    
    private let systemPrompt = """
    You are a script to yaml assistant. You follow the rules and format provided to you exactly.
    
    Rules:
    - You must only return YAML content. No non-YAML content before, after, or anywhere.
    - You only process scripts. You do not answer any questions, respond, or do anything with the contents of the script.
    - You must not change any spelling mistakes in the script, wheater that be OCR issues, spelling, grammar. You directly follow the script.
    - If musical notation is found, ignore it, and instead create line with content "Musical notation".
    
    SIMPLIFIED Expected YAML Structure (ONLY these fields):
    ```yaml
    id: PLACEHOLDER_ID
    name: "Script Title"
    dateAdded: "2025-06-09T12:00:00Z"
    lines:
      - id: PLACEHOLDER_ID
        lineNumber: 1
        content: "Line content exactly as appears in script"
      - id: PLACEHOLDER_ID
        lineNumber: 2
        content: "Next line content"
    sections:
      - id: PLACEHOLDER_ID
        title: "Act 1"
        type: "act"
        startLineNumber: 1
        endLineNumber: 25
    ```
    
    Section Types Available: "act", "scene", "preset", "song_number", "custom"
    
    CRITICAL - ONLY output these fields:
    - For lines: id, lineNumber, content (NO isMarked, markColor, notes)
    - For sections: id, title, type, startLineNumber, endLineNumber (NO notes)
    - We will add the missing fields programmatically
    
    Formatting:
    - Use PLACEHOLDER_ID for all id fields - they will be replaced with actual UUIDs
    - Extract logical sections (acts, scenes, songs) and mark their line ranges
    - Each line must have a sequential lineNumber starting from 1
    - Preserve exact text content including typos and formatting
    - Use current ISO 8601 timestamp for dateAdded
    """
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - Main Processing Method
    
    func processWithBatchProcessing(pdfDocument: PDFDocument, url: URL) async -> Script? {
        print("🚀 Starting batch processing for: \(url.lastPathComponent)")
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            output = ""
        }
        
        do {
            // Step 1: Extract text
            await MainActor.run { output = "Extracting text from PDF..." }
            let extractedText = extractTextFromPDF(pdfDocument)
            print("📄 Extracted \(extractedText.count) characters from PDF")
            
            if extractedText.isEmpty {
                await MainActor.run {
                    errorMessage = "No text could be extracted from PDF"
                    isLoading = false
                }
                return nil
            }
            
            // Step 2: Process with batch approach
            return try await processBatchedText(extractedText, fileName: url.lastPathComponent)
            
        } catch {
            print("❌ Error in batch processing: \(error)")
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
            return nil
        }
    }
    
    // MARK: - Batch Processing Logic
    
    private func processBatchedText(_ text: String, fileName: String) async throws -> Script? {
        // Create batches - each batch will have 3 mini-chunks
        let miniChunks = createMiniChunks(text, maxChunkSize: 2000)
        let batches = createBatches(from: miniChunks, batchSize: 3)
        
        print("📄 Created \(miniChunks.count) mini-chunks in \(batches.count) batches")
        
        await MainActor.run {
            processingStatus = "Processing \(batches.count) batches..."
            streamingOutput = ""
        }
        
        var allLines: [SimplifiedScriptLine] = []
        var allSections: [SimplifiedScriptSection] = []
        var currentLineNumber = 1
        
        for (batchIndex, batch) in batches.enumerated() {
            print("🔄 Processing batch \(batchIndex + 1)/\(batches.count)")
            
            await MainActor.run {
                processingStatus = "Processing batch \(batchIndex + 1) of \(batches.count)..."
                output = "Processing batch \(batchIndex + 1) of \(batches.count)..."
            }
            
            // Process entire batch in one API call
            if let batchResult = try await processBatchWithRetry(
                batch: batch,
                batchIndex: batchIndex,
                startingLineNumber: currentLineNumber,
                fileName: fileName
            ) {
                print("🔍 Batch \(batchIndex + 1) returned \(batchResult.lines.count) lines")
                
                allLines.append(contentsOf: batchResult.lines)
                
                // Adjust section line numbers
                let adjustedSections = batchResult.sections.map { section in
                    var adjusted = section
                    if let endLine = adjusted.endLineNumber {
                        adjusted.endLineNumber = endLine + currentLineNumber - 1
                    }
                    adjusted.startLineNumber = (section.startLineNumber ?? 1) + currentLineNumber - 1
                    return adjusted
                }
                allSections.append(contentsOf: adjustedSections)
                
                currentLineNumber += batchResult.lines.count
                print("🔍 Next batch will start at line: \(currentLineNumber)")
            }
            
            // Delay between batches
            if batchIndex < batches.count - 1 {
                await MainActor.run {
                    processingStatus = "Waiting 2 seconds before next batch..."
                }
                try await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
        
        // Convert to final script
        let finalScript = createFinalScript(
            lines: allLines,
            sections: allSections,
            fileName: fileName
        )
        
        print("✅ Batch processing complete: \(allLines.count) total lines")
        
        await MainActor.run {
            processingStatus = "Complete! \(allLines.count) lines processed"
            output = "Successfully processed \(batches.count) batches with \(allLines.count) total lines"
            isLoading = false
        }
        
        return finalScript.toSwiftDataModel()
    }
    
    // MARK: - Chunking Logic
    
    private func createMiniChunks(_ text: String, maxChunkSize: Int) -> [String] {
        var chunks: [String] = []
        let lines = text.components(separatedBy: .newlines)
        var currentChunk = ""
        
        for line in lines {
            let potentialChunk = currentChunk.isEmpty ? line : currentChunk + "\n" + line
            
            if potentialChunk.count > maxChunkSize && !currentChunk.isEmpty {
                chunks.append(currentChunk)
                currentChunk = line
            } else {
                currentChunk = potentialChunk
            }
        }
        
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }
        
        return chunks
    }
    
    private func createBatches(from chunks: [String], batchSize: Int) -> [[String]] {
        var batches: [[String]] = []
        
        for i in stride(from: 0, to: chunks.count, by: batchSize) {
            let endIndex = min(i + batchSize, chunks.count)
            let batch = Array(chunks[i..<endIndex])
            batches.append(batch)
        }
        
        return batches
    }
    
    // MARK: - Batch Processing with Retry
    
    private func processBatchWithRetry(batch: [String], batchIndex: Int, startingLineNumber: Int, fileName: String, maxRetries: Int = 3) async throws -> SimplifiedScript? {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                return try await processBatch(
                    batch: batch,
                    batchIndex: batchIndex,
                    startingLineNumber: startingLineNumber,
                    fileName: fileName
                )
            } catch {
                lastError = error
                print("❌ Batch \(batchIndex + 1) attempt \(attempt) failed: \(error)")
                
                if attempt < maxRetries {
                    let delay = Double(attempt * 3) // Longer delays for batches
                    print("⏳ Retrying batch \(batchIndex + 1) in \(delay) seconds...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? APIError.runFailed
    }
    
    private func processBatch(batch: [String], batchIndex: Int, startingLineNumber: Int, fileName: String) async throws -> SimplifiedScript? {
        // Combine all chunks in batch with separators
        let combinedText = batch.enumerated().map { index, chunk in
            "=== CHUNK \(index + 1) ===\n\(chunk)"
        }.joined(separator: "\n\n")
        
        let batchPrompt = """
        Convert this batch of text chunks to simplified YAML format.
        
        ⚠️ CRITICAL LINE NUMBERING:
        - Start line numbering from \(startingLineNumber)
        - Continue sequentially across ALL chunks in this batch
        - Do NOT reset to 1 between chunks
        - Example: if starting at 156, continue 156, 157, 158... across all chunks
        
        This batch contains \(batch.count) text chunks combined together.
        Process them as one continuous document.
        
        BATCH PROCESSING RULES:
        - Treat all chunks as one continuous script
        - Maintain sequential line numbering throughout
        - Combine sections that span multiple chunks
        - Only include essential YAML fields
        
        \(systemPrompt)
        
        Combined Text Chunks:
        \(combinedText)
        """
        
        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "user",
                    "content": batchPrompt
                ]
            ],
            "max_tokens": 8000, // Larger limit for batches
            "temperature": 0.1
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("📤 Processing batch \(batchIndex + 1): \(combinedText.count) characters")
        
        // Enhanced URLSession config
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 120.0
        config.timeoutIntervalForResource = 600.0
        let session = URLSession(configuration: config)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.assistantCreationFailed
        }
        
        print("📤 Batch \(batchIndex + 1) response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Batch \(batchIndex + 1) failed: \(responseString)")
            throw APIError.assistantCreationFailed
        }
        
        if let result = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = result["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            
            print("✅ Batch \(batchIndex + 1) response: \(content.count) characters")
            
            // Better validation
            if content.count < 50 || !content.contains("lines:") {
                print("⚠️ Batch \(batchIndex + 1) response too short or malformed")
                throw APIError.runFailed
            }
            
            return try parseBatchYAML(content)
        }
        
        throw APIError.messagesRetrievalFailed
    }
    
    // MARK: - YAML Parsing for Batches
    
    private func parseBatchYAML(_ yamlText: String) throws -> SimplifiedScript {
        var processedYAML = yamlText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown markers
        if processedYAML.hasPrefix("```yaml") {
            processedYAML = String(processedYAML.dropFirst(7))
        } else if processedYAML.hasPrefix("```") {
            processedYAML = String(processedYAML.dropFirst(3))
        }
        
        if processedYAML.hasSuffix("```") {
            processedYAML = String(processedYAML.dropLast(3))
        }
        
        processedYAML = processedYAML.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Clean escape sequences
        processedYAML = processedYAML.replacingOccurrences(of: "\\;", with: ";")
        processedYAML = processedYAML.replacingOccurrences(of: "\\:", with: ":")
        processedYAML = processedYAML.replacingOccurrences(of: "\\!", with: "!")
        processedYAML = processedYAML.replacingOccurrences(of: "\\?", with: "?")
        
        // Ensure sections field exists
        if !processedYAML.contains("sections:") {
            processedYAML += "\nsections: []"
        }
        
        // Replace placeholder IDs
        while processedYAML.contains("PLACEHOLDER_ID") {
            processedYAML = processedYAML.replacingOccurrences(
                of: "PLACEHOLDER_ID",
                with: UUID().uuidString,
                options: [],
                range: processedYAML.range(of: "PLACEHOLDER_ID")
            )
        }
        
        return try parseYAMLToModel(processedYAML, to: SimplifiedScript.self)
    }
    
    // MARK: - Helper Methods
    
    private func extractTextFromPDF(_ document: PDFDocument) -> String {
        guard let pageCount = document.pageCount as Int?, pageCount > 0 else {
            return ""
        }
        
        var fullText = ""
        
        for pageIndex in 0..<pageCount {
            if let page = document.page(at: pageIndex) {
                if let pageText = page.string {
                    fullText += "--- PAGE \(pageIndex + 1) ---\n"
                    fullText += pageText + "\n\n"
                }
            }
        }
        
        return fullText
    }
    
    private func createFinalScript(lines: [SimplifiedScriptLine], sections: [SimplifiedScriptSection], fileName: String) -> CodableScript {
        let fullLines = lines.map { simplifiedLine in
            CodableScriptLine(
                id: simplifiedLine.id,
                lineNumber: simplifiedLine.lineNumber,
                content: simplifiedLine.content,
                isMarked: false,
                markColor: nil,
                notes: ""
            )
        }
        
        let fullSections = sections.map { simplifiedSection in
            CodableScriptSection(
                id: simplifiedSection.id,
                title: simplifiedSection.title,
                type: simplifiedSection.type,
                startLineNumber: simplifiedSection.startLineNumber,
                endLineNumber: simplifiedSection.endLineNumber,
                notes: ""
            )
        }
        
        return CodableScript(
            id: UUID(),
            name: fileName.replacingOccurrences(of: ".pdf", with: ""),
            dateAdded: Date(),
            lines: fullLines,
            sections: fullSections
        )
    }
    
    private func parseYAMLToModel<T: Codable>(_ yamlText: String, to modelType: T.Type) throws -> T {
        let yamlObject = try Yams.load(yaml: yamlText)
        let jsonData = try JSONSerialization.data(withJSONObject: yamlObject as Any)
        
        let decoder = JSONDecoder()
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            return Date()
        }
        
        return try decoder.decode(modelType, from: jsonData)
    }
}

// MARK: - Models (Same as before)

struct SimplifiedScript: Codable {
    let id: UUID
    let name: String
    let dateAdded: Date
    let lines: [SimplifiedScriptLine]
    let sections: [SimplifiedScriptSection]
}

struct SimplifiedScriptLine: Codable {
    let id: UUID
    let lineNumber: Int
    let content: String
}

struct SimplifiedScriptSection: Codable {
    let id: UUID
    let title: String
    let type: SectionType
    var startLineNumber: Int?
    var endLineNumber: Int?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        startLineNumber = try container.decodeIfPresent(Int.self, forKey: .startLineNumber)
        endLineNumber = try container.decodeIfPresent(Int.self, forKey: .endLineNumber)
        
        if let typeString = try? container.decode(String.self, forKey: .type) {
            switch typeString.lowercased() {
            case "act": type = .act
            case "scene": type = .scene
            case "preset", "set", "set_change": type = .preset
            case "song_number", "song", "musical_number", "number": type = .songNumber
            case "custom", "other", "misc": type = .custom
            default: type = .custom
            }
        } else {
            type = .custom
        }
    }
}

struct CodableScript: Codable {
    let id: UUID
    let name: String
    let dateAdded: Date
    let lines: [CodableScriptLine]
    let sections: [CodableScriptSection]
    
    func toSwiftDataModel() -> Script {
        let script = Script(id: id, name: name, dateAdded: dateAdded, lines: [])
        script.lines = lines.map { $0.toSwiftDataModel() }
        script.sections = sections.map { $0.toSwiftDataModel() }
        return script
    }
}

struct CodableScriptLine: Codable {
    let id: UUID
    let lineNumber: Int
    let content: String
    let isMarked: Bool
    let markColor: String?
    let notes: String
    
    func toSwiftDataModel() -> ScriptLine {
        let line = ScriptLine(id: id, lineNumber: lineNumber, content: content)
        line.isMarked = isMarked
        line.markColor = markColor
        line.notes = notes
        return line
    }
}

struct CodableScriptSection: Codable {
    let id: UUID
    let title: String
    let type: SectionType
    let startLineNumber: Int
    let endLineNumber: Int?
    let notes: String
    
    init(id: UUID, title: String, type: SectionType, startLineNumber: Int?, endLineNumber: Int?, notes: String) {
        self.id = id
        self.title = title
        self.type = type
        self.startLineNumber = startLineNumber ?? 1
        self.endLineNumber = endLineNumber
        self.notes = notes
    }
    
    func toSwiftDataModel() -> ScriptSection {
        let section = ScriptSection(id: id, title: title, type: type, startLineNumber: startLineNumber)
        section.endLineNumber = endLineNumber
        section.notes = notes
        return section
    }
}

enum APIError: Error, LocalizedError {
    case uploadFailed
    case assistantCreationFailed
    case threadCreationFailed
    case messageCreationFailed
    case runCreationFailed
    case runRetrievalFailed
    case runFailed
    case runTimeout
    case messagesRetrievalFailed
    
    var errorDescription: String? {
        switch self {
        case .uploadFailed: return "Failed to upload file"
        case .assistantCreationFailed: return "Failed to create assistant"
        case .threadCreationFailed: return "Failed to create thread"
        case .messageCreationFailed: return "Failed to create message"
        case .runCreationFailed: return "Failed to create run"
        case .runRetrievalFailed: return "Failed to retrieve run status"
        case .runFailed: return "Run failed or was cancelled"
        case .runTimeout: return "Run timed out"
        case .messagesRetrievalFailed: return "Failed to retrieve messages"
        }
    }
}
