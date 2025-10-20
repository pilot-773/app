//
//  MIDIHelper.swift
//  MIDIKit • https://github.com/orchetect/MIDIKit
//  © 2021-2025 Steffan Andrews • Licensed under MIT License
//  Edited by Sasha Bagrov - 20/10/2025 

import MIDIKitIO
import SwiftUI

@Observable final class MIDIHelper {
    private weak var midiManager: ObservableMIDIManager?
    
    enum RemoteAction: String, CaseIterable {
        case nextLine = "Next Line"
        case previousLine = "Previous Line"
        case goCue = "Go Cue"
        case none = "None"
    }
    
    var programChangeMapping: [Int: RemoteAction] = [:]
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
    
    // MARK: - Connection Names
    static let universalInputConnectionName = "Universal MIDI Input"
    static let usbOutputConnectionName = "USB MIDI Output"
    static let bleOutputConnectionName = "BLE MIDI Output"
    
    private func setupConnections() {
        guard let midiManager else { return }
        
        do {
            print("Creating universal MIDI input connection.")
            try midiManager.addInputConnection(
                to: .allOutputs,
                tag: Self.universalInputConnectionName,
                filter: .owned(),
                receiver: .events { [weak self] events, timeStamp, source in
                    print("MIDI from source: \(source)")
                    self?.handleMIDIEvents(events)
                }
            )
            
            print("Creating USB MIDI output connection.")
            try midiManager.addOutputConnection(
                to: .inputs(matching: [.name("IDAM MIDI Host")]),
                tag: Self.usbOutputConnectionName
            )
            
            print("Creating BLE MIDI output connection.")
            try midiManager.addOutputConnection(
                to: .allInputs,
                tag: Self.bleOutputConnectionName,
                filter: .owned()
            )
            
        } catch {
            print("Error setting up MIDI connections:", error.localizedDescription)
        }
    }
    
    // MARK: - Event Handling
    private func handleMIDIEvents(_ events: [MIDIEvent]) {
        for event in events {
            switch event {
            case .programChange(let programChange):
                handleProgramChange(program: programChange.program, channel: programChange.channel)
            case .noteOn(let noteOn):
                print("Note On: \(noteOn.note) velocity: \(noteOn.velocity)")
            case .noteOff(let noteOff):
                print("Note Off: \(noteOff.note)")
            case .cc(let cc):
                print("CC: \(cc.controller) value: \(cc.value)")
            default:
                print("Other MIDI Event: \(event)")
            }
        }
    }
    
    private func handleProgramChange(program: UInt7, channel: UInt4) {
        let programInt = Int(program)
        
        guard programInt <= 32 else {
            print("Program change \(programInt) out of range (0-32)")
            return
        }
        
        print("Received PC \(programInt) on channel \(channel)")
        
        guard let action = programChangeMapping[programInt],
              action != .none else {
            print("No action mapped for PC \(programInt)")
            return
        }
        
        print("Executing MIDI action: \(action.rawValue)")
        
        let buttonValue: String
        switch action {
        case .previousLine: buttonValue = "0"
        case .nextLine: buttonValue = "1"
        case .goCue: buttonValue = "2"
        case .none: return
        }
        
        DispatchQueue.main.async {
            self.onButtonPress?(buttonValue)
        }
    }
    
    // MARK: - Configuration
    func mapProgramChange(_ program: Int, to action: RemoteAction) {
        guard program >= 0 && program <= 32 else { return }
        programChangeMapping[program] = action
        print("Mapped PC \(program) to \(action.rawValue)")
    }
    
    func clearMapping(for program: Int) {
        programChangeMapping[program] = .none
    }
    
    // MARK: - Output Methods
    var usbOutputConnection: MIDIOutputConnection? {
        midiManager?.managedOutputConnections[Self.usbOutputConnectionName]
    }
    
    var bleOutputConnection: MIDIOutputConnection? {
        midiManager?.managedOutputConnections[Self.bleOutputConnectionName]
    }
    
    func sendNoteOnUSB() {
        try? usbOutputConnection?.send(event: .noteOn(60, velocity: .midi1(127), channel: 0))
    }
    
    func sendNoteOffUSB() {
        try? usbOutputConnection?.send(event: .noteOff(60, velocity: .midi1(0), channel: 0))
    }
    
    func sendCC1USB() {
        try? usbOutputConnection?.send(event: .cc(1, value: .midi1(64), channel: 0))
    }
    
    func sendTestMIDIEventBLE() {
        try? bleOutputConnection?.send(event: .cc(.expression, value: .midi1(64), channel: 0))
    }
    
    func sendToAll(event: MIDIEvent) {
        try? usbOutputConnection?.send(event: event)
        try? bleOutputConnection?.send(event: event)
    }
}
