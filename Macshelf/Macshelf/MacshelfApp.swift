import SwiftUI

@main
struct MacshelfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No window from SwiftUI — the floating NSPanel is managed by AppDelegate.
        Settings { EmptyView() }
    }
}
