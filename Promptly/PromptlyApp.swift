//
//  PromptlyApp.swift
//  Promptly
//
//  Created by Sasha Bagrov on 04/06/2025.
//

import SwiftUI
import SwiftData
import MIDIKitIO
import WhatsNewKit

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
                .environment(
                    \.whatsNew,
                     .init(
                        versionStore: UserDefaultsWhatsNewVersionStore(),
                        whatsNewCollection: self
                     )
                )
        }
        .modelContainer(for: [Show.self, PerformanceReport.self])
    }
}

// MARK: - App+WhatsNewCollectionProvider
extension PromptlyApp: WhatsNewCollectionProvider {
    /// A WhatsNewCollection
    var whatsNewCollection: WhatsNewCollection {
        WhatsNew(
            version: "1.0.4",
            title: "DSMPrompt",
            features: [
                .init(
                    image: .init(
                        systemName: "square.and.arrow.down.on.square",
                        foregroundColor: .orange
                    ),
                    title: "Import & Export Show Files",
                    subtitle: "Import and export show files to have manual backups / share between members."
                ),
                .init(
                    image: .init(
                        systemName: "wand.and.stars",
                        foregroundColor: .cyan
                    ),
                    title: "What's New View",
                    subtitle: "Find out what's changed between versions."
                ),
                .init(
                    image: .init(
                        systemName: "hammer",
                        foregroundColor: .gray
                    ),
                    title: "Bug Fixes",
                    subtitle: "Bug fixes and stability improvements."
                )
            ],
            primaryAction: .init(
                hapticFeedback: {
                    #if os(iOS)
                    .notification(.success)
                    #else
                    nil
                    #endif
                }()
            ),
            secondaryAction: .init(
                title: "View on GitHub",
                action: .openURL(.init(string: "https://github.com/DSMPrompt/app/releases"))
            )
        )
    }
    
}
