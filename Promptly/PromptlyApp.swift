//
//  PromptlyApp.swift
//  Promptly
//
//  Created by Sasha Bagrov on 04/06/2025.
//

import SwiftUI
import SwiftData

@main
struct PromptlyApp: App {
    init() {
        UIScrollView.appearance().scrollsToTop = false
    }
    
    var body: some Scene {
        WindowGroup {
            HomeScreenView()
        }
        .modelContainer(for: [Show.self, PerformanceReport.self])
    }
}
