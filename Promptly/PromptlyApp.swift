//
//  PromptlyApp.swift
//  Promptly
//
//  Created by Sasha Bagrov on 04/06/2025.
//

import SwiftUI
import SwiftData
import MIDIKitIO


@main
struct PromptlyApp: App {
    @State var midiManager = ObservableMIDIManager(
        clientName: "DSMPromptMIDIManager",
        model: "DSMPrompt",
        manufacturer: "UrbanMechanicsLTD"
    )
    
    @State var midiHelper = MIDIHelper()

    init() {
        #if !os(macOS)
        UIScrollView.appearance().scrollsToTop = false
        #endif
        if UserDefaults.standard.string(forKey: "deviceUUID") == nil {
            UserDefaults.standard.set(UUID().uuidString, forKey: "deviceUUID")
        }
        
        midiHelper.setup(midiManager: midiManager)
    }
    
    var body: some Scene {
        WindowGroup {
            HomeScreenView()
                .environment(midiManager)
                .environment(midiHelper)
        }
        .modelContainer(for: [Show.self, PerformanceReport.self])
    }
}
