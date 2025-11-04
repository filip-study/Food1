//
//  Food1App.swift
//  Food1
//
//  Created by Filip Olszak on 3/11/25.
//

import SwiftUI
import SwiftData

@main
struct Food1App: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([Meal.self])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(modelContainer)
    }
}
