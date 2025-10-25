//
//  Imports.swift
//  Promptly
//
//  Created by Sasha Bagrov on 20/10/2025.
//

import Foundation
import SwiftData

class ShowImportManager {
    static func importShow(from data: Data, into context: ModelContext) throws -> Show {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let exportData = try decoder.decode(ShowExportData.self, from: data)
        
        let show = Show()
        show.id = UUID()
        show.title = exportData.show.title
        show.locationString = exportData.show.locationString
        show.dates = exportData.show.performanceDates
        
        context.insert(show)
        
        if let scriptData = exportData.script {
            let script = try createScript(from: scriptData, context: context)
            show.script = script
        }
        
        for perfData in exportData.performances {
            let performance = try createPerformance(from: perfData, show: show, context: context)
            show.peformances.append(performance)
        }
        
        return show
    }
    
    static func importShowFromFile(from url: URL, into context: ModelContext) throws -> Show {
        let data = try Data(contentsOf: url)
        return try importShow(from: data, into: context)
    }
    
    private static func createScript(from data: ScriptData, context: ModelContext) throws -> Script {
        let script = Script(
            id: UUID(),
            name: data.name,
            dateAdded: data.dateAdded
        )
        
        context.insert(script)
        
        for sectionData in data.sections {
            let section = ScriptSection(
                id: UUID(),
                title: sectionData.title,
                type: SectionType(rawValue: sectionData.type) ?? .custom,
                startLineNumber: sectionData.startLineNumber
            )
            section.endLineNumber = sectionData.endLineNumber
            section.notes = sectionData.notes
            
            context.insert(section)
            script.sections.append(section)
        }
        
        for lineData in data.lines {
            let line = ScriptLine(
                id: UUID(),
                lineNumber: lineData.lineNumber,
                content: lineData.content,
                flags: lineData.flags.compactMap { ScriptLineFlags(rawValue: $0) }
            )
            
            line.isMarked = lineData.isMarked
            line.markColor = lineData.markColor
            line.notes = lineData.notes
            
            context.insert(line)
            
            for elementData in lineData.elements {
                let element = LineElement(
                    id: UUID(),
                    position: elementData.position,
                    content: elementData.content,
                    type: ElementType(rawValue: elementData.type) ?? .word
                )
                element.isMarked = elementData.isMarked
                element.markColor = elementData.markColor
                
                context.insert(element)
                line.elements.append(element)
            }
            
            for cueData in lineData.cues {
                let cue = Cue(
                    id: UUID(),
                    lineId: line.id,
                    position: CuePosition(
                        elementIndex: cueData.position.elementIndex,
                        offset: CueOffset(rawValue: cueData.position.offset) ?? .after
                    ),
                    type: CueType(rawValue: cueData.type) ?? .lightingGo,
                    label: cueData.label
                )
                cue.notes = cueData.notes
                cue.hasAlert = cueData.hasAlert
                cue.alertSound = cueData.alertSound
                
                context.insert(cue)
                line.cues.append(cue)
            }
            
            script.lines.append(line)
        }
        
        return script
    }
    
    private static func createPerformance(from data: PerformanceData, show: Show, context: ModelContext) throws -> Performance {
        let performance = Performance(
            id: UUID(),
            date: data.date,
            calls: [],
            timing: nil,
            show: show
        )
        
        context.insert(performance)
        
        for callData in data.calls {
            let call = PerformanceCall(
                id: UUID(),
                title: callData.title,
                call: createCallType(from: callData.call)
            )
            
            context.insert(call)
            performance.calls.append(call)
        }
        
        if let timingData = data.timing {
            let timing = try createPerformanceTiming(from: timingData, context: context)
            performance.timing = timing
        }
        
        return performance
    }
    
    private static func createCallType(from data: CallTypeData) -> CallType {
        switch data.type {
        case "preShow":
            if let value = data.value, let preShowCall = PreShowCall(rawValue: value) {
                return .preShow(preShowCall)
            }
            return .preShow(.half)
        case "interval":
            if let value = data.value, let intervalCall = IntervalCall(rawValue: value) {
                return .interval(intervalCall)
            }
            return .interval(.half)
        case "houseManagement":
            if let value = data.value, let houseCall = HouseCall(rawValue: value) {
                return .houseManagement(houseCall)
            }
            return .houseManagement(.houseOpen)
        case "custom":
            if let date = data.date {
                return .custom(date)
            }
            return .custom(Date())
        default:
            return .preShow(.half)
        }
    }
    
    private static func createPerformanceTiming(from data: PerformanceTimingData, context: ModelContext) throws -> PerformanceTiming {
        let callSettings = CallSettings(
            halfTime: data.callSettings.halfTime,
            quarterTime: data.callSettings.quarterTime,
            fiveTime: data.callSettings.fiveTime,
            beginnersTime: data.callSettings.beginnersTime,
            houseOpenOffset: data.callSettings.houseOpenOffset,
            clearanceOffset: data.callSettings.clearanceOffset,
            enableSoundAlerts: data.callSettings.enableSoundAlerts,
            customMessage: data.callSettings.customMessage
        )
        
        context.insert(callSettings)
        
        let currentState = createPerformanceState(from: data.currentState)
        
        let timing = PerformanceTiming(
            id: UUID(),
            curtainTime: data.curtainTime,
            houseOpenTime: data.houseOpenTime,
            houseOpenPlanned: data.houseOpenPlanned,
            clearanceTime: data.clearanceTime,
            acts: [],
            intervals: [],
            callSettings: callSettings,
            currentState: currentState,
            startTime: data.startTime,
            endTime: data.endTime,
            actTimings: [],
            showStops: []
        )
        
        context.insert(timing)
        
        for actData in data.acts {
            let act = Act(number: actData.number, name: actData.name)
            act.id = UUID()
            act.startTime = actData.startTime
            act.endTime = actData.endTime
            act.includeInRunningTime = actData.includeInRunningTime
            
            context.insert(act)
            timing.acts.append(act)
        }
        
        for intervalData in data.intervals {
            let interval = Interval(number: intervalData.number, plannedDuration: intervalData.plannedDuration)
            interval.id = UUID()
            interval.name = intervalData.name
            interval.actualDuration = intervalData.actualDuration
            interval.startTime = intervalData.startTime
            interval.endTime = intervalData.endTime
            
            context.insert(interval)
            timing.intervals.append(interval)
        }
        
        for timingData in data.actTimings {
            let actTiming = ActTiming(
                actNumber: timingData.actNumber,
                startTime: timingData.startTime
            )
            actTiming.id = UUID()
            actTiming.endTime = timingData.endTime
            
            context.insert(actTiming)
            timing.actTimings.append(actTiming)
        }
        
        for stopData in data.showStops {
            let showStop = ShowStop(
                timestamp: stopData.timestamp,
                reason: stopData.reason,
                actNumber: stopData.actNumber
            )
            showStop.id = UUID()
            showStop.duration = stopData.duration
            
            context.insert(showStop)
            timing.showStops.append(showStop)
        }
        
        return timing
    }
    
    private static func createPerformanceState(from data: PerformanceStateData) -> PerformanceState {
        switch data.type {
        case "preShow":
            return .preShow
        case "houseOpen":
            return .houseOpen
        case "clearance":
            return .clearance
        case "inProgress":
            if let actNumber = data.value {
                return .inProgress(actNumber: actNumber)
            }
            return .preShow
        case "interval":
            if let intervalNumber = data.value {
                return .interval(intervalNumber: intervalNumber)
            }
            return .preShow
        case "completed":
            return .completed
        case "stopped":
            return .stopped
        default:
            return .preShow
        }
    }
}

enum ImportError: Error {
    case invalidFileFormat
    case corruptedData
    case unsupportedVersion
    case missingRequiredFields
}
