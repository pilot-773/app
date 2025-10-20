//
//  Exports.swift
//  Promptly
//
//  Created by Sasha Bagrov on 20/10/2025.
//

import Foundation
import SwiftData

class ShowExportManager {
    static func exportShow(_ show: Show) -> Data? {
        let exportData = ShowExportData(from: show)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        return try? encoder.encode(exportData)
    }
    
    static func exportShowToFile(_ show: Show, to url: URL) throws {
        guard let data = exportShow(show) else {
            throw ExportError1.serialisationFailed
        }
        try data.write(to: url)
    }
}

struct ShowExportData: Codable {
    var version: String = "1.0"
    var exportDate: Date = Date()
    
    let show: ShowData
    let script: ScriptData?
    let performances: [PerformanceData]
    
    init(from show: Show) {
        self.show = ShowData(from: show)
        self.script = show.script.map { ScriptData(from: $0) }
        self.performances = show.peformances.map { PerformanceData(from: $0) }
    }
}

struct ShowData: Codable {
    let id: String
    let title: String
    let locationString: String
    let performanceDates: [Date]
    
    init(from show: Show) {
        self.id = show.id.uuidString
        self.title = show.title
        self.locationString = show.locationString
        self.performanceDates = show.dates
    }
}

struct ScriptData: Codable {
    let id: String
    let name: String
    let dateAdded: Date
    let lines: [ScriptLineData]
    let sections: [ScriptSectionData]
    
    init(from script: Script) {
        self.id = script.id.uuidString
        self.name = script.name
        self.dateAdded = script.dateAdded
        self.lines = script.lines.map { ScriptLineData(from: $0) }
        self.sections = script.sections.map { ScriptSectionData(from: $0) }
    }
}

struct ScriptLineData: Codable {
    let id: String
    let lineNumber: Int
    let content: String
    let flags: [String]
    let elements: [LineElementData]
    let cues: [CueData]
    let isMarked: Bool
    let markColor: String?
    let notes: String
    
    init(from line: ScriptLine) {
        self.id = line.id.uuidString
        self.lineNumber = line.lineNumber
        self.content = line.content
        self.flags = line.flags.map { $0.rawValue }
        self.elements = line.elements.map { LineElementData(from: $0) }
        self.cues = line.cues.map { CueData(from: $0) }
        self.isMarked = line.isMarked
        self.markColor = line.markColor
        self.notes = line.notes
    }
}

struct ScriptSectionData: Codable {
    let id: String
    let title: String
    let type: String
    let startLineNumber: Int
    let endLineNumber: Int?
    let notes: String
    
    init(from section: ScriptSection) {
        self.id = section.id.uuidString
        self.title = section.title
        self.type = section.type.rawValue
        self.startLineNumber = section.startLineNumber
        self.endLineNumber = section.endLineNumber
        self.notes = section.notes
    }
}

struct LineElementData: Codable {
    let id: String
    let position: Int
    let content: String
    let type: String
    let isMarked: Bool
    let markColor: String?
    
    init(from element: LineElement) {
        self.id = element.id.uuidString
        self.position = element.position
        self.content = element.content
        self.type = element.type.rawValue
        self.isMarked = element.isMarked
        self.markColor = element.markColor
    }
}

struct CueData: Codable {
    let id: String
    let lineId: String
    let position: CuePositionData
    let type: String
    let label: String
    let notes: String
    let hasAlert: Bool
    let alertSound: String?
    
    init(from cue: Cue) {
        self.id = cue.id.uuidString
        self.lineId = cue.lineId.uuidString
        self.position = CuePositionData(from: cue.position)
        self.type = cue.type.rawValue
        self.label = cue.label
        self.notes = cue.notes
        self.hasAlert = cue.hasAlert
        self.alertSound = cue.alertSound
    }
}

struct CuePositionData: Codable {
    let elementIndex: Int
    let offset: String
    
    init(from position: CuePosition) {
        self.elementIndex = position.elementIndex
        self.offset = position.offset.rawValue
    }
}

struct PerformanceData: Codable {
    let id: String
    let date: Date
    let calls: [PerformanceCallData]
    let timing: PerformanceTimingData?
    
    init(from performance: Performance) {
        self.id = performance.id.uuidString
        self.date = performance.date
        self.calls = performance.calls.map { PerformanceCallData(from: $0) }
        self.timing = performance.timing.map { PerformanceTimingData(from: $0) }
    }
}

struct PerformanceCallData: Codable {
    let id: String
    let title: String
    let call: CallTypeData
    
    init(from call: PerformanceCall) {
        self.id = call.id.uuidString
        self.title = call.title
        self.call = CallTypeData(from: call.call)
    }
}

struct CallTypeData: Codable {
    let type: String
    let value: String?
    let date: Date?
    
    init(from callType: CallType) {
        switch callType {
        case .preShow(let preShowCall):
            self.type = "preShow"
            self.value = preShowCall.rawValue
            self.date = nil
        case .interval(let intervalCall):
            self.type = "interval"
            self.value = intervalCall.rawValue
            self.date = nil
        case .houseManagement(let houseCall):
            self.type = "houseManagement"
            self.value = houseCall.rawValue
            self.date = nil
        case .custom(let customDate):
            self.type = "custom"
            self.value = nil
            self.date = customDate
        }
    }
}

struct PerformanceTimingData: Codable {
    let id: String
    let curtainTime: Date
    let houseOpenTime: Date?
    let houseOpenPlanned: Date?
    let clearanceTime: Date?
    let acts: [ActData]
    let intervals: [IntervalData]
    let callSettings: CallSettingsData
    let currentState: PerformanceStateData
    let startTime: Date?
    let endTime: Date?
    let actTimings: [ActTimingData]
    let showStops: [ShowStopData]
    
    init(from timing: PerformanceTiming) {
        self.id = timing.id.uuidString
        self.curtainTime = timing.curtainTime
        self.houseOpenTime = timing.houseOpenTime
        self.houseOpenPlanned = timing.houseOpenPlanned
        self.clearanceTime = timing.clearanceTime
        self.acts = timing.acts.map { ActData(from: $0) }
        self.intervals = timing.intervals.map { IntervalData(from: $0) }
        self.callSettings = CallSettingsData(from: timing.callSettings)
        self.currentState = PerformanceStateData(from: timing.currentState)
        self.startTime = timing.startTime
        self.endTime = timing.endTime
        self.actTimings = timing.actTimings.map { ActTimingData(from: $0) }
        self.showStops = timing.showStops.map { ShowStopData(from: $0) }
    }
}

struct ActData: Codable {
    let id: String
    let number: Int
    let name: String
    let startTime: Date?
    let endTime: Date?
    let includeInRunningTime: Bool
    
    init(from act: Act) {
        self.id = act.id.uuidString
        self.number = act.number
        self.name = act.name
        self.startTime = act.startTime
        self.endTime = act.endTime
        self.includeInRunningTime = act.includeInRunningTime
    }
}

struct IntervalData: Codable {
    let id: String
    let number: Int
    let name: String
    let plannedDuration: TimeInterval
    let actualDuration: TimeInterval?
    let startTime: Date?
    let endTime: Date?
    
    init(from interval: Interval) {
        self.id = interval.id.uuidString
        self.number = interval.number
        self.name = interval.name
        self.plannedDuration = interval.plannedDuration
        self.actualDuration = interval.actualDuration
        self.startTime = interval.startTime
        self.endTime = interval.endTime
    }
}

struct CallSettingsData: Codable {
    let halfTime: TimeInterval
    let quarterTime: TimeInterval
    let fiveTime: TimeInterval
    let beginnersTime: TimeInterval
    let houseOpenOffset: TimeInterval
    let clearanceOffset: TimeInterval
    let enableSoundAlerts: Bool
    let customMessage: String
    
    init(from settings: CallSettings) {
        self.halfTime = settings.halfTime
        self.quarterTime = settings.quarterTime
        self.fiveTime = settings.fiveTime
        self.beginnersTime = settings.beginnersTime
        self.houseOpenOffset = settings.houseOpenOffset
        self.clearanceOffset = settings.clearanceOffset
        self.enableSoundAlerts = settings.enableSoundAlerts
        self.customMessage = settings.customMessage
    }
}

struct PerformanceStateData: Codable {
    let type: String
    let value: Int?
    
    init(from state: PerformanceState) {
        switch state {
        case .preShow:
            self.type = "preShow"
            self.value = nil
        case .houseOpen:
            self.type = "houseOpen"
            self.value = nil
        case .clearance:
            self.type = "clearance"
            self.value = nil
        case .inProgress(let actNumber):
            self.type = "inProgress"
            self.value = actNumber
        case .interval(let intervalNumber):
            self.type = "interval"
            self.value = intervalNumber
        case .completed:
            self.type = "completed"
            self.value = nil
        case .stopped:
            self.type = "stopped"
            self.value = nil
        }
    }
}

struct ActTimingData: Codable {
    let id: String
    let actNumber: Int
    let startTime: Date
    let endTime: Date?
    
    init(from timing: ActTiming) {
        self.id = timing.id.uuidString
        self.actNumber = timing.actNumber
        self.startTime = timing.startTime
        self.endTime = timing.endTime
    }
}

struct ShowStopData: Codable {
    let id: String
    let timestamp: Date
    let reason: String
    let duration: TimeInterval?
    let actNumber: Int
    
    init(from stop: ShowStop) {
        self.id = stop.id.uuidString
        self.timestamp = stop.timestamp
        self.reason = stop.reason
        self.duration = stop.duration
        self.actNumber = stop.actNumber
    }
}

enum ExportError1: Error {
    case serialisationFailed
    case invalidFileFormat
    case unsupportedVersion
}

extension PreShowCall {
    var rawValue: String {
        switch self {
        case .half: return "half"
        case .quarter: return "quarter"
        case .five: return "five"
        case .beginners: return "beginners"
        case .places: return "places"
        }
    }
    
    init?(rawValue: String) {
        switch rawValue {
        case "half": self = .half
        case "quarter": self = .quarter
        case "five": self = .five
        case "beginners": self = .beginners
        case "places": self = .places
        default: return nil
        }
    }
}

extension IntervalCall {
    var rawValue: String {
        switch self {
        case .half: return "half"
        case .quarter: return "quarter"
        case .five: return "five"
        case .beginners: return "beginners"
        }
    }
    
    init?(rawValue: String) {
        switch rawValue {
        case "half": self = .half
        case "quarter": self = .quarter
        case "five": self = .five
        case "beginners": self = .beginners
        default: return nil
        }
    }
}

extension HouseCall {
    var rawValue: String {
        switch self {
        case .houseOpen: return "houseOpen"
        case .clearance: return "clearance"
        }
    }
    
    init?(rawValue: String) {
        switch rawValue {
        case "houseOpen": self = .houseOpen
        case "clearance": self = .clearance
        default: return nil
        }
    }
}
