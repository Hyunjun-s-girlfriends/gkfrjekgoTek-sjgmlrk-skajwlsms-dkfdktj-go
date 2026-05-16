import SwiftUI

@main
struct StudyPulsDashboardApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(WindowSizeLimiter())
        }
    }
}
