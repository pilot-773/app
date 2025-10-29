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
            version: "1.0.7",
            title: "DSMPrompt",
            features: [
                .init(
                    image: .init(
                        systemName: "hammer",
                        foregroundColor: .gray
                    ),
                    title: "Bug Fixes and reverted features!",
                    subtitle: "Whoops! We fixed all the issues in the latest version."
                ),
                .init(
                    image: .init(
                        systemName: "hammer",
                        foregroundColor: .red
                    ),
                    title: "Still has exports / imports",
                    subtitle: "Only the scripts changed. Essentially - 1.0.4 + 1.0.3 = 1.0.6?"
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
