//
//  MIDIHelper.swift
//  MIDIKit • https://github.com/orchetect/MIDIKit
//  © 2021-2025 Steffan Andrews • Licensed under MIT License
//

import MIDIKitIO
import SwiftUI

/// Receiving MIDI happens on an asynchronous background thread. That means it cannot update
/// SwiftUI view state directly. Therefore, we need a helper class marked with `@Observable`
/// which contains properties that SwiftUI can use to update views.
@Observable final class MIDIHelper {
    private weak var midiManager: ObservableMIDIManager?
    
    // MIDI Action Types (matching your existing remote actions)
    enum RemoteAction: String, CaseIterable {
        case nextLine = "Next Line"
        case previousLine = "Previous Line"
        case goCue = "Go Cue"
        case none = "None"
    }
    
    // User-configurable mapping: Program Change number -> Action
    var programChangeMapping: [Int: RemoteAction] = [:]
    
    // Callback to execute remote functions (same pattern as bluetoothManager)
    var onButtonPress: ((String) -> Void)?
    
    public init() { }
    
    public func setup(midiManager: ObservableMIDIManager) {
        self.midiManager = midiManager
        
        do {
            print("Starting MIDI services.")
            try midiManager.start()
        } catch {
            print("Error starting MIDI services:", error.localizedDescription)
        }
        
        setupConnections()
    }
    
    private func setupConnections() {
        guard let midiManager else { return }
        
        do {
            try midiManager.addInputConnection(
                to: .allOutputs,
                tag: "Listener",
                filter: .owned(),
                receiver: .events { [weak self] events,_,_  in
                    self?.handleMIDIEvents(events)
                }
            )
        } catch {
            print("Error setting up MIDI connection:", error.localizedDescription)
        }
        
        // Keep your broadcaster
        do {
            try midiManager.addOutputConnection(
                to: .allInputs,
                tag: "Broadcaster",
                filter: .owned()
            )
        } catch {
            print("Error setting up broadcaster connection:", error.localizedDescription)
        }
    }
    
    private func handleMIDIEvents(_ events: [MIDIEvent]) {
        for event in events {
            switch event {
            case .programChange(let programChange):
                handleProgramChange(program: programChange.program, channel: programChange.channel)
            default:
                // Log other events for debugging
                print("MIDI Event: \(event)")
            }
        }
    }
    
    private func handleProgramChange(program: UInt7, channel: UInt4) {
        let programInt = Int(program)
        
        // Only handle program changes 0-32
        guard programInt <= 32 else {
            print("Program change \(programInt) out of range (0-32)")
            return
        }
        
        print("Received PC \(programInt) on channel \(channel)")
        
        // Check if user has mapped this program change to an action
        guard let action = programChangeMapping[programInt],
              action != .none else {
            print("No action mapped for PC \(programInt)")
            return
        }
        
        print("Executing MIDI action: \(action.rawValue)")
        
        // Convert to the same format as your Bluetooth remote
        let buttonValue: String
        switch action {
        case .previousLine:
            buttonValue = "0"
        case .nextLine:
            buttonValue = "1"
        case .goCue:
            buttonValue = "2"
        case .none:
            return
        }
        
        // Execute on main thread using the same callback pattern
        DispatchQueue.main.async {
            self.onButtonPress?(buttonValue)
        }
    }
    
    // Configuration methods
    func mapProgramChange(_ program: Int, to action: RemoteAction) {
        guard program >= 0 && program <= 32 else { return }
        programChangeMapping[program] = action
        print("Mapped PC \(program) to \(action.rawValue)")
    }
    
    func clearMapping(for program: Int) {
        programChangeMapping[program] = .none
    }
    
    func sendTestMIDIEvent() {
        let conn = midiManager?.managedOutputConnections["Broadcaster"]
        try? conn?.send(event: .cc(.expression, value: .midi1(64), channel: 0))
    }
}
