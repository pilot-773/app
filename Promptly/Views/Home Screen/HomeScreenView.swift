//
//  HomeScreenView.swift
//  Promptly
//
//  Created by Sasha Bagrov on 04/06/2025.
//

import SwiftUI
import SwiftData

struct HomeScreenView: View {
    @Query var shows: [Show] = []
    
    @Environment(\.modelContext) var modelContext
    
    @State var navStackMessage: String = ""
    @State var addShow: Bool = false
    
    //MARK: - Views
    var body: some View {
        NavigationStack {
            Group {
                self.content
            }
            .navigationTitle(Text(
                self.navStackMessage
            ))
            .toolbar {
                ToolbarItemGroup {
                    self.toolbarContent
                }
            }
            .onAppear {
                self.setupGreeting()
            }
            .sheet(isPresented: self.$addShow) {
                AddShowViewWrapper()
            }
        }
    }
    
    var content: some View {
        Group {
            List {
                Section(header: Text(
                    "Select a show"
                )) {
                    if self.shows.isEmpty {
                        ContentUnavailableView(
                            "No shows saved",
                            systemImage: "xmark.circle",
                            description: Text(
                                "Start by creating a show by clicking the plus icon in the top right hand corner."
                            )
                        )
                    } else {
                        ForEach(self.shows) { show in
                            NavigationLink(destination: ShowDetailView(show: show)) {
                                Text(show.title)
                            }
                        }
                    }
                }
            }
        }
    }
    
    var toolbarContent: some View {
        Group {
            Button {
                self.addShow = true
            } label: {
                Label(
                    "Add Show",
                    systemImage: "plus"
                )
            }
        }
    }
    
    //MARK: - Functions
    private func setupGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 5 && hour < 12 {
            self.navStackMessage = "Good Morning"
        } else if hour >= 12 && hour < 17 {
            self.navStackMessage = "Good Afternoon"
        } else if hour >= 17 && hour < 21 {
            self.navStackMessage = "Good Evening"
        } else {
            self.navStackMessage = "Good Night"
        }
    }
}

#Preview {
    HomeScreenView()
}
