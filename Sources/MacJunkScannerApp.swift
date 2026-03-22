import SwiftUI

@main
struct MacJunkScannerApp: App {
    @StateObject private var viewModel = JunkScannerViewModel()

    var body: some Scene {
        WindowGroup("Mac 垃圾扫描") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 980, minHeight: 680)
                .preferredColorScheme(.light)
        }
        .windowResizability(.contentSize)
    }
}
